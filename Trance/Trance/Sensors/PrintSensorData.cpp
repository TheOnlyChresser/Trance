#include "SensorData.hpp"
#include "Trance-Swift.h"
#include <iomanip>
#include <iostream>

namespace trance {
void sensorDataChanged(SensorUpdate update) {
  const auto data = Trance::copySensorSnapshot();
  std::cout << std::setprecision(15);
  const auto vector = [](const auto &v) {
    std::cout << '(' << v.getX() << ", " << v.getY() << ", " << v.getZ() << ')';
  };
  if (update == SensorUpdate::heartRate) {
    const auto pulse = data.getHeartRate();
    if (!pulse.getAvailable())
      std::cout << "Pulse unavailable";
    else
      std::cout << "Pulse: " << pulse.getBpm()
                << " BPM, timestamp: " << pulse.getTimestamp();
  } else if (update == SensorUpdate::face) {
    const auto face = data.getFace();
    if (!face.getAvailable())
      std::cout << "Face tracking unavailable";
    else {
      std::cout << "Face timestamp: " << face.getTimestamp()
                << " left origin/direction: ";
      vector(face.getLeftEyeOrigin());
      vector(face.getLeftEyeDirection());
      std::cout << " right origin/direction: ";
      vector(face.getRightEyeOrigin());
      vector(face.getRightEyeDirection());
      std::cout << " eyelid closure: " << face.getLeftEyeClosure() << ", "
                << face.getRightEyeClosure();
      const auto head = face.getHeadTransform();
      std::cout << " head matrix:";
      for (const auto &c :
           {head.getC0(), head.getC1(), head.getC2(), head.getC3()})
        std::cout << ' ' << c.getX() << ' ' << c.getY() << ' ' << c.getZ()
                  << ' ' << c.getW();
    }
  } else {
    const auto h = data.getHardware();
    std::cout << "Hardware: HealthKit=" << h.getHealthKit()
              << " face tracking=" << h.getFaceTracking()
              << " TrueDepth=" << h.getTrueDepthCamera()
              << " Watch paired=" << h.getWatchPaired();
  }
  std::cout << std::endl;
}
} // namespace trance
