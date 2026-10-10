import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _pump(
  WidgetTester tester,
  Map<String, Object> prefs,
) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'tutorial.minesweeper': true,
    ...prefs,
  });
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(ProgressStore(p))],
      child: const MaterialApp(
        home: GameIntro(gameId: 'minesweeper', child: Text('TRONG-GAME')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return p;
}

void main() {
  testWidgets('khong co van do: vao thang game, khong hoi', (tester) async {
    await _pump(tester, {});
    expect(find.text('TRONG-GAME'), findsOneWidget);
    expect(find.text('Chơi mới'), findsNothing);
  });

  testWidgets('co van do: hoi Tiep tuc hay Choi moi, Tiep tuc giu van', (
    tester,
  ) async {
    final p = await _pump(tester, {'state.minesweeper': '{"a":1}'});
    expect(find.text('TRONG-GAME'), findsNothing);
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(find.text('Chơi mới'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-description')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-resume')));
    await tester.pumpAndSettle();
    expect(find.text('TRONG-GAME'), findsOneWidget);
    expect(p.containsKey('state.minesweeper'), isTrue);
  });

  testWidgets('Choi moi: bo van do roi vao game', (tester) async {
    final p = await _pump(tester, {'state.minesweeper': '{"a":1}'});
    await tester.tap(find.byKey(const ValueKey('start-new')));
    await tester.pumpAndSettle();
    expect(find.text('TRONG-GAME'), findsOneWidget);
    expect(p.containsKey('state.minesweeper'), isFalse);
  });
}
