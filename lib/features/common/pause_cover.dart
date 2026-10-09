import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Lớp che bàn chơi khi tạm dừng: chạm hoặc bấm "Tiếp tục" để chơi tiếp.
/// Đặt trong Stack, phủ kín bàn chơi.
class PauseCover extends StatelessWidget {
  const PauseCover({required this.onResume, super.key});

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        key: const ValueKey('pause'),
        behavior: HitTestBehavior.opaque,
        onTap: onResume,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: Candy.purple,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.pause_circle_outline,
                    size: 72,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tạm dừng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CandyButton(
                    onPressed: onResume,
                    colors: Candy.green,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded),
                        SizedBox(width: 6),
                        Text('Tiếp tục'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
