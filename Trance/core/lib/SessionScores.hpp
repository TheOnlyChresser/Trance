#pragma once

#include "ScreenCalibration.hpp"

namespace trance {

struct ScoreValue {
  bool available = false;
  double value = 0;
  double coverage = 0;
};

struct SessionScores {
  ScoreValue afslapningsscore;
  ScoreValue fokusscore;
};

bool setRelaxationReference(double startBpm, double relaxedBpm);

bool setFocusTarget(double x, double y, double radius);

void clearScoreCalibration();

void startScores(double now);

void stopScores();

void recordScoreHeartRate(bool available, double bpm, double timestamp,
                          double now);

void recordScoreGaze(ScreenGaze gaze, double now);

SessionScores copyScores(double now);

}
