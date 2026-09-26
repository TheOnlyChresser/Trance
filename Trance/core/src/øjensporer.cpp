#include "../lib/øjensporer.hpp"

øjensporer::øjensporer() = default;
øjensporer::~øjensporer() = default;

void øjensporer::fokuspoint() {
  const auto data = Trance::copySensorSnapshot();
  const auto face = data.getFace();

  if (!face.getAvailable()) {
    return;
  }
  const std::vector rightEye = {face.getRightEyeDirection(),
                                face.getRightEyeOrigin()};
  const std::vector leftEye = {face.getLeftEyeDirection(),
                               face.getLeftEyeOrigin()};

  std::vector<float> rightEyeDir = {rightEye[0].getX(), rightEye[0].getY(),
                                    rightEye[0].getZ()};
  std::vector<float> rightEyeOrigin = {rightEye[1].getX(), rightEye[1].getY(),
                                       rightEye[1].getZ()};
  std::vector<float> LeftEyeDir = {leftEye[0].getX(), leftEye[0].getY(),
                                   leftEye[0].getZ()};
  std::vector<float> leftEyeOrigin = {leftEye[1].getX(), leftEye[1].getY(),
                                      leftEye[1].getZ()};

  std::vector<float> w = {leftEyeOrigin[0] - rightEyeOrigin[0],
                          leftEyeOrigin[1] - rightEyeOrigin[1],
                          leftEyeOrigin[2] - rightEyeOrigin[2]};
  float a = LeftEyeDir[0] * LeftEyeDir[0] + LeftEyeDir[1] * LeftEyeDir[1] +
            LeftEyeDir[2] * LeftEyeDir[2];
  float b = LeftEyeDir[0] * rightEyeDir[0] + LeftEyeDir[1] * rightEyeDir[1] +
            LeftEyeDir[2] * rightEyeDir[2];
  float c = rightEyeDir[0] * rightEyeDir[0] + rightEyeDir[1] * rightEyeDir[1] +
            rightEyeDir[2] * rightEyeDir[2];
  float d = LeftEyeDir[0] * w[0] + LeftEyeDir[1] * w[1] + LeftEyeDir[2] * w[2];
  float e =
      rightEyeDir[0] * w[0] + rightEyeDir[1] * w[1] + rightEyeDir[2] * w[2];

  float nævner = a * c - b * b;

  if (a <= 0 || c <= 0 || !std::isfinite(nævner) || nævner <= 1e-6f * a * c) {
    return;
  }

  float t = (b * e - c * d) / nævner;
  float s = (a * e - b * d) / nævner;

  if (!std::isfinite(t) || !std::isfinite(s) || t < 0 || s < 0) {
    return;
  }

  std::vector<float> leftPoint = {leftEyeOrigin[0] + t * LeftEyeDir[0],
                                  leftEyeOrigin[1] + t * LeftEyeDir[1],
                                  leftEyeOrigin[2] + t * LeftEyeDir[2]};
  std::vector<float> rightPoint = {rightEyeOrigin[0] + s * rightEyeDir[0],
                                   rightEyeOrigin[1] + s * rightEyeDir[1],
                                   rightEyeOrigin[2] + s * rightEyeDir[2]};

  std::vector<float> fokusPunkt = {(leftPoint[0] + rightPoint[0]) / 2,
                                   (leftPoint[1] + rightPoint[1]) / 2,
                                   (leftPoint[2] + rightPoint[2]) / 2};

  Trance::receiveFokusPunkt(fokusPunkt[0], fokusPunkt[1], fokusPunkt[2]);
};
