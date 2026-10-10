import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';

/// Phat am hieu ung that tu assets/sfx/*.wav (sinh boi tools/gen_sfx.dart).
/// Moi loai am giu toi da [_voices] AudioPlayer xoay vong de phat chong nhau.
/// Moi loi plugin (vd chay trong test, nen tang thieu plugin) deu bi nuot:
/// am thanh khong bao gio duoc lam sap game.
class SfxEngine {
  SfxEngine._() {
    // Tắt tiếng thì cắt luôn các tiếng đang phát dở.
    enabled.addListener(() {
      if (enabled.value) return;
      for (final list in _pool.values) {
        for (final p in list) {
          unawaited(p.stop().catchError((Object _) {}));
        }
      }
    });
  }

  static final SfxEngine instance = SfxEngine._();

  /// Bat/tat am thanh (man Cai dat ghi vao day).
  static final ValueNotifier<bool> enabled = ValueNotifier(true);

  static const _voices = 3;
  final Map<SfxKind, List<AudioPlayer>> _pool = {};
  final Map<SfxKind, int> _next = {};
  final Random _rng = Random();
  bool _broken = false;

  static String assetOf(SfxKind k, [String? theme]) =>
      'sfx/${Sfx.shared.contains(k) ? 'common' : theme ?? Sfx.theme}/'
      '${k.name}.wav';

  static final Set<String> _loaded = {};

  /// Nạp trước bộ tiếng của một chủ đề (chỉ nạp một lần).
  static Future<void> preloadTheme(String theme) async {
    if (!_loaded.add(theme)) return;
    try {
      await AudioCache.instance.loadAll([
        for (final k in SfxKind.values) assetOf(k, theme),
      ]);
    } on Object catch (e) {
      _loaded.remove(theme);
      debugPrint('SfxEngine: khong nap duoc bo tieng $theme: $e');
    }
  }

  /// Đổi chủ đề âm sắc theo màn hình (sảnh chờ hoặc từng game).
  static void setTheme(String theme) {
    if (Sfx.theme == theme) return;
    Sfx.theme = theme;
    unawaited(preloadTheme(theme));
  }

  /// Gan [Sfx.player] va nap truoc file am. Goi mot lan o main().
  static Future<void> install() async {
    Sfx.player = instance.play;
    await preloadTheme(Sfx.theme);
  }

  void play(SfxKind kind) {
    if (!enabled.value || _broken) return;
    try {
      final list = _pool.putIfAbsent(kind, () => []);
      final i = _next[kind] ?? 0;
      _next[kind] = (i + 1) % _voices;
      if (list.length <= i) {
        list.add(
          AudioPlayer(playerId: 'sfx_${kind.name}_$i')
            ..setReleaseMode(ReleaseMode.stop).catchError((Object _) {}),
        );
      }
      final p = list[i];
      // Tiếng bấm nút đổi cao độ nhẹ mỗi lần cho đỡ đơn điệu.
      final rate = kind == SfxKind.click
          ? 0.94 + _rng.nextDouble() * 0.16
          : 1.0;
      unawaited(
        p
            .stop()
            .then((_) => p.setPlaybackRate(rate))
            .then((_) {
              // Tắt tiếng trong lúc đang nạp (vd. chính cú bấm nút loa phát
              // tiếng click): không phát nữa.
              if (!enabled.value) return null;
              return p.play(AssetSource(assetOf(kind)), volume: 0.8);
            })
            .then((_) {
              // Phát xong lệnh mà người dùng đã tắt tiếng giữa chừng (web):
              // cắt luôn.
              if (!enabled.value) return p.stop();
            })
            .catchError(_onError),
      );
    } on Object catch (e) {
      _onError(e);
    }
  }

  void _onError(Object e) {
    if (e is MissingPluginException) _broken = true;
    debugPrint('SfxEngine: $e');
  }
}
