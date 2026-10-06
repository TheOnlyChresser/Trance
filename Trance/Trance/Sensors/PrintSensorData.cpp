#include "SensorData.hpp"
#include "Trance-Swift.h"

#include <chrono>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <optional>
#include <sstream>

namespace trance {
namespace {

constexpr auto printInterval = std::chrono::seconds(1);

struct TrackingState {
  bool face, fresh, screen, gaze, onScreen, pulse;
  bool operator==(const TrackingState &) const = default;
};

std::mutex printMutex;
std::chrono::steady_clock::time_point lastPrint;
std::optional<TrackingState> previousTracking;
std::optional<double> previousRelaxation, previousFocus;

void printAge(std::ostream &out, double timestamp, double now) {
  const double age = now - timestamp;
  if (std::isfinite(age) && timestamp > 0 && age >= 0)
    out << ", age=" << std::setprecision(2) << age << " s";
  else
    out << ", invalid timestamp";
}

void printVector(std::ostream &out, ScreenVector3 value) {
  out << std::setprecision(4) << '(' << value.x << ", " << value.y << ", "
      << value.z << ')';
}

void printEye(std::ostream &out, const char *label,
              const Trance::TranceMatrix4 &transform) {
  const auto origin = transform.getC3();
  const auto direction = transform.getC2();

  out << label << " eye (camera coordinates): origin(m)=";
  printVector(out, {origin.getX(), origin.getY(), origin.getZ()});
  out << ", forward=";
  printVector(out, {direction.getX(), direction.getY(), direction.getZ()});
  out << '\n';
}

void printHit(std::ostream &out, const char *label, ScreenHit hit) {
  out << label << '=';
  if (!hit.available) {
    out << "unavailable";
    return;
  }

  out << std::setprecision(1) << '(' << hit.x << ", " << hit.y
      << ") px, onScreen=" << hit.onScreen;
}

void printScore(std::ostream &out, const char *label, ScoreValue score,
                std::optional<double> &previous) {
  out << label << ": " << std::setprecision(1);

  if (score.available) {
    out << score.value * 100 << '%';
    if (previous)
      out << " (" << std::showpos << (score.value - *previous) * 100
          << std::noshowpos << " pp)";
    previous = score.value;
  } else {
    out << "unavailable";
    previous.reset();
  }

  out << ", coverage=" << score.coverage * 100 << "%\n";
}

} // namespace

void sensorDataChanged(SensorUpdate update) {
  const auto currentTime = std::chrono::steady_clock::now();
  const std::lock_guard lock(printMutex);
  const double now = std::chrono::duration<double>(
                         std::chrono::system_clock::now().time_since_epoch())
                         .count();

  const auto sensors = Trance::copySensorSnapshot();
  const auto face = sensors.getFace();
  const auto pulse = sensors.getHeartRate();
  const auto hardware = sensors.getHardware();
  const auto screen = copyCalibratedScreen();
  const auto gaze = copyScreenGaze(now);

  const double faceAge = now - face.getTimestamp();
  const bool faceFresh = face.getAvailable() && std::isfinite(faceAge) &&
                         faceAge >= 0 && faceAge <= maximumGazeSampleAge;
  const TrackingState tracking{face.getAvailable(),    faceFresh,
                               screen.available,       gaze.combined.available,
                               gaze.combined.onScreen, pulse.getAvailable()};

  if (previousTracking == tracking && update != SensorUpdate::hardware &&
      currentTime - lastPrint < printInterval)
    return;

  previousTracking = tracking;
  lastPrint = currentTime;
  const auto scores = copyScores(now);
  std::ostringstream out;
  out << std::fixed << std::boolalpha << std::setprecision(1);

  out << "\n=== TRANCE SENSOR UPDATE ===\n"
      << "Hardware: HealthKit=" << hardware.getHealthKit()
      << ", faceTracking=" << hardware.getFaceTracking()
      << ", TrueDepth=" << hardware.getTrueDepthCamera()
      << ", watchPaired=" << hardware.getWatchPaired() << '\n';

  out << "Heart rate (latest sample): ";
  if (pulse.getAvailable() && std::isfinite(pulse.getBpm()) &&
      pulse.getBpm() > 0) {
    out << pulse.getBpm() << " BPM";
    printAge(out, pulse.getTimestamp(), now);
  } else {
    out << "unavailable";
  }
  out << '\n';

  out << "Face: tracked=" << face.getAvailable() << ", fresh=" << faceFresh;
  if (face.getAvailable()) {
    printAge(out, face.getTimestamp(), now);
    out << ", closure left=" << face.getLeftEyeClosure()
        << ", right=" << face.getRightEyeClosure();
  }
  out << '\n';
  if (faceFresh) {
    printEye(out, "Left", face.getLeftEyeTransform());
    printEye(out, "Right", face.getRightEyeTransform());
  }

  out << "Screen: ";
  if (screen.available) {
    out << std::setprecision(1) << screen.pixelWidth << 'x'
        << screen.pixelHeight
        << " px, raw gaze span=" << length(screen.horizontal) * 1000 << 'x'
        << length(screen.vertical) * 1000
        << " mm, raw fit error=" << screen.calibrationError * 1000
        << " mm, mapping error=" << screen.normalizedCalibrationError * 100
        << "%\nCalibration top-left (camera, m)=";
    printVector(out, screen.topLeft);
  } else {
    out << "uncalibrated";
  }
  out << ", samples/point=" << screenCalibrationSampleCount() << '\n';

  out << "Gaze: ";
  printHit(out, "left", gaze.leftEye);
  out << " | ";
  printHit(out, "right", gaze.rightEye);
  out << " | ";
  printHit(out, "combined", gaze.combined);
  out << '\n';

  out << "Snapshot focus point (camera, m): ";
  if (faceFresh && face.getFocusPointAvailable()) {
    const auto point = face.getFocusPoint();
    printVector(out, {point.getX(), point.getY(), point.getZ()});
  } else {
    out << "unavailable";
  }
  out << '\n';

  printScore(out, "Relaxation", scores.afslapningsscore, previousRelaxation);
  printScore(out, "Focus", scores.fokusscore, previousFocus);
  std::cout << out.str() << std::flush;
}

} // namespace trance
