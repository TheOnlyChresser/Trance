#include "../lib/øjensporer.hpp"
#include "../lib/ScreenCalibration.hpp"

#include <algorithm>

namespace {
constexpr double maximumRaySeparation = 0.015;
constexpr double maximumRayDistance = 1.5;
}

std::optional<vec3d> øjensporer::fokuspoint(vec3d leftOrigin,
                                            vec3d leftDirection,
                                            vec3d rightOrigin,
                                            vec3d rightDirection) {
  if (!finite(leftOrigin) || !finite(rightOrigin) || !finite(leftDirection) ||
      !finite(rightDirection))
    return std::nullopt;

  const double leftLength = length(leftDirection);
  const double rightLength = length(rightDirection);

  if (!std::isfinite(leftLength) || !std::isfinite(rightLength) ||
      leftLength <= 0 || rightLength <= 0)
    return std::nullopt;

  leftDirection = leftDirection * (1 / leftLength);
  rightDirection = rightDirection * (1 / rightLength);

  const auto betweenEyes = leftOrigin - rightOrigin;
  const double alignment = dot(leftDirection, rightDirection);
  const double nævner = 1 - alignment * alignment;

  if (nævner < 1e-6)
    return std::nullopt;

  const double leftOffset = dot(leftDirection, betweenEyes);
  const double rightOffset = dot(rightDirection, betweenEyes);
  const double leftDistance = (alignment * rightOffset - leftOffset) / nævner;
  const double rightDistance = (rightOffset - alignment * leftOffset) / nævner;

  const bool leftForward =
      leftDistance > 0 && leftDistance <= maximumRayDistance;
  const bool rightForward =
      rightDistance > 0 && rightDistance <= maximumRayDistance;

  if (!leftForward || !rightForward)
    return std::nullopt;

  const auto leftPoint = leftOrigin + leftDirection * leftDistance;
  const auto rightPoint = rightOrigin + rightDirection * rightDistance;

  if (length(leftPoint - rightPoint) > maximumRaySeparation)
    return std::nullopt;

  return (leftPoint + rightPoint) * 0.5;
}

namespace trance {

namespace {
ScreenVector3 inEyeAxes(ScreenVector3 vector, EyePose eye) {
  return {dot(vector, eye.xAxis), dot(vector, eye.yAxis),
          dot(vector, eye.zAxis)};
}
}

bool validEye(EyePose eye) {
  return finite(eye.origin) && finite(eye.xAxis) && finite(eye.yAxis) &&
         finite(eye.zAxis) && std::abs(length(eye.xAxis) - 1) < 0.01 &&
         std::abs(length(eye.yAxis) - 1) < 0.01 &&
         std::abs(length(eye.zAxis) - 1) < 0.01 &&
         std::abs(dot(eye.xAxis, eye.yAxis)) < 0.01 &&
         std::abs(dot(eye.xAxis, eye.zAxis)) < 0.01 &&
         std::abs(dot(eye.yAxis, eye.zAxis)) < 0.01;
}

ScreenHit intersectScreen(ScreenRectangle screen, ScreenVector3 origin,
                          ScreenVector3 direction) {
  ScreenHit result;
  if (!screen.available || screen.pixelWidth < 2 || screen.pixelHeight < 2 ||
      !finite(origin) || !finite(direction) || !finite(screen.topLeft) ||
      !finite(screen.horizontal) || !finite(screen.vertical))
    return result;

  const double directionLength = length(direction);
  const auto normal = cross(screen.horizontal, screen.vertical);
  const double areaSquared = dot(normal, normal);
  const double nævner = dot(direction, normal);
  if (directionLength < 1e-9 || areaSquared <= 1e-12 ||
      std::abs(nævner) < 1e-6 * std::sqrt(areaSquared) * directionLength)
    return result;

  const double distance = dot(screen.topLeft - origin, normal) / nævner;
  if (!std::isfinite(distance) || distance <= 0)
    return result;

  result.position = origin + direction * distance;
  const auto offset = result.position - screen.topLeft;
  const double x = dot(cross(offset, screen.vertical), normal) / areaSquared;
  const double y = dot(cross(screen.horizontal, offset), normal) / areaSquared;
  if (!std::isfinite(x) || !std::isfinite(y))
    return {};

  result.available = true;
  result.x = x * (screen.pixelWidth - 1);
  result.y = y * (screen.pixelHeight - 1);
  result.onScreen = x >= -1e-9 && x <= 1 + 1e-9 && y >= -1e-9 && y <= 1 + 1e-9;
  if (result.onScreen) {
    result.column = static_cast<int>(
        std::lround(std::clamp(result.x, 0.0, double(screen.pixelWidth - 1))));
    result.row = static_cast<int>(
        std::lround(std::clamp(result.y, 0.0, double(screen.pixelHeight - 1))));
  }
  return result;
}

ScreenRectangle screenRelativeToEye(ScreenRectangle screen, EyePose eye) {
  if (!screen.available || !validEye(eye))
    return {};

  screen.topLeft = inEyeAxes(screen.topLeft - eye.origin, eye);
  screen.horizontal = inEyeAxes(screen.horizontal, eye);
  screen.vertical = inEyeAxes(screen.vertical, eye);
  return screen;
}

}
