import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../core/models/human_pose.dart';
import '../domain/rf_source.dart';
import 'aura_rf_protocol.dart';

class BleRfSource implements RfFrameSource {
  static final Guid serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid notifyUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  final _frames = StreamController<RfFrame>.broadcast();
  final _reassembler = AuraBleReassembler();
  final List<RfFrame> _queue = <RfFrame>[];
  Completer<RfFrame>? _waiter;
  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scan;
  StreamSubscription<List<int>>? _notify;

  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) async {
    await FlutterBluePlus.stopScan();
    final completer = Completer<BluetoothDevice>();
    _scan = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        if (result.device.platformName == 'AuraVision-CSI') {
          if (!completer.isCompleted) completer.complete(result.device);
          break;
        }
      }
    });
    await FlutterBluePlus.startScan(timeout: timeout, withNames: ['AuraVision-CSI']);
    final device = await completer.future.timeout(timeout);
    await _scan?.cancel();
    _device = device;
    await device.connect(timeout: timeout);
    final services = await device.discoverServices();
    final characteristic = services
        .expand((s) => s.characteristics)
        .cast<BluetoothCharacteristic?>()
        .firstWhere((c) => c?.serviceUuid == serviceUuid && c?.uuid == notifyUuid, orElse: () => null);
    if (characteristic == null) throw StateError('لم يتم العثور على خدمة AuraVision BLE');
    await characteristic.setNotifyValue(true);
    _notify = characteristic.onValueReceived.listen(_onChunk);
  }

  void _onChunk(List<int> value) {
    final packet = _reassembler.add(Uint8List.fromList(value));
    if (packet == null) return;
    try {
      final p = AuraRfPacket.parse(packet);
      final frame = RfFrame(
        real: p.real,
        imaginary: p.imaginary,
        sampleRateHz: 60,
        carrierHz: p.centerFrequencyHz > 0 ? p.centerFrequencyHz : 2.437e9,
        pose: HumanPose3D(
          trackId: 0,
          keypoints: List<PoseKeypoint>.generate(
            17,
            (_) => PoseKeypoint(position: Vector3.zero(), confidence: 0),
            growable: false,
          ),
        ),
      );
      _frames.add(frame);
      if (_waiter != null && !_waiter!.isCompleted) { final w = _waiter!; _waiter = null; w.complete(frame); } else { _queue.add(frame); }
    } on FormatException {
      // الإطار التالف لا يوقف stream.
    }
  }

  Stream<RfFrame> get frames => _frames.stream;

  @override
  Future<RfFrame> nextFrame() async {
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    _waiter ??= Completer<RfFrame>();
    return _waiter!.future;
  }

  Future<void> dispose() async {
    await _notify?.cancel();
    await _scan?.cancel();
    await _device?.disconnect();
    await _frames.close();
  }
}
