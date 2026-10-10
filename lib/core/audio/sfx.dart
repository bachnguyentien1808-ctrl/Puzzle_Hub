/// Cac loai am thanh hieu ung. Game goi `Sfx.play(SfxKind.x)`; phan phat am
/// that duoc nap qua [Sfx.player] (agent app-shell cai dat that, mac dinh no-op).
enum SfxKind {
  // Giao diện ngoài game.
  click,
  back,
  open,
  pause,
  resume,
  newGame,
  select,
  filter,
  option,
  // Thao tác trong game.
  tap,
  place,
  erase,
  pop,
  flip,
  slide,
  flag,
  merge,
  hint,
  // Kết quả.
  match,
  success,
  error,
  win,
  lose,
  boom,
}

abstract final class Sfx {
  /// Tiếng DÙNG CHUNG cho mọi màn (nút chức năng, chọn game, chọn nhóm game,
  /// thắng, thua): luôn lấy từ assets/sfx/common, không đổi theo game.
  /// Giữ trùng `SHARED` trong tools/gen_sfx_v2.py.
  static const shared = {
    SfxKind.click,
    SfxKind.back,
    SfxKind.open,
    SfxKind.pause,
    SfxKind.resume,
    SfxKind.newGame,
    SfxKind.select,
    SfxKind.filter,
    SfxKind.option,
    SfxKind.win,
    SfxKind.lose,
  };

  /// Chủ đề âm sắc hiện tại (trùng tên bài nhạc nền): `lobby` hoặc id file của
  /// game như `sudoku`, `game2048`. Mỗi chủ đề có đủ bộ tiếng riêng.
  static String theme = 'lobby';

  /// Ham phat am; mac dinh khong lam gi. App-shell gan ham that khi khoi dong.
  static void Function(SfxKind kind) player = (_) {};

  static void play(SfxKind kind) => player(kind);
}
