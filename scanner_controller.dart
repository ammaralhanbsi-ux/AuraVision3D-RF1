import 'dart:async';
import 'dart:math' as math;

import 'package:aura_rf_ffi/aura_rf_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/scan_snapshot.dart';
import '../data/rf_material_classifier.dart';
import '../data/rf_pose_estimator.dart';
import '../data/synthetic_rf_source.dart';
import '../data/udp_rf_source.dart';
import '../data/ble_rf_source.dart';
import '../data/sam_m50_pro_source.dart';
import '../domain/rf_source.dart';

final scannerControllerProvider = NotifierProvider<ScannerController, ScanState>(
  ScannerController.new,
);

class ScanState {
  const ScanState({required this.snapshot, required this.isRunning});

  factory ScanState.initial() => ScanState(
        snapshot: ScanSnapshot(
          timestamp: DateTime.now(),
          frequencyHz: 5.18e9,
          dopplerHz: 0,
          dynamicScore: 0,
          attenuationDb: 0,
          material: MaterialClass.unknown,
          materialConfidence: 0,
          distanceMeters: 2.4,
          positiveDelta: 0,
          pose: SyntheticRfSource().demoPose(0),
        ),
        isRunning: false,
      );

  final ScanSnapshot snapshot;
  final bool isRunning;

  ScanState copyWith({ScanSnapshot? snapshot, bool? isRunning}) {
    return ScanState(
      snapshot: snapshot ?? this.snapshot,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

class ScannerController extends Notifier<ScanState> {
  late final AuraRfEngine _engine;
  late RfFrameSource _source;
  late final NativePoseEstimator _poseEstimator;
  late final NativeMaterialClassifier _materialClassifier;
  Timer? _timer;
  double _previousDynamic = 0;
  double _previousRouterActivity = 0;

  @override
  ScanState build() {
    _engine = AuraRfEngine();
    _source = UdpRfSource();
    _poseEstimator = NativePoseEstimator(_engine);
    _materialClassifier = NativeMaterialClassifier(_engine);
    ref.onDispose(() {
      _timer?.cancel();
      if (_source is UdpRfSource) { unawaited((_source as UdpRfSource).dispose()); }
      if (_source is BleRfSource) { unawaited((_source as BleRfSource).dispose()); }
      if (_source is SamM50ProSource) { unawaited((_source as SamM50ProSource).dispose()); }
      _engine.dispose();
    });
    return ScanState.initial();
  }

  /// يبدّل إلى UDP المباشر من ESP32. هذا هو المسار الافتراضي للإنتاج.
  void useUdp() {
    _timer?.cancel();
    if (_source is UdpRfSource) return;
    if (_source is BleRfSource) unawaited((_source as BleRfSource).dispose());
    if (_source is SamM50ProSource) unawaited((_source as SamM50ProSource).dispose());
    _source = UdpRfSource();
  }

  /// يبدّل إلى BLE GATT. يستعمل عند عدم توفر UDP أو أثناء الإعداد الميداني.
  Future<void> useBle() async {
    _timer?.cancel();
    if (_source is UdpRfSource) await (_source as UdpRfSource).dispose();
    if (_source is SamM50ProSource) await (_source as SamM50ProSource).dispose();
    final source = BleRfSource();
    await source.connect();
    _source = source;
  }

  /// يربط الهاتف مباشرةً بلوحة SAM M50 PRO المحلية على 192.168.8.1.
  /// لا ينفذ أي أمر تغيير إعدادات؛ يقرأ Telemetry فقط.
  void useSamM50Pro({String? username, String? password, String? cookieHeader}) {
    _timer?.cancel();
    if (_source is UdpRfSource) unawaited((_source as UdpRfSource).dispose());
    if (_source is BleRfSource) unawaited((_source as BleRfSource).dispose());
    if (_source is SamM50ProSource) unawaited((_source as SamM50ProSource).dispose());
    _source = SamM50ProSource(
      username: username,
      password: password,
      cookieHeader: cookieHeader,
    );
  }

  void toggleRunning() {
    if (state.isRunning) {
      _timer?.cancel();
      state = state.copyWith(isRunning: false);
      return;
    }
    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => tick());
    unawaited(tick());
  }

  Future<void> tick() async {
    final frame = await _source.nextFrame();
    final router = frame.routerTelemetry;
    if (router != null) {
      final activity = router.activity;
      final motion = (activity * 0.72 + _previousRouterActivity * 0.28).clamp(0.0, 1.0);
      _previousRouterActivity = activity;
      state = state.copyWith(
        snapshot: ScanSnapshot(
          timestamp: router.timestamp,
          frequencyHz: (router.frequencyMHz ?? 0) * 1e6,
          dopplerHz: 0,
          dynamicScore: motion,
          attenuationDb: 0,
          material: MaterialClass.unknown,
          materialConfidence: 0,
          distanceMeters: 0,
          positiveDelta: activity,
          pose: frame.pose,
          routerTelemetry: router,
        ),
      );
      return;
    }
    final rf = _engine.processCsi(
      real: frame.real,
      imaginary: frame.imaginary,
      sampleRateHz: frame.sampleRateHz,
      carrierHz: frame.carrierHz,
    );
    final pose = _poseEstimator.smooth(frame.pose, 0.24);
    final motion = (rf.motionScore * 0.65) +
        ((_previousDynamic * 0.35).clamp(0.0, 1.0));
    _previousDynamic = motion;
    final material = _materialClassifier.classify(
      attenuationDb: rf.attenuationDb,
      dynamicScore: motion,
      positiveDelta: rf.positiveDelta,
    );
    state = state.copyWith(
      snapshot: ScanSnapshot(
        timestamp: DateTime.now(),
        frequencyHz: frame.carrierHz,
        dopplerHz: rf.dopplerHz,
        dynamicScore: motion,
        attenuationDb: rf.attenuationDb,
        material: material,
        materialConfidence: rf.confidence,
        distanceMeters: 2.4 + 0.08 * math.sin(DateTime.now().millisecond / 1000),
        positiveDelta: rf.positiveDelta,
        pose: pose,
      ),
    );
  }
}
