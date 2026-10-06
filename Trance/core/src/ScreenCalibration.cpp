#include "../lib/ScreenCalibration.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <iostream>
#include <mutex>
#include <optional>

namespace trance {
namespace {

constexpr int samplesPerPoint = 45;
constexpr int maximumCalibrationCandidates = 2 * samplesPerPoint;
constexpr double maximumCalibrationSampleGap = 1.5;
constexpr double maximumCalibrationError = 0.1;
constexpr double maximumRetryCandidateDifference = 0.02;
constexpr double maximumEyeToScreenDistance = 1.5;
constexpr double minimumGazeSpan = 0.001;
ScreenCalibrationStatus calibrationStatus;

bool rejectCalibration(ScreenCalibrationFailure failure, const char *reason,
                       double value, double limit = 0) {
  calibrationStatus.failure = failure;
  calibrationStatus.measuredValue = value;
  calibrationStatus.limit = limit;
  std::cout << "Trance screen calibration failed: " << reason
            << ", value=" << value;
  if (calibrationStatus.pointIndex >= 0)
    std::cout << ", point=" << calibrationStatus.pointIndex + 1;
  if (calibrationStatus.retryPointIndex >= 0)
    std::cout << ", retry point=" << calibrationStatus.retryPointIndex + 1;
  if (limit > 0)
    std::cout << ", limit=" << limit;
  std::cout << '\n' << std::flush;
  return false;
}

std::optional<ScreenVector3> cameraPlanePosition(EyePose eye) {
  ScreenRectangle plane;
  plane.available = true;
  plane.horizontal = {1, 0, 0};
  plane.vertical = {0, 1, 0};
  plane.pixelWidth = plane.pixelHeight = 2;

  const auto hit = intersectScreen(plane, eye.origin, eye.zAxis);
  if (!hit.available ||
      length(hit.position - eye.origin) > maximumEyeToScreenDistance)
    return std::nullopt;
  return hit.position;
}

bool fresh(EyeTrackingSample sample, double now) {
  const double age = now - sample.timestamp;
  return sample.available && std::isfinite(now) &&
         std::isfinite(sample.timestamp) && age >= 0 &&
         age <= maximumGazeSampleAge;
}

bool openEye(double closure) {
  return std::isfinite(closure) && closure >= 0 && closure < 0.5;
}

struct CalibrationObservation {
  ScreenVector3 left, right;
};

struct CalibrationPoint {
  int count = 0;
  int candidateCount = 0;
  double x = 0, y = 0;
  double lastTimestamp = 0;
  ScreenVector3 sum;
  double squaredDistanceSum = 0;
  ScreenVector3 leftSum, rightSum;
  std::array<CalibrationObservation, maximumCalibrationCandidates> observations;
};

std::mutex trackingMutex;
std::array<CalibrationPoint, 5> calibrationPoints;
ScreenRectangle calibratedScreen;
ScreenRectangle leftCalibration, rightCalibration;
ScreenGaze latestGaze;
int calibrationWidth = 0, calibrationHeight = 0;

double median(std::array<double, maximumCalibrationCandidates> values,
              int count) {
  auto middle = values.begin() + count / 2;
  std::nth_element(values.begin(), middle, values.begin() + count);
  if (count % 2 != 0)
    return *middle;
  return (*middle + *std::max_element(values.begin(), middle)) * 0.5;
}

void summarizePoint(CalibrationPoint &point) {
  std::array<std::array<double, maximumCalibrationCandidates>, 4> coordinates{};
  for (int index = 0; index < point.candidateCount; ++index) {
    const auto &sample = point.observations[index];
    coordinates[0][index] = sample.left.x;
    coordinates[1][index] = sample.left.y;
    coordinates[2][index] = sample.right.x;
    coordinates[3][index] = sample.right.y;
  }
  std::array<double, 4> centers{}, limits{};
  for (int axis = 0; axis < 4; ++axis) {
    centers[axis] = median(coordinates[axis], point.candidateCount);
    for (int index = 0; index < point.candidateCount; ++index)
      coordinates[axis][index] =
          std::abs(coordinates[axis][index] - centers[axis]);
    limits[axis] =
        std::max(4.5 * median(coordinates[axis], point.candidateCount), 1e-5);
  }

  point.count = 0;
  point.sum = point.leftSum = point.rightSum = {};
  point.squaredDistanceSum = 0;
  for (int index = point.candidateCount - 1;
       index >= 0 && point.count < samplesPerPoint; --index) {
    bool inlier = true;
    for (int axis = 0; axis < 4; ++axis)
      inlier = inlier && coordinates[axis][index] <= limits[axis];
    if (!inlier)
      continue;
    const auto &sample = point.observations[index];
    const auto position = (sample.left + sample.right) * 0.5;
    point.leftSum = point.leftSum + sample.left;
    point.rightSum = point.rightSum + sample.right;
    point.sum = point.sum + position;
    point.squaredDistanceSum += dot(position, position);
    ++point.count;
  }
}

ScreenVector3 pointMean(const CalibrationPoint &point, int eye) {
  const double weight = 1.0 / point.count;
  if (eye == 0)
    return point.leftSum * weight;
  if (eye == 1)
    return point.rightSum * weight;
  return point.sum * weight;
}

std::optional<std::array<ScreenVector3, 3>> fitRectangle(int eye) {
  std::array<ScreenVector3, 5> positions;
  ScreenVector3 center;
  for (int index = 0; index < 5; ++index) {
    const auto &point = calibrationPoints[index];
    if (point.count < samplesPerPoint)
      return std::nullopt;
    positions[index] = pointMean(point, eye);
    center = center + positions[index];
  }

  const auto &middle = calibrationPoints[0];
  const auto &topLeft = calibrationPoints[1], &topRight = calibrationPoints[2];
  const auto &bottomRight = calibrationPoints[3],
             &bottomLeft = calibrationPoints[4];
  const double width = topRight.x - topLeft.x;
  const double height = bottomLeft.y - topLeft.y;
  if (width <= 0 || height <= 0 || middle.x != 0.5 || middle.y != 0.5 ||
      topLeft.x != bottomLeft.x || topRight.x != bottomRight.x ||
      topLeft.y != topRight.y || bottomLeft.y != bottomRight.y ||
      std::abs(topLeft.x + topRight.x - 1) > 1e-9 ||
      std::abs(topLeft.y + bottomLeft.y - 1) > 1e-9)
    return std::nullopt;

  const auto horizontal =
      (positions[2] + positions[3] - positions[1] - positions[4]) *
      (0.5 / width);
  const auto vertical =
      (positions[3] + positions[4] - positions[1] - positions[2]) *
      (0.5 / height);
  return std::array{center * 0.2, horizontal, vertical};
}

ScreenVector3 screenPosition(ScreenRectangle screen, double x, double y) {
  return screen.topLeft + screen.horizontal * x + screen.vertical * y;
}

ScreenHit eyeHit(EyePose eye, double closure, ScreenRectangle calibration,
                 ScreenRectangle &screen) {
  screen = openEye(closure) ? screenRelativeToEye(calibration, eye)
                            : ScreenRectangle{};
  return intersectScreen(screen, {}, {0, 0, 1});
}

std::optional<ScreenRectangle> fitPixelMapping(ScreenRectangle screen, int eye,
                                               int excludedPoint = -1) {
  std::array<std::array<double, 5>, 3> equations{};
  for (int index = 0; index < 5; ++index) {
    if (index == excludedPoint)
      continue;
    const auto &point = calibrationPoints[index];
    const auto mean = pointMean(point, eye);
    const auto hit =
        intersectScreen(screen, mean + ScreenVector3{0, 0, 1}, {0, 0, -1});
    if (!hit.available)
      return std::nullopt;
    const std::array features{hit.x / (screen.pixelWidth - 1),
                              hit.y / (screen.pixelHeight - 1), 1.0};
    for (int row = 0; row < 3; ++row) {
      for (int column = 0; column < 3; ++column)
        equations[row][column] += features[row] * features[column];
      equations[row][3] += features[row] * point.x;
      equations[row][4] += features[row] * point.y;
    }
  }
  for (int column = 0; column < 3; ++column) {
    int pivot = column;
    for (int row = column + 1; row < 3; ++row)
      if (std::abs(equations[row][column]) > std::abs(equations[pivot][column]))
        pivot = row;
    const double divisor = equations[pivot][column];
    if (!std::isfinite(divisor) || std::abs(divisor) < 1e-9)
      return std::nullopt;
    std::swap(equations[column], equations[pivot]);
    for (double &coefficient : equations[column])
      coefficient /= divisor;
    for (int row = 0; row < 3; ++row) {
      if (row == column)
        continue;
      const double factor = equations[row][column];
      for (int index = 0; index < 5; ++index)
        equations[row][index] -= factor * equations[column][index];
    }
  }
  const double a = equations[0][3], b = equations[1][3];
  const double c = equations[0][4], d = equations[1][4];
  const double e = equations[2][3], f = equations[2][4];
  const double determinant = a * d - b * c;
  if (!std::isfinite(determinant) || std::abs(determinant) < 1e-9)
    return std::nullopt;
  const auto horizontal = screen.horizontal, vertical = screen.vertical;
  screen.topLeft = screen.topLeft +
                   horizontal * ((b * f - d * e) / determinant) +
                   vertical * ((c * e - a * f) / determinant);
  screen.horizontal = (horizontal * d - vertical * c) * (1 / determinant);
  screen.vertical = (vertical * a - horizontal * b) * (1 / determinant);
  if (!finite(screen.topLeft) || !finite(screen.horizontal) ||
      !finite(screen.vertical))
    return std::nullopt;
  return screen;
}

double mappingError(ScreenRectangle screen, const CalibrationPoint &point,
                    int eye) {
  const auto mean = pointMean(point, eye);
  const auto hit =
      intersectScreen(screen, mean + ScreenVector3{0, 0, 1}, {0, 0, -1});
  return hit.available ? std::hypot(hit.x / (screen.pixelWidth - 1) - point.x,
                                    hit.y / (screen.pixelHeight - 1) - point.y)
                       : INFINITY;
}

int retryPoint(ScreenRectangle screen, int eye, int fallback) {
  int result = fallback;
  double bestError = INFINITY;
  std::array<double, 5> errors;
  errors.fill(INFINITY);
  for (int excluded = 0; excluded < 5; ++excluded) {
    const auto mapping = fitPixelMapping(screen, eye, excluded);
    if (!mapping)
      continue;
    double squaredError = 0;
    for (int index = 0; index < 5; ++index) {
      if (index == excluded)
        continue;
      const double error =
          mappingError(*mapping, calibrationPoints[index], eye);
      squaredError += error * error;
    }
    errors[excluded] = std::sqrt(squaredError / 4);
    if (errors[excluded] < bestError) {
      bestError = errors[excluded];
      result = excluded;
    }
  }
  calibrationStatus.retryPointMask = 0;
  if (std::isfinite(bestError)) {
    for (int index = 0; index < 5; ++index) {
      if (errors[index] <= bestError + maximumRetryCandidateDifference)
        calibrationStatus.retryPointMask |= 1 << index;
    }
  }
  if (calibrationStatus.retryPointMask & (1 << fallback))
    result = fallback;
  return result;
}

std::optional<ScreenRectangle> fitCalibration(int eye) {
  const auto coefficients = fitRectangle(eye);
  if (!coefficients) {
    rejectCalibration(ScreenCalibrationFailure::layout,
                      "invalid five-point target layout", 0);
    return std::nullopt;
  }

  const auto center = (*coefficients)[0];
  const auto horizontal = (*coefficients)[1];
  const auto vertical = (*coefficients)[2];
  const double width = length(horizontal), height = length(vertical);
  const char *label = eye == 0 ? "left" : eye == 1 ? "right" : "combined";
  std::cout << "Trance screen calibration fit (" << label << "): center(m)=("
            << center.x << ", " << center.y << ", " << center.z
            << "), gaze span=" << width << 'x' << height << " m\n"
            << std::flush;
  if (!finite(center) || !finite(horizontal) || width < minimumGazeSpan) {
    rejectCalibration(ScreenCalibrationFailure::width,
                      "horizontal gaze span is too small (m)", width,
                      minimumGazeSpan);
    return std::nullopt;
  }
  if (!finite(vertical) || height < minimumGazeSpan) {
    rejectCalibration(ScreenCalibrationFailure::height,
                      "vertical gaze span is too small (m)", height,
                      minimumGazeSpan);
    return std::nullopt;
  }
  const double axisSeparation =
      length(cross(horizontal, vertical)) / (width * height);
  if (!std::isfinite(axisSeparation) || axisSeparation < 0.05) {
    rejectCalibration(ScreenCalibrationFailure::axes,
                      "gaze axes cannot be distinguished", axisSeparation,
                      0.05);
    return std::nullopt;
  }

  ScreenRectangle screen;
  screen.available = true;
  screen.topLeft = center - (horizontal + vertical) * 0.5;
  screen.horizontal = horizontal;
  screen.vertical = vertical;
  screen.pixelWidth = calibrationWidth;
  screen.pixelHeight = calibrationHeight;

  const auto mapping = fitPixelMapping(screen, eye);
  if (!mapping) {
    rejectCalibration(ScreenCalibrationFailure::axes,
                      "screen mapping is singular", 0);
    return std::nullopt;
  }
  screen = *mapping;

  double squaredError = 0, normalizedSquaredError = 0;
  double largestError = 0;
  int worstPoint = 0;
  for (int index = 0; index < 5; ++index) {
    const auto &point = calibrationPoints[index];
    const auto mean = pointMean(point, eye);
    const double error =
        length(screenPosition(screen, point.x, point.y) - mean);
    const double normalizedError = mappingError(screen, point, eye);
    if (normalizedError > largestError) {
      largestError = normalizedError;
      worstPoint = index;
    }
    squaredError += error * error;
    normalizedSquaredError += normalizedError * normalizedError;
  }
  if (largestError > 2 * maximumCalibrationError) {
    calibrationStatus.pointIndex = worstPoint;
    calibrationStatus.retryPointIndex = retryPoint(screen, eye, worstPoint);
    calibrationStatus.sampleCount = calibrationPoints[worstPoint].count;
    rejectCalibration(ScreenCalibrationFailure::pointError,
                      "point mapping error exceeds limit", largestError,
                      2 * maximumCalibrationError);
    return std::nullopt;
  }
  screen.calibrationError = std::sqrt(squaredError / calibrationPoints.size());
  screen.normalizedCalibrationError =
      std::sqrt(normalizedSquaredError / calibrationPoints.size());
  if (!std::isfinite(screen.normalizedCalibrationError) ||
      screen.normalizedCalibrationError > maximumCalibrationError) {
    calibrationStatus.pointIndex = worstPoint;
    calibrationStatus.retryPointIndex = retryPoint(screen, eye, worstPoint);
    calibrationStatus.sampleCount = calibrationPoints[worstPoint].count;
    rejectCalibration(
        ScreenCalibrationFailure::meanError, "mean mapping error exceeds limit",
        screen.normalizedCalibrationError, maximumCalibrationError);
    return std::nullopt;
  }
  return screen;
}

} // namespace

ScreenVector3 screenGridPoint(ScreenRectangle screen, int column, int row) {
  if (!screen.available || screen.pixelWidth < 2 || screen.pixelHeight < 2 ||
      column < 0 || row < 0 || column >= screen.pixelWidth ||
      row >= screen.pixelHeight)
    return {};

  return screenPosition(screen, double(column) / (screen.pixelWidth - 1),
                        double(row) / (screen.pixelHeight - 1));
}

void beginScreenCalibration(int pixelWidth, int pixelHeight) {
  const std::lock_guard lock(trackingMutex);
  calibrationPoints = {};
  calibrationStatus = {};
  calibratedScreen = {};
  leftCalibration = rightCalibration = {};
  latestGaze = {};
  calibrationWidth = pixelWidth;
  calibrationHeight = pixelHeight;
  if (pixelWidth >= 2 && pixelHeight >= 2)
    std::cout
        << "Trance screen calibration started: resumable pixel mapping v6, "
        << pixelWidth << 'x' << pixelHeight << " px, " << samplesPerPoint
        << " samples/point\n"
        << std::flush;
}

void resetScreenCalibration() { beginScreenCalibration(0, 0); }

bool restartScreenCalibrationPoint(int pointIndex) {
  const std::lock_guard lock(trackingMutex);
  if (pointIndex < 0 || pointIndex >= 5 || calibrationWidth < 2 ||
      calibrationHeight < 2)
    return false;
  calibrationPoints[pointIndex] = {};
  calibrationStatus = {};
  calibratedScreen = leftCalibration = rightCalibration = {};
  latestGaze = {};
  std::cout << "Trance screen calibration retry: point " << pointIndex + 1
            << "/5, other points retained\n"
            << std::flush;
  return true;
}

int screenCalibrationSampleCount() { return samplesPerPoint; }

int addScreenCalibrationSample(int pointIndex, double x, double y,
                               EyeTrackingSample sample, double now) {
  const std::lock_guard lock(trackingMutex);
  if (pointIndex < 0 || pointIndex >= 5 || calibrationWidth < 2 ||
      calibrationHeight < 2)
    return 0;

  auto &point = calibrationPoints[pointIndex];
  if (point.count >= samplesPerPoint || !std::isfinite(x) ||
      !std::isfinite(y) || x < 0 || x > 1 || y < 0 || y > 1 ||
      !fresh(sample, now) || !openEye(sample.leftEyeClosure) ||
      !openEye(sample.rightEyeClosure) || !validEye(sample.leftEye) ||
      !validEye(sample.rightEye) || sample.timestamp <= point.lastTimestamp ||
      (point.candidateCount > 0 && (point.x != x || point.y != y)))
    return point.count;

  const auto left = cameraPlanePosition(sample.leftEye);
  const auto right = cameraPlanePosition(sample.rightEye);
  if (!left || !right)
    return point.count;

  if (point.candidateCount > 0 &&
      sample.timestamp - point.lastTimestamp > maximumCalibrationSampleGap)
    point = {};
  point.x = x;
  point.y = y;
  point.lastTimestamp = sample.timestamp;
  if (point.candidateCount == maximumCalibrationCandidates) {
    std::move(point.observations.begin() + 1, point.observations.end(),
              point.observations.begin());
    --point.candidateCount;
  }
  point.observations[point.candidateCount++] = {*left, *right};
  summarizePoint(point);
  if (point.count == samplesPerPoint) {
    const auto mean = point.sum * (1.0 / point.count);
    const double variance =
        point.squaredDistanceSum / point.count - dot(mean, mean);
    std::cout << "Trance screen calibration point " << pointIndex + 1
              << "/5: " << point.count
              << " samples, window=" << point.candidateCount << ", target=("
              << x << ", " << y << "), projected mean(m)=(" << mean.x << ", "
              << mean.y << ", " << mean.z
              << "), spread=" << std::sqrt(std::max(0.0, variance)) * 1000
              << " mm\n"
              << std::flush;
  }
  return point.count;
}

bool finishScreenCalibration() {
  const std::lock_guard lock(trackingMutex);
  calibrationStatus = {};
  if (calibrationWidth < 2 || calibrationHeight < 2)
    return rejectCalibration(ScreenCalibrationFailure::resolution,
                             "invalid screen resolution", calibrationWidth);
  for (int index = 0; index < 5; ++index) {
    if (calibrationPoints[index].count < samplesPerPoint) {
      calibrationStatus.failure = ScreenCalibrationFailure::samples;
      calibrationStatus.pointIndex = index;
      calibrationStatus.sampleCount = calibrationPoints[index].count;
      std::cout << "Trance screen calibration failed: point " << index + 1
                << " has " << calibrationPoints[index].count << '/'
                << samplesPerPoint << " samples\n"
                << std::flush;
      return false;
    }
  }
  const auto combined = fitCalibration(-1);
  if (!combined)
    return false;
  const auto left = fitCalibration(0);
  if (!left)
    return false;
  const auto right = fitCalibration(1);
  if (!right)
    return false;
  calibratedScreen = *combined;
  leftCalibration = *left;
  rightCalibration = *right;
  std::cout << "Trance screen calibration complete: per-eye affine mapping"
            << ", mapping error=" << combined->normalizedCalibrationError * 100
            << "%\n"
            << std::flush;
  return true;
}

ScreenCalibrationStatus copyScreenCalibrationStatus() {
  const std::lock_guard lock(trackingMutex);
  return calibrationStatus;
}

ScreenRectangle copyCalibratedScreen() {
  const std::lock_guard lock(trackingMutex);
  return calibratedScreen;
}

void recordScreenGaze(EyeTrackingSample sample, double now) {
  const std::lock_guard lock(trackingMutex);
  latestGaze = {};
  if (!fresh(sample, now) || !calibratedScreen.available)
    return;

  latestGaze.timestamp = sample.timestamp;
  latestGaze.leftEye = eyeHit(sample.leftEye, sample.leftEyeClosure,
                              leftCalibration, latestGaze.screenInLeftEye);
  latestGaze.rightEye = eyeHit(sample.rightEye, sample.rightEyeClosure,
                               rightCalibration, latestGaze.screenInRightEye);

  if (latestGaze.leftEye.available && latestGaze.rightEye.available) {
    const auto &left = latestGaze.leftEye;
    const auto &right = latestGaze.rightEye;
    auto &combined = latestGaze.combined;
    combined.available = true;
    combined.x = (left.x + right.x) / 2;
    combined.y = (left.y + right.y) / 2;
    const double x = combined.x / (calibratedScreen.pixelWidth - 1);
    const double y = combined.y / (calibratedScreen.pixelHeight - 1);
    combined.onScreen =
        x >= -1e-9 && x <= 1 + 1e-9 && y >= -1e-9 && y <= 1 + 1e-9;
    if (combined.onScreen) {
      combined.column = static_cast<int>(std::lround(combined.x));
      combined.row = static_cast<int>(std::lround(combined.y));
    }
    combined.position = screenPosition(calibratedScreen, x, y);
  }
}

ScreenGaze copyScreenGaze(double now) {
  const std::lock_guard lock(trackingMutex);
  const double age = now - latestGaze.timestamp;
  if (!std::isfinite(now) || age < 0 || age > maximumGazeSampleAge)
    return {};
  return latestGaze;
}

} // namespace trance
