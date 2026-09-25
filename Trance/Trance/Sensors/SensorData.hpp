#pragma once

namespace trance {
enum class SensorUpdate { heartRate, face, hardware };
// swift calls this notification after storing a new reading. No sensor data is
// passed here, C++ reads a value copy from Swift using
// Trance::copySensorSnapshot()
void sensorDataChanged(SensorUpdate update);
} // namespace trance
