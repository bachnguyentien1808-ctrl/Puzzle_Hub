import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Bo mau tuoi dung cho nut / bieu tuong tren the kinh.
abstract final class FrostColors {
  static const green = Color(0xFF22B573);
  static const blue = Color(0xFF2F80FF);
  static const orange = Color(0xFFFF8A1F);
  static const red = Color(0xFFEF4B5B);
  static const purple = Color(0xFF8B5CF6);
  static const teal = Color(0xFF0EB5C9);
  static const pink = Color(0xFFEC4899);
  static const amber = Color(0xFFF5A60B);
  static const indigo = Color(0xFF5B5BE6);

  /// Mau cho 9 phim so 1-9.
  static const digits = [
    blue,
    green,
    orange,
    purple,
    pink,
    teal,
    red,
    amber,
    indigo,
  ];
}

/// Bang mau "kinh mo sang" (the trang bo tron, chu xanh dam) cua giao dien
/// moi, doi theo buoi: ngay (trang), chieu (kem am), dem (xanh navy).
class FrostStyle {
  const FrostStyle({
    required this.fill,
    required this.border,
    required this.key,
    required this.ink,
    required this.subInk,
    required this.accent,
    required this.onAccent,
  });

  /// Nen the kinh va vien.
  final Color fill;
  final Color border;

  /// Nen nut / phim so.
  final Color key;

  /// Chu chinh, chu phu, mau nhan manh (nut chinh) va chu tren mau nhan.
  final Color ink;
  final Color subInk;
  final Color accent;
  final Color onAccent;

  static const day = FrostStyle(
    fill: Color(0xA3FFFFFF),
    border: Color(0xCCFFFFFF),
    key: Color(0xFFFFFFFF),
    ink: Color(0xFF1B2F57),
    subInk: Color(0xFF5D7096),
    accent: Color(0xFF2F6BFF),
    onAccent: Colors.white,
  );

  static const dusk = FrostStyle(
    fill: Color(0xB3FFF3E6),
    border: Color(0xD9FFE6CC),
    key: Color(0xFFFFFBF6),
    ink: Color(0xFF47263A),
    subInk: Color(0xFF8A6070),
    accent: Color(0xFFE8602C),
    onAccent: Colors.white,
  );

  static const night = FrostStyle(
    fill: Color(0xB3141E4C),
    border: Color(0x80B8C8FF),
    key: Color(0xCC24336E),
    ink: Color(0xFFEAF0FF),
    subInk: Color(0xFFA9B8E6),
    accent: Color(0xFF4F83FF),
    onAccent: Colors.white,
  );

  static FrostStyle forPhase(DayPhase p) => switch (p) {
    DayPhase.day => day,
    DayPhase.dusk => dusk,
    DayPhase.night => night,
  };

  /// Theo buoi cua app; chua co (vd. test) thi theo do sang cua theme.
  static FrostStyle of(BuildContext context) {
    final p =
        BackdropPhaseScope.maybeOf(context) ??
        (Theme.of(context).brightness == Brightness.light
            ? DayPhase.day
            : DayPhase.night);
    return forPhase(p);
  }
}

/// The kinh mo bo tron (lam mo phia sau, vien sang, bong nhe).
class FrostCard extends StatelessWidget {
  const FrostCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.strong = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Nen dac hon (de doc, noi bat): dung cho bang thanh tich.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final f = FrostStyle.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26102040),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: strong ? f.key.withValues(alpha: .93) : f.fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: f.border, width: 1.4),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: f.ink),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nut vien thuoc kinh: [primary] = nen mau nhan, chu trang; con lai = nen
/// trang mo, chu xanh dam. [onPressed] null = nut tat (mo di).
class FrostButton extends StatelessWidget {
  const FrostButton({
    required this.child,
    required this.onPressed,
    this.primary = false,
    this.selected = false,
    this.tint,
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool primary;

  /// Dang duoc chon (vd. tab do kho hien tai): to mau nhan nhu nut chinh.
  final bool selected;

  /// Mau rieng cua nut: nen pha nhe mau nay, chu/icon dam mau nay; khi chon
  /// hoac [primary] thi to dac mau nay. null = mau nhan chung.
  final Color? tint;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final f = FrostStyle.of(context);
    final accent = primary || selected;
    final base = tint ?? f.accent;
    final dark = f.ink.computeLuminance() > .5;
    final fg = accent
        ? f.onAccent
        : tint == null
        ? f.ink
        : (dark
              ? Color.lerp(tint, Colors.white, .35)!
              : Color.lerp(tint, Colors.black, .3)!);
    return Opacity(
      opacity: onPressed == null ? 0.65 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: accent
                ? null
                : tint == null
                ? f.key
                : Color.alphaBlend(tint!.withValues(alpha: .16), f.key),
            border: !accent && tint != null
                ? Border.all(color: tint!.withValues(alpha: .5), width: 1.3)
                : null,
            gradient: accent
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(base, Colors.white, .2)!, base],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: (accent ? base : const Color(0xFF102040)).withValues(
                  alpha: accent ? .35 : .2,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onPressed,
            child: Padding(
              padding: padding,
              child: IconTheme.merge(
                data: IconThemeData(color: fg),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: fg, fontWeight: FontWeight.w800),
                  child: Center(widthFactor: 1, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Muc menu doc ben trai (icon + chu); muc dang mo nen sang nhu the.
class FrostNavItem {
  const FrostNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// Mau o tron cua bieu tuong.
  final Color color;
}

class FrostNavRail extends StatelessWidget {
  const FrostNavRail({required this.items, super.key});

  final List<FrostNavItem> items;

  @override
  Widget build(BuildContext context) {
    final f = FrostStyle.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: it.selected
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(f.accent, Colors.white, .2)!,
                          f.accent,
                        ],
                      )
                    : null,
                color: it.selected ? null : f.key,
                border: Border.all(
                  color: it.selected ? f.accent : f.border,
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (it.selected ? f.accent : const Color(0xFF102040))
                        .withValues(alpha: it.selected ? .4 : .2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: it.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: it.color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(it.icon, size: 20, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            it.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: it.selected ? f.onAccent : f.ink,
                            ),
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
