import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/game_logo.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/features/daily/daily_screen.dart';
import 'package:puzzle_hub/games/game_registry.dart';

const _ink = Candy.brown;
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
  const _Badge(this.icon, this.title, this.desc, this.value, this.target);

  final IconData icon;
  final String title;
  final String desc;
  final int value;
  final int target;

  bool get unlocked => value >= target;
}

/// Trang Thành tích: tổng điểm, cấp bậc, huy hiệu và điểm theo từng game.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(progressStoreProvider);
    final today = ref.read(todayProvider)();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: store.version,
          builder: (context, _, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GlassPanel(
                  radius: 30,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: Candy.gold,
                            size: 30,
                            shadows: _shadow,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Thành tích',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              shadows: _shadow,
                            ),
                          ),
                          const Spacer(),
                          GlassCloseButton(
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          child: _Body(store: store, today: today),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
      _Badge(Icons.flag_rounded, 'Khởi đầu', 'Thắng ván đầu tiên', tot.won, 1),
      _Badge(Icons.shield_rounded, 'Chiến binh', 'Thắng 25 ván', tot.won, 25),
      _Badge(
        Icons.military_tech_rounded,
        'Bền bỉ',
        'Thắng 100 ván',
        tot.won,
        100,
      ),
      _Badge(
        Icons.apps_rounded,
        'Đa tài',
        'Chơi thử cả ${ids.length} trò',
        gamesTried,
        ids.length,
      ),
      _Badge(Icons.star_rounded, 'Nghìn điểm', 'Đạt 1.000 điểm', points, 1000),
      _Badge(
        Icons.stars_rounded,
        'Ngôi sao lớn',
        'Đạt 5.000 điểm',
        points,
        5000,
      ),
      _Badge(
        Icons.local_fire_department_rounded,
        'Giữ lửa',
        'Chuỗi thử thách 3 ngày',
        bestDaily,
        3,
      ),
      _Badge(
        Icons.calendar_month_rounded,
        'Tuần lễ vàng',
        'Chuỗi thử thách 7 ngày',
        bestDaily,
        7,
      ),
      _Badge(
        Icons.bolt_rounded,
        'Thắng liên tiếp',
        'Thắng 5 ván liền một trò',
        bestWinStreak,
        5,
      ),
      _Badge(
        Icons.task_alt_rounded,
        'Chăm chỉ',
        'Xong 10 thử thách ngày',
        store.dailyDone().length,
        10,
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
        const SizedBox(height: 20),
        _Label('Huy hiệu · $unlocked/${badges.length}'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 600 ? 3 : 2;
            const gap = 10.0;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final b in badges)
                  SizedBox(width: w, child: _BadgeTile(b)),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const _Label('Điểm theo trò chơi'),
        const SizedBox(height: 10),
        for (final g in gameRegistry)
          _GameRow(game: g, store: store, total: points),
      ],
    );
  }
}

/// Thẻ lớn: tổng điểm, cấp bậc và thanh tiến độ lên cấp kế.
class _Hero extends StatelessWidget {
  const _Hero({required this.points});

  final int points;

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
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: Candy.orange,
        ),
        border: Border.all(color: Candy.gold, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .25),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng điểm',
                      style: TextStyle(
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
                          fontSize: 40,
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
                  color: Colors.black26,
                ),
                child: Text(
                  cur.$1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.black26,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
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
                child: _Cream(
                  child: Row(
                    children: [
                      Icon(icon, color: Candy.gold, size: 28),
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

class _BadgeTile extends StatelessWidget {
  const _BadgeTile(this.b);

  final _Badge b;

  @override
  Widget build(BuildContext context) {
    final on = b.unlocked;
    return Opacity(
      opacity: on ? 1 : .78,
      child: _Cream(
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: on
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: Candy.orange,
                      )
                    : null,
                color: on ? null : const Color(0xFFD9CBB3),
                border: Border.all(
                  color: on ? Colors.white : const Color(0xFFBFAF93),
                  width: 3,
                ),
              ),
              child: Icon(
                on ? b.icon : Icons.lock_rounded,
                color: on ? Colors.white : const Color(0xFF8A7B63),
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              b.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            Text(
              b.desc,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _inkSoft,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (on)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF3FA535))
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (b.value / b.target).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE6D7BC),
                      valueColor: const AlwaysStoppedAnimation(Candy.gold),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${b.value}/${b.target}',
                    style: const TextStyle(
                      color: _inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
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
      child: _Cream(
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
                      backgroundColor: const Color(0xFFE6D7BC),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        shadows: _shadow,
      ),
    );
  }
}

/// Thẻ kem bo tròn dùng chung cho các ô trong trang.
class _Cream extends StatelessWidget {
  const _Cream({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF6E3), Candy.cream],
        ),
        border: Border.all(color: Candy.gold, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }
}
