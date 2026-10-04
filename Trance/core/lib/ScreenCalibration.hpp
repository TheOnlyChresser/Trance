#pragma once

namespace trance {

struct ScreenVector3 {
  double x = 0, y = 0, z = 0;
};

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

ScreenVector3 screenGridPoint(ScreenRectangle screen, int column, int row);
ScreenHit intersectScreen(ScreenRectangle screen, ScreenVector3 origin,
                          ScreenVector3 direction);
ScreenRectangle screenRelativeToEye(ScreenRectangle screen, EyePose eye);

void beginScreenCalibration(int pixelWidth, int pixelHeight);
void resetScreenCalibration();
int addScreenCalibrationSample(int pointIndex, double x, double y,
                               EyeTrackingSample sample, double now);
bool finishScreenCalibration();
ScreenRectangle copyCalibratedScreen();
void recordScreenGaze(EyeTrackingSample sample, double now);
ScreenGaze copyScreenGaze(double now);

}
