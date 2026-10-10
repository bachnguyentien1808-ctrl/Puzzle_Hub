import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Phan hoi xuc giac dung chung. Bat/tat qua [GameFx.haptics]
/// (man Cai dat ghi vao day).
abstract final class GameFx {
  static final ValueNotifier<bool> haptics = ValueNotifier(true);

  static void tap() {
    if (haptics.value) HapticFeedback.selectionClick();
  }

  static void success() {
    if (haptics.value) HapticFeedback.mediumImpact();
  }

  static void error() {
    if (haptics.value) HapticFeedback.heavyImpact();
  }
}

/// Hieu ung phao giay khi thang: no tu giua ra roi roi xuong, nhieu mau va
/// hinh (chu nhat, tron, sao). Dat len Stack, hien khi [show] = true.
/// Khong chan thao tac (IgnorePointer).
class Confetti extends StatefulWidget {
  const Confetti({required this.show, super.key});

  final bool show;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  final _rng = Random();
  late final List<_Piece> _pieces = List.generate(
    150,
    (i) => _Piece(_rng, burst: i < 70),
  );

  static const _colors = [
    Color(0xFFFF5252),
    Color(0xFFFFC107),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFB388FF),
    Color(0xFFFF80AB),
    Color(0xFFFFAB40),
    Color(0xFF64FFDA),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.show) _c.forward();
  }

  @override
  void didUpdateWidget(Confetti old) {
    super.didUpdateWidget(old);
    if (widget.show && !old.show) _c.forward(from: 0);
    if (!widget.show && old.show) _c.reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value, _colors),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(Random r, {required this.burst})
    : x = r.nextDouble(),
      speed = 0.6 + r.nextDouble() * 0.9,
      drift = (r.nextDouble() - 0.5) * 0.4,
      size = 6 + r.nextDouble() * 8,
      spin = r.nextDouble() * pi * 4,
      color = r.nextInt(8),
      shape = r.nextInt(3),
      angle = -pi * (0.1 + r.nextDouble() * 0.8),
      power = 0.25 + r.nextDouble() * 0.5,
      delay = r.nextDouble() * 0.2;

  final bool burst;
  final double x;
  final double speed;
  final double drift;
  final double size;
  final double spin;
  final int color;
  final int shape;
  final double angle;
  final double power;
  final double delay;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.colors);

  final List<_Piece> pieces;
  final double t;
  final List<Color> colors;

  static Path _star(double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(cos(a) * rad, sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    for (final p in pieces) {
      final k = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (k <= 0) continue;
      double x;
      double y;
      if (p.burst) {
        // No tu giua man hinh theo goc ngau nhien, giam toc roi roi do trong luc.
        final out = 1 - pow(1 - k, 3).toDouble();
        final reach = p.power * size.shortestSide * 1.6;
        x = size.width / 2 + cos(p.angle) * reach * out;
        y = size.height * 0.42 + sin(p.angle) * reach * out;
        y += k * k * size.height * 0.9;
      } else {
        x = (p.x + p.drift * k) * size.width;
        y = -20 + k * p.speed * (size.height + 40);
      }
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * k);
      final paint = Paint()
        ..color = colors[p.color].withValues(
          alpha: (1 - k * k * k).clamp(0, 1),
        );
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
        default:
          canvas.drawPath(_star(p.size * 0.7), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Hieu ung "nay" (scale + fade) khi widget xuat hien hoac [trigger] doi.
class PopIn extends StatelessWidget {
  const PopIn({
    required this.child,
    this.trigger,
    this.duration = const Duration(milliseconds: 220),
    super.key,
  });

  final Widget child;

  /// Doi gia tri nay de chay lai hieu ung (vd gia tri o).
  final Object? trigger;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(trigger),
      tween: Tween(begin: 0.6, end: 1),
      duration: duration,
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.scale(scale: v, child: child),
      ),
      child: child,
    );
  }
}

/// Lac ngang ngan (bao loi). Goi `shakeKey.currentState?.shake()`.
class Shake extends StatefulWidget {
  const Shake({required this.child, super.key});

  final Widget child;

  @override
  State<Shake> createState() => ShakeState();
}

class ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  void shake() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) => Transform.translate(
      offset: Offset(sin(_c.value * pi * 6) * 8 * (1 - _c.value), 0),
      child: child,
    ),
    child: widget.child,
  );
}

