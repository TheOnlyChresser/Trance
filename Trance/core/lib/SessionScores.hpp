#pragma once

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

struct ScoreVector3 {
  double x = 0, y = 0, z = 0;
};

struct ScoreFaceSample {
  bool available = false;
  double timestamp = 0;
  double leftEyeClosure = 0, rightEyeClosure = 0;
  ScoreVector3 leftOrigin, rightOrigin, leftDirection, rightDirection;
};

bool setRelaxationReference(double startBpm, double relaxedBpm);

bool setFocusTarget(ScoreVector3 target, double toleranceRadians);

void clearScoreCalibration();

void startScores(double now);

void stopScores();

void recordScoreHeartRate(bool available, double bpm, double timestamp,
                          double now);

void recordScoreFace(ScoreFaceSample sample, double now);

SessionScores copyScores(double now);
}
