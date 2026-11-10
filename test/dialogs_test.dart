import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voges_click/editor/dialogs.dart';
import 'package:voges_click/l10n/app_localizations.dart';

/// Shows a dialog over an empty window and gives what it returned.
Future<ValueGetter<T?>> _open<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext context) ask, {
  Size window = const Size(1400, 900),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext host;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          host = context;
          return const Scaffold();
        },
      ),
    ),
  );
  T? result;
  ask(host).then((value) => result = value).ignore();
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('Enter confirms the text and Shift+Enter does not', (
    tester,
  ) async {
    final result = await _open(tester, askText);
    await tester.enterText(find.byType(TextField).first, 'Hello');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(result()?.text, 'Hello');
  });

  testWidgets('Enter on an empty text keeps the dialog open', (tester) async {
    final result = await _open(tester, askText);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result(), isNull);
  });
}
