import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/theme/day_phase.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/frost.dart';

/// Man rong tu muc nay tro len dung bo cuc "the kinh o giua".
const frostWideMin = 1100.0;

/// Man du rong de them cot thanh tich ben phai.
const frostStatsMin = 1240.0;

/// Khung man rong cho cac game: the kinh toi o giua chua man choi, banh rang
/// + nut sang/toi goc tren phai, bang thanh tich ben phai (man rong hon) va
/// cau noi nho goc duoi trai. Man hep tra ve [child] nguyen ven.
class FrostWideShell extends ConsumerWidget {
  const FrostWideShell({
    required this.gameId,
    required this.onHelp,
    required this.child,
    super.key,
  });

  final String gameId;
  final VoidCallback onHelp;
  final Widget child;

  static Color _cardFill(DayPhase p) => switch (p) {
    DayPhase.day => const Color(0x8A163560),
    DayPhase.dusk => const Color(0xA62E1A3C),
    DayPhase.night => const Color(0xB80E1D4A),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = BackdropPhaseScope.maybeOf(context) ?? DayPhase.day;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < frostWideMin) return child;
        final showStats = c.maxWidth >= frostStatsMin;
        final outerW = showStats ? 250.0 : 190.0;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
              child: Row(
                children: [
                  SizedBox(width: outerW, child: const _Quote()),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _cardFill(phase),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: .5),
                                  width: 1.4,
                                ),
                              ),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: outerW,
                    child: showStats
                        ? Align(
                            alignment: Alignment.topRight,
                            child: _StatsCard(gameId: gameId),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 16,
              child: Row(
                children: [
                  const _MoonButton(),
                  _GearMenu(gameId: gameId, onHelp: onHelp),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 6, bottom: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.white, width: 2)),
          ),
          child: Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text(
              '“Mỗi con số đúng là một bước tiến\ngần hơn đến chiến thắng.”',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Color(0xAA000000), blurRadius: 8)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nut doi nhanh giao dien sang / toi.
class _MoonButton extends ConsumerWidget {
  const _MoonButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: dark ? 'Giao diện sáng' : 'Giao diện tối',
      child: FrostButton(
        tint: FrostColors.indigo,
        radius: 22,
        padding: const EdgeInsets.all(9),
        onPressed: () => ref
            .read(settingsProvider.notifier)
            .setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
        child: Icon(
          dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 22,
        ),
      ),
    );
  }
}

/// Banh rang: Trang chu, Thong ke, Cai dat, Huong dan.
class _GearMenu extends StatelessWidget {
  const _GearMenu({required this.gameId, required this.onHelp});

  final String gameId;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<String> item(
      String v,
      IconData icon,
      Color color,
      String label,
    ) => PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'home':
            context.go('/');
          case 'stats':
            context.push('/stats');
          case 'settings':
            context.push('/settings');
          case 'help':
            onHelp();
        }
      },
      itemBuilder: (_) => [
        item('home', Icons.home_rounded, FrostColors.orange, 'Trang chủ'),
        item('stats', Icons.bar_chart_rounded, FrostColors.green, 'Thống kê'),
        item('settings', Icons.tune_rounded, FrostColors.blue, 'Cài đặt'),
        item('help', Icons.help_outline_rounded, FrostColors.pink, 'Hướng dẫn'),
      ],
      child: const Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
        child: _GearFace(),
      ),
    );
  }
}

class _GearFace extends StatelessWidget {
  const _GearFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          FrostColors.blue.withValues(alpha: .16),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: FrostColors.blue.withValues(alpha: .5),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33102040),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.settings_rounded,
        size: 22,
        color: Color.lerp(FrostColors.blue, Colors.black, .3),
      ),
    );
  }
}

/// Bang thanh tich cua game (dac, de doc) theo tien do da luu.
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FrostStyle.of(context);
    final ps = ref.watch(progressStoreProvider);
    return ValueListenableBuilder<int>(
      valueListenable: ps.version,
      builder: (_, _, _) {
        final st = ps.stats(gameId);
        final rate = st.played == 0 ? 0 : (st.won * 100 / st.played).round();
        Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  k,
                  style: TextStyle(
                    color: f.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                v,
                style: TextStyle(
                  color: f.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        );
        return FrostCard(
          strong: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.emoji_events_outlined, color: FrostColors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Thành tích',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              row('Tổng điểm', '${ps.totalPoints}'),
              row('Đã chơi', '${st.played}'),
              row('Đã thắng', '${st.won}'),
              row('Tỷ lệ thắng', '$rate%'),
              const Divider(),
              row('Chuỗi thắng', '${st.streak}'),
              row('Chuỗi dài nhất', '${st.bestStreak}'),
            ],
          ),
        );
      },
    );
  }
}
