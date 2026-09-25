#pragma once

namespace trance {
enum class SensorUpdate { heartRate, face, hardware };
// swift calls this notification after storing a new reading c++ reads a value
// copy via Trance::copySensorSnapshot() from Trance-Swift.h.
void sensorDataChanged(SensorUpdate update);
} // namespace trance
