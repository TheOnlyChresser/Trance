#include "../lib/øjensporer.hpp"

std::string øjensporer::fokuspoint() {
  if (face.getAvailable()) {
    return std::string("face is uavailable");
  }
  const std::vector rightEye = {face.getRightEyeDirection(),
                                face.getRightEyeOrigin()};
  const std::vector leftEye = {face.getLeftEyeDirection(),
                               face.getLeftEyeOrigin()};

  std::vector<float> rightEyeDir = {rightEye[0].getX(), rightEye[0].getY(),
                                    rightEye[0].getZ()};
  std::vector<float> rightEyeOrigin = {
    rightEye[1].getX(), {rightEye[1].getY(), {rightEye[1].getZ()};
  std::vector<float> LeftEyeDir = {leftEye[0].getX(), leftEye[0].getY(),
                                   leftEye[0].getZ()};
  std::vector<float> leftEyeOrigin = {
    leftEye[1].getX(), {leftEye[1].getY(), {leftEye[1].getZ()};

  float s =
      (rightEyeOrigin[1] * LeftEyeDir[0] - leftEyeOrigin[1] * LeftEyeDir[0] -
       rightEyeOrigin[0] * LeftEyeDir[1] + leftEyeOrigin[0] * LeftEyeDir[1]) /
      (rightEyeDir[0] * LeftEyeDir[1] -
       rightEyeDir[1] * LeftEyeDir[0]) float t =
          (rightEyeOrigin[0] + s * rightEyeDir[0] - leftEyeOrigin[0]) /
          (LeftEyeDir[0])
};
