#ifndef AURAVISION_RF_ENGINE_H_
#define AURAVISION_RF_ENGINE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AuraRfFeatures {
  double doppler_hz;
  double motion_score;
  double attenuation_db;
  double positive_delta;
  double confidence;
} AuraRfFeatures;

void* aura_engine_create(void);
void aura_engine_destroy(void* handle);

double aura_estimate_doppler(double velocity_mps, double wavelength_m, double cos_theta);

void aura_process_csi(
    const float* real,
    const float* imaginary,
    int32_t length,
    double sample_rate_hz,
    double carrier_hz,
    AuraRfFeatures* out_features);

void aura_smooth_pose(
    void* handle,
    const float* xyz,
    int32_t point_count,
    double alpha,
    float* output_xyz);

int32_t aura_classify_material(
    double attenuation_db,
    double dynamic_score,
    double positive_delta);

#ifdef __cplusplus
}
#endif

#endif
