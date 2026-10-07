import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

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
    key: Color(0xE6FFFFFF),
    ink: Color(0xFF1B2F57),
    subInk: Color(0xFF5D7096),
    accent: Color(0xFF2F6BFF),
    onAccent: Colors.white,
  );

  static const dusk = FrostStyle(
    fill: Color(0xB3FFF3E6),
    border: Color(0xD9FFE6CC),
    key: Color(0xEBFFF8F1),
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
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

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
              color: f.fill,
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
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool primary;

  /// Dang duoc chon (vd. tab do kho hien tai): to mau nhan nhu nut chinh.
  final bool selected;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final f = FrostStyle.of(context);
    final accent = primary || selected;
    final fg = accent ? f.onAccent : f.ink;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: accent ? null : f.key,
            gradient: accent
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(f.accent, Colors.white, .18)!,
                      f.accent,
                    ],
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: (accent ? f.accent : const Color(0xFF102040)).withValues(
                  alpha: accent ? .35 : .12,
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
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
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: it.selected ? f.fill : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: it.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        it.icon,
                        size: 22,
                        color: it.selected ? f.accent : Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          it.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: it.selected ? f.ink : Colors.white,
                            shadows: it.selected
                                ? null
                                : const [
                                    Shadow(
                                      color: Color(0x99000000),
                                      blurRadius: 6,
                                    ),
                                  ],
                          ),
                        ),
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
}
