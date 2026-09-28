class RouterTelemetry {
  const RouterTelemetry({
    required this.timestamp,
    this.networkType,
    this.rssiDbm,
    this.rsrpDbm,
    this.rsrqDb,
    this.sinrDb,
    this.signalPercent,
    this.batteryPercent,
    this.txMbps,
    this.rxMbps,
    this.connectedClients,
    this.ssid,
    this.channel,
    this.bandwidthMHz,
    this.frequencyMHz,
    this.dataRxBytes,
    this.dataTxBytes,
    this.source,
  });

  final DateTime timestamp;
  final String? networkType;
  final double? rssiDbm;
  final double? rsrpDbm;
  final double? rsrqDb;
  final double? sinrDb;
  final double? signalPercent;
  final double? batteryPercent;
  final double? txMbps;
  final double? rxMbps;
  final int? connectedClients;
  final String? ssid;
  final int? channel;
  final double? bandwidthMHz;
  final double? frequencyMHz;
  final int? dataRxBytes;
  final int? dataTxBytes;
  final String? source;

  double get activity {
    final signal = (signalPercent ?? _signalFromDbm()).clamp(0.0, 100.0) / 100.0;
    final traffic = (((rxMbps ?? 0) + (txMbps ?? 0)) / 50.0).clamp(0.0, 1.0);
    return (signal * 0.25 + traffic * 0.75).clamp(0.0, 1.0);
  }

  double _signalFromDbm() {
    final value = rssiDbm ?? rsrpDbm;
    if (value == null) return 0;
    // RSSI/RSRP אינם זהים למדד איכות, לכן זו תצוגת HUD בלבד.
    return ((value + 110.0) / 60.0 * 100.0).clamp(0.0, 100.0);
  }

  RouterTelemetry copyWith({
    DateTime? timestamp,
    String? networkType,
    double? rssiDbm,
    double? rsrpDbm,
    double? rsrqDb,
    double? sinrDb,
    double? signalPercent,
    double? batteryPercent,
    double? txMbps,
    double? rxMbps,
    int? connectedClients,
    String? ssid,
    int? channel,
    double? bandwidthMHz,
    double? frequencyMHz,
    int? dataRxBytes,
    int? dataTxBytes,
    String? source,
  }) => RouterTelemetry(
        timestamp: timestamp ?? this.timestamp,
        networkType: networkType ?? this.networkType,
        rssiDbm: rssiDbm ?? this.rssiDbm,
        rsrpDbm: rsrpDbm ?? this.rsrpDbm,
        rsrqDb: rsrqDb ?? this.rsrqDb,
        sinrDb: sinrDb ?? this.sinrDb,
        signalPercent: signalPercent ?? this.signalPercent,
        batteryPercent: batteryPercent ?? this.batteryPercent,
        txMbps: txMbps ?? this.txMbps,
        rxMbps: rxMbps ?? this.rxMbps,
        connectedClients: connectedClients ?? this.connectedClients,
        ssid: ssid ?? this.ssid,
        channel: channel ?? this.channel,
        bandwidthMHz: bandwidthMHz ?? this.bandwidthMHz,
        frequencyMHz: frequencyMHz ?? this.frequencyMHz,
        dataRxBytes: dataRxBytes ?? this.dataRxBytes,
        dataTxBytes: dataTxBytes ?? this.dataTxBytes,
        source: source ?? this.source,
      );
}
