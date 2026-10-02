#include "../lib/øjensporer.hpp"

øjensporer::øjensporer() = default;
øjensporer::~øjensporer() = default;

double dot(const std::vector<double>& u, const std::vector<double>& v) {
  return u[0] * v[0] + u[1] * v[1] + u[2] * v[2];
}

std::vector<double> getDifferenceVector(const std::vector<double>& u, const std::vector<double>& v) {
    return {v[0] - u[0], v[1] - u[1], v[3] - u[3]};
}

void øjensporer::fokuspoint() {
  const Trance::SensorSnapshot data = Trance::copySensorSnapshot();
  const Trance::TranceFaceData face = data.getFace();

  if (!face.getAvailable()) {
    return;
  }
  const std::vector rightEye = {face.getRightEyeDirection(),
                                face.getRightEyeOrigin()};
  const std::vector leftEye = {face.getLeftEyeDirection(),
                               face.getLeftEyeOrigin()};

  std::vector<double> rightEyeDir = {rightEye[0].getX(), rightEye[0].getY(),
                                    rightEye[0].getZ()};
  std::vector<double> rightEyeOrigin = {rightEye[1].getX(), rightEye[1].getY(),
                                       rightEye[1].getZ()};
  std::vector<double> LeftEyeDir = {leftEye[0].getX(), leftEye[0].getY(),
                                   leftEye[0].getZ()};
  std::vector<double> leftEyeOrigin = {leftEye[1].getX(), leftEye[1].getY(),
                                      leftEye[1].getZ()};

  std::vector<double> w = getDifferenceVector(LeftEyeDir, rightEyeDir);
    
  double a = dot(LeftEyeDir, LeftEyeDir);
  double b = dot(rightEyeDir, LeftEyeDir);
  double c = dot(rightEyeDir, rightEyeDir);
  double d = dot(LeftEyeDir, w);
  double e = dot(rightEyeDir, w);

  double nævner = a * c - b * b;

  if (a <= 0 || c <= 0 || !std::isfinite(nævner) || nævner <= 1e-6f * a * c) {
    return;
  }

  double t = (b * e - c * d) / nævner;
  double s = (a * e - b * d) / nævner;

  if (!std::isfinite(t) || !std::isfinite(s) || t < 0 || s < 0) {
    return;
  }

  std::vector<double> leftPoint = {leftEyeOrigin[0] + t * LeftEyeDir[0],
                                  leftEyeOrigin[1] + t * LeftEyeDir[1],
                                  leftEyeOrigin[2] + t * LeftEyeDir[2]};
  std::vector<double> rightPoint = {rightEyeOrigin[0] + s * rightEyeDir[0],
                                   rightEyeOrigin[1] + s * rightEyeDir[1],
                                   rightEyeOrigin[2] + s * rightEyeDir[2]};

  std::vector<double> fokusPunkt = {(leftPoint[0] + rightPoint[0]) / 2,
                                   (leftPoint[1] + rightPoint[1]) / 2,
                                   (leftPoint[2] + rightPoint[2]) / 2};

  Trance::receiveFokusPunkt(fokusPunkt[0], fokusPunkt[1], fokusPunkt[2]);
};
