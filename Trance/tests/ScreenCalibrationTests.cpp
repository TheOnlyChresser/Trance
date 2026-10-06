#include "../core/lib/ScreenCalibration.hpp"
#include "../core/lib/SessionScores.hpp"

#include <array>
#include <cassert>
#include <cmath>
#include <iostream>
#include <sstream>
#include <string>

using namespace trance;

ScreenVector3 normalize(ScreenVector3 v) {
  const double length = std::hypot(v.x, v.y, v.z);
  return v * (1 / length);
}

EyePose eyeLookingAt(ScreenVector3 origin, ScreenVector3 target) {
  EyePose eye;
  eye.origin = origin;
  eye.zAxis = normalize(target - origin);
  eye.xAxis = normalize(cross({0, 1, 0}, eye.zAxis));
  eye.yAxis = cross(eye.zAxis, eye.xAxis);
  return eye;
}

EyeTrackingSample sampleLookingAt(ScreenVector3 target, double time) {
  EyeTrackingSample sample;
  sample.available = true;
  sample.timestamp = time;
  sample.leftEye = eyeLookingAt({-0.032, 0, 0.4}, target);
  sample.rightEye = eyeLookingAt({0.032, 0, 0.4}, target);
  return sample;
}

EyeTrackingSample sampleWithRightEyeBias(ScreenVector3 target, double time,
                                       double degrees) {
  auto sample = sampleLookingAt(target, time);
  const double angle = -degrees * std::acos(-1) / 180;
  const auto direction = sample.rightEye.zAxis;
  const ScreenVector3 rotated{
      std::cos(angle) * direction.x + std::sin(angle) * direction.z,
      direction.y,
      -std::sin(angle) * direction.x + std::cos(angle) * direction.z};
  sample.rightEye =
      eyeLookingAt(sample.rightEye.origin, sample.rightEye.origin + rotated);
  return sample;
}

