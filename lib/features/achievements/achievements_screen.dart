import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/game_logo.dart';
import 'package:puzzle_hub/features/common/sky_page.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';

const _ink = Color(0xFF7A4A21);
const _inkSoft = Color(0xFF9A6B3C);
const _shadow = [Shadow(color: Color(0x88000000), blurRadius: 3)];

/// Cấp bậc theo tổng điểm: (tên, điểm cần đạt).
const _ranks = <(String, int)>[
  ('Tân binh', 0),
  ('Học việc', 500),
  ('Thành thạo', 2000),
  ('Cao thủ', 5000),
  ('Bậc thầy', 10000),
  ('Huyền thoại', 25000),
];

/// Một huy hiệu: mở khoá khi [value] đạt [target].
class _Badge {
  const _Badge(
    this.icon,
    this.title,
    this.desc,
    this.value,
    this.target,
    this.tier,
  );

  final IconData icon;
  final String title;
  final String desc;
  final int value;
  final int target;
  final SkyTier tier;

  bool get unlocked => value >= target;
}

/// Trang Thành tích: tổng điểm, cấp bậc, huy hiệu và điểm theo từng game.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({this.gameId, super.key});

  /// Có giá trị: bảng điểm riêng của game này (mở từ ô điểm trong game).
  final String? gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(progressStoreProvider);
    final today = ref.read(todayProvider)();
    final one = gameId == null ? null : gameById(gameId!);
    return ValueListenableBuilder<int>(
      valueListenable: store.version,
      builder: (context, _, _) => SkyPage(
        warm: true,
        title: 'Thành tích',
        icon: one?.icon ?? Icons.emoji_events_rounded,
        subtitle: one == null
            ? 'Tổng điểm, cấp bậc và huy hiệu của bạn'
            : 'Bảng điểm riêng của ${one.title}',
        children: [
          one == null
              ? _Body(store: store, today: today)
              : _GameBody(game: one, store: store),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.store, required this.today});

  final ProgressStore store;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final ids = [for (final g in gameRegistry) g.id];
    final tot = store.totals(ids);
    final points = store.totalPoints;
    final rate = tot.played == 0 ? 0 : (tot.won * 100 / tot.played).round();
    final streak = store.currentStreak(today);
    final bestDaily = store.bestStreak();
    var gamesTried = 0;
    var bestWinStreak = 0;
    for (final id in ids) {
      final s = store.stats(id);
      if (s.played > 0) gamesTried++;
      if (s.bestStreak > bestWinStreak) bestWinStreak = s.bestStreak;
    }
    final badges = <_Badge>[
      _Badge(
        Icons.flag_rounded,
        'Khởi đầu',
        'Thắng ván đầu tiên',
        tot.won,
        1,
        SkyTier.bronze,
      ),
      _Badge(
        Icons.shield_rounded,
        'Chiến binh',
        'Thắng 25 ván',
        tot.won,
        25,
        SkyTier.silver,
      ),
      _Badge(
        Icons.military_tech_rounded,
        'Bền bỉ',
        'Thắng 100 ván',
        tot.won,
        100,
        SkyTier.gold,
      ),
      _Badge(
        Icons.apps_rounded,
        'Đa tài',
        'Chơi thử cả ${ids.length} trò',
        gamesTried,
        ids.length,
        SkyTier.silver,
      ),
      _Badge(
        Icons.star_rounded,
        'Nghìn điểm',
        'Đạt 1.000 điểm',
        points,
        1000,
        SkyTier.bronze,
      ),
      _Badge(
        Icons.stars_rounded,
        'Ngôi sao lớn',
        'Đạt 5.000 điểm',
        points,
        5000,
        SkyTier.gold,
      ),
      _Badge(
        Icons.local_fire_department_rounded,
        'Giữ lửa',
        'Chuỗi thử thách 3 ngày',
        bestDaily,
        3,
        SkyTier.bronze,
      ),
      _Badge(
        Icons.calendar_month_rounded,
        'Tuần lễ vàng',
        'Chuỗi thử thách 7 ngày',
        bestDaily,
        7,
        SkyTier.gold,
      ),
      _Badge(
        Icons.bolt_rounded,
        'Thắng liên tiếp',
        'Thắng 5 ván liền một trò',
        bestWinStreak,
        5,
        SkyTier.silver,
      ),
      _Badge(
        Icons.task_alt_rounded,
        'Chăm chỉ',
        'Xong 10 thử thách ngày',
        store.dailyDone().length,
        10,
        SkyTier.diamond,
      ),
    ];
    final unlocked = badges.where((b) => b.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(points: points),
        const SizedBox(height: 14),
        _StatGrid(
          items: [
            ('Ván đã chơi', '${tot.played}', Icons.sports_esports_rounded),
            ('Ván thắng', '${tot.won}', Icons.verified_rounded),
            ('Tỉ lệ thắng', '$rate%', Icons.percent_rounded),
            ('Chuỗi ngày', '$streak', Icons.local_fire_department_rounded),
          ],
        ),
        const SizedBox(height: 18),
        SkySection(
          'Huy hiệu · $unlocked/${badges.length}',
          Icons.workspace_premium_rounded,
          color: const Color(0xFFE59A12),
        ),
        SkyBadgeGrid(
          badges: [
            for (final b in badges)
              SkyBadgeTile(
                icon: b.icon,
                title: b.title,
                desc: b.desc,
                value: b.value,
                target: b.target,
                tier: b.tier,
              ),
          ],
        ),
        const SizedBox(height: 18),
        const SkySection(
          'Điểm theo trò chơi',
          Icons.videogame_asset_rounded,
          color: Color(0xFFD35400),
        ),
        for (final g in gameRegistry)
          _GameRow(game: g, store: store, total: points),
      ],
    );
  }
}

