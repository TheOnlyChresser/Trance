#pragma once

#include "øjensporer.hpp"

namespace trance {

using ScreenVector3 = vec3d;

inline constexpr double maximumGazeSampleAge = 0.25;

struct EyePose {
  ScreenVector3 origin;
  ScreenVector3 xAxis, yAxis, zAxis;
};

struct EyeTrackingSample {
  bool available = false;
  double timestamp = 0;
  double leftEyeClosure = 0, rightEyeClosure = 0;
  EyePose leftEye, rightEye;
};

struct ScreenRectangle {
  bool available = false;
  ScreenVector3 topLeft;
  ScreenVector3 horizontal, vertical;
  int pixelWidth = 0, pixelHeight = 0;
  double calibrationError = 0;
  double normalizedCalibrationError = 0;
};

struct ScreenHit {
  bool available = false;
  bool onScreen = false;
  double x = 0, y = 0;
  int column = -1, row = -1;
  ScreenVector3 position;
};

struct ScreenGaze {
  double timestamp = 0;
  ScreenHit leftEye, rightEye, combined;
  ScreenRectangle screenInLeftEye, screenInRightEye;
};

enum class ScreenCalibrationFailure {
  none,
  resolution,
  samples,
  layout,
  width,
  height,
  axes,
  pointError,
  meanError
};

struct ScreenCalibrationStatus {
  ScreenCalibrationFailure failure = ScreenCalibrationFailure::none;
  int pointIndex = -1, retryPointIndex = -1, sampleCount = 0;
  int retryPointMask = 0;
  double measuredValue = 0, limit = 0;
};

ScreenVector3 screenGridPoint(ScreenRectangle screen, int column, int row);
bool validEye(EyePose eye);
ScreenHit intersectScreen(ScreenRectangle screen, ScreenVector3 origin,
                          ScreenVector3 direction);
ScreenRectangle screenRelativeToEye(ScreenRectangle screen, EyePose eye);

void beginScreenCalibration(int pixelWidth, int pixelHeight);
void resetScreenCalibration();
bool restartScreenCalibrationPoint(int pointIndex);
int screenCalibrationSampleCount();
int addScreenCalibrationSample(int pointIndex, double x, double y,
                               EyeTrackingSample sample, double now);
bool finishScreenCalibration();
ScreenCalibrationStatus copyScreenCalibrationStatus();
ScreenRectangle copyCalibratedScreen();
void recordScreenGaze(EyeTrackingSample sample, double now);
ScreenGaze copyScreenGaze(double now);

} // namespace trance
