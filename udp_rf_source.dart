import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../core/models/human_pose.dart';
import '../domain/rf_source.dart';
import 'aura_rf_protocol.dart';

/// مستقبل UDP مباشر من ESP32. بالإضافة للاستقبال يرسل keepalive إلى ESP
/// حتى يبقى هناك uplink Wi-Fi يولد إطارات يمكن للـPHY استخراج CSI منها.
class UdpRfSource implements RfFrameSource {
  UdpRfSource({this.port = 8765, this.espAddress = '192.168.4.1', this.controlPort = 8766});

  final int port;
  final String espAddress;
  final int controlPort;
  RawDatagramSocket? _socket;
  RawDatagramSocket? _controlSocket;
  Timer? _keepAlive;
  StreamSubscription<RawSocketEvent>? _subscription;
  final StreamController<RfFrame> _frames = StreamController<RfFrame>.broadcast();
  final List<RfFrame> _queue = <RfFrame>[];
  Completer<RfFrame>? _waiter;
  final HumanPose3D _emptyPose = HumanPose3D(
    trackId: 0,
    keypoints: List<PoseKeypoint>.generate(
      17,
      (_) => PoseKeypoint(position: Vector3.zero(), confidence: 0),
      growable: false,
    ),
  );

  Future<void> start() async {
    if (_socket != null) return;
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
    _socket = socket;
    _controlSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final datagram = socket.receive();
      if (datagram == null) return;
      try {
        final packet = AuraRfPacket.parse(Uint8List.fromList(datagram.data));
        if (packet.real.isEmpty) return;
        final frame = RfFrame(
          real: packet.real,
          imaginary: packet.imaginary,
          sampleRateHz: 60,
          carrierHz: packet.centerFrequencyHz > 0 ? packet.centerFrequencyHz : 2.437e9,
          pose: _emptyPose.copy(),
        );
        _frames.add(frame);
        if (_waiter != null && !_waiter!.isCompleted) {
          final w = _waiter!; _waiter = null; w.complete(frame);
        } else {
          if (_queue.length >= 8) _queue.removeAt(0);
          _queue.add(frame);
        }
      } on FormatException {
        // تجاهل الإطار التالف واستمرار التدفق.
      }
    });
    _keepAlive = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final data = Uint8List.fromList(<int>[0x41, 0x56, 0x31, 0x00]);
      _controlSocket?.send(data, InternetAddress(espAddress), controlPort);
    });
  }

  Stream<RfFrame> get frames => _frames.stream;

  @override
  Future<RfFrame> nextFrame() async {
    await start();
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    _waiter ??= Completer<RfFrame>();
    return _waiter!.future;
  }

  Future<void> dispose() async {
    _keepAlive?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _controlSocket?.close();
    _socket = null;
    _controlSocket = null;
    await _frames.close();
  }
}
