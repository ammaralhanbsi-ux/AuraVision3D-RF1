import 'package:aura_rf_ffi/aura_rf_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Doppler equation remains numerically stable', () {
    final engine = AuraRfEngine();
    addTearDown(engine.dispose);

    final hz = engine.estimateDoppler(
      velocityMps: 1,
      wavelengthM: 299792458.0 / 5.18e9,
      cosTheta: 1,
    );
    expect(hz, closeTo(34.56, 0.3));
  });

  test('material classifier emits documented class IDs', () {
    final engine = AuraRfEngine();
    addTearDown(engine.dispose);
    expect(
      engine.classifyMaterial(
        attenuationDb: 1,
        dynamicScore: 0.9,
        positiveDelta: 0.2,
      ),
      3,
    );
  });
}
