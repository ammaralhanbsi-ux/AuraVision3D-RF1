import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

enum Keypoint17 {
  nose,
  leftEye,
  rightEye,
  leftEar,
  rightEar,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

extension Keypoint17Label on Keypoint17 {
  String get arName => const {
        Keypoint17.nose: 'الأنف',
        Keypoint17.leftEye: 'العين اليسرى',
        Keypoint17.rightEye: 'العين اليمنى',
        Keypoint17.leftEar: 'الأذن اليسرى',
        Keypoint17.rightEar: 'الأذن اليمنى',
        Keypoint17.leftShoulder: 'الكتف الأيسر',
        Keypoint17.rightShoulder: 'الكتف الأيمن',
        Keypoint17.leftElbow: 'المرفق الأيسر',
        Keypoint17.rightElbow: 'المرفق الأيمن',
        Keypoint17.leftWrist: 'الرسغ الأيسر',
        Keypoint17.rightWrist: 'الرسغ الأيمن',
        Keypoint17.leftHip: 'الورك الأيسر',
        Keypoint17.rightHip: 'الورك الأيمن',
        Keypoint17.leftKnee: 'الركبة اليسرى',
        Keypoint17.rightKnee: 'الركبة اليمنى',
        Keypoint17.leftAnkle: 'الكاحل الأيسر',
        Keypoint17.rightAnkle: 'الكاحل الأيمن',
      }[this]!;
}

class PoseKeypoint {
  const PoseKeypoint({required this.position, required this.confidence});

  final Vector3 position;
  final double confidence;

  PoseKeypoint copyWith({Vector3? position, double? confidence}) {
    return PoseKeypoint(
      position: position ?? this.position,
      confidence: confidence ?? this.confidence,
    );
  }
}

class HumanPose3D {
  HumanPose3D({required this.keypoints, this.trackId = 1});

  final int trackId;
  final List<PoseKeypoint> keypoints;

  double get averageConfidence => keypoints.isEmpty
      ? 0
      : keypoints.fold<double>(0, (sum, p) => sum + p.confidence) /
          keypoints.length;

  double displacementFrom(HumanPose3D previous) {
    if (previous.keypoints.length != keypoints.length || keypoints.isEmpty) {
      return 0;
    }
    var sum = 0.0;
    for (var i = 0; i < keypoints.length; i++) {
      sum += (keypoints[i].position - previous.keypoints[i].position).length;
    }
    return sum / math.max(1, keypoints.length);
  }

  HumanPose3D copy() => HumanPose3D(
        trackId: trackId,
        keypoints: keypoints
            .map((p) => p.copyWith(position: Vector3.copy(p.position)))
            .toList(growable: false),
      );
}

const kSkeletonEdges = <List<int>>[
  [0, 1],
  [0, 2],
  [1, 3],
  [2, 4],
  [0, 5],
  [0, 6],
  [5, 6],
  [5, 7],
  [7, 9],
  [6, 8],
  [8, 10],
  [5, 11],
  [6, 12],
  [11, 12],
  [11, 13],
  [13, 15],
  [12, 14],
  [14, 16],
];
