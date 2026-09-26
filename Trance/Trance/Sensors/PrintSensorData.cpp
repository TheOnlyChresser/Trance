#include "SensorData.hpp"

#include <chrono>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <optional>

#include "../../core/lib/SessionScores.hpp"

namespace trance {
namespace {

constexpr auto scorePrintInterval = std::chrono::seconds(6);

std::mutex scorePrintMutex;
std::chrono::steady_clock::time_point lastScorePrint;
std::optional<double> previousRelaxation;
std::optional<double> previousFocus;

void printScore(const char *label, ScoreValue score,
                std::optional<double> &previous) {
  std::cout << label << ": ";

  if (!score.available) {
    std::cout << "unavailable";
    previous.reset();
    return;
  }

  const double percent = score.value * 100;
  std::cout << std::fixed << std::setprecision(1) << percent << '%';

  if (previous) {
    const double change = percent - *previous * 100;
    std::cout << " (" << std::showpos << change << std::noshowpos << " pp)";
  }

  previous = score.value;
}

} // namespace

void sensorDataChanged(SensorUpdate) {
  const auto currentTime = std::chrono::steady_clock::now();
  const std::lock_guard lock(scorePrintMutex);

  if (lastScorePrint.time_since_epoch().count() != 0 &&
      currentTime - lastScorePrint < scorePrintInterval)
    return;

  lastScorePrint = currentTime;

  const double now =
      std::chrono::duration<double>(
          std::chrono::system_clock::now().time_since_epoch())
          .count();
  const auto scores = copyScores(now);

  std::cout << "=== SCORE UPDATE === ";
  printScore("Relaxation", scores.afslapningsscore, previousRelaxation);
  std::cout << " | ";
  printScore("Focus", scores.fokusscore, previousFocus);
  std::cout << std::endl;
}
} // namespace trance
