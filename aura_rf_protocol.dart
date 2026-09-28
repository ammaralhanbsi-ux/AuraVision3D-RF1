import 'dart:typed_data';

/// بروتوكول AuraVision RF v1.
/// الرأس 32 بايت Little Endian ثم CSI خام كما يخرجه ESP-IDF: Imaginary,Real,Imaginary,Real... كـ signed int8.
class AuraRfPacket {
  AuraRfPacket({
    required this.transport,
    required this.flags,
    required this.sequence,
    required this.timestampUs,
    required this.centerFrequencyHz,
    required this.rssiDbm,
    required this.noiseDbm,
    required this.csi,
  });

  static const int headerLength = 32;
  static const int magic = 0x41565246;
  static const int version = 1;

  final int transport;
  final int flags;
  final int sequence;
  final int timestampUs;
  final double centerFrequencyHz;
  final int rssiDbm;
  final int noiseDbm;
  final List<int> csi;

  static AuraRfPacket parse(Uint8List bytes) {
    if (bytes.length < headerLength) throw const FormatException('إطار RF أقصر من الرأس');
    final b = ByteData.sublistView(bytes);
    if (b.getUint32(0, Endian.little) != magic) throw const FormatException('Magic غير صحيح');
    if (b.getUint8(4) != version) throw const FormatException('إصدار البروتوكول غير مدعوم');
    final csiLength = b.getUint16(24, Endian.little);
    if (csiLength > bytes.length - headerLength) throw const FormatException('طول CSI غير صالح');
    final payload = bytes.sublist(headerLength, headerLength + csiLength);
    final expected = b.getUint32(28, Endian.little);
    if (crc32(payload) != expected) throw const FormatException('CRC32 غير صحيح');
    return AuraRfPacket(
      transport: b.getUint8(5),
      flags: b.getUint16(6, Endian.little),
      sequence: b.getUint32(8, Endian.little),
      timestampUs: b.getUint64(12, Endian.little),
      centerFrequencyHz: b.getUint16(20, Endian.little) * 1e6,
      rssiDbm: b.getInt8(22),
      noiseDbm: b.getInt8(23),
      csi: List<int>.unmodifiable(payload),
    );
  }

  List<double> get real => _complexComponent(true);
  List<double> get imaginary => _complexComponent(false);

  List<double> _complexComponent(bool realPart) {
    final n = csi.length ~/ 2;
    final result = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final value = csi[i * 2 + (realPart ? 1 : 0)];
      result[i] = value.toDouble();
    }
    return result;
  }

  static int crc32(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final value in data) {
      crc ^= value & 0xFF;
      for (var i = 0; i < 8; i++) {
        crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xEDB88320 : 0);
      }
    }
    return (~crc) & 0xFFFFFFFF;
  }
}

/// إعادة تجميع BLE: [sequence16][offset16][total16][payload].
class AuraBleReassembler {
  int? _sequence;
  int? _total;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  int _received = 0;

  Uint8List? add(Uint8List chunk) {
    if (chunk.length < 6) return null;
    final d = ByteData.sublistView(chunk);
    final seq = d.getUint16(0, Endian.little);
    final offset = d.getUint16(2, Endian.little);
    final total = d.getUint16(4, Endian.little);
    if (offset == 0) {
      _sequence = seq;
      _total = total;
      _buffer.clear();
      _received = 0;
    }
    if (_sequence != seq || _total != total || offset != _received) return null;
    _buffer.add(chunk.sublist(6));
    _received += chunk.length - 6;
    if (_received == total) {
      final result = _buffer.takeBytes();
      _sequence = null;
      _total = null;
      _received = 0;
      return result;
    }
    return null;
  }
}
