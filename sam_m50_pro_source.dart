import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:vector_math/vector_math_64.dart';

import '../../core/models/human_pose.dart';
import '../../core/models/router_telemetry.dart';
import '../domain/rf_source.dart';

/// مصدر قراءة آمن (GET فقط) لراوتر SAM M50 PRO.
///
/// لا يفترض API داخلياً غير موثق. يبدأ بصفحة الإدارة ثم يجرب مسارات
/// حالة شائعة قابلة للضبط، ويستخرج حقول JSON المعروفة حتى لو تغيرت
/// بنية الرد. لا ينفذ أي POST/PUT/DELETE ولا يغيّر إعدادات الراوتر.
class SamM50ProSource implements RfFrameSource {
  SamM50ProSource({
    this.baseUri = const Uri(scheme: 'http', host: '192.168.8.1'),
    this.username,
    this.password,
    this.cookieHeader,
    this.pollInterval = const Duration(milliseconds: 1000),
    this.requestTimeout = const Duration(seconds: 3),
    List<String>? candidatePaths,
  }) : candidatePaths = candidatePaths ?? const <String>[
          '/',
          '/api/status',
          '/api/device/status',
          '/api/monitor/status',
          '/api/monitoring/status',
          '/api/device/information',
          '/api/network/status',
          '/status',
          '/status.json',
          '/api/status.json',
        ];

  final Uri baseUri;
  final String? username;
  final String? password;
  final String? cookieHeader;
  final Duration pollInterval;
  final Duration requestTimeout;
  final List<String> candidatePaths;

  final HttpClient _client = HttpClient();
  final HumanPose3D _emptyPose = HumanPose3D(
    trackId: 0,
    keypoints: List<PoseKeypoint>.generate(
      17,
      (_) => PoseKeypoint(position: Vector3.zero(), confidence: 0),
      growable: false,
    ),
  );

  RouterTelemetry? _last;
  DateTime? _lastPoll;
  Uri? _workingUri;
  String? _lastError;
  Future<RouterTelemetry>? _inFlight;

  String? get lastError => _lastError;
  Uri? get workingUri => _workingUri;

  @override
  Future<RfFrame> nextFrame() async {
    final now = DateTime.now();
    if (_lastPoll != null && now.difference(_lastPoll!) < pollInterval && _last != null) {
      return _toFrame(_last!);
    }
    _lastPoll = now;
    final telemetry = await fetchTelemetry();
    return _toFrame(telemetry);
  }

