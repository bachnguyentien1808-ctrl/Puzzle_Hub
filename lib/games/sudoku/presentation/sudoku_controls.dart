import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/frost.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
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
    required this.canRedo,
    required this.notesOn,
    required this.hintsLeft,
    required this.onUndo,
    required this.onRedo,
    required this.onErase,
    required this.onNotes,
    required this.onHint,
    super.key,
  });

  final bool canUndo;
  final bool canRedo;
  final bool notesOn;
  final int hintsLeft;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onErase;
  final VoidCallback onNotes;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Act(
          icon: Icons.undo,
          label: 'Hoàn tác',
          tint: FrostColors.blue,
          onTap: canUndo ? onUndo : null,
        ),
        _Act(
          icon: Icons.redo,
          label: 'Làm lại',
          tint: FrostColors.indigo,
          onTap: canRedo ? onRedo : null,
        ),
        _Act(
          icon: Icons.backspace_outlined,
          label: 'Xoá',
          tint: FrostColors.red,
          onTap: onErase,
        ),
        _Act(
          icon: notesOn ? Icons.edit : Icons.edit_outlined,
          label: 'Ghi chú',
          tint: FrostColors.purple,
          selected: notesOn,
          badge: notesOn ? 'BẬT' : 'TẮT',
          badgeColor: notesOn ? Candy.green.last : Colors.blueGrey,
          onTap: onNotes,
        ),
        _Act(
          icon: Icons.lightbulb_outline,
          label: 'Gợi ý',
          tint: FrostColors.amber,
          badge: '$hintsLeft',
          badgeColor: hintsLeft > 0 ? Candy.orange.last : Colors.blueGrey,
          onTap: hintsLeft > 0 ? onHint : null,
        ),
      ],
    );
  }
}

class _Act extends StatelessWidget {
  const _Act({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tint,
    this.selected = false,
    this.badge,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color tint;

  /// Dang bat (vd. che do ghi chu): to mau nhan.
  final bool selected;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    Widget ic = Icon(icon, size: 24);
    if (badge != null) {
      ic = Badge(
        label: Text(badge!),
        backgroundColor: badgeColor,
        textColor: Colors.white,
        offset: const Offset(10, -4),
        child: ic,
      );
    }
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FrostButton(
            tint: tint,
            selected: selected,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            onPressed: onTap,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ic,
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 11),
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

/// Mot phim so Sudoku (so lon + so o con thieu); du 9 thi mo va khoa.
class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.digit,
    required this.remaining,
    required this.notesOn,
    required this.onDigit,
    this.height = 46,
  });

  final int digit;
  final int remaining;
  final bool notesOn;
  final ValueChanged<int> onDigit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final base = FrostColors.digits[(digit - 1) % 9];
    final dark = FrostStyle.of(context).ink.computeLuminance() > .5;
    final color = dark ? Color.lerp(base, Colors.white, .6)! : base;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: remaining <= 0 ? 0.3 : 1,
      child: FrostButton(
        key: ValueKey('sudoku-pad-$digit'),
        tint: base,
        radius: 14,
        padding: const EdgeInsets.symmetric(vertical: 4),
        onPressed: remaining <= 0 ? null : () => onDigit(digit),
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$digit',
                style: TextStyle(
                  fontSize: notesOn ? 19 : 23,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                remaining <= 0 ? '' : '$remaining',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  color: color.withValues(alpha: .8),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ban phim so 1-9 mot hang (dien thoai), moi nut hien so con lai.
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
              child: _PadKey(
                digit: d,
                remaining: remaining[d - 1],
                notesOn: notesOn,
                onDigit: onDigit,
              ),
            ),
          ),
      ],
    );
  }
}

/// Ban phim so 3x3 (man rong): cung phim, xep luoi.
class SudokuNumGrid extends StatelessWidget {
  const SudokuNumGrid({
    required this.remaining,
    required this.notesOn,
    required this.onDigit,
    super.key,
  });

  final List<int> remaining;
  final bool notesOn;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 3; r++)
          Padding(
            padding: EdgeInsets.only(top: r == 0 ? 0 : 10),
            child: Row(
              children: [
                for (var c = 0; c < 3; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: c == 0 ? 0 : 10),
                      child: _PadKey(
                        digit: r * 3 + c + 1,
                        remaining: remaining[r * 3 + c],
                        notesOn: notesOn,
                        onDigit: onDigit,
                        height: 52,
                      ),
                    ),
                  ),
              ],
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
                  horizontal: 16,
                  vertical: 12,
                ),
                onPressed: () => onPick(l),
                child: SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Icon(levelIcon(l), size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.label, style: const TextStyle(fontSize: 17)),
                            Text(
                              _sub(stats(l)),
                              style: const TextStyle(
                                fontSize: 12,
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
                        size: 28,
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

/// Bang ket qua sau van (thang hoac thua).
class SudokuResultPanel extends StatelessWidget {
  const SudokuResultPanel({
    required this.won,
    required this.seconds,
    required this.mistakes,
    required this.mistakeLimit,
    required this.hints,
    required this.best,
    required this.newRecord,
    required this.title,
    required this.actions,
    super.key,
  });

  final bool won;
  final int seconds;
  final int mistakes;
  final bool mistakeLimit;
  final int hints;
  final int? best;
  final bool newRecord;
  final String title;
  final List<Widget> actions;

  static const _ink = Color(0xFF5A3410);

  @override
  Widget build(BuildContext context) {
    final colors = won
        ? const [Candy.cream, Candy.creamDeep]
        : const [Color(0xFFFFE0DA), Color(0xFFF5AFA6)];
    return PopIn(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Candy.gold, width: 3),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0xFFB07A3E), offset: Offset(0, 5)),
            BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 9),
              blurRadius: 8,
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: _ink, fontWeight: FontWeight.w700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events : Icons.heart_broken_outlined,
                size: 52,
                color: won ? Candy.orange.last : Candy.red.last,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              if (newRecord) ...[
                const SizedBox(height: 8),
                const PopIn(
                  duration: Duration(milliseconds: 500),
                  child: CandyRibbon(text: 'Kỷ lục mới!', colors: Candy.orange),
                ),
              ],
              const SizedBox(height: 12),
              _row(Icons.timer_outlined, 'Thời gian', formatClock(seconds)),
              _row(
                Icons.close_rounded,
                'Lỗi',
                mistakeLimit ? '$mistakes/3' : '$mistakes',
              ),
              _row(Icons.lightbulb_outline, 'Gợi ý đã dùng', '$hints'),
              if (best != null)
                _row(
                  Icons.workspace_premium_outlined,
                  'Kỷ lục',
                  formatClock(best!),
                ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData i, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(i, size: 20, color: Candy.brown),
        const SizedBox(width: 10),
        Expanded(child: Text(k)),
        Text(
          v,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
