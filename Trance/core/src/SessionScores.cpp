#include "../lib/SessionScores.hpp"

#include <algorithm>
#include <cmath>
#include <deque>
#include <mutex>
#include <numbers>

namespace trance {

namespace {

struct Observation {
  double time, value;
  bool valid;
};

struct Window {
  double duration, maxAge;
  bool calibrated = false;
  std::deque<Observation> samples{};

  void prune(double now) {
    while (samples.size() > 1 && samples[1].time <= now - duration)
      samples.pop_front();
  }
};

struct State {
  bool active = false;
  double started = 0, startBpm = 0, relaxedBpm = 0, minCosine = 1;
  ScoreVector3 target;
  Window heart{30, 15}, gaze{10, 0.25};
};

State state;
std::mutex stateMutex;

bool running(double now) {
  return state.active && std::isfinite(now) && now >= state.started;
}

void clearHistory() {
  state.heart.samples.clear();
  state.gaze.samples.clear();
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

  const bool fresh =
      time >= state.started && time <= now && now - time < window.maxAge;
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

  double total = 0, duration = 0;

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
  }

  result.coverage = std::clamp(duration / window.duration, 0.0, 1.0);

  if (samples.back().valid && now - samples.back().time < window.maxAge &&
      duration + 1e-8 >= window.duration / 2) {
    result.value = total / duration;
    result.available = true;
  }

  return result;
}

bool normalize(ScoreVector3 &v) {
  const double length = std::hypot(v.x, v.y, v.z);

  if (!std::isfinite(length) || length <= 1e-12)
    return false;

  v = {v.x / length, v.y / length, v.z / length};
  return true;
}

double gazeValue(ScoreFaceSample sample) {
  if (!(sample.leftEyeClosure >= 0 && sample.leftEyeClosure < 0.5 &&
        sample.rightEyeClosure >= 0 && sample.rightEyeClosure < 0.5))
    return NAN;

  auto left = sample.leftDirection, right = sample.rightDirection;

  if (!normalize(left) || !normalize(right))
    return NAN;

  ScoreVector3 gaze{left.x + right.x, left.y + right.y, left.z + right.z};
  ScoreVector3 target{
      state.target.x - (sample.leftOrigin.x / 2 + sample.rightOrigin.x / 2),
      state.target.y - (sample.leftOrigin.y / 2 + sample.rightOrigin.y / 2),
      state.target.z - (sample.leftOrigin.z / 2 + sample.rightOrigin.z / 2)};

  if (!normalize(gaze) || !normalize(target))
    return NAN;

  return gaze.x * target.x + gaze.y * target.y + gaze.z * target.z >=
                 state.minCosine
             ? 1
             : 0;
}

ScoreValue normalized(ScoreValue score) {
  if (!score.available || !std::isfinite(score.value))
    return {false, 0, score.coverage};

  score.value = std::clamp(score.value, 0.0, 1.0);

  return score;
}

}

bool setRelaxationReference(double startBpm, double relaxedBpm) {
  const std::lock_guard lock(stateMutex);

  state.heart.samples.clear();
  state.startBpm = startBpm;
  state.relaxedBpm = relaxedBpm;
  state.heart.calibrated = std::isfinite(startBpm) &&
                           std::isfinite(relaxedBpm) && relaxedBpm > 0 &&
                           startBpm - relaxedBpm >= 1;

  return state.heart.calibrated;
}

bool setFocusTarget(ScoreVector3 target, double toleranceRadians) {
  const std::lock_guard lock(stateMutex);

  state.gaze.samples.clear();
  state.target = target;
  state.gaze.calibrated = std::isfinite(target.x) && std::isfinite(target.y) &&
                          std::isfinite(target.z) && toleranceRadians > 0 &&
                          toleranceRadians < std::numbers::pi / 2;
  state.minCosine = state.gaze.calibrated ? std::cos(toleranceRadians) : 1;

  return state.gaze.calibrated;
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

  record(state.heart, available, bpm > 0 ? bpm : NAN, timestamp, now);
}

void recordScoreFace(ScoreFaceSample sample, double now) {
  const std::lock_guard lock(stateMutex);

  record(state.gaze, sample.available, gazeValue(sample), sample.timestamp,
         now);
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

}
