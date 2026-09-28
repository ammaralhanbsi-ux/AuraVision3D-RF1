import '../../core/models/scan_snapshot.dart';
import '../../core/models/router_telemetry.dart';
import '../../core/models/human_pose.dart';

abstract interface class RfFrameSource {
  Future<RfFrame> nextFrame();
}

class RfFrame {
  const RfFrame({
    required this.real,
    required this.imaginary,
    required this.sampleRateHz,
    required this.carrierHz,
    required this.pose,
    this.routerTelemetry,
  });

  final List<double> real;
  final List<double> imaginary;
  final double sampleRateHz;
  final double carrierHz;
  final HumanPose3D pose;
  final RouterTelemetry? routerTelemetry;
}

abstract interface class PoseEstimator {
  HumanPose3D smooth(HumanPose3D pose, double alpha);
}

abstract interface class MaterialClassifier {
  MaterialClass classify({
    required double attenuationDb,
    required double dynamicScore,
    required double positiveDelta,
  });
}