/// Vo man thang: the lon mot khoi (sao bong + chi so + ruy-bang ky luc + diem +
/// nut), kem phao giay. Hien trong Overlay goc cua ung dung nen NOI HAN len
/// tren toan man hinh (ca thanh tren), khong bi gioi han trong khung game.
class WinBanner extends StatefulWidget {
  const WinBanner({
    required this.show,
    required this.title,
    this.subtitle,
    this.onAgain,
    this.points,
    this.stars = 3,
    this.chips = const [],
    this.ribbon,
    this.againLabel = 'Chơi lại',
    this.againKey,
    this.onExit,
    this.starKeyPrefix,
    this.lose = false,
    this.loseIcon,
    super.key,
  });

  final bool show;
  final String title;
  final String? subtitle;
  final VoidCallback? onAgain;
  final int? points;
  final int stars;
  final List<WinChip> chips;
  final String? ribbon;
  final String againLabel;
  final Key? againKey;
  final VoidCallback? onExit;
  final String? starKeyPrefix;
  final bool lose;
  final IconData? loseIcon;

  @override
  State<WinBanner> createState() => _WinBannerState();
}

class _WinBannerState extends State<WinBanner> {
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    // Không được gọi show() trong lúc build: mở lớp phủ sau khung hình đầu,
    // rồi chỉ việc đổi nội dung theo widget.show.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _portal.show();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (_) => !widget.show
          ? const IgnorePointer(child: SizedBox.shrink())
          : Material(
              type: MaterialType.transparency,
              child: _WinBannerBody(
                show: true,
                title: widget.title,
                subtitle: widget.subtitle,
                onAgain: widget.onAgain,
                points: widget.points,
                stars: widget.stars,
                chips: widget.chips,
                ribbon: widget.ribbon,
                againLabel: widget.againLabel,
                againKey: widget.againKey,
                onExit: widget.onExit,
                starKeyPrefix: widget.starKeyPrefix,
                lose: widget.lose,
                loseIcon: widget.loseIcon,
              ),
            ),
    );
  }
}

class _WinBannerBody extends StatelessWidget {
  const _WinBannerBody({
    required this.show,
    required this.title,
    this.subtitle,
    this.onAgain,
    this.points,
    this.stars = 3,
    this.chips = const [],
    this.ribbon,
    this.againLabel = 'Chơi lại',
    this.againKey,
    this.onExit,
    this.starKeyPrefix,
    this.lose = false,
    this.loseIcon,
  });

  final bool show;
  final String title;
  final String? subtitle;
  final VoidCallback? onAgain;

  /// Diem nhan duoc o van nay; hien "+N diem" dem tang dan.
  final int? points;

  /// Số sao đạt được (0-3); sao chưa đạt hiện mờ.
  final int stars;

  /// Các chỉ số của ván (lượt, thời gian...) hiện thành viên thuốc dưới tiêu đề.
  final List<WinChip> chips;

  /// Dải ruy-băng như "Kỷ lục mới!".
  final String? ribbon;
  final String againLabel;
  final Key? againKey;

  /// Có thì hiện thêm nút đỏ "Thoát" cạnh nút chơi lại.
  final VoidCallback? onExit;

  /// Có thì mỗi sao có key `<prefix>-1..3` (để test).
  final String? starKeyPrefix;

  /// Thẻ thua: bom + sao xám, viền đỏ, ruy-băng đỏ, không có pháo giấy.
  final bool lose;

