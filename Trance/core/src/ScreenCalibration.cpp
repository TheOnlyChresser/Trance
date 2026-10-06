#include "../lib/ScreenCalibration.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <mutex>
#include <optional>

namespace trance {
namespace {

constexpr int samplesPerPoint = 45;
constexpr double maximumCalibrationError = 0.012;

bool fresh(EyeTrackingSample sample, double now) {
  const double age = now - sample.timestamp;
  return sample.available && std::isfinite(now) &&
         std::isfinite(sample.timestamp) && age >= 0 && age <= maximumGazeSampleAge;
}

bool openEye(double closure) {
  return std::isfinite(closure) && closure >= 0 && closure < 0.5;
}

struct CalibrationPoint {
  int count = 0;
  double x = 0, y = 0;
  double lastTimestamp = 0;
  ScreenVector3 sum;
};

std::mutex trackingMutex;
std::array<CalibrationPoint, 5> calibrationPoints;
ScreenRectangle calibratedScreen;
ScreenGaze latestGaze;
int calibrationWidth = 0, calibrationHeight = 0;

std::optional<std::array<ScreenVector3, 3>> fitRectangle() {
  std::array<ScreenVector3, 5> positions;
  ScreenVector3 center;
  for (int index = 0; index < 5; ++index) {
    const auto &point = calibrationPoints[index];
    if (point.count < samplesPerPoint)
      return std::nullopt;
    positions[index] = point.sum * (1.0 / point.count);
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

ScreenHit eyeHit(EyePose eye, double closure, ScreenRectangle &screen) {
  screen = openEye(closure) ? screenRelativeToEye(calibratedScreen, eye)
                            : ScreenRectangle{};
  return intersectScreen(screen, {}, {0, 0, 1});
}

}

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
  calibratedScreen = {};
  latestGaze = {};
  calibrationWidth = pixelWidth;
  calibrationHeight = pixelHeight;
}

void resetScreenCalibration() { beginScreenCalibration(0, 0); }

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
      (point.count > 0 && (point.x != x || point.y != y)))
    return point.count;

  const auto position = øjensporer::fokuspoint(
      sample.leftEye.origin, sample.leftEye.zAxis,
      sample.rightEye.origin, sample.rightEye.zAxis);
  if (!position)
    return point.count;

  point.x = x;
  point.y = y;
  point.lastTimestamp = sample.timestamp;
  point.sum = point.sum + *position;
  return ++point.count;
}

bool finishScreenCalibration() {
  const std::lock_guard lock(trackingMutex);
  const auto coefficients = fitRectangle();
  if (!coefficients || calibrationWidth < 2 || calibrationHeight < 2)
    return false;

  const auto center = (*coefficients)[0];
  auto horizontal = (*coefficients)[1];
  const double width = length(horizontal);
  if (!finite(center) || !finite(horizontal) || width < 0.02 || width > 0.3)
    return false;

  const auto horizontalAxis = horizontal * (1 / width);
  auto vertical = (*coefficients)[2] -
                  horizontalAxis * dot((*coefficients)[2], horizontalAxis);
  const double height = length(vertical);
  const double aspectRatio =
      double(calibrationWidth - 1) / (calibrationHeight - 1);
  if (!finite(vertical) || height < 0.02 || height > 0.4 ||
      std::abs(width / height / aspectRatio - 1) > 0.25 ||
      length(center) > 0.2 || std::abs(center.z) > 0.08)
    return false;

  double horizontalWeight = 0, verticalWeight = 0;
  for (const auto &point : calibrationPoints) {
    horizontalWeight += (point.x - 0.5) * (point.x - 0.5);
    verticalWeight += (point.y - 0.5) * (point.y - 0.5);
  }
  const double columns = calibrationWidth - 1;
  const double rows = calibrationHeight - 1;
  const double spacing =
      (width * columns * horizontalWeight + height * rows * verticalWeight) /
      (columns * columns * horizontalWeight + rows * rows * verticalWeight);
  horizontal = horizontalAxis * (spacing * columns);
  vertical = vertical * (spacing * rows / height);

  ScreenRectangle screen;
  screen.topLeft = center - (horizontal + vertical) * 0.5;
  screen.horizontal = horizontal;
  screen.vertical = vertical;
  screen.pixelWidth = calibrationWidth;
  screen.pixelHeight = calibrationHeight;

  double squaredError = 0;
  for (const auto &point : calibrationPoints) {
    const auto predicted = screenPosition(screen, point.x, point.y);
    const double error = length(predicted - point.sum * (1.0 / point.count));
    if (error > 2 * maximumCalibrationError)
      return false;
    squaredError += error * error;
  }
  screen.calibrationError = std::sqrt(squaredError / calibrationPoints.size());
  if (!std::isfinite(screen.calibrationError) ||
      screen.calibrationError > maximumCalibrationError)
    return false;

  screen.available = true;
  calibratedScreen = screen;
  return true;
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
  latestGaze.leftEye =
      eyeHit(sample.leftEye, sample.leftEyeClosure, latestGaze.screenInLeftEye);
  latestGaze.rightEye = eyeHit(sample.rightEye, sample.rightEyeClosure,
                               latestGaze.screenInRightEye);

  if (latestGaze.leftEye.available && latestGaze.rightEye.available) {
    const auto &left = latestGaze.leftEye;
    const auto &right = latestGaze.rightEye;
    auto &combined = latestGaze.combined;
    combined.available = true;
    combined.x = (left.x + right.x) / 2;
    combined.y = (left.y + right.y) / 2;
    combined.onScreen = left.onScreen && right.onScreen;
    if (combined.onScreen) {
      combined.column = static_cast<int>(std::lround(combined.x));
      combined.row = static_cast<int>(std::lround(combined.y));
    }
    const double x = combined.x / (calibratedScreen.pixelWidth - 1);
    const double y = combined.y / (calibratedScreen.pixelHeight - 1);
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

}
