import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/daily/daily_challenge.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/game_logo.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/features/common/card_close_button.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';
import 'package:puzzle_hub/games/game_registry.dart';

/// Dong ho cho man ngay; test ghi de de co ngay co dinh.
final todayProvider = Provider<DateTime Function()>((_) => DateTime.now);

GameInfo? gameById(String id) {
  for (final g in gameRegistry) {
    if (g.id == id) return g;
  }
  return null;
}

const _weekdayLong = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];
const _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

String dayLabel(DateTime d) =>
    '${_weekdayLong[d.weekday - 1]}, ${d.day}/${d.month}/${d.year}';

/// Trang thai thu thach cua mot ngay.
enum DailyStatus { notStarted, inProgress, done }

DailyStatus dailyStatus(ProgressStore store, String key, String gameId) {
  if (store.isDailyDone(key)) return DailyStatus.done;
  if (store.hasState('daily.$gameId.$key')) return DailyStatus.inProgress;
  return DailyStatus.notStarted;
}

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});

  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen>
    with SingleTickerProviderStateMixin {
  late final ProgressStore _store = ref.read(progressStoreProvider);
  late final DateTime _today = ref.read(todayProvider)();
  late final String _key = dateKey(_today);
  late DateTime _month = DateTime(_today.year, _today.month);
  late final AnimationController _flame = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _store.pruneDaily(keep: _key);
      if (!mounted) return;
      // Vua hoan thanh hom nay ma chua mung: chay ngon lua + phao giay.
      if (_store.isDailyDone(_key) && _store.lastCelebratedDaily != _key) {
        await _store.markDailyCelebrated(_key);
        if (!mounted) return;
        setState(() => _celebrate = true);
        Sfx.play(SfxKind.win);
        GameFx.success();
        if (!animationsOff(context)) _flame.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _flame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameId = dailyGameFor(_today);
    final game = gameById(gameId);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _store.version,
              builder: (context, _, _) {
                final done = _store.dailyDone();
                final status = dailyStatus(_store, _key, gameId);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      // Tất cả trong một khối kính, nút × đóng ở góc phải.
                      child: GlassPanel(
                        radius: 30,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text(
                                    'Thử thách mỗi ngày',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Color(0x88000000),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GlassCloseButton(
                                  onTap: () => context.canPop()
                                      ? context.pop()
                                      : context.go('/'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: ListView(
                                children: [
                                  _TodayCard(
                                    today: _today,
                                    game: game,
                                    gameId: gameId,
                                    status: status,
                                    score: done[_key],
                                  ),
                                  const SizedBox(height: 14),
                                  _StreakRow(
                                    current: _store.currentStreak(_today),
                                    best: _store.bestStreak(),
                                    flame: _flame,
                                  ),
                                  const SizedBox(height: 14),
                                  _WeekStrip(today: _today, done: done),
                                  const SizedBox(height: 14),
                                  _MonthCalendar(
                                    month: _month,
                                    today: _today,
                                    done: done,
                                    onMonth: (m) => setState(() => _month = m),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned.fill(child: Confetti(show: _celebrate)),
          ],
        ),
      ),
    );
  }
}

const _ink = Candy.brown;
const _inkSoft = Color(0xFF9A6B3C);
const _shadow = [Shadow(color: Color(0x88000000), blurRadius: 3)];

/// Tam kem hai lop (khung CandyFrame + long kem sang) de chu nau doc duoc
/// tren ca nen sang lan toi.
class _CreamPanel extends StatelessWidget {
  const _CreamPanel({required this.child, this.padding = 12});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return CandyFrame(
      padding: 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFFFF6E3),
        ),
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.today,
    required this.game,
    required this.gameId,
    required this.status,
    required this.score,
  });

  final DateTime today;
  final GameInfo? game;
  final String gameId;
  final DailyStatus status;
  final int? score;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final available = game?.dailyBuilder != null;
    final colors = Candy.forId(gameId);
    final (statusIcon, statusText) = switch (status) {
      DailyStatus.done => (
        Icons.check_circle_rounded,
        score == null ? 'Đã hoàn thành' : 'Đã hoàn thành · $score điểm',
      ),
      DailyStatus.inProgress => (Icons.timelapse_rounded, 'Đang chơi dở'),
      DailyStatus.notStarted => (Icons.radio_button_unchecked, 'Chưa chơi'),
    };
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Candy.gold, width: 3),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: Candy.deep(colors), offset: const Offset(0, 5)),
          const BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 10),
            blurRadius: 8,
          ),
        ],
      ),
      child: Stack(
        children: [
          const CandyGloss(radius: 22),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabel(today),
                  style: t.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: _shadow,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GameLogo(id: gameId, size: 80),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Câu đố hôm nay',
                            style: t.labelMedium?.copyWith(
                              color: Colors.white,
                              shadows: _shadow,
                            ),
                          ),
                          Text(
                            game?.title ?? gameId,
                            style: t.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              shadows: _shadow,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Row(
                              key: ValueKey(status),
                              children: [
                                Icon(statusIcon, size: 18, color: Colors.white),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    available ? statusText : 'Sắp có',
                                    style: t.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      shadows: _shadow,
                                    ),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: CandyButton(
                    colors: available ? Candy.green : Candy.blue,
                    dim: !available,
                    radius: 18,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: available
                        ? () {
                            GameFx.tap();
                            Sfx.play(SfxKind.tap);
                            context.go('/daily/play');
                          }
                        : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status == DailyStatus.done
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        const SizedBox(width: 6),
                        Text(switch ((available, status)) {
                          (false, _) => 'Sắp có',
                          (_, DailyStatus.done) => 'Xem lại',
                          (_, DailyStatus.inProgress) => 'Chơi tiếp',
                          _ => 'Chơi ngay',
                        }, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
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

class _StreakRow extends StatelessWidget {
  const _StreakRow({
    required this.current,
    required this.best,
    required this.flame,
  });

  final int current;
  final int best;
  final Animation<double> flame;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Chuỗi hiện tại',
            value: '$current ngày',
            colors: Candy.orange,
            icon: AnimatedBuilder(
              animation: flame,
              builder: (_, child) {
                final v = flame.value;
                // Bung to roi lang lai, chop sang khi vua hoan thanh.
                final scale =
                    1 + 0.6 * Curves.elasticOut.transform(v) * (1 - v);
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 32,
                color: current > 0 ? const Color(0xFFFFEB3B) : Colors.white54,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Dài nhất',
            value: '$best ngày',
            colors: Candy.purple,
            icon: Icon(
              Icons.emoji_events_rounded,
              size: 32,
              color: best > 0 ? const Color(0xFFFFEB3B) : Colors.white54,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String value;
  final Widget icon;
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
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: t.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            shadows: _shadow,
                          ),
                        ),
                      ),
                      Text(
                        label,
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

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today, required this.done});

  final DateTime today;
  final Map<String, int?> done;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final days = [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ];
    return _CreamPanel(
      padding: 10,
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Semantics(
                label:
                    '${dayLabel(d)}: ${done.containsKey(dateKey(d)) ? 'đã xong' : 'chưa xong'}',
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Text(
                        _weekdayShort[d.weekday - 1],
                        style: t.labelSmall?.copyWith(
                          color: _inkSoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _DayDot(
                        day: d.day,
                        done: done.containsKey(dateKey(d)),
                        today: dateKey(d) == dateKey(today),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.done, required this.today});

  final int day;
  final bool done;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: Candy.green,
              )
            : null,
        color: done
            ? null
            : today
            ? Candy.creamDeep
            : Colors.transparent,
        border: Border.all(
          color: today ? Candy.gold : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: done
            ? [
                BoxShadow(
                  color: Candy.deep(Candy.green),
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
          : Text(
              '$day',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _ink,
                fontWeight: today ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.month,
    required this.today,
    required this.done,
    required this.onMonth,
  });

  final DateTime month;
  final DateTime today;
  final Map<String, int?> done;
  final ValueChanged<DateTime> onMonth;

  /// Vuốt ngang để đổi tháng.
  void _swipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 200) return;
    onMonth(DateTime(month.year, month.month + (v < 0 ? 1 : -1)));
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _MonthPickerDialog(month: month, today: today),
    );
    if (picked != null) onMonth(picked);
  }

  Widget _nav(String tip, IconData icon, VoidCallback? onTap) {
    return IconButton(
      tooltip: tip,
      color: _ink,
      disabledColor: _ink.withValues(alpha: 0.3),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 36, height: 40),
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final first = DateTime(month.year, month.month);
    final daysIn = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;
    final count = done.keys.where((k) {
      final d = parseDateKey(k);
      return d.year == month.year && d.month == month.month;
    }).length;
    final isCurrent = month.year == today.year && month.month == today.month;
    return _CreamPanel(
      padding: 6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: _swipe,
        child: Column(
          children: [
            Row(
              children: [
                _nav(
                  'Năm trước',
                  Icons.keyboard_double_arrow_left,
                  () => onMonth(DateTime(month.year - 1, month.month)),
                ),
                _nav(
                  'Tháng trước',
                  Icons.chevron_left,
                  () => onMonth(DateTime(month.year, month.month - 1)),
                ),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('daily-month-title'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pick(context),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Tháng ${month.month}/${month.year}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleMedium?.copyWith(
                                  color: _ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: _ink,
                            ),
                          ],
                        ),
                        Text(
                          'Hoàn thành $count/$daysIn ngày',
                          style: t.bodySmall?.copyWith(color: _inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
                _nav(
                  'Tháng sau',
                  Icons.chevron_right,
                  () => onMonth(DateTime(month.year, month.month + 1)),
                ),
                _nav(
                  'Năm sau',
                  Icons.keyboard_double_arrow_right,
                  () => onMonth(DateTime(month.year + 1, month.month)),
                ),
              ],
            ),
            if (!isCurrent)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: TextButton.icon(
                  key: const ValueKey('daily-today'),
                  onPressed: () => onMonth(DateTime(today.year, today.month)),
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: const Text('Về hôm nay'),
                  style: TextButton.styleFrom(
                    foregroundColor: _ink,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final w in _weekdayShort)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: t.labelSmall?.copyWith(
                          color: _inkSoft,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.15,
              children: [
                for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                for (var day = 1; day <= daysIn; day++)
                  Center(
                    child: _DayDot(
                      day: day,
                      done: done.containsKey(
                        dateKey(DateTime(month.year, month.month, day)),
                      ),
                      today: isCurrent && day == today.day,
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

/// Hộp chọn nhanh tháng/năm: mũi tên đổi năm, lưới 12 tháng.
class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.month, required this.today});

  final DateTime month;
  final DateTime today;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.month.year;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 46, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF6E3), Candy.cream],
                  ),
                  border: Border.all(color: Candy.bgTop, width: 4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Năm trước',
                          color: _ink,
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setState(() => _year--),
                        ),
                        Expanded(
                          child: Text(
                            '$_year',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Năm sau',
                          color: _ink,
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () => setState(() => _year++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                      children: [for (var m = 1; m <= 12; m++) _monthButton(m)],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CardCloseButton(
                  key: const ValueKey('daily-month-close'),
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthButton(int m) {
    final selected = _year == widget.month.year && m == widget.month.month;
    final isNow = _year == widget.today.year && m == widget.today.month;
    return GestureDetector(
      key: ValueKey('daily-month-$m'),
      onTap: () => Navigator.pop(context, DateTime(_year, m)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Candy.orange,
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: .6),
          border: Border.all(
            color: isNow ? _ink : Candy.gold,
            width: isNow ? 3 : 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'T$m',
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// /daily/play: dung man game cua ngay o che do thu thach.
class DailyPlayScreen extends ConsumerWidget {
  const DailyPlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.read(todayProvider)();
    final game = gameById(dailyGameFor(today));
    final builder = game?.dailyBuilder;
    if (builder != null) return builder(dateKey(today));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/daily'),
        ),
        title: const Text('Thử thách mỗi ngày'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameLogo(id: game?.id ?? '', size: 96),
            const SizedBox(height: 16),
            Text('Sắp có', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${game?.title ?? 'Trò chơi này'} chưa hỗ trợ thử thách ngày.',
            ),
          ],
        ),
      ),
    );
  }
}
