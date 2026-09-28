#include "aura_rf_engine.h"

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstddef>
#include <cstdlib>
#include <numeric>
#include <vector>

namespace {
constexpr double kSpeedOfLight = 299'792'458.0;
constexpr double kEpsilon = 1e-9;

struct EngineState {
  std::vector<float> previous;
  bool initialized = false;
};

static double clamp01(double x) {
  return std::max(0.0, std::min(1.0, x));
}



}  // namespace

extern "C" {

void* aura_engine_create(void) {
  return new EngineState();
}

void aura_engine_destroy(void* handle) {
  delete static_cast<EngineState*>(handle);
}

double aura_estimate_doppler(double velocity_mps, double wavelength_m, double cos_theta) {
  if (!(wavelength_m > kEpsilon)) return 0.0;
  return (2.0 * velocity_mps / wavelength_m) * cos_theta;
}

void aura_process_csi(
    const float* real,
    const float* imaginary,
    int32_t length,
    double sample_rate_hz,
    double carrier_hz,
    AuraRfFeatures* out_features) {
  if (!out_features) return;
  AuraRfFeatures& out = *out_features;
  out = AuraRfFeatures{0.0, 0.0, 0.0, 0.0, 0.0};
  if (!real || !imaginary || length <= 0 || !(carrier_hz > 0.0)) return;

  std::vector<double> magnitudes;
  magnitudes.reserve(static_cast<size_t>(length));
  std::vector<double> phases;
  phases.reserve(static_cast<size_t>(length));

  for (int32_t i = 0; i < length; ++i) {
    const double re = real[i];
    const double im = imaginary[i];
    magnitudes.push_back(std::hypot(re, im));
    phases.push_back(std::atan2(im, re));
  }

  const double mean_amp = std::accumulate(magnitudes.begin(), magnitudes.end(), 0.0) /
                          static_cast<double>(magnitudes.size());
  const double rms = std::sqrt(
      std::inner_product(magnitudes.begin(), magnitudes.end(), magnitudes.begin(), 0.0) /
      static_cast<double>(magnitudes.size()));
  const double amplitude_variation = rms > kEpsilon ?
      std::sqrt(std::max(0.0, rms * rms - mean_amp * mean_amp)) / rms : 0.0;

  double phase_change = 0.0;
  for (size_t i = 1; i < phases.size(); ++i) {
    double delta = phases[i] - phases[i - 1];
    while (delta > M_PI) delta -= 2.0 * M_PI;
    while (delta < -M_PI) delta += 2.0 * M_PI;
    phase_change += std::abs(delta);
  }
  phase_change /= std::max<size_t>(1, phases.size() - 1);

  // D = mean(|H|) يستخدم هنا كإشارة موجبة لتغير القناة حول قيمة مرجعية ضمن frame واحد.
  const double positive_delta = std::max(0.0, rms - 1.0);
  const double motion_score = clamp01(0.68 * amplitude_variation +
                                      0.32 * std::min(phase_change / M_PI, 1.0));

  const double attenuation_db = -20.0 * std::log10(std::max(mean_amp, kEpsilon));
  const double wavelength = kSpeedOfLight / carrier_hz;

  // الاستدلال على السرعة من تغير الطور هنا مبسط جداً: نستخدم تردد أخذ العينات وحجم تغير الطور
  // لتقدير تردد الحركة، ثم نحقنه في معادلة Doppler كقيمة اتجاهية تقريبية.
  const double phase_rate_hz = sample_rate_hz * phase_change / (2.0 * M_PI);
  const double velocity_estimate = std::abs(phase_rate_hz) * wavelength / 2.0;
  out.doppler_hz = aura_estimate_doppler(velocity_estimate, wavelength, 1.0);
  out.motion_score = motion_score;
  out.attenuation_db = attenuation_db;
  out.positive_delta = positive_delta;
  out.confidence = clamp01(0.35 + 0.65 * (1.0 - std::abs(0.85 - rms)) *
                                  (0.5 + 0.5 * (1.0 - std::min(phase_change / M_PI, 1.0))));
  return;
}

void aura_smooth_pose(
    void* handle,
    const float* xyz,
    int32_t point_count,
    double alpha,
    float* output_xyz) {
  if (!handle || !xyz || !output_xyz || point_count <= 0) return;
  auto* state = static_cast<EngineState*>(handle);
  const size_t n = static_cast<size_t>(point_count) * 3U;
  const float a = static_cast<float>(std::max(0.01, std::min(1.0, alpha)));

  if (!state->initialized || state->previous.size() != n) {
    state->previous.assign(xyz, xyz + n);
    state->initialized = true;
  }

  for (size_t i = 0; i < n; ++i) {
    state->previous[i] = a * xyz[i] + (1.0f - a) * state->previous[i];
    output_xyz[i] = state->previous[i];
  }
}

int32_t aura_classify_material(
    double attenuation_db,
    double dynamic_score,
    double positive_delta) {
  const double d = clamp01(dynamic_score);

  // القواعد رقمية قابلة للاستبدال لاحقاً بمصنف ML مدرّب على بيانات معايرة حقيقية.
  if (d > 0.62) return 3;            // حركة بشرية محتملة
  if (positive_delta < 0.08 && attenuation_db < 1.5) return 0;  // فراغ محتمل
  if (attenuation_db > 18.0) return 2;  // استجابة شديدة الخمود/انعكاس محتمل للمعدن
  if (attenuation_db >= 2.5) return 1; // كتلة صلبة محتملة
  return 4;
}

}  // extern "C"
