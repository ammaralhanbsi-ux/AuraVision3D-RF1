#include <cassert>
#include <cmath>
#include <iostream>

#include "../packages/aura_rf_ffi/src/aura_rf_engine.h"

int main() {
  const double lambda = 299792458.0 / 5.18e9;
  const double hz = aura_estimate_doppler(1.0, lambda, 1.0);
  assert(std::abs(hz - 34.56) < 0.4);

  float re[56]{};
  float im[56]{};
  for (int i = 0; i < 56; ++i) {
    re[i] = 1.0f;
    im[i] = 0.0f;
  }
  AuraRfFeatures features{};
  aura_process_csi(re, im, 56, 30.0, 5.18e9, &features);
  assert(features.motion_score >= 0.0 && features.motion_score <= 1.0);

  void* handle = aura_engine_create();
  float pose[51]{};
  float out[51]{};
  aura_smooth_pose(handle, pose, 17, 0.25f, out);
  aura_engine_destroy(handle);

  assert(aura_classify_material(1.0, 0.9, 0.2) == 3);
  assert(aura_classify_material(20.0, 0.1, 0.2) == 2);
  std::cout << "AuraVision native tests: OK\n";
}
