import 'dart:math';

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/frost.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_game.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_solver.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_burst.dart';

/// Dang ve cua mot o: gradient, mau chu ep buoc (null = theo loai chu so).
class _Look {
  const _Look(this.colors, {this.fg});

  /// null = o trong: khong ve vien o, de lo nen xanh dam cua khung.
  final List<Color>? colors;
  final Color? fg;
}

/// Ban co 9x9 kieu keo ngot: khung kem, o bong noi, to sang, vien chon dong,
/// song sang.
class SudokuBoard extends StatefulWidget {
  const SudokuBoard({
    required this.game,
    required this.selected,
    required this.onTap,
    required this.wave,
    required this.waveDelay,
    required this.hintUnit,
    required this.hintCell,
    this.burst,
    this.burstDelay = const {},
    super.key,
  });

  final SudokuGame game;
  final int? selected;
  final ValueChanged<int> onTap;

  /// Bo dieu khien song sang (0..1) va do tre cua tung o (0..1).
  final Animation<double> wave;
  final Map<int, double> waveDelay;

  /// Don vi va o cua goi y dang hien.
  final List<int> hintUnit;
  final int? hintCell;

  /// Hieu ung bung sang khi xong hang/cot/khoi (tuy chon).
  final Animation<double>? burst;
  final Map<int, double> burstDelay;

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> {
  int? _down;

  SudokuGame get game => widget.game;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final f = FrostStyle.of(context);
    return _Frame(
      f: f,
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, box) {
            final size = box.maxWidth;
            final cell = size / 9;
            final sel = widget.selected;
            final selVal = sel == null ? 0 : game.values[sel];
            final hintSet = widget.hintUnit.toSet();
            int at(Offset p) {
              final c = (p.dx / cell).floor().clamp(0, 8);
              final r = (p.dy / cell).floor().clamp(0, 8);
              return r * 9 + c;
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final i = at(d.localPosition);
                setState(() => _down = i);
                widget.onTap(i);
              },
              onTapUp: (_) => setState(() => _down = null),
              onTapCancel: () => setState(() => _down = null),
              child: Stack(
                children: [
                  // Dai sang hang + cot (va khoi) cua o dang chon, nam duoi o
                  // de ca o trong cung thay ro.
                  if (sel != null) ..._bands(sel, cell, size, reduce),
                  // Lop o.
                  Column(
                    children: [
                      for (var r = 0; r < 9; r++)
                        Expanded(
                          child: Row(
                            children: [
                              for (var c = 0; c < 9; c++)
                                Expanded(
                                  child: _Cell(
                                    key: ValueKey('sudoku-cell-${r * 9 + c}'),
                                    index: r * 9 + c,
                                    game: game,
                                    size: cell,
                                    selVal: selVal,
                                    look: _look(
                                      r * 9 + c,
                                      sel,
                                      selVal,
                                      hintSet,
                                    ),
                                    pressed: _down == r * 9 + c,
                                    reduce: reduce,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Vien 9 khoi 3x3.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _GridPainter(f.ink)),
                    ),
                  ),
                  // Bung sang khi xong hang/cot/khoi.
                  if (!reduce && widget.burst != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: SudokuBurstPainter(
                            widget.burst!,
                            widget.burstDelay,
                          ),
                        ),
                      ),
                    ),
                  // Song sang.
                  if (!reduce)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _WavePainter(
                            widget.wave,
                            widget.waveDelay,
                            f.accent,
                          ),
                        ),
                      ),
                    ),
                  // Vien chon dong.
                  if (sel != null)
                    AnimatedPositioned(
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                      left: sel % 9 * cell,
                      top: sel ~/ 9 * cell,
                      width: cell,
                      height: cell,
                      child: IgnorePointer(
                        child: _PulseBorder(
                          color: game.isWrong(sel) ? Candy.red.first : f.accent,
                          reduce: reduce,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _bands(int sel, double cell, double size, bool reduce) {
    final d = reduce ? Duration.zero : const Duration(milliseconds: 160);
    final r = sel ~/ 9;
    final c = sel % 9;
    final br = r ~/ 3 * 3;
    final bc = c ~/ 3 * 3;
    Widget band({
      required double left,
      required double top,
      required double w,
      required double h,
      required double alpha,
      required bool edge,
    }) {
      return AnimatedPositioned(
        duration: d,
        curve: Curves.easeOutCubic,
        left: left,
        top: top,
        width: w,
        height: h,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: alpha),
              border: edge
                  ? Border.all(
                      color: Colors.white.withValues(alpha: .55),
                      width: 1.5,
                    )
                  : null,
            ),
          ),
        ),
      );
    }

    return [
      band(
        left: bc * cell,
        top: br * cell,
        w: cell * 3,
        h: cell * 3,
        alpha: .16,
        edge: false,
      ),
      band(left: 0, top: r * cell, w: size, h: cell, alpha: .34, edge: true),
      band(left: c * cell, top: 0, w: cell, h: size, alpha: .34, edge: true),
    ];
  }

  _Look _look(int i, int? sel, int selVal, Set<int> hintSet) {
    final f = FrostStyle.of(context);
    final v = game.values[i];
    List<Color> flat(Color c) => [c, c];
    if (i == widget.hintCell) {
      return _Look(flat(const Color(0xCC3DBE6B)), fg: f.ink);
    }
    if (game.isWrong(i)) {
      return _Look(flat(const Color(0x66E53935)), fg: const Color(0xFFD32F2F));
    }
    if (sel != null) {
      if (i == sel) {
        return _Look(flat(f.accent.withValues(alpha: .86)), fg: f.onAccent);
      }
      if (selVal != 0 && v == selVal) {
        return _Look(flat(f.accent.withValues(alpha: .34)), fg: f.ink);
      }
      final same =
          i ~/ 9 == sel ~/ 9 ||
          i % 9 == sel % 9 ||
          SudokuSolver.boxOf(i) == SudokuSolver.boxOf(sel);
      if (same) return _Look(flat(f.accent.withValues(alpha: .12)));
    }
    if (hintSet.contains(i)) {
      return _Look(flat(const Color(0x3A3DBE6B)));
    }
    return const _Look(null);
  }
}

/// Khung ban co: nen sang, vien dam, bo tron.
class _Frame extends StatelessWidget {
  const _Frame({required this.f, required this.child});

  final FrostStyle f;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: f.key,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: f.ink.withValues(alpha: .85), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26102040),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(3), child: child),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.index,
    required this.game,
    required this.size,
    required this.selVal,
    required this.look,
    required this.pressed,
    required this.reduce,
    super.key,
  });

  final int index;
  final SudokuGame game;
  final double size;
  final int selVal;
  final _Look look;
  final bool pressed;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final v = game.values[index];
    final given = game.isGiven(index);
    final f = FrostStyle.of(context);
    Widget child;
    if (v != 0) {
      final color =
          look.fg ??
          (given
              ? f.ink
              : game.hinted.contains(index)
              ? const Color(0xFF1F8A3B)
              : f.accent);
      final text = Text(
        '$v',
        style: TextStyle(
          fontSize: size * 0.56,
          height: 1,
          fontWeight: given ? FontWeight.w900 : FontWeight.w800,
          color: color,
        ),
      );
      child = given || reduce ? text : PopIn(trigger: '$index-$v', child: text);
    } else if (game.notes[index] != 0) {
      child = _Notes(
        mask: game.notes[index],
        size: size,
        selVal: selVal,
        fg: look.fg,
        base: f.subInk,
        hot: f.accent,
      );
    } else {
      child = const SizedBox.shrink();
    }
    final r = index ~/ 9;
    final c = index % 9;
    const thin = 0.8;
    const thick = 2.0;
    return AnimatedScale(
      scale: pressed ? 0.9 : 1,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 80),
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
        margin: EdgeInsets.fromLTRB(
          c % 3 == 0 ? thick : thin,
          r % 3 == 0 ? thick : thin,
          c % 3 == 2 ? thick : thin,
          r % 3 == 2 ? thick : thin,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          gradient: look.colors == null
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: look.colors!,
                ),
          boxShadow: look.colors == null || look.colors!.first.a < 0.9
              ? null
              : [
                  BoxShadow(
                    color: Color.alphaBlend(Colors.black38, look.colors!.last),
                    offset: const Offset(0, 1.5),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (look.colors != null && look.colors!.first.a >= 0.9)
              const CandyGloss(radius: 4, opacity: 0.5),
            child,
            if (v != 0 && !given && !reduce)
              Positioned.fill(
                child: IgnorePointer(
                  child: _PlaceRing(key: ValueKey('ring-$index-$v')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Vong sang no ra roi tat khi dat mot so.
class _PlaceRing extends StatelessWidget {
  const _PlaceRing({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (_, t, _) => t >= 1
          ? const SizedBox.shrink()
          : Transform.scale(
              scale: 1 + 0.5 * t,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9 * (1 - t)),
                    width: 2.5 * (1 - t) + 0.5,
                  ),
                ),
              ),
            ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({
    required this.mask,
    required this.size,
    required this.selVal,
    required this.fg,
    required this.base,
    required this.hot,
  });

  final int mask;
  final double size;
  final int selVal;
  final Color? fg;
  final Color base;
  final Color hot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < 3; c++)
                    Expanded(child: Center(child: _note(r * 3 + c + 1))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _note(int d) {
    if (mask & (1 << d) == 0) return const SizedBox.shrink();
    final isHot = d == selVal;
    return Text(
      '$d',
      style: TextStyle(
        fontSize: size * 0.24,
        height: 1,
        fontWeight: isHot ? FontWeight.w900 : FontWeight.w600,
        color: isHot ? (fg ?? hot) : (fg ?? base),
      ),
    );
  }
}

/// Vien o dang chon, nhip nhe (dung yen khi giam chuyen dong).
class _PulseBorder extends StatefulWidget {
  const _PulseBorder({required this.color, required this.reduce});

  final Color color;
  final bool reduce;

  @override
  State<_PulseBorder> createState() => _PulseBorderState();
}

class _PulseBorderState extends State<_PulseBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduce) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseBorder old) {
    super.didUpdateWidget(old);
    if (widget.reduce && _c.isAnimating) _c.stop();
    if (!widget.reduce && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final t = Curves.easeInOut.transform(_c.value);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: widget.color, width: 2 + t * 1.2),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.12 + 0.18 * t),
              blurRadius: 3 + 5 * t,
            ),
          ],
        ),
      );
    },
  );
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final thin = Paint()
      ..strokeWidth = 0.8
      ..color = ink.withValues(alpha: 0.22);
    final thick = Paint()
      ..strokeWidth = 2
      ..color = ink.withValues(alpha: 0.85);
    for (var i = 1; i < 9; i++) {
      if (i % 3 == 0) continue;
      canvas
        ..drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), thin)
        ..drawLine(Offset(0, i * cell), Offset(size.width, i * cell), thin);
    }
    for (var i = 3; i < 9; i += 3) {
      canvas
        ..drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), thick)
        ..drawLine(Offset(0, i * cell), Offset(size.width, i * cell), thick);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.ink != ink;
}

/// Ve song sang: moi o sang len roi tat theo do tre rieng.
class _WavePainter extends CustomPainter {
  _WavePainter(this.wave, this.delay, this.color) : super(repaint: wave);

  final Animation<double> wave;
  final Map<int, double> delay;
  final Color color;

  /// Phan thoi gian moi o sang (tren thang 0..1 cua ca song).
  static const span = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final t = wave.value;
    if (t <= 0 || t >= 1 || delay.isEmpty) return;
    final cell = size.width / 9;
    const scale = 1 - span;
    final paint = Paint();
    for (final e in delay.entries) {
      final start = e.value * scale;
      final k = (t - start) / span;
      if (k <= 0 || k >= 1) continue;
      final a = sin(k * pi);
      paint.color = color.withValues(alpha: 0.35 * a);
      final r = Rect.fromLTWH(
        e.key % 9 * cell,
        e.key ~/ 9 * cell,
        cell,
        cell,
      ).deflate(cell * 0.08 * (1 - a));
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.18)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.delay != delay;
}
