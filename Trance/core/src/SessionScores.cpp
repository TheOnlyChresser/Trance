#include "../lib/SessionScores.hpp"

#include <algorithm>
#include <cmath>
#include <deque>
#include <mutex>

namespace trance {

namespace {

struct Observation {
  double time, value;
  bool valid;
};

struct Window {
  // grace er hvor længe scoren overlever et hul i målingerne, fx når man
  // blinker
  double duration, maxAge, grace;
  bool calibrated = false;
  std::deque<Observation> samples{};

  void prune(double now) {
    while (samples.size() > 1 && samples[1].time <= now - duration)
      samples.pop_front();
  }
};

struct State {
  bool active = false;
  double started = 0, startBpm = 0, relaxedBpm = 0;

  double targetX = 0, targetY = 0, radius = 0;

  double baselineSum = 0, baselineStart = 0, baselineLast = 0;
  int baselineCount = 0;

  Window heart{30, 15, 0}, gaze{10, maximumGazeSampleAge, 1};
};

State state;
std::mutex stateMutex;

bool running(double now) {
  return state.active && std::isfinite(now) && now >= state.started;
}

bool isFresh(double time, double now, double maxAge) {
  return time >= state.started && time <= now && now - time <= maxAge;
}

void clearHistory() {
  state.heart.samples.clear();
  state.gaze.samples.clear();

  state.baselineSum = state.baselineStart = state.baselineLast = 0;
  state.baselineCount = 0;
}

void record(Window &window, bool available, double value, double time,
            double now) {
  if (!window.calibrated || !running(now))
    return;

  auto &samples = window.samples;

  if (!samples.empty()) {
    const double lastTime = samples.back().time;

    if (now <= lastTime || (available && time <= lastTime))
      return;
  }

  const bool fresh = isFresh(time, now, window.maxAge);
  const bool valid = available && fresh && std::isfinite(value);

  if (!fresh || !available)
    time = now;

  samples.push_back({time, valid ? value : 0, valid});

  window.prune(now);
}

ScoreValue average(Window &window, double now) {
  window.prune(now);

  const auto &samples = window.samples;
  ScoreValue result;

  if (samples.empty() || samples.back().time > now)
    return result;

  double total = 0, duration = 0, lastEnd = -INFINITY;

  for (std::size_t i = 0; i < samples.size(); ++i) {
    const auto &sample = samples[i];

    if (!sample.valid)
      continue;

    const double next = i + 1 < samples.size() ? samples[i + 1].time : now;
    const double end = std::min({now, next, sample.time + window.maxAge});
    const double begin =
        std::max({sample.time, state.started, now - window.duration});
    const double dt = std::max(0.0, end - begin);

    total += sample.value * dt;
    duration += dt;
    lastEnd = end;
  }

  result.coverage = std::clamp(duration / window.duration, 0.0, 1.0);

  // et blink må ikke gøre scoren utilgængelig, men den forsvinder, hvis
  // målingerne stopper i længere tid end grace
  if (now - lastEnd <= window.grace && duration + 1e-8 >= window.duration / 2) {
    result.value = total / duration;
    result.available = true;
  }

  return result;
}

bool relaxationReference(double startBpm, double relaxedBpm) {
  const bool finite = std::isfinite(startBpm) && std::isfinite(relaxedBpm);
  const bool lowerPulse = relaxedBpm > 0 && startBpm - relaxedBpm >= 1;

  state.heart.samples.clear();
  state.startBpm = startBpm;
  state.relaxedBpm = relaxedBpm;
  state.heart.calibrated = finite && lowerPulse;

  return state.heart.calibrated;
}

ScoreValue normalized(ScoreValue score) {
  if (!score.available || !std::isfinite(score.value))
    return {false, 0, score.coverage};

  score.value = std::clamp(score.value, 0.0, 1.0);

  return score;
}

} // namespace

bool setRelaxationReference(double startBpm, double relaxedBpm) {
  const std::lock_guard lock(stateMutex);

  return relaxationReference(startBpm, relaxedBpm);
}

bool setFocusTarget(double x, double y, double radius) {
  const auto screen = copyCalibratedScreen();
  const std::lock_guard lock(stateMutex);

  const bool onScreen = x >= 0 && x <= screen.pixelWidth - 1 && y >= 0 &&
                        y <= screen.pixelHeight - 1;

  const double maxRadius =
      std::min(screen.pixelWidth, screen.pixelHeight) / 2.0;
  const bool validRadius = radius > 0 && radius <= maxRadius;
  const bool valid = screen.available && onScreen && validRadius;

  const bool sameTarget = std::abs(x - state.targetX) < 1e-6 &&
                          std::abs(y - state.targetY) < 1e-6 &&
                          std::abs(radius - state.radius) < 1e-6;

  if (valid && state.gaze.calibrated && sameTarget)
    return true;

  state.gaze.samples.clear();
  state.targetX = x;
  state.targetY = y;
  state.radius = radius;
  state.gaze.calibrated = valid;

  return valid;
}

void clearScoreCalibration() {
  const std::lock_guard lock(stateMutex);

  state.heart.calibrated = state.gaze.calibrated = false;
  clearHistory();
}

void startScores(double now) {
  const std::lock_guard lock(stateMutex);

  state.active = std::isfinite(now) && now >= 0;
  state.started = now;
  clearHistory();
}

void stopScores() {
  const std::lock_guard lock(stateMutex);

  state.active = false;
  clearHistory();
}

void recordScoreHeartRate(bool available, double bpm, double timestamp,
                          double now) {
  const std::lock_guard lock(stateMutex);

  const bool validPulse = available && std::isfinite(bpm) && bpm > 0;
  const bool newSample =
      state.baselineCount == 0 || timestamp > state.baselineLast;
  const bool collectBaseline = !state.heart.calibrated && running(now);

  if (collectBaseline && validPulse && newSample &&
      isFresh(timestamp, now, state.heart.maxAge)) {
    if (timestamp - state.baselineLast >= state.heart.maxAge) {
      state.baselineCount = 0;
      state.baselineSum = 0;
    }

    if (state.baselineCount == 0)
      state.baselineStart = timestamp;

    state.baselineLast = timestamp;
    state.baselineSum += bpm;
    ++state.baselineCount;

    if (state.baselineCount >= 3 && timestamp - state.baselineStart >= 10) {
      const double baseline = state.baselineSum / state.baselineCount;
      relaxationReference(baseline, baseline * 0.9);
    }
  }

  record(state.heart, available, bpm > 0 ? bpm : NAN, timestamp, now);
}

void recordScoreGaze(ScreenGaze gaze, double now) {
  const std::lock_guard lock(stateMutex);

  const auto hit = gaze.combined;
  const bool available =
      hit.available && std::isfinite(hit.x) && std::isfinite(hit.y);

  const double distance =
      std::hypot(hit.x - state.targetX, hit.y - state.targetY);
  const double focused = hit.onScreen && distance <= state.radius ? 1 : 0;

  record(state.gaze, available, focused, gaze.timestamp, now);
}

SessionScores copyScores(double now) {
  const std::lock_guard lock(stateMutex);

  if (!running(now))
    return {};

  auto relaxation = average(state.heart, now);

  if (relaxation.available)
    relaxation.value = (state.startBpm - relaxation.value) /
                       (state.startBpm - state.relaxedBpm);

  return {normalized(relaxation), normalized(average(state.gaze, now))};
}

} // namespace trance
