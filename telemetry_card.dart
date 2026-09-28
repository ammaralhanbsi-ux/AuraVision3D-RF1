import 'package:flutter/material.dart';

class TelemetryCard extends StatelessWidget {
  const TelemetryCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.progress,
    super.key,
  });

  final String title;
  final String value;
  final String unit;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xAA0C121A),
          border: Border.all(color: const Color(0x556DFFEA)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 3,
              backgroundColor: Colors.white12,
            ),
          ],
        ),
      ),
    );
  }
}
