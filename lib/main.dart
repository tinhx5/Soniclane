import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/services/billing_service.dart';
import 'core/services/database_service.dart';
import 'core/services/sonic_audio_engine.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/cockpit_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Windows Desktop window configuration
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(420, 720),
      center: true,
      title: 'Soniclane Cockpit',
      backgroundColor: Color(0xFF0D0F12),
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize Local SQLite DB, Billing & MediaKit / AudioService Engine
  await DatabaseService.instance.database;
  await SonicAudioEngine.instance.initialize();
  await BillingService.instance.initialize(
    onProUnlocked: () async {
      final current = await DatabaseService.instance.loadSettings();
      await DatabaseService.instance
          .saveSettings(current.copyWith(isPro: true));
    },
  );

  runApp(const ProviderScope(child: SoniclaneApp()));
}

class SoniclaneApp extends StatelessWidget {
  const SoniclaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soniclane',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkCockpitTheme(),
      home: const CockpitShell(),
    );
  }
}
