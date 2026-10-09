import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_hub/core/audio/sfx_player.dart';

/// Nhạc nền: một bài cho sảnh chờ (`lobby`) và mỗi game một bài riêng
/// (file assets/music/TÊN.mp3, lặp vô hạn). Đổi bài thì bài cũ tắt dần rồi bài
/// mới mở dần. Bật/tắt theo cùng công tắc âm thanh với hiệu ứng
/// ([SfxEngine.enabled]). Mọi lỗi plugin (test, thiếu plugin, trình duyệt chặn
/// tự phát) đều bị nuốt.
class MusicEngine {
  MusicEngine._() {
    SfxEngine.enabled.addListener(_apply);
  }

  static final MusicEngine instance = MusicEngine._();

  /// Tên file nhạc theo id game (đa số trùng id).
  static String trackForGame(String gameId) =>
      gameId == '2048' ? 'game2048' : gameId;

  /// Âm lượng riêng từng bài: sảnh chờ to hơn, trong game nhỏ để còn nghe
  /// hiệu ứng; hai bài có bè trầm dày thì hạ thêm.
  static double volumeOf(String track) => switch (track) {
    'lobby' => 0.38,
    'game2048' || 'kakuro' => 0.22,
    _ => 0.27,
  };

  AudioPlayer? _player;
  String? _wanted;
  String? _current;
  bool _foreground = true;
  bool _playing = false;
  bool _starting = false;
  bool _broken = false;
  Timer? _fade;

  bool get _shouldPlay =>
      _wanted != null && _foreground && SfxEngine.enabled.value;

  /// Bài cần phát ở màn hiện tại; null = im lặng.
  void setTrack(String? track) {
    if (_wanted == track) return;
    _wanted = track;
    _apply();
  }

  /// App ra nền thì tạm dừng, quay lại thì phát tiếp.
  void setForeground({required bool foreground}) {
    _foreground = foreground;
    _apply();
  }

  bool _webUnlocked = false;

  /// Trình duyệt chỉ cho phát sau khi người dùng chạm: gọi mỗi lần chạm.
  /// Trên web, lệnh phát đầu tiên (chưa có cử chỉ) bị trình duyệt chặn lặng lẽ
  /// mà vẫn trả về như thành công, nên ở lần chạm đầu tiên phải phát lại.
  void kick() {
    if (!_shouldPlay) return;
    if (!_playing) {
      _apply();
      return;
    }
    if (kIsWeb && !_webUnlocked) {
      _webUnlocked = true;
      final p = _player;
      final track = _current;
      if (p == null || track == null) return;
      unawaited(() async {
        try {
          await p.stop();
          await p.setVolume(0);
          await p.play(AssetSource('music/$track.mp3'));
          if (_shouldPlay) _fadeTo(volumeOf(track));
        } on Object catch (e) {
          debugPrint('MusicEngine: $e');
        }
      }());
    }
  }

  void _apply() {
    if (_broken) return;
    if (!_shouldPlay) {
      // Tắt tiếng: im ngay lập tức; ra nền hoặc không có bài: tắt dần.
      if (!SfxEngine.enabled.value) {
        _silenceNow();
      } else if (_playing) {
        _stop();
      }
      return;
    }
    if (_playing && _current == _wanted) return;
    if (_playing) {
      // Đổi bài: tắt dần bài cũ rồi mới mở bài mới.
      _playing = false;
      _fadeTo(0, then: () => unawaited(_start()));
    } else {
      unawaited(_start());
    }
  }

  Future<void> _start() async {
    final track = _wanted;
    if (_playing || _starting || track == null || !_shouldPlay) return;
    _starting = true;
    try {
      var p = _player;
      if (p == null) {
        p = AudioPlayer(playerId: 'music_bg');
        _player = p;
        await p.setReleaseMode(ReleaseMode.loop);
      }
      await p.setVolume(0);
      if (_current == track) {
        await p.resume();
      } else {
        await p.play(AssetSource('music/$track.mp3'));
        _current = track;
      }
      _playing = true;
      // Trong lúc nạp bài người dùng có thể đã tắt tiếng: im ngay.
      if (_shouldPlay) {
        _fadeTo(volumeOf(track));
      } else {
        _silenceNow();
      }
    } on Object catch (e) {
      // Chưa được phép phát (cần chạm trước) hoặc thiếu plugin.
      _playing = false;
      if (e is MissingPluginException) _broken = true;
      debugPrint('MusicEngine: $e');
    } finally {
      _starting = false;
    }
    // Trong lúc nạp bài, màn hình có thể đã đổi: kiểm tra lại.
    if (_playing && _current != _wanted) _apply();
  }

  /// Dừng hẳn ngay, không tắt dần (khi người dùng bấm tắt tiếng).
  void _silenceNow() {
    _fade?.cancel();
    _playing = false;
    final p = _player;
    if (p == null) return;
    unawaited(p.setVolume(0).catchError((Object _) {}));
    unawaited(p.pause().catchError((Object _) {}));
  }

  void _stop() {
    _playing = false;
    final p = _player;
    if (p == null) return;
    _fadeTo(0, then: () => unawaited(p.pause().catchError((Object _) {})));
  }

  void _fadeTo(double target, {VoidCallback? then}) {
    _fade?.cancel();
    final p = _player;
    if (p == null) return;
    var step = 0;
    const steps = 12;
    final start = target == 0 ? volumeOf(_current ?? 'lobby') : 0.0;
    _fade = Timer.periodic(const Duration(milliseconds: 35), (t) {
      step++;
      final v = start + (target - start) * (step / steps);
      p.setVolume(v.clamp(0, 1)).catchError((Object _) {});
      if (step >= steps) {
        t.cancel();
        then?.call();
      }
    });
  }
}
