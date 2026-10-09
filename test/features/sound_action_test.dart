import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/audio/sfx_player.dart';
import 'package:puzzle_hub/features/common/hub_panels.dart';

void main() {
  testWidgets('nút loa bật/tắt công tắc âm thanh chung', (tester) async {
    SfxEngine.enabled.value = true;
    addTearDown(() => SfxEngine.enabled.value = true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(actions: const [SoundAction()])),
      ),
    );
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('sound-toggle')));
    await tester.pump();
    expect(SfxEngine.enabled.value, isFalse);
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    await tester.tap(find.byKey(const Key('sound-toggle')));
    await tester.pump();
    expect(SfxEngine.enabled.value, isTrue);
  });
}
