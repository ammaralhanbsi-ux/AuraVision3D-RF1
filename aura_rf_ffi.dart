import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

@ffi.Native<ffi.Pointer<ffi.Void> Function()>(symbol: 'aura_engine_create')
external ffi.Pointer<ffi.Void> _createEngine();

@ffi.Native<ffi.Void Function(ffi.Pointer<ffi.Void>)>(symbol: 'aura_engine_destroy')
external void _destroyEngine(ffi.Pointer<ffi.Void> handle);

@ffi.Native<ffi.Double Function(ffi.Double, ffi.Double, ffi.Double)>(
  symbol: 'aura_estimate_doppler',
)
external double _estimateDoppler(double velocity, double wavelength, double cosTheta);

@ffi.Native<ffi.Void Function(
  ffi.Pointer<ffi.Float>,
  ffi.Pointer<ffi.Float>,
  ffi.Int32,
  ffi.Double,
  ffi.Double,
  ffi.Pointer<_NativeFeatures>,
)>(symbol: 'aura_process_csi')
external void _processCsi(
  ffi.Pointer<ffi.Float> real,
  ffi.Pointer<ffi.Float> imaginary,
  int length,
  double sampleRateHz,
  double carrierHz,
  ffi.Pointer<_NativeFeatures> output,
);

@ffi.Native<ffi.Void Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Float>,
  ffi.Int32,
  ffi.Float,
  ffi.Pointer<ffi.Float>,
)>(symbol: 'aura_smooth_pose')
external void _smoothPose(
  ffi.Pointer<ffi.Void> handle,
  ffi.Pointer<ffi.Float> xyz,
  int pointCount,
  double alpha,
  ffi.Pointer<ffi.Float> output,
);

@ffi.Native<ffi.Int32 Function(ffi.Double, ffi.Double, ffi.Double)>(
  symbol: 'aura_classify_material',
)
external int _classifyMaterial(double attenuationDb, double dynamicScore, double positiveDelta);

final class _NativeFeatures extends ffi.Struct {
  @ffi.Double()
  external double dopplerHz;

  @ffi.Double()
  external double motionScore;

  @ffi.Double()
  external double attenuationDb;

  @ffi.Double()
  external double positiveDelta;

  @ffi.Double()
  external double confidence;
}

class AuraRfFeatures {
  const AuraRfFeatures({
    required this.dopplerHz,
    required this.motionScore,
    required this.attenuationDb,
    required this.positiveDelta,
    required this.confidence,
  });

  final double dopplerHz;
  final double motionScore;
  final double attenuationDb;
  final double positiveDelta;
  final double confidence;
}

class AuraRfEngine {
  AuraRfEngine() : _handle = _createEngine();

  ffi.Pointer<ffi.Void> _handle;
  bool _disposed = false;

  AuraRfFeatures processCsi({
    required List<double> real,
    required List<double> imaginary,
    required double sampleRateHz,
    required double carrierHz,
  }) {
    _checkAlive();
    if (real.length != imaginary.length || real.isEmpty) {
      throw ArgumentError('real/imaginary يجب أن يكونا بنفس الطول وغير فارغين');
    }
    final re = calloc<ffi.Float>(real.length);
    final im = calloc<ffi.Float>(imaginary.length);
    try {
      for (var i = 0; i < real.length; i++) {
        re[i] = real[i];
        im[i] = imaginary[i];
      }
      final raw = calloc<_NativeFeatures>();
      try {
        _processCsi(re, im, real.length, sampleRateHz, carrierHz, raw);
        return AuraRfFeatures(
          dopplerHz: raw.ref.dopplerHz,
          motionScore: raw.ref.motionScore,
          attenuationDb: raw.ref.attenuationDb,
          positiveDelta: raw.ref.positiveDelta,
          confidence: raw.ref.confidence,
        );
      } finally {
        calloc.free(raw);
      }
    } finally {
      calloc
        ..free(re)
        ..free(im);
    }
  }

  List<double> smoothPose(List<double> xyz, double alpha) {
    _checkAlive();
    if (xyz.length % 3 != 0 || xyz.isEmpty) {
      throw ArgumentError('xyz يجب أن يحتوي على 3 قيم لكل نقطة');
    }
    final input = calloc<ffi.Float>(xyz.length);
    final output = calloc<ffi.Float>(xyz.length);
    try {
      for (var i = 0; i < xyz.length; i++) input[i] = xyz[i];
      _smoothPose(_handle, input, xyz.length ~/ 3, alpha, output);
      return List<double>.generate(xyz.length, (i) => output[i]);
    } finally {
      calloc
        ..free(input)
        ..free(output);
    }
  }

  double estimateDoppler({
    required double velocityMps,
    required double wavelengthM,
    required double cosTheta,
  }) {
    _checkAlive();
    return _estimateDoppler(velocityMps, wavelengthM, cosTheta);
  }

  int classifyMaterial({
    required double attenuationDb,
    required double dynamicScore,
    required double positiveDelta,
  }) {
    _checkAlive();
    return _classifyMaterial(attenuationDb, dynamicScore, positiveDelta);
  }

  void dispose() {
    if (_disposed) return;
    _destroyEngine(_handle);
    _disposed = true;
  }

  void _checkAlive() {
    if (_disposed) {
      throw StateError('AuraRfEngine تم تحريره بالفعل');
    }
  }
}
