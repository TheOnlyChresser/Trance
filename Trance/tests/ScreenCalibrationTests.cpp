#include "../core/lib/ScreenCalibration.hpp"

#include <array>
#include <cassert>
#include <cmath>
#include <iostream>

using namespace trance;

ScreenVector3 normalize(ScreenVector3 v) {
  const double length = std::hypot(v.x, v.y, v.z);
  return {v.x / length, v.y / length, v.z / length};
}

ScreenVector3 cross(ScreenVector3 a, ScreenVector3 b) {
  return {a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x};
}

EyePose eyeLookingAt(ScreenVector3 origin, ScreenVector3 target) {
  EyePose eye;
  eye.origin = origin;
  eye.zAxis = normalize(
      {target.x - origin.x, target.y - origin.y, target.z - origin.z});
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

int main() {
  ScreenRectangle screen;
  screen.available = true;
  screen.topLeft = {-0.035, 0.005, 0};
  screen.horizontal = {0.07, 0, 0};
  screen.vertical = {0, -0.14, 0};
  screen.pixelWidth = 701;
  screen.pixelHeight = 1401;

  const auto corner = screenGridPoint(screen, 700, 1400);
  assert(std::abs(corner.x - 0.035) < 1e-8);
  assert(std::abs(corner.y + 0.135) < 1e-8);
  const auto across = screenGridPoint(screen, 1, 0);
  const auto down = screenGridPoint(screen, 0, 1);
  assert(std::abs((across.x - screen.topLeft.x) - (screen.topLeft.y - down.y)) <
         1e-8);
  const auto hit = intersectScreen(screen, {0, -0.065, 0.4}, {0, 0, -1});
  assert(hit.available && hit.onScreen && hit.column == 350 && hit.row == 700);
  assert(!intersectScreen(screen, {0, 0, 0.4}, {1, 0, 0}).available);
  const auto outside = intersectScreen(screen, {0.1, 0, 0.4}, {0, 0, -1});
  assert(outside.available && !outside.onScreen);

  beginScreenCalibration(701, 1401);
  assert(!finishScreenCalibration());
  const std::array<std::array<double, 2>, 5> points = {
      {{0.5, 0.5}, {0.04, 0.02}, {0.96, 0.02}, {0.96, 0.98}, {0.04, 0.98}}};
  double time = 100;
  for (int index = 0; index < 5; ++index) {
    const auto x = points[index][0], y = points[index][1];
    const ScreenVector3 target{-0.035 + 0.07 * x, 0.005 - 0.14 * y, 0};
    int count = 0;
    for (int sample = 0; sample < 45; ++sample) {
      time += 0.02;
      count = addScreenCalibrationSample(index, x, y,
                                         sampleLookingAt(target, time), time);
    }
    assert(count == 45);
  }
  assert(finishScreenCalibration());
  const auto calibrated = copyCalibratedScreen();
  assert(calibrated.available && calibrated.calibrationError < 1e-8);

  time += 0.02;
  auto sample = sampleLookingAt({-0.0175, -0.1, 0}, time);
  recordScreenGaze(sample, time);
  const auto gaze = copyScreenGaze(time);
  assert(gaze.leftEye.onScreen && gaze.rightEye.onScreen &&
         gaze.combined.onScreen);
  assert(gaze.leftEye.column == 175 && gaze.leftEye.row == 1050);
  assert(gaze.rightEye.column == 175 && gaze.rightEye.row == 1050);
  assert(gaze.combined.column == 175 && gaze.combined.row == 1050);
  assert(!copyScreenGaze(time + 0.3).combined.available);
  sample.leftEyeClosure = 0.8;
  recordScreenGaze(sample, time);
  assert(!copyScreenGaze(time).combined.available);

  resetScreenCalibration();
  assert(!copyCalibratedScreen().available);
  std::cout << "Screen calibration tests passed\n";
}
