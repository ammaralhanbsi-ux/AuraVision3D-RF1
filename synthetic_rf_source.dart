import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../../core/models/human_pose.dart';
import '../domain/rf_source.dart';

class SyntheticRfSource implements RfFrameSource {
  SyntheticRfSource({this.subcarriers = 56});

  final int subcarriers;
  int _frame = 0;

  @override
  Future<RfFrame> nextFrame() async {
    final t = _frame++ / 30.0;
    final real = <double>[];
    final imaginary = <double>[];
    for (var k = 0; k < subcarriers; k++) {
      final phase = 0.18 * k + 0.7 * math.sin(t * 1.8 + k * 0.04);
      final envelope = 1.0 + 0.17 * math.sin(t * 2.4) *
          math.cos(k * 0.09);
      real.add(envelope * math.cos(phase));
      imaginary.add(envelope * math.sin(phase));
    }

    final pose = demoPose(t);
    return RfFrame(
      real: real,
      imaginary: imaginary,
      sampleRateHz: 30.0,
      carrierHz: 5.18e9,
      pose: pose,
    );
  }

  HumanPose3D demoPose(double t) {
    final sway = 0.12 * math.sin(t * 1.7);
    final arm = 0.28 * math.sin(t * 2.2);
    final leg = 0.22 * math.sin(t * 1.6 + 1.0);

    final p = <Vector3>[
      Vector3(sway, 1.65, -2.4),
      Vector3(sway - 0.05, 1.71, -2.39),
      Vector3(sway + 0.05, 1.71, -2.39),
      Vector3(sway - 0.10, 1.67, -2.38),
      Vector3(sway + 0.10, 1.67, -2.38),
      Vector3(sway - 0.21, 1.42, -2.40),
      Vector3(sway + 0.21, 1.42, -2.40),
      Vector3(sway - 0.39, 1.15 + arm, -2.42),
      Vector3(sway + 0.39, 1.15 - arm, -2.42),
      Vector3(sway - 0.48, 0.92 + arm, -2.45),
      Vector3(sway + 0.48, 0.92 - arm, -2.45),
      Vector3(sway - 0.16, 0.87, -2.42),
      Vector3(sway + 0.16, 0.87, -2.42),
      Vector3(sway - 0.18 + leg, 0.46, -2.45),
      Vector3(sway + 0.18 - leg, 0.46, -2.45),
      Vector3(sway - 0.23 + leg, 0.08, -2.49),
      Vector3(sway + 0.23 - leg, 0.08, -2.49),
    ];

    return HumanPose3D(
      trackId: 1,
      keypoints: p
          .map((position) => PoseKeypoint(position: position, confidence: 0.94))
          .toList(growable: false),
    );
  }
}
