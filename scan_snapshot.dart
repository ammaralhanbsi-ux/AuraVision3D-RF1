import 'human_pose.dart';
import 'router_telemetry.dart';

enum MaterialClass { voidSpace, concrete, metal, dynamicHuman, unknown }

extension MaterialClassLabel on MaterialClass {
  String get arName => switch (this) {
        MaterialClass.voidSpace => 'فراغ محتمل',
        MaterialClass.concrete => 'كتلة صلبة',
        MaterialClass.metal => 'معدن محتمل',
        MaterialClass.dynamicHuman => 'حركة بشرية',
        MaterialClass.unknown => 'غير معروف',
      };
}

class ScanSnapshot {
  const ScanSnapshot({
    required this.timestamp,
    required this.frequencyHz,
    required this.dopplerHz,
    required this.dynamicScore,
    required this.attenuationDb,
    required this.material,
    required this.materialConfidence,
    required this.distanceMeters,
    required this.positiveDelta,
    required this.pose,
    this.routerTelemetry,
  });

  final DateTime timestamp;
  final double frequencyHz;
  final double dopplerHz;
  final double dynamicScore;
  final double attenuationDb;
  final MaterialClass material;
  final double materialConfidence;
  final double distanceMeters;
  final double positiveDelta;
  final HumanPose3D pose;
  final RouterTelemetry? routerTelemetry;
}