/// Bảng điểm riêng của một game: điểm, thống kê và huy hiệu của game đó.
class _GameBody extends StatelessWidget {
  const _GameBody({required this.game, required this.store});

  final GameInfo game;
  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final pts = store.gamePoints(game.id);
    final s = store.stats(game.id);
    final rate = s.played == 0 ? 0 : (s.won * 100 / s.played).round();
    final badges = <(_Badge,)>[
      (
        _Badge(
          Icons.flag_rounded,
          'Khởi đầu',
          'Thắng ván đầu tiên',
          s.won,
          1,
          SkyTier.bronze,
        ),
      ),
      (
        _Badge(
          Icons.shield_rounded,
          'Quen tay',
          'Thắng 10 ván',
          s.won,
          10,
          SkyTier.silver,
        ),
      ),
      (
        _Badge(
          Icons.military_tech_rounded,
          'Cao thủ',
          'Thắng 30 ván',
          s.won,
          30,
          SkyTier.gold,
        ),
      ),
      (
        _Badge(
          Icons.bolt_rounded,
          'Liền mạch',
          'Thắng 3 ván liên tiếp',
          s.bestStreak,
          3,
          SkyTier.bronze,
        ),
      ),
      (
        _Badge(
          Icons.local_fire_department_rounded,
          'Bất bại',
          'Thắng 7 ván liên tiếp',
          s.bestStreak,
          7,
          SkyTier.gold,
        ),
      ),
      (
        _Badge(
          Icons.star_rounded,
          'Khá điểm',
          'Đạt 500 điểm',
          pts,
          500,
          SkyTier.bronze,
        ),
      ),
      (
        _Badge(
          Icons.stars_rounded,
          'Nhiều điểm',
          'Đạt 2.000 điểm',
          pts,
          2000,
          SkyTier.silver,
        ),
      ),
      (
        _Badge(
          Icons.diamond_rounded,
          'Điểm vàng',
          'Đạt 5.000 điểm',
          pts,
          5000,
          SkyTier.diamond,
        ),
      ),
    ];
    final got = badges.where((b) => b.$1.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hero(points: pts, label: 'Điểm ${game.title}'),
        const SizedBox(height: 14),
        _StatGrid(
          items: [
            ('Ván đã chơi', '${s.played}', Icons.sports_esports_rounded),
            ('Ván thắng', '${s.won}', Icons.verified_rounded),
            ('Tỉ lệ thắng', '$rate%', Icons.percent_rounded),
            (
              'Thắng liền',
              '${s.bestStreak}',
              Icons.local_fire_department_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SkySection(
          'Huy hiệu · $got/${badges.length}',
          Icons.workspace_premium_rounded,
          color: const Color(0xFFE59A12),
        ),
        SkyBadgeGrid(
          badges: [
            for (final (b,) in badges)
              SkyBadgeTile(
                icon: b.icon,
                title: b.title,
                desc: b.desc,
                value: b.value,
                target: b.target,
                tier: b.tier,
              ),
          ],
        ),
        const SizedBox(height: 18),
        SkySection(
          'Chi tiết ${game.title}',
          Icons.videogame_asset_rounded,
          color: const Color(0xFFD35400),
        ),
        _GameRow(game: game, store: store, total: pts),
      ],
    );
  }
}

/// Thẻ lớn: tổng điểm, cấp bậc, các chặng cấp và thanh tiến độ lên cấp kế.
class _Hero extends StatelessWidget {
  const _Hero({required this.points, this.label = 'Tổng điểm'});