  /// Thẻ thua: biểu tượng thay quả bom (null = bom).
  final IconData? loseIcon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (show)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 350),
              builder: (_, v, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.9,
                    colors: [
                      (lose ? const Color(0xFF7A0C1A) : const Color(0xFF1C3A8F))
                          .withValues(alpha: 0.55 * v),
                      Colors.black.withValues(alpha: 0.82 * v),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(child: Confetti(show: show && !lose)),
        if (show)
          Positioned.fill(
            child: Center(
              child: _Impact(
                lose: lose,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = min(box.maxWidth - 20, 480).toDouble();
                    // Màn thấp (điện thoại ngang...) thì thu nhỏ cả thẻ cho vừa.
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FittedBox(
                        child: SizedBox(width: w, child: _card()),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF4F6FF), Color(0xFFB5C0EA), Color(0xFFE9EDFF)],
        ),
        boxShadow: [
          const BoxShadow(
            color: Color(0x99000000),
            blurRadius: 30,
            offset: Offset(0, 12),
          ),
          BoxShadow(
            color: lose ? const Color(0x88FF3B3B) : const Color(0x553E6BFF),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2B4FA6), Color(0xFF1B2F6E)],
            ),
          ),
          child: Stack(
            children: [
              for (final (l, t, r, b, s) in const [
                (14.0, 14.0, null, null, 30.0),
                (null, 18.0, 14.0, null, 34.0),
                (12.0, null, null, 150.0, 26.0),
                (null, null, 12.0, 160.0, 30.0),
              ])
                Positioned(
                  left: l,
                  top: t,
                  right: r,
                  bottom: b,
                  child: Icon(
                    Icons.star_rounded,
                    size: s,
                    color: const Color(0x22A9B8FF),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lose)
                      _BombHero(icon: loseIcon)
                    else
                      _StarsHero(lit: stars, keyPrefix: starKeyPrefix),
                    const SizedBox(height: 6),
                    _outlined(
                      title,
                      50,
                      lose ? const Color(0xFF8A1020) : const Color(0xFF14226B),
                    ),
                    if (chips.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [for (final c in chips) _Pill(chip: c)],
                        ),
                      )
                    else if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFC9D4FF),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (ribbon != null) ...[
                      const SizedBox(height: 16),
                      _GoldRibbon(text: ribbon!, red: lose),
                    ],
                    if (points != null && points! > 0) ...[
                      const SizedBox(height: 16),
                      _PointsBadge(points: points!),
                    ],
                    if (onAgain != null || onExit != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          if (onAgain != null)
                            Expanded(
                              child: CandyButton(
                                key: againKey,
                                onPressed: onAgain,
                                colors: Candy.green,
                                radius: 20,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: _btnLabel(
                                  Icons.refresh_rounded,
                                  againLabel,
                                ),
                              ),
                            ),
                          if (onAgain != null && onExit != null)
                            const SizedBox(width: 14),
                          if (onExit != null)
                            Expanded(
                              child: CandyButton(
                                onPressed: onExit,
                                colors: Candy.red,
                                radius: 20,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: _btnLabel(Icons.logout_rounded, 'Thoát'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _btnLabel(IconData icon, String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 26),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ),
    ],
  );

  /// Chữ trắng viền xanh đậm, bóng dưới: kiểu chữ game. Viền làm bằng bóng
  /// (một Text duy nhất để test tìm được đúng một chữ).
  static Widget _outlined(String text, double size, Color edge) {
    final shadows = <Shadow>[
      for (var i = 0; i < 12; i++)
        Shadow(
          color: edge,
          offset: Offset(cos(i * pi / 6) * 3.2, sin(i * pi / 6) * 3.2),
        ),
      const Shadow(color: Color(0x66000000), offset: Offset(0, 6)),
    ];
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.1,
        color: Colors.white,
        shadows: shadows,
      ),
    );
  }
}

/// Một chỉ số của ván (icon + chữ) trên thẻ thắng.
class WinChip {
  const WinChip(this.icon, this.text);

  final IconData icon;
  final String text;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.chip});

  final WinChip chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF2A4A9C),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF5F86E0), width: 2.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chip.icon, size: 26, color: const Color(0xFFFFC73A)),
          const SizedBox(width: 8),
          Text(
            chip.text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ruy-băng vàng hai đuôi xẻ chữ V, chữ nâu đậm.
class _GoldRibbon extends StatelessWidget {
  const _GoldRibbon({required this.text, this.red = false});

  final String text;
  final bool red;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 66,
      child: CustomPaint(
        painter: _RibbonPainter(red: red),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 30, right: 30),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    red
                        ? Icons.dangerous_rounded
                        : Icons.workspace_premium_rounded,
                    color: red ? Colors.white : const Color(0xFF7A4210),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    maxLines: 1,
                    style: TextStyle(
                      color: red ? Colors.white : const Color(0xFF6A3A0C),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
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

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter({required this.red});

  final bool red;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const tail = 34.0;
    final bodyBottom = h * 0.78;
    final dark = Paint()
      ..color = red ? const Color(0xFFB3162C) : const Color(0xFFE59A1E);
    // Đuôi trái và phải, xẻ chữ V.
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, h * 0.2)
          ..lineTo(tail + 8, h * 0.2)
          ..lineTo(tail + 8, h)
          ..lineTo(0, h)
          ..lineTo(tail * 0.4, h * 0.6)
          ..close(),
        dark,
      )
      ..drawPath(
        Path()
          ..moveTo(w, h * 0.2)
          ..lineTo(w - tail - 8, h * 0.2)
          ..lineTo(w - tail - 8, h)
          ..lineTo(w, h)
          ..lineTo(w - tail * 0.4, h * 0.6)
          ..close(),
        dark,
      );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(tail, 0, w - tail, bodyBottom),
      const Radius.circular(8),
    );
    canvas
      ..drawShadow(Path()..addRRect(body), const Color(0xFF000000), 4, false)
      ..drawRRect(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: red
                ? const [
                    Color(0xFFFF7B6B),
                    Color(0xFFE5364B),
                    Color(0xFFC61F3A),
                  ]
                : const [
                    Color(0xFFFFE27A),
                    Color(0xFFFFC233),
                    Color(0xFFF5A623),
                  ],
          ).createShader(body.outerRect),
      )
      ..drawRRect(
        body.deflate(2.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x88FFFFFF),
      );
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) => old.red != red;
}

