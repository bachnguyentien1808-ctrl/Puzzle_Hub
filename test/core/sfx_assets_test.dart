import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/audio/music_player.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/audio/sfx_player.dart';
import 'package:puzzle_hub/games/game_registry.dart';

void main() {
  test('mỗi chủ đề âm sắc có đủ SfxKind dưới dạng wav hợp lệ', () {
    final themes = [
      for (final g in gameRegistry) MusicEngine.trackForGame(g.id),
      'lobby',
    ];
    for (final theme in themes) {
      for (final k in SfxKind.values) {
        final f = File('assets/${SfxEngine.assetOf(k, theme)}');
        expect(f.existsSync(), isTrue, reason: 'thiếu ${f.path}');
        final bytes = f.readAsBytesSync();
        expect(bytes.length, greaterThan(1000), reason: '${f.path} quá nhỏ');
        // Phần đầu file WAV: "RIFF" ... "WAVE".
        expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      }
    }
  });

  test('mỗi game và sảnh chờ có một file nhạc nền', () {
    final ids = [
      for (final g in gameRegistry) MusicEngine.trackForGame(g.id),
      'lobby',
    ];
    for (final id in ids) {
      final f = File('assets/music/$id.mp3');
      expect(f.existsSync(), isTrue, reason: 'thiếu ${f.path}');
      expect(f.lengthSync(), greaterThan(100 * 1024), reason: f.path);
    }
  });
}
