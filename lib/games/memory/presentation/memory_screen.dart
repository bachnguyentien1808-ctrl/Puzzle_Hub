import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/game_action_button.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/common/confirm_new_game.dart';
import 'package:puzzle_hub/features/common/game_block.dart';
import 'package:puzzle_hub/features/common/game_overlays.dart';
import 'package:puzzle_hub/features/common/hub_panels.dart';
import 'package:puzzle_hub/features/howto/tutorial_gate.dart';
import 'package:puzzle_hub/games/memory/domain/memory_engine.dart';
import 'package:puzzle_hub/games/memory/presentation/memory_card_view.dart';

const _id = 'memory';

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key, this.daily});

  /// Khoa ngay yyyyMMdd khi la thu thach ngay (luon 4x4, bo bieu tuong).
  final String? daily;

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen>
    with SingleTickerProviderStateMixin {
  late final GameStore _store = GameStore(
    ref.read(progressStoreProvider),
    daily: widget.daily,
  );
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late MemoryGame _game;
  Timer? _hideTimer;
  Timer? _peekTimer;
  Timer? _resultTimer;
  Timer? _clock;
  int _gen = 0;
  bool _paused = false;
  bool _peeking = false;
  bool _showResult = false;

  /// Đang hiện trang "Chọn kiểu chơi" (thay cho bàn chơi, không đè lên nhau).
  bool _showSetup = false;

  /// Trang chọn mở ngay khi vào game: bấm × thì về trang chủ.
  bool _initialSetup = false;
  bool _lost = false;
  bool _newRecord = false;
  int? _points;
  final Set<int> _bad = {};

  bool get _isDaily => widget.daily != null;

  @override
  void initState() {
    super.initState();
    MemoryGame? restored;
    final saved = _store.loadState(_id);
    if (saved != null) {
      try {
        restored = MemoryGame.fromJson(saved);
      } on Object {
        restored = null;
      }
    }
    if (restored != null && !restored.won) {
      _game = restored;
      _intro.forward();
    } else {
      _game = _create(MemorySize.s4x4, MemorySet.icons);
      _intro.forward();
      if (!_isDaily) {
        _showSetup = true;
        _initialSetup = true;
      }
    }
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused || _peeking || _over || !_game.started) {
        return;
      }
      setState(() => _game.seconds++);
      if (_game.seconds >= _limit) {
        _timeUp();
        return;
      }
      if (_game.seconds % 5 == 0) _save();
    });
  }

  bool get _over => _game.won || _lost;
  int get _limit => Scoring.timeLimit(_game.size.pairs * 10);

  void _timeUp() {
    _lost = true;
    _cancelTimers();
    _store.clearState(_id);
    GameFx.error();
    Sfx.play(SfxKind.lose);
  }

  MemoryGame _create(MemorySize size, MemorySet set) =>
      MemoryGame(size: size, set: set, rng: _store.rngFor(_id));

  void _save() {
    if (_game.won) return;
    _store.saveState(_id, _game.toJson());
  }

  void _cancelTimers() {
    _hideTimer?.cancel();
    _peekTimer?.cancel();
    _resultTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    _clock?.cancel();
    _intro.dispose();
    super.dispose();
  }

  void _startNew(MemorySize size, MemorySet set) {
    Sfx.play(SfxKind.newGame);
    _cancelTimers();
    setState(() {
      _game = _create(size, set);
      _gen++;
      _paused = false;
      _peeking = false;
      _showResult = false;
      _lost = false;
      _newRecord = false;
      _points = null;
      _bad.clear();
    });
    _intro.forward(from: 0);
    _save();
  }

  /// Hiện trang "Chọn kiểu chơi" riêng (như Sudoku) thay cho bàn chơi.
  void _openSetup() => setState(() => _showSetup = true);

  void _setupStart(MemorySize size, MemorySet set) {
    _initialSetup = false;
    TutorialGate.fire(_id);
    setState(() => _showSetup = false);
    _startNew(size, set);
  }

  void _setupClose() {
    // Vừa vào game mà đóng thì về trang chủ; từ ván đang chơi thì quay lại ván.
    if (_initialSetup) {
      context.go(_store.homeRoute);
    } else {
      setState(() => _showSetup = false);
    }
  }

  Future<void> _restart() async {
    if (!_over && !await confirmNewGame(context)) return;
    if (!mounted) return;
    if (_isDaily) {
      _startNew(MemorySize.s4x4, MemorySet.icons);
    } else {
      _openSetup();
    }
  }

  bool get _locked => _paused || _peeking || _over;

  void _onTap(int i) {
    if (_locked || _game.waiting) return;
    final first = !_game.started;
    final r = _game.flip(i);
    if (r == FlipResult.ignored) return;
    if (first) _store.recordStart(_game.size.statsId);
    GameFx.tap();
    Sfx.play(SfxKind.flip);
    setState(() {});
    switch (r) {
      case FlipResult.match:
        GameFx.success();
        Sfx.play(SfxKind.match);
      case FlipResult.mismatch:
        GameFx.error();
        Sfx.play(SfxKind.error);
        final open = [
          for (var k = 0; k < _game.cards.length; k++)
            if (_game.cards[k].faceUp) k,
        ];
        setState(() => _bad.addAll(open));
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(milliseconds: 950), () {
          if (!mounted) return;
          setState(() {
            _game.hideMismatch();
            _bad.clear();
          });
          _save();
        });
      case FlipResult.first || FlipResult.ignored:
        break;
    }
    if (_game.won) {
      _onWin();
    } else {
      _save();
    }
  }

  void _onWin() {
    final g = _game;
    if (_points == null) {
      final pairs = g.size.pairs;
      final pts = Scoring.points(
        base: 800,
        seconds: g.seconds,
        parSeconds: pairs * 10,
        mult: max(0.5, pairs / 8),
        mistakes: max(0, g.moves - pairs) ~/ 2,
        hints: g.peeksUsed,
      );
      _points = pts;
      _store.awardPoints(_id, pts);
    }
    final prev = _store.stats(g.size.statsId).best;
    _newRecord = !_isDaily && (prev == null || g.moves < prev);
    if (_isDaily) {
      _store.recordWin(_id, score: g.moves);
    } else {
      _store.recordWin(g.size.statsId, score: g.moves, lowerIsBetter: true);
      if (g.size == MemorySize.s4x4) {
        _store.recordScore(_id, g.moves, lowerIsBetter: true);
      }
    }
    _store.clearState(_id);
    _resultTimer?.cancel();
    _resultTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      GameFx.success();
      Sfx.play(SfxKind.win);
      setState(() => _showResult = true);
    });
  }

  void _peek() {
    if (_locked || _game.waiting || !_game.usePeek()) return;
    Sfx.play(SfxKind.hint);
    setState(() => _peeking = true);
    _save();
    _peekTimer?.cancel();
    _peekTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _peeking = false);
    });
  }

  void _togglePause() {
    if (_over) return;
    setState(() => _paused = !_paused);
    Sfx.play(_paused ? SfxKind.pause : SfxKind.resume);
    if (_paused) _save();
  }

  static String _fmt(int sec) =>
      '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_showSetup) {
      return _SetupSheet(
        size: _game.size,
        set: _game.set,
        onStart: _setupStart,
        onClose: _setupClose,
      );
    }
    final s = Theme.of(context).colorScheme;
    final best = _store.stats(_game.size.statsId).best;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: const [SoundAction(), ScoreChip(), HubMenuAction()],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: modestColumnWidth(context, 780),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                // Khoi rong hon, thap hon (khong keo cao het man hinh).
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 860),
                  child: GameBlock(
                    expand: true,
                    title: _isDaily ? 'Tìm cặp - Thử thách ngày' : 'Tìm cặp',
                    onBack: () => context.go(_store.homeRoute),
                    child: Column(
                      children: [
                        _statsRow(s, best),
                        const SizedBox(height: 10),
                        CandyRibbon(
                          text:
                              '${_game.size.label} · ${_game.size.pairs} cặp'
                              '${best == null ? '' : ' · Kỷ lục: $best lượt'}',
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _board(s)),
                        const SizedBox(height: 12),
                        GlassPanel(
                          padding: const EdgeInsets.all(10),
                          child: _actions(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          WinBanner(
            show: _showResult || _lost,
            lose: _lost,
            loseIcon: Icons.timer_off_rounded,
            title: _lost ? 'Hết giờ!' : 'Hoàn thành!',
            subtitle: _lost ? 'Thử lại nhé!' : null,
            points: _lost ? null : _points,
            stars: _game.stars,
            starKeyPrefix: 'memory-star',
            chips: [
              WinChip(Icons.touch_app_outlined, '${_game.moves} lượt'),
              WinChip(Icons.timer_outlined, _fmt(_game.seconds)),
            ],
            ribbon: _newRecord && !_lost
                ? 'Kỷ lục mới! ${_game.moves} lượt'
                : null,
            againLabel: _isDaily ? 'Chơi lại' : 'Ván mới',
            againKey: const ValueKey('memory-again'),
            onAgain: _restart,
            onExit: () => context.go(_store.homeRoute),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(ColorScheme s, int? best) {
    return GlassBar(
      children: [
        _Stat(
          Icons.timer_outlined,
          _fmt(max(0, _limit - _game.seconds)),
          'Còn lại',
          Candy.blue,
        ),
        _Stat(Icons.touch_app_outlined, '${_game.moves}', 'Lượt', Candy.green),
        _Stat(
          Icons.local_fire_department,
          'x${_game.combo}',
          'Chuỗi',
          _game.combo >= 2 ? Candy.orange : Candy.purple,
        ),
      ],
    );
  }

  Widget _board(ColorScheme s) {
    final size = _game.size;
    return LayoutBuilder(
      builder: (context, box) {
        final gap = size.cols >= 6 ? 6.0 : 8.0;
        final cell = [
          (box.maxWidth - 30 - gap * (size.cols - 1)) / size.cols,
          (box.maxHeight - 34 - gap * (size.rows - 1)) / size.rows,
        ].reduce((a, b) => a < b ? a : b).clamp(20.0, 140.0);
        final w = cell * size.cols + gap * (size.cols - 1);
        final h = cell * size.rows + gap * (size.rows - 1);
        return Center(
          child: CandyFrame(
            padding: 6,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  GridView.count(
                    crossAxisCount: size.cols,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < _game.cards.length; i++)
                        MemoryCardView(
                          key: ValueKey('memory-card-$_gen-$i'),
                          set: _game.set,
                          symbol: _game.cards[i].symbol,
                          visible:
                              !_paused &&
                              (_game.cards[i].faceUp ||
                                  _game.cards[i].matched ||
                                  _peeking),
                          matched: _game.cards[i].matched,
                          mismatch: _bad.contains(i),
                          intro: _intro,
                          index: i,
                          total: _game.cards.length,
                          onTap: () => _onTap(i),
                        ),
                    ],
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: GlassStyle.of(context).inner,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pause_circle,
                                size: 56,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Đã tạm dừng',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              CandyButton(
                                key: const ValueKey('memory-resume'),
                                colors: Candy.green,
                                onPressed: _togglePause,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_arrow),
                                    SizedBox(width: 6),
                                    Text('Tiếp tục'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actions() {
    final canPeek = !_locked && !_game.waiting && _game.peeksLeft > 0;
    final canPause = !_over;
    Widget round(
      Key key,
      String tip,
      IconData icon,
      List<Color> colors,
      VoidCallback? onTap,
    ) {
      return GameActionButton(
        buttonKey: key,
        tooltip: tip,
        icon: icon,
        colors: colors,
        onPressed: onTap,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Badge.count(
          count: _game.peeksLeft,
          isLabelVisible: _game.peeksLeft > 0,
          child: round(
            const ValueKey('memory-peek'),
            'Nhìn trước (còn ${_game.peeksLeft})',
            Icons.visibility_outlined,
            Candy.purple,
            canPeek ? _peek : null,
          ),
        ),
        round(
          const ValueKey('memory-pause'),
          _paused ? 'Tiếp tục' : 'Tạm dừng',
          _paused ? Icons.play_arrow : Icons.pause,
          Candy.orange,
          canPause ? _togglePause : null,
        ),
        round(
          const ValueKey('memory-new'),
          _isDaily ? 'Chơi lại cùng đề' : 'Ván mới',
          Icons.refresh_rounded,
          Candy.green,
          _restart,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label, this.colors);

  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: GlassStat(icon: icon, text: value, colors: colors),
    );
  }
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({
    required this.size,
    required this.set,
    required this.onStart,
    required this.onClose,
  });

  final MemorySize size;
  final MemorySet set;
  final void Function(MemorySize size, MemorySet set) onStart;
  final VoidCallback onClose;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  late MemorySize _size = widget.size;
  late MemorySet _set = widget.set;

  static const _ink = Candy.brown;

  @override
  Widget build(BuildContext context) {
    // Một trang riêng như Sudoku: khối kính giữa nền game, nút × ở góc. Nền
    // game do GameIntro bọc sẵn bên ngoài.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: PickerScroll(
          padding: PickerFrame.outer(context),
          child: ConstrainedBox(
            constraints: PickerFrame.box(context, 580),
            child: _card(context),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    return GlassPanel(
      radius: PickerFrame.radius(context),
      padding: PickerFrame.inner(
        context,
        const EdgeInsets.fromLTRB(26, 28, 26, 24),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: CandyButton(
                  onPressed: null,
                  colors: Candy.orange,
                  circle: true,
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.style_rounded, size: 52),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: CandyRibbon(
                  text: 'Chọn kiểu chơi',
                  colors: Candy.orange,
                ),
              ),
              const SizedBox(height: 18),
              const _SetupLabel('Kích thước', Icons.grid_view_rounded),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.3,
                children: [for (final z in MemorySize.values) _sizeTile(z)],
              ),
              const SizedBox(height: 14),
              const _SetupLabel('Bộ hình', Icons.category_rounded),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (i, z) in MemorySet.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _setTile(z)),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              CandyButton(
                key: const ValueKey('memory-start'),
                colors: Candy.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                onPressed: () => widget.onStart(_size, _set),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 28),
                    SizedBox(width: 6),
                    Text('Bắt đầu', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GlassCloseButton(
              key: const ValueKey('memory-setup-close'),
              onTap: widget.onClose,
            ),
          ),
        ],
      ),
    );
  }

  /// Ô chọn: viền vàng + dấu tích khi được chọn.
  Widget _choice({
    required Key key,
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Sfx.play(SfxKind.option);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Candy.orange,
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: .55),
          border: Border.all(
            color: selected ? Colors.white : Candy.gold,
            width: selected ? 3 : 2,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x55000000),
                    offset: Offset(0, 3),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: child),
            if (selected)
              Positioned(
                top: -12,
                right: -8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2E7D32),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sizeTile(MemorySize z) {
    final on = z == _size;
    final fg = on ? Colors.white : _ink;
    return _choice(
      key: ValueKey('memory-size-${z.label}'),
      selected: on,
      onTap: () => setState(() => _size = z),
      child: Row(
        children: [
          _miniGrid(z, on),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  z.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                Text(
                  '${z.pairs} cặp',
                  style: TextStyle(
                    color: fg.withValues(alpha: .85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hình lưới thu nhỏ đúng số cột x hàng của bàn.
  Widget _miniGrid(MemorySize z, bool on) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: on ? Colors.black26 : Candy.creamDeep,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            for (var r = 0; r < z.rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < z.cols; c++)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(0.8),
                          decoration: BoxDecoration(
                            color: on ? Colors.white : Candy.gold,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
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

  Widget _setTile(MemorySet z) {
    final on = z == _set;
    final fg = on ? Colors.white : _ink;
    final sample = switch (z) {
      MemorySet.icons => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 18),
          SizedBox(width: 3),
          Icon(Icons.star, size: 18),
          SizedBox(width: 3),
          Icon(Icons.pets, size: 18),
        ],
      ),
      MemorySet.shapes => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 18),
          SizedBox(width: 3),
          Icon(Icons.square, size: 18),
          SizedBox(width: 3),
          Icon(Icons.change_history, size: 18),
        ],
      ),
      MemorySet.letters => const Text(
        'A B C',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    };
    return SizedBox(
      height: 76,
      child: _choice(
        key: ValueKey('memory-set-${z.name}'),
        selected: on,
        onTap: () => setState(() => _set = z),
        child: IconTheme(
          data: IconThemeData(color: fg),
          child: DefaultTextStyle(
            style: TextStyle(color: fg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                sample,
                const SizedBox(height: 6),
                Text(
                  z.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupLabel extends StatelessWidget {
  const _SetupLabel(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Candy.gold),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Color(0x99000000), blurRadius: 3)],
          ),
        ),
      ],
    );
  }
}