  Future<RouterTelemetry> fetchTelemetry() {
    final active = _inFlight;
    if (active != null) return active;
    final future = _fetchTelemetryInternal();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<RouterTelemetry> _fetchTelemetryInternal() async {
    final responses = <_HttpPayload>[];
    final paths = <String>{...candidatePaths};
    if (_workingUri != null) paths.add(_workingUri!.path);

    for (final path in paths) {
      try {
        final uri = baseUri.replace(path: path.isEmpty ? '/' : path);
        final payload = await _get(uri);
        responses.add(payload);
        final telemetry = _extractTelemetry(payload.body, uri.toString());
        if (telemetry != null) {
          _workingUri = uri;
          _lastError = null;
          _last = telemetry;
          return telemetry;
        }
      } catch (e) {
        _lastError = e.toString();
      }
    }

    // إذا لم نجد JSON منظماً، نحلل HTML الخاص بلوحة التحكم.
    for (final response in responses) {
      final telemetry = _extractTelemetry(response.body, response.uri.toString());
      if (telemetry != null) {
        _workingUri = response.uri;
        _lastError = null;
        _last = telemetry;
        return telemetry;
      }
    }

    throw StateError(
      'تعذر اكتشاف بيانات SAM M50 PRO من ${baseUri.host}. '
      'تحقق من اتصال الهاتف بشبكة الراوتر وتسجيل الدخول. '
      'آخر خطأ: ${_lastError ?? 'لا توجد بيانات قابلة للقراءة'}',
    );
  }

  Future<_HttpPayload> _get(Uri uri) async {
    final request = await _client.getUrl(uri).timeout(requestTimeout);
    request.followRedirects = true;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json,text/html;q=0.9,*/*;q=0.8');
    if (username != null && password != null) {
      request.headers.set(HttpHeaders.authorizationHeader,
          'Basic ${base64Encode(utf8.encode('$username:$password'))}');
    }
    if (cookieHeader != null && cookieHeader!.isNotEmpty) {
      request.headers.set(HttpHeaders.cookieHeader, cookieHeader!);
    }
    final response = await request.close().timeout(requestTimeout);
    final body = await utf8.decodeStream(response).timeout(requestTimeout);
    if (response.statusCode == HttpStatus.unauthorized || response.statusCode == HttpStatus.forbidden) {
      throw HttpException('HTTP ${response.statusCode}: يلزم تسجيل الدخول إلى لوحة SAM M50 PRO', uri: uri);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return _HttpPayload(uri, body, response.headers.contentType?.mimeType);
  }

  RouterTelemetry? _extractTelemetry(String body, String source) {
    final json = _tryJson(body);
    if (json != null) {
      final map = _flatten(json);
      final found = RouterTelemetry(
        timestamp: DateTime.now(),
        networkType: _string(map, const ['networktype', 'network_type', 'rat', 'mode', 'network']),
        rssiDbm: _number(map, const ['rssi', 'wifi_signal', 'wifisignal']),
        rsrpDbm: _number(map, const ['rsrp', 'lte_rsrp']),
        rsrqDb: _number(map, const ['rsrq', 'lte_rsrq']),
        sinrDb: _number(map, const ['sinr', 'lte_sinr', 'snr']),
        signalPercent: _number(map, const ['signal', 'signalstrength', 'signal_strength', 'signalpercent', 'signal_percent']),
        batteryPercent: _number(map, const ['battery', 'batterylevel', 'battery_level']),
        txMbps: _rateMbps(map, const ['txrate', 'tx_rate', 'upload', 'uploadspeed', 'tx']),
        rxMbps: _rateMbps(map, const ['rxrate', 'rx_rate', 'download', 'downloadspeed', 'rx']),
        connectedClients: _integer(map, const ['connectedclients', 'connected_clients', 'clients', 'usercount', 'users']),
        ssid: _string(map, const ['ssid', 'wifi_ssid', 'wifiname']),
        channel: _integer(map, const ['channel', 'wifi_channel']),
        bandwidthMHz: _number(map, const ['bandwidth', 'channelbandwidth', 'channel_bandwidth']),
        frequencyMHz: _number(map, const ['frequency', 'freq', 'earfcn_frequency']),
        dataRxBytes: _integer(map, const ['datarx', 'data_rx', 'rxbytes', 'rx_bytes']),
        dataTxBytes: _integer(map, const ['datatx', 'data_tx', 'txbytes', 'tx_bytes']),
        source: source,
      );
      if (_hasSignal(found) || found.networkType != null || found.connectedClients != null) return found;
    }

    return _extractFromHtml(body, source);
  }

  RouterTelemetry? _extractFromHtml(String body, String source) {
    final text = body.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ');
    double? numberAfter(List<String> labels) {
      for (final label in labels) {
        final pattern = RegExp('${RegExp.escape(label)}\\s*[:=]\\s*(-?\\d+(?:\\.\\d+)?)', caseSensitive: false);
        final m = pattern.firstMatch(text);
        if (m != null) return double.tryParse(m.group(1)!);
      }
      return null;
    }

    final telemetry = RouterTelemetry(
      timestamp: DateTime.now(),
      networkType: _textAfter(text, const ['network', 'network type', 'mode']),
      rssiDbm: numberAfter(const ['RSSI', 'WiFi Signal']),
      rsrpDbm: numberAfter(const ['RSRP']),
      rsrqDb: numberAfter(const ['RSRQ']),
      sinrDb: numberAfter(const ['SINR', 'SNR']),
      signalPercent: numberAfter(const ['signal', 'signal strength']),
      batteryPercent: numberAfter(const ['battery', 'battery level']),
      txMbps: numberAfter(const ['upload', 'tx rate', 'tx']),
      rxMbps: numberAfter(const ['download', 'rx rate', 'rx']),
      connectedClients: numberAfter(const ['clients', 'connected devices'])?.round(),
      ssid: _textAfter(text, const ['SSID', 'WiFi SSID']),
      channel: numberAfter(const ['channel'])?.round(),
      bandwidthMHz: numberAfter(const ['bandwidth', 'channel bandwidth']),
      source: source,
    );
    if (_hasSignal(telemetry) || telemetry.networkType != null || telemetry.connectedClients != null) return telemetry;
    return null;
  }

  RfFrame _toFrame(RouterTelemetry telemetry) {
    // لا نسمّي هذه CSI: هي عينة محايدة فقط حتى يبقى العقد الحالي قابلاً
    // للعمل. الـController يعالج routerTelemetry كـTelemetry وليس كـCSI.
    return RfFrame(
      real: const <double>[1.0],
      imaginary: const <double>[0.0],
      sampleRateHz: 1.0,
      carrierHz: (telemetry.frequencyMHz ?? 0) * 1e6,
      pose: _emptyPose.copy(),
      routerTelemetry: telemetry,
    );
  }

  static dynamic _tryJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _flatten(dynamic value, [String prefix = '']) {
    final result = <String, dynamic>{};
    if (value is Map) {
      value.forEach((key, child) {
        final name = prefix.isEmpty ? '$key' : '$prefix.$key';
        result[name.toLowerCase()] = child;
        result.addAll(_flatten(child, name));
      });
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        result.addAll(_flatten(value[i], '$prefix.$i'));
      }
    }
    return result;
  }

  static dynamic _lookup(Map<String, dynamic> map, List<String> aliases) {
    for (final alias in aliases) {
      final target = alias.toLowerCase();
      for (final entry in map.entries) {
        final key = entry.key.split('.').last.toLowerCase();
        if (key == target) return entry.value;
      }
    }
    return null;
  }

  static double? _number(Map<String, dynamic> map, List<String> aliases) {
    final value = _lookup(map, aliases);
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(RegExp('[^0-9+\\-.]'), ''));
    return null;
  }

  static double? _rateMbps(Map<String, dynamic> map, List<String> aliases) {
    final value = _number(map, aliases);
    if (value == null) return null;
    final raw = _lookup(map, aliases)?.toString().toLowerCase() ?? '';
    if (raw.contains('kbps')) return value / 1000.0;
    if (raw.contains('gbps')) return value * 1000.0;
    return value;
  }

  static int? _integer(Map<String, dynamic> map, List<String> aliases) => _number(map, aliases)?.round();

  static String? _string(Map<String, dynamic> map, List<String> aliases) {
    final value = _lookup(map, aliases);
    if (value == null) return null;
    return value.toString();
  }

  static bool _hasSignal(RouterTelemetry t) =>
      t.rssiDbm != null || t.rsrpDbm != null || t.sinrDb != null || t.signalPercent != null;

  static String? _textAfter(String text, List<String> labels) {
    for (final label in labels) {
      final m = RegExp('${RegExp.escape(label)}\\s*[:=]\\s*([^|,;]+)', caseSensitive: false).firstMatch(text);
      if (m != null) return m.group(1)?.trim();
    }
    return null;
  }

  Future<void> dispose() async => _client.close(force: true);
}

class _HttpPayload {
  const _HttpPayload(this.uri, this.body, this.contentType);
  final Uri uri;
  final String body;
  final String? contentType;
}
