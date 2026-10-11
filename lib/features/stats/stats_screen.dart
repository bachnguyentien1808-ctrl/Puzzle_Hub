import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';
import 'package:puzzle_hub/features/common/sky_page.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({this.gameId, super.key});

  /// Có giá trị: chỉ thống kê trò chơi này (mở từ trong game).
  final String? gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(progressStoreProvider);
    final today = ref.read(todayProvider)();
    return ValueListenableBuilder<int>(
      valueListenable: store.version,
      builder: (context, _, _) {
        final one = gameId == null ? null : gameById(gameId!);
        final games = one == null ? gameRegistry : [one];
        final tot = store.totals(games.map((g) => g.id));
        final rate = tot.played == 0 ? 0 : (tot.won * 100 / tot.played);
        final st = one == null ? null : store.stats(one.id);
        return SkyPage(
          title: 'Thống kê',
          icon: one?.icon ?? Icons.bar_chart_rounded,
          subtitle: one == null
              ? 'Thành tích chơi của bạn'
              : 'Thành tích của ${one.title}',
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.6,
              children: [
                _Big(
                  colors: Candy.blue,
                  icon: Icons.sports_esports_rounded,
                  value: '${tot.played}',
                  label: 'Ván đã chơi',
                ),
                _Big(
                  colors: Candy.green,
                  icon: Icons.verified_rounded,
                  value: '${rate.round()}%',
                  label: 'Tỉ lệ thắng',
                ),
                if (st == null) ...[
                  _Big(
                    colors: Candy.orange,
                    icon: Icons.local_fire_department_rounded,
                    value: '${store.currentStreak(today)}',
                    label: 'Chuỗi ngày',
                  ),
                  _Big(
                    colors: Candy.purple,
                    icon: Icons.emoji_events_rounded,
                    value: '${store.bestStreak()}',
                    label: 'Chuỗi dài nhất',
                  ),
                ] else ...[
                  _Big(
                    colors: Candy.orange,
                    icon: Icons.local_fire_department_rounded,
                    value: '${st.streak}',
                    label: 'Thắng liên tiếp',
                  ),
                  _Big(
                    colors: Candy.purple,
                    icon: Icons.emoji_events_rounded,
                    value: '${st.bestStreak}',
                    label: 'Chuỗi thắng dài nhất',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 28),
            _SectionLabel(
              one == null ? 'Theo trò chơi' : 'Chi tiết',
              Icons.sports_esports_rounded,
            ),
            const SizedBox(height: 16),
            for (final g in games) _GameRow(game: g, stats: store.stats(g.id)),
          ],
        );
      },
    );
  }
}

const _ink = Color(0xFF1B3FA6);
const _inkSoft = Color(0xFF5B77B8);
const _shadow = [Shadow(color: Color(0x88000000), blurRadius: 3)];

/// Nhãn nhóm: vòng tròn màu chứa biểu tượng + chữ xanh đậm.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      SkySection(text, icon, color: const Color(0xFF2E7BE0));
}

class _Big extends StatelessWidget {
  const _Big({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Candy.gold, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: Candy.deep(colors), offset: const Offset(0, 4)),
          const BoxShadow(
            color: Color(0x44000000),
            offset: Offset(0, 8),
            blurRadius: 6,
          ),
        ],
      ),
      child: Stack(
        children: [
          const CandyGloss(radius: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                IconTile(
                  icon: icon,
                  size: 52,
                  background: Colors.white24,
                  foreground: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        child: Text(
                          value,
                          style: t.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            shadows: _shadow,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: Colors.white,
                          shadows: _shadow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.stats});

  final GameInfo game;
  final GameStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = Candy.forId(game.id);
    final rate = stats.played == 0
        ? 0.0
        : (stats.won / stats.played).clamp(0.0, 1.0);
    final best = game.bestLabel(stats.best);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SkyCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Candy.gold, width: 2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Candy.deep(colors),
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const CandyGloss(),
                  Icon(game.icon, color: Colors.white, size: 30),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          game.title,
                          style: t.titleMedium?.copyWith(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        '${stats.won}/${stats.played} · ${(rate * 100).round()}%',
                        style: t.labelMedium?.copyWith(
                          color: _ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: rate),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 12,
                        color: colors.last,
                        backgroundColor: Candy.creamDeep,
                        semanticsLabel: 'Tỉ lệ thắng ${game.title}',
                      ),
                    ),
                  ),
                  if (best != null) ...[
                    const SizedBox(height: 4),
                    Text(best, style: t.bodySmall?.copyWith(color: _inkSoft)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
