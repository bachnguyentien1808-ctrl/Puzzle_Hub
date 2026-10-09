import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Nút × ở góc thẻ kem: rê chuột vào thì chuyển đỏ, icon trắng.
class CardCloseButton extends StatefulWidget {
  const CardCloseButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  State<CardCloseButton> createState() => _CardCloseButtonState();
}

class _CardCloseButtonState extends State<CardCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Đóng',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Sfx.play(SfxKind.back);
            widget.onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover ? const Color(0xFFE53935) : const Color(0x22000000),
              border: _hover ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: _hover ? Colors.white : Candy.brown,
            ),
          ),
        ),
      ),
    );
  }
}
