import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/features/achievements/achievements_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Map<String, Object> init) async {
  SharedPreferences.setMockInitialValues(init);
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: AchievementsScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('chưa chơi: cấp Tân binh, huy hiệu còn khoá', (tester) async {
    await _pump(tester, {});
    expect(find.text('Thành tích'), findsOneWidget);
    expect(find.text('Tân binh'), findsOneWidget);
    expect(find.text('Huy hiệu · 0/10'), findsOneWidget);
    expect(find.text('Chưa chơi'), findsWidgets);
  });

  testWidgets('có điểm và ván thắng: lên cấp, mở huy hiệu', (tester) async {
    await _pump(tester, {
      'score.total': 1200,
      'score.game.2048': 1200,
      'stats.2048': '{"played":3,"won":2,"best":900,"streak":2,"bestStreak":2}',
    });
    expect(find.text('Học việc'), findsOneWidget);
    // Khởi đầu (thắng ván đầu) + Nghìn điểm.
    expect(find.text('Huy hiệu · 2/10'), findsOneWidget);
    expect(find.textContaining('Chơi 3 · Thắng 2'), findsOneWidget);
  });
}