  final int points;
  final String label;

  @override
  Widget build(BuildContext context) {
    var idx = 0;
    for (var i = 0; i < _ranks.length; i++) {
      if (points >= _ranks[i].$2) idx = i;
    }
    final isMax = idx == _ranks.length - 1;
    final cur = _ranks[idx];
    final next = isMax ? null : _ranks[idx + 1];
    final progress = next == null
        ? 1.0
        : ((points - cur.$2) / (next.$2 - cur.$2)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFB347), Color(0xFFD35400)],
        ),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55D35400),
            offset: Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE680), Color(0xFFE59A12)],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 40,
                  shadows: _shadow,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        shadows: _shadow,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Scoring.format(points),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          shadows: _shadow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: Text(
                  cur.$1,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < _ranks.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 4,
                      color: i <= idx ? Colors.white : Colors.white30,
                    ),
                  ),
                Container(
                  width: i == idx ? 22 : 14,
                  height: i == idx ? 22 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= idx ? const Color(0xFFFFD84A) : Colors.white30,
                    border: Border.all(
                      color: Colors.white,
                      width: i == idx ? 3 : 2,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.black26,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD84A)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            next == null
                ? 'Bạn đã đạt cấp cao nhất!'
                : 'Còn ${Scoring.format(next.$2 - points)} điểm nữa để lên '
                      '${next.$1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              shadows: _shadow,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<(String, String, IconData)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 600 ? 4 : 2;
        const gap = 10.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (label, value, icon) in items)
              SizedBox(
                width: w,
                child: SkyCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(icon, color: const Color(0xFFE59A12), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value,
                              style: const TextStyle(
                                color: _ink,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _inkSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.store,
    required this.total,
  });

  final GameInfo game;
  final ProgressStore store;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pts = store.gamePoints(game.id);
    final s = store.stats(game.id);
    final share = total == 0 ? 0.0 : (pts / total).clamp(0.0, 1.0);
    final best = game.bestLabel(s.best);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SkyCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GameLogo(id: game.id, size: 46),
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
                          style: const TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${Scoring.format(pts)} điểm',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: share,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF2DFC0),
                      valueColor: AlwaysStoppedAnimation(
                        Candy.forId(game.id).last,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.played == 0
                        ? 'Chưa chơi'
                        : 'Chơi ${s.played} · Thắng ${s.won}'
                              '${best == null ? '' : ' · $best'}',
                    style: const TextStyle(
                      color: _inkSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
