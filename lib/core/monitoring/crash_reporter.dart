import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dependency-light crash reporter (house style: raw REST via Dio, no SDK).
///
/// Dormant unless the build is run with `--dart-define=SENTRY_DSN=...`. When set,
/// uncaught Flutter + async errors are POSTed to Sentry's store endpoint. Always
/// fail-soft — reporting must never crash the app. Uses query-string auth (what
/// browser SDKs use) to avoid a CORS preflight on the custom auth header.
const _dsn = String.fromEnvironment('SENTRY_DSN');
const _env = String.fromEnvironment('SENTRY_ENV', defaultValue: 'production');

/// Installs global error handlers. Call once from main() before runApp.
void initCrashReporting() {
  if (_parseDsn(_dsn) == null) return; // dormant
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    prev?.call(details); // keep the default console logging
    _report(details.exception, details.stack);
  };
  // Errors outside the widget tree (async gaps, platform callbacks).
  PlatformDispatcher.instance.onError = (error, stack) {
    _report(error, stack);
    return false; // let the platform's default handler run too
  };
}

void _report(Object error, StackTrace? stack) {
  final endpoint = _parseDsn(_dsn);
  if (endpoint == null) return;
  // Fire-and-forget; swallow every failure so the error path never throws.
  () async {
    try {
      await Dio().post(
        endpoint,
        data: {
          'event_id': _eventId(),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'platform': 'javascript',
          'level': 'error',
          'logger': 'nuzl-app',
          'environment': _env,
          'exception': {
            'values': [
              {'type': error.runtimeType.toString(), 'value': error.toString()},
            ],
          },
          if (stack != null) 'extra': {'stack': stack.toString()},
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          // Don't let a non-2xx from Sentry surface as an exception.
          validateStatus: (_) => true,
        ),
      );
    } catch (_) {/* fail-soft */}
  }();
}

/// Builds the Sentry store URL (with query-string auth) from a DSN, or null if
/// the DSN is absent/malformed. DSN: `https://<publicKey>@<host>/<projectId>`.
String? _parseDsn(String dsn) {
  if (dsn.trim().isEmpty) return null;
  final u = Uri.tryParse(dsn.trim());
  if (u == null || u.userInfo.isEmpty) return null;
  final projectId = u.path.replaceAll(RegExp(r'^/+'), '');
  if (projectId.isEmpty) return null;
  return '${u.scheme}://${u.host}/api/$projectId/store/'
      '?sentry_key=${u.userInfo}&sentry_version=7';
}

/// 32-char hex event id. Non-crypto source is fine for a de-dup id.
String _eventId() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final r = identityHashCode(Object()).toRadixString(16);
  return (t + r + '0' * 32).substring(0, 32);
}