/// "+N diem" dem tang dan tu 0: viên thuốc vàng cam, đồng xu sao bên trái.
class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: points),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 22, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFFC77A0A), width: 3),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD84F), Color(0xFFFFB02E), Color(0xFFF58A12)],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x88F5A623), blurRadius: 18),
            BoxShadow(color: Color(0x66000000), offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC77A0A), width: 3),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFF1A6), Color(0xFFFFC233)],
                ),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Colors.white,
                size: 30,
                shadows: [Shadow(color: Color(0xFFC77A0A), blurRadius: 2)],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${Scoring.format(v)} điểm',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    shadows: [
                      Shadow(color: Color(0xFFB5600A), offset: Offset(0, 3)),
                      Shadow(color: Color(0xFFB5600A), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ba sao bóng (giữa to nhất) trên nền tia sáng, kèm lấp lánh và mảnh giấy;
/// nảy dần lên.
class _StarsHero extends StatelessWidget {
  const _StarsHero({required this.lit, this.keyPrefix});

  final int lit;
  final String? keyPrefix;

  Widget _star(double size, int i) {
    final on = i < lit;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + i * 220),
      curve: Curves.elasticOut,
      builder: (_, k, child) => Transform.scale(
        scale: k.clamp(0.0, 1.5),
        child: Transform.rotate(angle: (1 - k) * -1.2, child: child),
      ),
      child: SizedBox(
        key: keyPrefix == null ? null : ValueKey('$keyPrefix-${i + 1}'),
        width: size,
        height: size,
        child: CustomPaint(painter: _GlossStarPainter(on: on)),
      ),
    );
  }

  static const _sparkles = [
    (0.20, 0.10, 20.0),
    (0.80, 0.08, 24.0),
    (0.07, 0.62, 14.0),
    (0.93, 0.64, 14.0),
    (0.32, 0.90, 14.0),
    (0.70, 0.92, 14.0),
  ];

  static const _bits = [
    (0.10, 0.28, Color(0xFFFF7BB5), -0.6),
    (0.15, 0.76, Color(0xFFFFD54F), 0.5),
    (0.28, 0.14, Color(0xFF4FC3F7), 0.9),
    (0.86, 0.26, Color(0xFF4FC3F7), -0.7),
    (0.90, 0.46, Color(0xFFFFD54F), 0.6),
    (0.84, 0.78, Color(0xFFB66BFF), -0.5),
    (0.60, 0.04, Color(0xFF76E05B), 0.8),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          const h = 170.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _SunburstPainter(on: lit > 0)),
              ),
              for (final (x, y, s) in _sparkles)
                Positioned(
                  left: w * x - s / 2,
                  top: h * y - s / 2,
                  child: Icon(
                    Icons.auto_awesome,
                    size: s,
                    color: const Color(0xFFFFE9A0),
                  ),
                ),
              for (final (x, y, c, a) in _bits)
                Positioned(
                  left: w * x - 7,
                  top: h * y - 3,
                  child: Transform.rotate(
                    angle: a,
                    child: Container(
                      width: 14,
                      height: 7,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 22,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _star(86, 0),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: _star(112, 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _star(86, 2),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tia sáng tỏa ra từ giữa, mờ dần ra rìa.
class _SunburstPainter extends CustomPainter {
  const _SunburstPainter({required this.on});

  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    if (!on) return;
    final c = Offset(size.width / 2, size.height * 0.42);
    final r = size.width * 0.5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x99FFD54F), Color(0x00FFD54F)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final ray = Paint()..color = const Color(0x22FFE9A0);
    for (var i = 0; i < 14; i++) {
      final a0 = i * 2 * pi / 14;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + cos(a0) * r, c.dy + sin(a0) * r)
          ..lineTo(c.dx + cos(a0 + .12) * r, c.dy + sin(a0 + .12) * r)
          ..close(),
        ray,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SunburstPainter old) => old.on != on;
}

/// Sao bóng bo tròn góc: viền cam, ruột vàng gradient, vệt sáng.
class _GlossStarPainter extends CustomPainter {
  const _GlossStarPainter({required this.on, this.grey = false});

  final bool on;

  /// Sao xám đặc (thẻ thua) thay vì sao mờ trong suốt.
  final bool grey;

  Path _star(Size s, {double inset = 0}) {
    final c = Offset(s.width / 2, s.height * 0.54);
    final ro = s.width * 0.46 - inset;
    final ri = ro * 0.5;
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? ro : ri;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(c.dx + cos(a) * r, c.dy + sin(a) * r);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _star(size, inset: 6);
    final round = size.width * 0.09;
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = round * 2 + 5
        ..strokeJoin = StrokeJoin.round
        ..color = grey
            ? const Color(0xFF59648F)
            : on
            ? const Color(0xFFE08A12)
            : const Color(0x44FFFFFF),
    );
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: grey
            ? const [Color(0xFFC3CAE3), Color(0xFF8590B8)]
            : on
            ? const [Color(0xFFFFF08A), Color(0xFFFFC21A)]
            : const [Color(0x44FFFFFF), Color(0x22FFFFFF)],
      ).createShader(Offset.zero & size);
    canvas
      ..drawPath(path, fill)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = round * 2
          ..strokeJoin = StrokeJoin.round
          ..shader = fill.shader,
      );
    if (on) {
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * 0.30,
          size.height * 0.18,
          size.width * 0.22,
          size.height * 0.1,
        ),
        Paint()..color = const Color(0xAAFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlossStarPainter old) =>
      old.on != on || old.grey != grey;
}

