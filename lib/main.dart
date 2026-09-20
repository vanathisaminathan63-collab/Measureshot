import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/report_controller.dart';
import 'controllers/location_controller.dart';
import 'controllers/measurement_controller.dart';
import 'controllers/history_controller.dart';
import 'theme/app_theme.dart';
import 'views/main_shell.dart';

void main() {
  debugPrint('[App] process started (pid $pid)');
  runApp(const MeasureShotApp());
}

class MeasureShotApp extends StatelessWidget {
  const MeasureShotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReportController()),
        ChangeNotifierProvider(create: (_) => LocationController()),
        ChangeNotifierProvider(create: (_) => MeasurementController()),
        ChangeNotifierProvider(create: (_) => HistoryController()),
      ],
      child: MaterialApp(
        title: 'MeasureShot',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const MainShell(),
      ),
    );
  }
}