int main() {
  ScreenRectangle screen;
  screen.available = true;
  screen.topLeft = {-0.035, 0.005, 0};
  screen.horizontal = {0.07, 0, 0};
  screen.vertical = {0, -0.14, 0};
  screen.pixelWidth = 701;
  screen.pixelHeight = 1401;

  // this test maps pixel (700, 1400) on a 701 x 1401 grid to corner (0.035,
  // -0.135, 0). It checks the corner coordinates with a tolerance of 1e-8.
  const auto corner = screenGridPoint(screen, 700, 1400);
  assert(std::abs(corner.x - 0.035) < 1e-8);
  assert(std::abs(corner.y + 0.135) < 1e-8);

  // this test compares pixels (1, 0) and (0, 1) to check equal horizontal and
  // vertical spacing.
  const auto across = screenGridPoint(screen, 1, 0);
  const auto down = screenGridPoint(screen, 0, 1);
  assert(std::abs((across.x - screen.topLeft.x) - (screen.topLeft.y - down.y)) <
         1e-8);

  // this test casts a ray from (0, -0.065, 0.4) in direction (0, 0, -1) to
  // check a hit at pixel (350, 700).
  const auto hit = intersectScreen(screen, {0, -0.065, 0.4}, {0, 0, -1});
  assert(hit.available && hit.onScreen && hit.column == 350 && hit.row == 700);

  // this test uses direction (1, 0, 0), parallel to the screen, to check that
  // no intersection is available.
  assert(!intersectScreen(screen, {0, 0, 0.4}, {1, 0, 0}).available);

  // this test casts a ray from (0.1, 0, 0.4) to check that a plane hit outside
  // the screen is marked off-screen.
  const auto outside = intersectScreen(screen, {0.1, 0, 0.4}, {0, 0, -1});
  assert(outside.available && !outside.onScreen);

  // this test starts calibration at 701 x 1401 pixels with no samples to check
  // that finishing fails.
  beginScreenCalibration(701, 1401);
  assert(!finishScreenCalibration());

  // this test uses the five listed positions with 45 samples each, spaced 0.02
  // seconds apart. It checks that calibration succeeds and the recovered screen
  // has error below 1e-8.
  const std::array<std::array<double, 2>, 5> points = {
      {{0.5, 0.5}, {0.04, 0.02}, {0.96, 0.02}, {0.96, 0.98}, {0.04, 0.98}}};
  double time = 100;
  for (int index = 0; index < 5; ++index) {
    const auto x = points[index][0], y = points[index][1];
    const ScreenVector3 target{-0.035 + 0.07 * x, 0.005 - 0.14 * y, 0};
    int count = 0;
    for (int sample = 0; sample < screenCalibrationSampleCount(); ++sample) {
      time += 0.02;
      count = addScreenCalibrationSample(index, x, y,
                                         sampleLookingAt(target, time), time);
    }
    assert(count == screenCalibrationSampleCount());
  }
  assert(finishScreenCalibration());
  const auto calibrated = copyCalibratedScreen();
  assert(calibrated.available && calibrated.calibrationError < 1e-8);

  // this test aims both eyes at (-0.0175, -0.1, 0) to check that all gaze hits
  // map to pixel (175, 1050).
  time += 0.02;
  auto sample = sampleLookingAt({-0.0175, -0.1, 0}, time);
  recordScreenGaze(sample, time);
  const auto gaze = copyScreenGaze(time);
  assert(gaze.leftEye.onScreen && gaze.rightEye.onScreen &&
         gaze.combined.onScreen);
  assert(gaze.leftEye.column == 175 && gaze.leftEye.row == 1050);
  assert(gaze.rightEye.column == 175 && gaze.rightEye.row == 1050);
  assert(gaze.combined.column == 175 && gaze.combined.row == 1050);

  // this test reads gaze after 0.3 seconds to check that it expires past the
  // 0.25-second freshness limit.
  assert(!copyScreenGaze(time + 0.3).combined.available);

  // this test sets left-eye closure to 0.8, above the 0.5 limit, to check that
  // combined gaze is unavailable.
  sample.leftEyeClosure = 0.8;
  recordScreenGaze(sample, time);
  assert(!copyScreenGaze(time).combined.available);

  assert(setFocusTarget(175, 1050, 32));
  const double started = time;
  startScores(started);

  for (int index = 0; index <= 500; ++index) {
    time = started + index * 0.02;
    const auto target = index < 250 ? ScreenVector3{-0.0175, -0.1, 0}
                                  : ScreenVector3{0.0175, -0.1, 0};
    recordScreenGaze(sampleLookingAt(target, time), time);
    recordScoreGaze(copyScreenGaze(time), time);
  }

  const auto focus = copyScores(time).fokusscore;
  assert(focus.available && std::abs(focus.value - 0.5) < 1e-8);
  assert(std::abs(focus.coverage - 1) < 1e-8);

  time += 0.02;
  sample = sampleLookingAt({-0.0175, -0.1, 0}, time);
  sample.leftEyeClosure = 0.8;
  recordScreenGaze(sample, time);
  recordScoreGaze(copyScreenGaze(time), time);
  assert(copyScores(time).fokusscore.available);
  assert(!copyScores(time + 1.1).fokusscore.available);
  stopScores();

  // this test resets the calibrated screen to check that its availability is
  // cleared.
  resetScreenCalibration();
  assert(!copyCalibratedScreen().available);

  for (double bias : {2.0, -2.0}) {
    beginScreenCalibration(701, 1401);
    for (int index = 0; index < 5; ++index) {
      const auto x = points[index][0], y = points[index][1];
      const ScreenVector3 target{-0.035 + 0.07 * x, 0.005 - 0.14 * y, 0};
      int count = 0;
      for (int n = 0; n < screenCalibrationSampleCount(); ++n) {
        time += 0.02;
        count = addScreenCalibrationSample(
            index, x, y, sampleWithRightEyeBias(target, time, bias), time);
      }
      assert(count == screenCalibrationSampleCount());
    }
    assert(finishScreenCalibration());
    const auto biasedScreen = copyCalibratedScreen();
    assert(std::abs(biasedScreen.topLeft.z) < 1e-8);
    assert(std::abs(length(biasedScreen.horizontal) - 0.07) < 0.002);
    assert(std::abs(length(biasedScreen.vertical) - 0.14) < 0.002);
    for (const auto &point : points) {
      time += 0.02;
      const ScreenVector3 target{-0.035 + 0.07 * point[0],
                                0.005 - 0.14 * point[1], 0};
      recordScreenGaze(sampleWithRightEyeBias(target, time, bias), time);
      const auto biasedGaze = copyScreenGaze(time);
      assert(biasedGaze.combined.available && biasedGaze.combined.onScreen);
      assert(std::abs(biasedGaze.combined.x - point[0] * 700) < 4);
      assert(std::abs(biasedGaze.combined.y - point[1] * 1400) < 4);
    }
    time += 0.02;
    recordScreenGaze(sampleWithRightEyeBias({0.1, -0.065, 0}, time, bias),
                     time);
    const auto offScreen = copyScreenGaze(time);
    assert(offScreen.combined.available && !offScreen.combined.onScreen);
  }

  beginScreenCalibration(701, 1401);
  time += 0.02;
  sample = sampleLookingAt({0, -0.065, 0}, time);
  assert(addScreenCalibrationSample(0, 0.5, 0.5, sample, time + 0.3) == 0);
  sample.leftEyeClosure = 0.8;
  assert(addScreenCalibrationSample(0, 0.5, 0.5, sample, time) == 0);
  sample.leftEyeClosure = 0;
  sample.rightEye = eyeLookingAt(sample.rightEye.origin,
                                sample.rightEye.origin + ScreenVector3{1, 0, 0});
  assert(addScreenCalibrationSample(0, 0.5, 0.5, sample, time) == 0);
  sample = sampleLookingAt({0, -0.065, 0}, time);
  sample.rightEye = eyeLookingAt(sample.rightEye.origin,
                                sample.rightEye.origin + ScreenVector3{0, 0, 1});
  assert(addScreenCalibrationSample(0, 0.5, 0.5, sample, time) == 0);
  sample = sampleLookingAt({0, -0.065, 0}, time);
  assert(addScreenCalibrationSample(0, 0.5, 0.5, sample, time) == 1);
  assert(addScreenCalibrationSample(0, 0.5, 0.5, sample, time) == 1);

  beginScreenCalibration(701, 1401);
  for (int index = 0; index < 5; ++index) {
    const auto x = points[index][0], y = points[index][1];
    const ScreenVector3 target{-0.035 + 0.07 * x, 0.005 - 0.04 * y, 0};
    for (int n = 0; n < screenCalibrationSampleCount(); ++n) {
      time += 0.02;
      addScreenCalibrationSample(index, x, y, sampleLookingAt(target, time),
                                 time);
    }
  }
  std::ostringstream failure;
  auto *output = std::cout.rdbuf(failure.rdbuf());
  const bool invalidGeometryAccepted = finishScreenCalibration();
  std::cout.rdbuf(output);
  assert(!invalidGeometryAccepted && !copyCalibratedScreen().available);
  assert(failure.str().find("aspect-ratio error exceeds 0.25") !=
         std::string::npos);

  resetScreenCalibration();
  std::cout << "Screen calibration and score tests passed\n";
}
