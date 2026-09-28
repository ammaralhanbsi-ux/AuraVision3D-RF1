import 'dart:ui';

import 'package:ar_flutter_plugin_plus/ar_flutter_plugin_plus.dart';
import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ar/presentation/ar_holographic_layer.dart';
import '../application/scanner_controller.dart';
import 'widgets/rf_contour_painter.dart';
import 'widgets/telemetry_card.dart';

class ScannerHudScreen extends ConsumerStatefulWidget {
  const ScannerHudScreen({super.key});

  @override
  ConsumerState<ScannerHudScreen> createState() => _ScannerHudScreenState();
}

class _ScannerHudScreenState extends ConsumerState<ScannerHudScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  ARSessionManager? _arSession;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _arSession?.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _onArCreated(
    ARSessionManager session,
    ARObjectManager object,
    ARAnchorManager anchor,
    ARLocationManager location,
  ) {
    _arSession = session;
    session.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: false,
    );
    object.onInitialize();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scannerControllerProvider);
    final s = state.snapshot;
    final dynamic = s.dynamicScore.clamp(0, 1);

    return Scaffold(
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ARView(
              onARViewCreated: _onArCreated,
              planeDetectionConfig: PlaneDetectionConfig.none,
            ),
            AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => CustomPaint(
                painter: RfContourPainter(value: 0.8, phase: _clock.value),
              ),
            ),
            AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => ARHumanMeshRenderer(
                pose: s.pose,
                frame: _clock.value,
              ),
            ),
            _HudOverlay(
              state: state,
              onUseSam: () => ref.read(scannerControllerProvider.notifier).useSamM50Pro(),
              onToggle: () => ref
                  .read(scannerControllerProvider.notifier)
                  .toggleRunning(),
            ),
          ],
        ),
      ),
    );
  }
}


String _signalText(dynamic t) {
  final value = t.rsrpDbm ?? t.rssiDbm;
  return value == null ? '—' : value.toStringAsFixed(0);
}

double _signalProgress(dynamic t) {
  final value = t.signalPercent;
  if (value != null) return (value / 100).clamp(0, 1);
  final dbm = t.rssiDbm ?? t.rsrpDbm;
  if (dbm == null) return 0;
  return ((dbm + 110) / 60).clamp(0, 1);
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay({required this.state, required this.onUseSam, required this.onToggle});

  final ScanState state;
  final VoidCallback onUseSam;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = state.snapshot;
    final people = s.dynamicScore > 0.36 ? 1 : 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xB3090E15),
                    border: Border.all(color: const Color(0x5555E8FF)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar_rounded, size: 22),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('AuraVision 3D RF', style: TextStyle(fontWeight: FontWeight.w800)),
                            Text(s.routerTelemetry != null ? 'راوتر SAM M50 PRO • بيانات محلية مباشرة' : 'نظام المسح الفضائي • وضع التجربة', style: TextStyle(fontSize: 10, color: Colors.white60)),
                          ],
                        ),
                      ),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isRunning ? const Color(0xFF7CFF00) : Colors.orange,
                          boxShadow: [BoxShadow(color: state.isRunning ? const Color(0xFF7CFF00) : Colors.orange, blurRadius: 9)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (s.routerTelemetry != null) ...[
              Row(
                children: [
                  Expanded(child: TelemetryCard(
                    title: 'قوة الإشارة',
                    value: _signalText(s.routerTelemetry!),
                    unit: 'dBm',
                    progress: _signalProgress(s.routerTelemetry!),
                  )),
                  const SizedBox(width: 9),
                  Expanded(child: TelemetryCard(
                    title: 'SINR',
                    value: s.routerTelemetry!.sinrDb?.toStringAsFixed(1) ?? '—',
                    unit: 'dB',
                    progress: ((s.routerTelemetry!.sinrDb ?? -10) + 10) / 40,
                  )),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: TelemetryCard(
                    title: 'التنزيل',
                    value: s.routerTelemetry!.rxMbps?.toStringAsFixed(1) ?? '—',
                    unit: 'Mbps',
                    progress: ((s.routerTelemetry!.rxMbps ?? 0) / 100).clamp(0, 1),
                  )),
                  const SizedBox(width: 9),
                  Expanded(child: TelemetryCard(
                    title: 'الرفع',
                    value: s.routerTelemetry!.txMbps?.toStringAsFixed(1) ?? '—',
                    unit: 'Mbps',
                    progress: ((s.routerTelemetry!.txMbps ?? 0) / 100).clamp(0, 1),
                  )),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: TelemetryCard(
                    title: 'الأجهزة المتصلة',
                    value: '${s.routerTelemetry!.connectedClients ?? 0}',
                    unit: 'جهاز',
                    progress: ((s.routerTelemetry!.connectedClients ?? 0) / 10).clamp(0, 1),
                  )),
                  const SizedBox(width: 9),
                  Expanded(child: TelemetryCard(
                    title: 'النشاط الشبكي',
                    value: '${(s.dynamicScore * 100).round()}',
                    unit: '%',
                    progress: s.dynamicScore,
                  )),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: TelemetryCard(
                    title: 'قوة التغيّر',
                    value: '${(s.dynamicScore * 100).round()}',
                    unit: '%',
                    progress: s.dynamicScore,
                  )),
                  const SizedBox(width: 9),
                  Expanded(child: TelemetryCard(
                    title: 'Doppler تقديري',
                    value: s.dopplerHz.toStringAsFixed(1),
                    unit: 'Hz',
                    progress: (s.dopplerHz.abs() / 80).clamp(0, 1),
                  )),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(child: TelemetryCard(
                    title: 'المادة/الفراغ',
                    value: s.material.arName,
                    unit: '${(s.materialConfidence * 100).round()}%',
                    progress: s.materialConfidence,
                  )),
                  const SizedBox(width: 9),
                  Expanded(child: TelemetryCard(
                    title: 'المسافة',
                    value: s.distanceMeters.toStringAsFixed(2),
                    unit: 'm',
                    progress: (1 - (s.distanceMeters / 5)).clamp(0, 1),
                  )),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xAA080D13),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x4437FFD7)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_search_rounded, size: 25),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.routerTelemetry != null
                          ? 'الشبكة: ${s.routerTelemetry!.networkType ?? 'غير معروف'}   •   القناة: ${s.routerTelemetry!.channel ?? '—'}   •   SSID: ${s.routerTelemetry!.ssid ?? '—'}'
                          : 'الأشخاص الديناميكيون: $people   •   الحالة: ${s.dynamicScore > 0.65 ? 'يمشي' : s.dynamicScore > 0.28 ? 'واقف/يتحرّك قليلاً' : 'ثابت'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onToggle,
                    icon: Icon(state.isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(state.isRunning ? 'إيقاف' : 'بدء'),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: onUseSam,
                    icon: const Icon(Icons.router_rounded, size: 18),
                    label: const Text('M50 PRO'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              s.routerTelemetry != null
                  ? 'مصدر البيانات: لوحة SAM M50 PRO المحلية. لا يتم ادعاء CSI أو استشعار عبر الجدران.'
                  : 'تنبيه: النتائج RF احتمالية وليست إثباتاً لوجود أشخاص أو تجاويف خلف الجدران.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
