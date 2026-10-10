import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/game_action_button.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';

/// mm:ss (hoac h:mm:ss).
String formatClock(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

IconData levelIcon(SudokuLevel l) => switch (l) {
  SudokuLevel.easy => Icons.signal_cellular_alt_1_bar,
  SudokuLevel.medium => Icons.signal_cellular_alt_2_bar,
  SudokuLevel.hard => Icons.signal_cellular_alt,
  SudokuLevel.expert => Icons.local_fire_department_outlined,
};

/// Mau rieng cua tung do kho.
List<Color> levelColors(SudokuLevel l) => switch (l) {
  SudokuLevel.easy => Candy.green,
  SudokuLevel.medium => Candy.blue,
  SudokuLevel.hard => Candy.orange,
  SudokuLevel.expert => Candy.red,
};

/// Hang nut thao tac: hoan tac, lam lai, xoa, ghi chu, goi y.
class SudokuActions extends StatelessWidget {
  const SudokuActions({
    required this.canUndo,
    required this.paused,
    required this.canPause,
    required this.hintsLeft,
    required this.onUndo,
    required this.onErase,
    required this.onPause,
    required this.onHint,
    this.showNew = false,
    this.onNew,
    super.key,
  });

  final bool canUndo;
  final bool paused;
  final bool canPause;
  final int hintsLeft;
  final VoidCallback onUndo;
  final VoidCallback onErase;
  final VoidCallback onPause;
  final VoidCallback onHint;

  /// Hiện nút Ván mới (thử thách ngày thì ẩn); [onNew] null = bị mờ.
  final bool showNew;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Act(
          icon: Icons.undo,
          label: 'Hoàn tác',
          colors: Candy.blue,
          onTap: canUndo ? onUndo : null,
        ),
        _Act(
          icon: Icons.backspace_outlined,
          label: 'Xoá',
          colors: Candy.red,
          onTap: onErase,
        ),
        _Act(
          icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: paused ? 'Tiếp tục' : 'Tạm dừng',
          colors: Candy.orange,
          active: paused,
          onTap: canPause ? onPause : null,
        ),
        _Act(
          icon: Icons.lightbulb_outline,
          label: 'Gợi ý',
          colors: Candy.teal,
          badge: '$hintsLeft',
          badgeColor: hintsLeft > 0 ? Candy.orange.last : Colors.blueGrey,
          onTap: hintsLeft > 0 ? onHint : null,
        ),
        if (showNew)
          _Act(
            icon: Icons.refresh_rounded,
            label: 'Ván mới',
            colors: Candy.green,
            onTap: onNew,
          ),
      ],
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.active = true,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback? onTap;

  /// false = nut tat (mo di).
  final bool active;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GameActionButton(
        icon: icon,
        tooltip: label,
        colors: colors,
        dim: !active,
        onPressed: onTap,
        badge: badge,
      ),
    );
  }
}

/// Ban phim so 1-9, moi nut hien so con lai; du 9 thi mo va khoa.
class SudokuNumPad extends StatelessWidget {
  const SudokuNumPad({
    required this.remaining,
    required this.notesOn,
    required this.onDigit,
    super.key,
  });

  /// remaining[d-1] = so o con thieu cua chu so d.
  final List<int> remaining;
  final bool notesOn;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var d = 1; d <= 9; d++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: remaining[d - 1] <= 0 ? 0.3 : 1,
                child: CandyButton(
                  key: ValueKey('sudoku-pad-$d'),
                  colors: Candy.palettes[(d - 1) % Candy.palettes.length],
                  dim: notesOn,
                  radius: 10,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  onPressed: remaining[d - 1] <= 0 ? null : () => onDigit(d),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$d',
                          style: TextStyle(
                            fontSize: notesOn ? 19 : 23,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          remaining[d - 1] <= 0 ? '' : '${remaining[d - 1]}',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.1,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Danh sach chon do kho kem ky luc tung muc.
class SudokuLevelPicker extends StatelessWidget {
  const SudokuLevelPicker({
    required this.stats,
    required this.onPick,
    this.current,
    super.key,
  });

  final GameStats Function(SudokuLevel) stats;
  final ValueChanged<SudokuLevel> onPick;
  final SudokuLevel? current;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, l) in SudokuLevel.values.indexed)
          PopIn(
            trigger: l,
            duration: Duration(milliseconds: 220 + 60 * k),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: CandyButton(
                key: ValueKey('sudoku-level-${l.name}'),
                colors: levelColors(l),
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                sfx: SfxKind.option,
                onPressed: () => onPick(l),
                child: SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Icon(levelIcon(l), size: 38),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.label, style: const TextStyle(fontSize: 22)),
                            Text(
                              _sub(stats(l)),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        l == current
                            ? Icons.star_rounded
                            : Icons.play_arrow_rounded,
                        size: 34,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _sub(GameStats st) {
    final best = st.best == null
        ? 'Chưa có kỷ lục'
        : 'Kỷ lục ${formatClock(st.best!)}';
    return '$best · Thắng ${st.won}/${st.played}';
  }
}
