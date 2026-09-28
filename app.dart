import 'package:flutter/material.dart';

import 'core/theme/aura_theme.dart';
import 'features/scanner/presentation/scanner_hud_screen.dart';

class AuraVisionApp extends StatelessWidget {
  const AuraVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AuraVision 3D RF',
      theme: AuraTheme.dark(),
      locale: const Locale('ar'),
      home: const ScannerHudScreen(),
    );
  }
}
