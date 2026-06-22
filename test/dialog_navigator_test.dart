import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nuzl_app/core/widgets/app_dialog.dart';

/// Regression guard for the dialog/navigator mismatch that blanked the page and
/// silently dropped every create/edit submit (feed post, lead, contact, etc.).
///
/// The real app wraps authed screens in a go_router ShellRoute — a *nested*
/// Navigator. Callers close AppDialog with `Navigator.pop(context, value)` using
/// the SCREEN context, which resolves to that shell navigator. If AppDialog is
/// shown on the ROOT navigator (showDialog's default), that pop pops the *page*
/// (blank screen) instead of the dialog, and the dialog's future never resolves
/// (so the submit code after `await AppDialog.show(...)` never runs).
///
/// These tests reproduce that exact setup and assert the fixed behaviour
/// (useRootNavigator:false). They FAIL if useRootNavigator is ever flipped back.
Widget _appWithShellDialog({required List<Widget> Function(BuildContext) actions}) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      ShellRoute(
        // Mirrors _BottomNavShell: a Scaffold hosting the nested-navigator child.
        builder: (_, __, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, __) => Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () async {
                      _lastResult = await AppDialog.show<bool>(
                        context,
                        title: 'New post',
                        children: const [Text('DIALOG_BODY')],
                        actions: actions(context),
                      );
                      _resolved = true;
                    },
                    child: const Text('OPEN_DIALOG'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

bool? _lastResult;
bool _resolved = false;

void main() {
  setUp(() {
    _lastResult = null;
    _resolved = false;
  });

  testWidgets('Post closes the dialog (not the page) and resolves the future with the value',
      (tester) async {
    await tester.pumpWidget(_appWithShellDialog(actions: (context) => [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post')),
        ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('OPEN_DIALOG'));
    await tester.pumpAndSettle();
    expect(find.text('DIALOG_BODY'), findsOneWidget, reason: 'dialog should open');

    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('DIALOG_BODY'), findsNothing, reason: 'dialog must close on Post');
    expect(find.text('OPEN_DIALOG'), findsOneWidget,
        reason: 'the underlying page must remain — never blank');
    expect(_resolved, isTrue, reason: 'AppDialog.show future must complete (submit code runs)');
    expect(_lastResult, isTrue, reason: 'the popped value must reach the caller');
  });

  testWidgets('Cancel resolves the future with false and keeps the page', (tester) async {
    await tester.pumpWidget(_appWithShellDialog(actions: (context) => [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post')),
        ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('OPEN_DIALOG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('DIALOG_BODY'), findsNothing);
    expect(find.text('OPEN_DIALOG'), findsOneWidget);
    expect(_resolved, isTrue);
    expect(_lastResult, isFalse);
  });
}
