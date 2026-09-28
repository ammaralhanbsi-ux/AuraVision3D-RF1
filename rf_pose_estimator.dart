import 'package:aura_rf_ffi/aura_rf_ffi.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../core/models/human_pose.dart';
import '../domain/rf_source.dart';

class NativePoseEstimator implements PoseEstimator {
  NativePoseEstimator(this.engine);

  final AuraRfEngine engine;

  @override
  HumanPose3D smooth(HumanPose3D pose, double alpha) {
    final flat = <double>[];
    for (final point in pose.keypoints) {
      flat
        ..add(point.position.x)
        ..add(point.position.y)
        ..add(point.position.z);
    }
    final smoothed = engine.smoothPose(flat, alpha);
    final points = <PoseKeypoint>[];
    for (var i = 0; i < pose.keypoints.length; i++) {
      final base = i * 3;
      points.add(PoseKeypoint(
        position: Vector3(smoothed[base], smoothed[base + 1], smoothed[base + 2]),
        confidence: pose.keypoints[i].confidence,
      ));
    }
    return HumanPose3D(trackId: pose.trackId, keypoints: points);
  }
}
