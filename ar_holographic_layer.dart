import 'package:flutter/material.dart';

import '../../../core/models/human_pose.dart';

class ARHumanMeshRenderer extends StatelessWidget {
  const ARHumanMeshRenderer({required this.pose, required this.frame, super.key});

  final HumanPose3D pose;
  final double frame;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: HolographicPosePainter(pose: pose, frame: frame),
        size: Size.infinite,
      ),
    );
  }
}

class HolographicPosePainter extends CustomPainter {
  const HolographicPosePainter({required this.pose, required this.frame});

  final HumanPose3D pose;
  final double frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.keypoints.isEmpty) return;

    Offset project(PoseKeypoint point) {
      final x = size.width * (0.50 + point.position.x * 0.20);
      final y = size.height * (0.64 - point.position.y * 0.26);
      return Offset(x, y);
    }

    final line = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        colors: [
          const Color(0xCC00E5FF),
          Color.lerp(const Color(0xCC00E5FF), const Color(0xCC7CFF00), frame)!,
          const Color(0xCC7CFF00),
        ],
      ).createShader(Offset.zero & size);

    for (final edge in kSkeletonEdges) {
      if (edge[0] >= pose.keypoints.length || edge[1] >= pose.keypoints.length) continue;
      canvas.drawLine(project(pose.keypoints[edge[0]]), project(pose.keypoints[edge[1]]), line);
    }

    final node = Paint()..style = PaintingStyle.fill;
    for (final point in pose.keypoints) {
      node.color = Color.lerp(
        const Color(0xFFD8F6FF),
        const Color(0xFF7CFF00),
        (0.4 + 0.3 * (0.5 + 0.5 * (frame * 2 - 1))).clamp(0, 1),
      )!;
      canvas.drawCircle(project(point), 4.2, node);
    }
  }

  @override
  bool shouldRepaint(covariant HolographicPosePainter oldDelegate) {
    return oldDelegate.pose != pose || oldDelegate.frame != frame;
  }
}
