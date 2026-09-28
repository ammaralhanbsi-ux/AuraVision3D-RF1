import 'package:aura_rf_ffi/aura_rf_ffi.dart';

import '../../core/models/scan_snapshot.dart';
import '../domain/rf_source.dart';

class NativeMaterialClassifier implements MaterialClassifier {
  const NativeMaterialClassifier(this.engine);

  final AuraRfEngine engine;

  @override
  MaterialClass classify({
    required double attenuationDb,
    required double dynamicScore,
    required double positiveDelta,
  }) {
    final code = engine.classifyMaterial(
      attenuationDb: attenuationDb,
      dynamicScore: dynamicScore,
      positiveDelta: positiveDelta,
    );
    return switch (code) {
      0 => MaterialClass.voidSpace,
      1 => MaterialClass.concrete,
      2 => MaterialClass.metal,
      3 => MaterialClass.dynamicHuman,
      _ => MaterialClass.unknown,
    };
  }
}
