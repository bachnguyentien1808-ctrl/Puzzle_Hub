import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Nút chức năng tròn dùng chung cho mọi game: cùng một kích thước, chỉ có
/// biểu tượng; tên hiện khi rê chuột (tooltip). [badge] là chấm số ở góc.
class GameActionButton extends StatelessWidget {
  const GameActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.colors = Candy.blue,
    this.badge,
    this.dim = false,
    this.buttonKey,
    super.key,
  });

  /// Đường kính nút = 2 * [_pad] + [_iconSize].
  static const double _pad = 9;
  static const double _iconSize = 24;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final String? badge;

  /// Làm mờ dù vẫn bấm được (nút đang bật).
  final bool dim;

  /// Khoá đặt trực tiếp lên [CandyButton] (test tìm nút theo khoá này).
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final button = Tooltip(
      message: tooltip,
      child: CandyButton(
        key: buttonKey,
        colors: colors,
        dim: dim || onPressed == null,
        circle: true,
        padding: const EdgeInsets.all(_pad),
        onPressed: onPressed,
        child: Icon(icon, size: _iconSize),
      ),
    );
    if (badge == null) return button;
    return Badge(label: Text(badge!), child: button);
  }
}
