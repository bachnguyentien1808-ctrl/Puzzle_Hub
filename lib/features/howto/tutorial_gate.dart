import 'package:flutter/widgets.dart';

/// Hướng dẫn chờ hiện: `GameIntro` đặt sẵn khi bắt đầu ván mới, game gọi
/// [fire] ngay khi người chơi đã chọn xong (mức, kích thước...) và bàn chơi
/// hiện ra. Chơi tiếp ván dở thì không đặt nên [fire] không làm gì.
class TutorialGate {
  TutorialGate._();

  static final _pending = <String, VoidCallback>{};

  static void arm(String gameId, VoidCallback show) => _pending[gameId] = show;

  static void disarm(String gameId) => _pending.remove(gameId);

  static void fire(String gameId) {
    final show = _pending.remove(gameId);
    if (show == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }
}