/// Bom đỏ nứt có đầu lâu trắng, ba sao xám phía sau, mảnh vỡ đỏ bắn ra.
class _BombHero extends StatelessWidget {
  const _BombHero({this.icon});

  /// Có thì thay quả bom bằng biểu tượng này (vd đồng hồ khi hết giờ).
  final IconData? icon;

  static const _shards = [
    (0.20, 0.20, -0.6),
    (0.80, 0.18, 0.7),
    (0.08, 0.50, 0.4),
    (0.92, 0.46, -0.5),
    (0.14, 0.86, 0.9),
    (0.86, 0.84, -0.8),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          const h = 190.0;
          Widget grey(double size) => SizedBox(
            width: size,
            height: size,
            child: const CustomPaint(
              painter: _GlossStarPainter(on: false, grey: true),
            ),
          );
          return Stack(
            alignment: Alignment.center,
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 0.7,
                      colors: [Color(0x66FF5A4A), Color(0x00FF5A4A)],
                    ),
                  ),
                ),
              ),
              for (final (x, y, a) in _shards)
                Positioned(
                  left: w * x - 8,
                  top: h * y - 4,
                  child: Transform.rotate(
                    angle: a,
                    child: Container(
                      width: 16,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B4B),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              Positioned(left: w * 0.5 - 118, bottom: 30, child: grey(78)),
              Positioned(right: w * 0.5 - 118, bottom: 30, child: grey(78)),
              Positioned(bottom: 6, child: grey(76)),
              if (icon != null)
                Positioned(
                  top: 8,
                  child: Container(
                    width: 124,
                    height: 124,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFF6B5B), Color(0xFFC81E32)],
                      ),
                      border: Border.all(color: Colors.white, width: 5),
                      boxShadow: const [
                        BoxShadow(color: Color(0x88FF3B3B), blurRadius: 24),
                      ],
                    ),
                    child: Icon(icon, size: 76, color: Colors.white),
                  ),
                )
              else
                const Positioned(
                  top: 0,
                  child: SizedBox(
                    width: 130,
                    height: 140,
                    child: CustomPaint(painter: _BombPainter()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BombPainter extends CustomPainter {
  const _BombPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.58);
    final r = size.width * 0.40;
    final ball = Rect.fromCircle(center: c, radius: r);
    canvas
      ..drawCircle(c, r + 4, Paint()..color = const Color(0xFF8A1020))
      ..drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            colors: [Color(0xFFFF8A78), Color(0xFFE5303F), Color(0xFFB01426)],
          ).createShader(ball),
      );
    // Nắp và ngòi.
    final cap = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(c.dx + r * 0.38, c.dy - r * 0.92),
        width: 26,
        height: 16,
      ),
      const Radius.circular(4),
    );
    canvas
      ..save()
      ..translate(c.dx + r * 0.38, c.dy - r * 0.92)
      ..rotate(0.5)
      ..translate(-(c.dx + r * 0.38), -(c.dy - r * 0.92))
      ..drawRRect(cap, Paint()..color = const Color(0xFF4A4F66))
      ..restore();
    final fuse = Path()
      ..moveTo(c.dx + r * 0.52, c.dy - r * 1.0)
      ..quadraticBezierTo(
        c.dx + r * 0.7,
        c.dy - r * 1.35,
        c.dx + r * 1.0,
        c.dy - r * 1.3,
      );
    canvas
      ..drawPath(
        fuse,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF6A4A2A),
      )
      ..drawCircle(
        Offset(c.dx + r * 1.0, c.dy - r * 1.3),
        7,
        Paint()..color = const Color(0xFFFFC233),
      )
      ..drawCircle(
        Offset(c.dx + r * 1.0, c.dy - r * 1.3),
        3.5,
        Paint()..color = Colors.white,
      );
    // Vết nứt.
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xAA5A0A14);
    canvas
      ..drawPath(
        Path()
          ..moveTo(c.dx - r * 0.1, c.dy - r * 0.95)
          ..lineTo(c.dx - r * 0.3, c.dy - r * 0.55)
          ..lineTo(c.dx - r * 0.1, c.dy - r * 0.4),
        crack,
      )
      ..drawPath(
        Path()
          ..moveTo(c.dx + r * 0.9, c.dy - r * 0.1)
          ..lineTo(c.dx + r * 0.6, c.dy + r * 0.05)
          ..lineTo(c.dx + r * 0.7, c.dy + r * 0.3),
        crack,
      );
    // Đầu lâu.
    final white = Paint()..color = Colors.white;
    final dark = Paint()..color = const Color(0xFF8A1020);
    canvas
      ..drawCircle(Offset(c.dx, c.dy + 2), r * 0.40, white)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx, c.dy + r * 0.42),
            width: r * 0.46,
            height: r * 0.26,
          ),
          const Radius.circular(4),
        ),
        white,
      )
      ..drawCircle(Offset(c.dx - r * 0.16, c.dy), r * 0.11, dark)
      ..drawCircle(Offset(c.dx + r * 0.16, c.dy), r * 0.11, dark)
      ..drawPath(
        Path()
          ..moveTo(c.dx, c.dy + r * 0.12)
          ..lineTo(c.dx - r * 0.06, c.dy + r * 0.24)
          ..lineTo(c.dx + r * 0.06, c.dy + r * 0.24)
          ..close(),
        dark,
      );
    canvas.drawOval(
      Rect.fromLTWH(c.dx - r * 0.7, c.dy - r * 0.8, r * 0.35, r * 0.2),
      Paint()..color = const Color(0x66FFFFFF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Thẻ thắng/thua bật ra thật mạnh: phóng to từ nhỏ có độ nảy; thẻ thua rung
/// ngang vài nhịp, thẻ thắng có vầng sáng vàng đập nhẹ phía sau.
class _Impact extends StatelessWidget {
  const _Impact({required this.child, required this.lose});

  final Widget child;
  final bool lose;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      builder: (_, t, child) {
        final pop = Curves.easeOutBack.transform(min(1, t * 1.4));
        final shake = lose ? sin(t * 38) * 14 * (1 - t) * (1 - t) : 0.0;
        final halo = lose ? 0.0 : (0.35 + 0.25 * sin(t * 12)) * min(1, t * 3);
        return Opacity(
          opacity: min(1, t * 4),
          child: Transform.translate(
            offset: Offset(shake, 0),
            child: Transform.scale(
              scale: 0.3 + 0.7 * pop,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  boxShadow: [
                    if (!lose)
                      BoxShadow(
                        color: const Color(0xFFFFC73A).withValues(alpha: halo),
                        blurRadius: 70,
                        spreadRadius: 14,
                      ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
