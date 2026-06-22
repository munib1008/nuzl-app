import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/monitoring/crash_reporter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initCrashReporting(); // dormant unless --dart-define=SENTRY_DSN is set
  runApp(const ProviderScope(child: NuzlApp()));
}
