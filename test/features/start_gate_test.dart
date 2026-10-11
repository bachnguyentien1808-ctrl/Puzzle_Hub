import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _pump(
  WidgetTester tester,
  Map<String, Object> prefs, {
  String gameId = 'minesweeper',
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'tutorial.$gameId': true, ...prefs});
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [progressStoreProvider.overrideWithValue(ProgressStore(p))],
      child: MaterialApp(
        home: GameIntro(
          gameId: gameId,
          tutorialEveryTime: false,
          child: const Text('TRONG-GAME'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return p;
}

void main() {
  testWidgets('khong co van do: nut Bat dau choi, bam moi vao game', (
    tester,
  ) async {
    await _pump(tester, {});
    expect(find.text('TRONG-GAME'), findsNothing);
    expect(find.text('BẮT ĐẦU CHƠI'), findsOneWidget);
    // Màn Bắt đầu chơi có mô tả game.
    expect(find.byKey(const ValueKey('game-description')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-question')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('start-play')));
    await tester.pumpAndSettle();
    expect(find.text('TRONG-GAME'), findsOneWidget);
  });

  testWidgets('co van do: hoi co muon tiep tuc khong, Co thi giu van', (
    tester,
  ) async {
    final p = await _pump(tester, {'state.minesweeper': '{"a":1}'});
    expect(find.text('TRONG-GAME'), findsNothing);
    expect(find.byKey(const ValueKey('start-question')), findsOneWidget);
    expect(find.textContaining('chơi không?'), findsOneWidget);
    expect(find.text('Có'), findsOneWidget);
    expect(find.text('Không'), findsOneWidget);
    // Màn hỏi Có / Không không có mô tả game.
    expect(find.byKey(const ValueKey('game-description')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('start-yes')));
    await tester.pumpAndSettle();
    expect(find.text('TRONG-GAME'), findsOneWidget);
    expect(p.containsKey('state.minesweeper'), isTrue);
  });

  testWidgets('Khong: bo van do roi vao game moi', (tester) async {
    final p = await _pump(tester, {'state.minesweeper': '{"a":1}'});
    // Màn hẹp: nút Không nằm dưới nút Có, có thể cần cuộn tới.
    await tester.ensureVisible(find.byKey(const ValueKey('start-no')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-no')));
    await tester.pumpAndSettle();
    expect(find.text('TRONG-GAME'), findsOneWidget);
    expect(p.containsKey('state.minesweeper'), isFalse);
  });

  testWidgets(
    'game choi theo ai (Nonogram, Tat den): Bat dau choi, khong hoi',
    (tester) async {
      for (final id in ['nonogram', 'lights_out']) {
        // Có ván dở cũng không hỏi Tiếp tục: chỉ có nút Bắt đầu chơi + mô tả.
        await _pump(tester, {'state.$id': '{"a":1}'}, gameId: id);
        expect(find.text('TRONG-GAME'), findsNothing, reason: id);
        expect(find.byKey(const ValueKey('start-question')), findsNothing);
        expect(find.byKey(const ValueKey('game-description')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('start-play')));
        await tester.pumpAndSettle();
        expect(find.text('TRONG-GAME'), findsOneWidget, reason: id);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
