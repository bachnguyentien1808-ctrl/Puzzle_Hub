import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/game_store.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/frost.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_engine.dart';
import 'package:puzzle_hub/games/sudoku/domain/sudoku_game.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_board.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_burst.dart';
import 'package:puzzle_hub/games/sudoku/presentation/sudoku_controls.dart';

const _id = 'sudoku';

/// Khoa cai dat rieng cua Sudoku (gioi han loi), khong theo che do ngay.
const _cfgKey = 'sudoku.cfg';

/// Do kho co dinh cua thu thach ngay.
const dailyLevel = SudokuLevel.medium;

class SudokuScreen extends ConsumerStatefulWidget {
  const SudokuScreen({super.key, this.daily});

  /// Khoa ngay yyyyMMdd neu la thu thach ngay.
  final String? daily;

  @override
  ConsumerState<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends ConsumerState<SudokuScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final GameStore _store;
  late final ProgressStore _ps;

  /// null = dang o man chon do kho (che do thuong).
  SudokuGame? _game;
  int _gen = 0;
  int? _sel;
  bool _notes = false;
  bool _paused = false;
  bool _appActive = true;
  bool _limitCfg = true;

  Timer? _timer;
  final ValueNotifier<int> _clock = ValueNotifier(0);

  String? _hintText;
  List<int> _hintUnit = const [];
  int? _hintCell;

  late final AnimationController _wave = AnimationController(vsync: this);
  Map<int, double> _waveDelay = const {};
  late final AnimationController _burst = AnimationController(vsync: this);
  Map<int, double> _burstDelay = const {};
  int _toastId = 0;
  List<String> _toastMessages = const [];
  final _shakeKey = GlobalKey<ShakeState>();
  final _focus = FocusNode(debugLabel: 'sudoku');

  bool _showWin = false;
  bool _showResult = false;
  bool _newRecord = false;
  int? _points;

  /// Diem thuong cua van nay (hang/cot/khoi xong) va cac don vi da thuong.
  int _bonusPoints = 0;
  final Set<String> _awardedUnits = {};
  int? _best;
  Timer? _resultTimer;

  bool get _daily => _store.isDaily;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ps = ref.read(progressStoreProvider);
    _store = GameStore(_ps, daily: widget.daily);
    _limitCfg = _ps.loadState(_cfgKey)?['ml'] as bool? ?? true;
    final saved = _store.loadState(_id);
    if (saved != null) {
      try {
        final g = SudokuGame.fromJson(saved);
        if (!g.isOver) _game = g;
      } on Object {
        // Trang thai hong -> bat dau lai.
      }
    }
    if (_game == null && _daily) _startNew(dailyLevel, notify: false);
    _clock.value = _game?.elapsed ?? 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _resultTimer?.cancel();
    _wave.dispose();
    _burst.dispose();
    _clock.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _appActive = s == AppLifecycleState.resumed;
    if (!_appActive && _game != null && !_game!.isOver) {
      _save();
      if (!_paused) setState(() => _paused = true);
    }
  }

  // ---------- Vong doi van ----------

  void _tick() {
    final g = _game;
    if (g == null || g.isOver || _paused || !_appActive) return;
    g.elapsed++;
    _clock.value = g.elapsed;
    if (g.elapsed % 5 == 0) _save();
  }

  void _save() {
    final g = _game;
    if (g == null || g.isOver) return;
    _store.saveState(_id, g.toJson());
  }

  void _startNew(SudokuLevel level, {bool notify = true}) {
    final seed = _daily ? _store.rngFor(_id)!.nextInt(1 << 31) : null;
    final gen = SudokuEngine.generateLevel(level, seed: seed);
    void apply() {
      _game = SudokuGame.fresh(gen, level, mistakeLimit: _limitCfg);
      _gen++;
      _resetUi();
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
    _clock.value = 0;
    _store
      ..recordStart(_id)
      ..recordStart(level.statsId);
    _save();
    Sfx.play(SfxKind.flip);
  }

  void _resetUi() {
    _sel = null;
    _notes = false;
    _paused = false;
    _hintText = null;
    _hintUnit = const [];
    _hintCell = null;
    _showWin = false;
    _showResult = false;
    _newRecord = false;
    _points = null;
    _bonusPoints = 0;
    _awardedUnits.clear();
    _waveDelay = const {};
    _resultTimer?.cancel();
    _wave.value = 0;
    _burst.value = 0;
    _burstDelay = const {};
    _toastMessages = const [];
  }

  void _restartSame() {
    final g = _game;
    if (g == null) return;
    setState(() {
      g
        ..restart()
        ..mistakeLimit = _limitCfg;
      _gen++;
      _resetUi();
    });
    _clock.value = 0;
    _save();
    Sfx.play(SfxKind.flip);
  }

  void _backToPicker() {
    if (_daily) {
      context.go(_store.homeRoute);
      return;
    }
    _store.clearState(_id);
    setState(() {
      _game = null;
      _gen++;
      _resetUi();
    });
  }

  // ---------- Thao tac ----------

  void _select(int i) {
    if (_paused || _game == null) return;
    setState(() {
      _sel = i;
      if (_hintCell != null && _hintCell != i) _clearHint();
    });
    Sfx.play(SfxKind.tap);
    _focus.requestFocus();
  }

  void _clearHint() {
    _hintText = null;
    _hintUnit = const [];
    _hintCell = null;
  }

  void _digit(int d) {
    final g = _game;
    final i = _sel;
    if (g == null || i == null || _paused || g.isOver) return;
    if (_lockedCell(i)) {
      _lockedFeedback();
      return;
    }
    // Cac don vi da day tu truoc (van restore/de bai) khong duoc thuong lai.
    _awardedUnits.addAll(fullUnitKeys(g.values));
    if (_notes) {
      if (g.toggleNote(i, d)) {
        setState(_clearHint);
        Sfx.play(SfxKind.tap);
        GameFx.tap();
        _save();
      }
      return;
    }
    final r = g.place(i, d);
    if (!r.changed) return;
    setState(_clearHint);
    _afterPlace(i, r);
  }

  void _afterPlace(int i, PlaceResult r) {
    final g = _game!;
    if (r.wrong) {
      Sfx.play(SfxKind.error);
      GameFx.error();
      _shakeKey.currentState?.shake();
      if (g.isLost) {
        _onLose();
        return;
      }
    } else {
      Sfx.play(SfxKind.place);
      GameFx.tap();
      if (g.isWon) {
        _awardBonus(detectCompletion(g.values, i).takeNew(_awardedUnits));
        _onWin(i);
        return;
      }
      final done = detectCompletion(g.values, i);
      if (r.completed.isNotEmpty || !done.isEmpty) {
        Sfx.play(SfxKind.success);
        GameFx.success();
        if (r.completed.isNotEmpty) _runUnitWave(i, r.completed);
        _announceCompletion(i, done);
      }
    }
    _save();
  }

  void _erase() {
    final g = _game;
    final i = _sel;
    if (g == null || i == null || _paused) return;
    if (_lockedCell(i)) {
      _lockedFeedback();
      return;
    }
    if (g.erase(i)) {
      setState(_clearHint);
      Sfx.play(SfxKind.erase);
      GameFx.tap();
      _save();
    }
  }

  void _undo() {
    final g = _game;
    if (g == null || _paused) return;
    final locked = lockedCells(g.values, g.isWrong);
    final i = g.undo();
    if (i == null) return;
    if (locked.contains(i)) {
      g.redo(); // o da khoa: giu nguyen, khong hoan tac
      _lockedFeedback();
      return;
    }
    setState(() {
      _sel = i;
      _clearHint();
    });
    Sfx.play(SfxKind.erase);
    _save();
  }

  void _redo() {
    final g = _game;
    if (g == null || _paused) return;
    final i = g.redo();
    if (i == null) return;
    setState(() {
      _sel = i;
      _clearHint();
    });
    Sfx.play(SfxKind.place);
    _save();
  }

  void _hint() {
    final g = _game;
    if (g == null || _paused || g.isOver) return;
    final h = g.useHint(_sel);
    if (h == null) return;
    setState(() {
      _sel = h.index;
      _hintText = h.explanation;
      _hintUnit = h.unit;
      _hintCell = h.index;
    });
    Sfx.play(SfxKind.match);
    _afterPlace(h.index, h.place);
  }

  void _togglePause() {
    final g = _game;
    if (g == null || g.isOver) return;
    setState(() => _paused = !_paused);
    Sfx.play(SfxKind.tap);
    if (_paused) _save();
  }

  void _setLimit(bool on) {
    _limitCfg = on;
    _ps.saveState(_cfgKey, {'ml': on});
    final g = _game;
    setState(() {
      // Khong bat lai giua van neu da cham 3 loi (se thua ngay).
      if (g != null && !(on && g.mistakes >= SudokuGame.maxMistakes)) {
        g.mistakeLimit = on;
      }
    });
    _save();
  }

  // ---------- Hieu ung ----------

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  void _runUnitWave(int origin, List<List<int>> units) {
    if (_reduce) return;
    final d = <int, double>{};
    for (final u in units) {
      for (final j in u) {
        final dist = max(
          (j ~/ 9 - origin ~/ 9).abs(),
          (j % 9 - origin % 9).abs(),
        );
        final v = dist / 8;
        d[j] = d.containsKey(j) ? min(d[j]!, v) : v;
      }
    }
    _playWave(d, const Duration(milliseconds: 750));
  }

  /// Bung sang + thong bao khi vua xong hang/cot/khoi hoac du 9 so.
  void _announceCompletion(int origin, SudokuCompletion done) {
    final fresh = done.takeNew(_awardedUnits);
    if (fresh.isEmpty) return;
    final pts = _awardBonus(fresh);
    if (_reduce) return;
    final cells = fresh.cells(_game!.values);
    setState(() {
      _burstDelay = burstDelays(cells, origin);
      _toastId++;
      _toastMessages = [
        ...fresh.messages,
        if (fresh.unitCount >= 2) 'Combo ×${fresh.combo == 2 ? '2' : '1,5'}!',
        if (pts > 0) '+${Scoring.format(pts)} điểm',
      ];
    });
    _burst
      ..duration = const Duration(milliseconds: 900)
      ..forward(from: 0);
  }

  /// Cong diem thuong cho cac don vi MOI xong (da qua takeNew).
  int _awardBonus(SudokuCompletion fresh) {
    final pts = fresh.points(_levelMult(_game!.level));
    if (pts > 0) {
      _bonusPoints += pts;
      _store.awardPoints(_id, pts);
    }
    return pts;
  }

  /// O thuoc hang/cot/khoi da xong dung thi bi khoa, khong sua duoc nua.
  bool _lockedCell(int i) {
    final g = _game;
    return g != null && lockedCells(g.values, g.isWrong).contains(i);
  }

  void _lockedFeedback() {
    Sfx.play(SfxKind.error);
    GameFx.error();
    _shakeKey.currentState?.shake();
    if (_reduce) return;
    setState(() {
      _toastId++;
      _toastMessages = const ['Ô đã khoá, không sửa được nữa'];
    });
  }

  void _runBoardWave(int origin) {
    if (_reduce) return;
    final d = <int, double>{
      for (var j = 0; j < 81; j++)
        j: ((j ~/ 9 - origin ~/ 9).abs() + (j % 9 - origin % 9).abs()) / 16,
    };
    _playWave(d, const Duration(milliseconds: 1300));
  }

  void _playWave(Map<int, double> d, Duration dur) {
    setState(() => _waveDelay = d);
    _wave
      ..duration = dur
      ..forward(from: 0);
  }

  void _onWin(int origin) {
    final g = _game!;
    final t = g.elapsed;
    if (!_daily) {
      final prev = _store.stats(g.level.statsId).best;
      _newRecord = prev == null || t < prev;
      _best = _newRecord ? t : prev;
      _store.recordWin(g.level.statsId, score: t, lowerIsBetter: true);
    }
    _store
      ..recordWin(_id, score: t, lowerIsBetter: true)
      ..clearState(_id);
    final pts = Scoring.points(
      base: 1000,
      seconds: t,
      parSeconds: _parSeconds(g.level),
      mult: _levelMult(g.level),
      mistakes: g.mistakes,
      hints: g.hintsUsed,
    );
    _points = pts + _bonusPoints;
    _store.awardPoints(_id, pts);
    Sfx.play(SfxKind.win);
    GameFx.success();
    setState(() {
      _sel = null;
      _showWin = true;
      _clearHint();
    });
    _runBoardWave(origin);
    _resultTimer = Timer(Duration(milliseconds: _reduce ? 0 : 1600), () {
      if (mounted) setState(() => _showResult = true);
    });
  }

  static double _levelMult(SudokuLevel l) => switch (l) {
    SudokuLevel.easy => 1.0,
    SudokuLevel.medium => 1.5,
    SudokuLevel.hard => 2.0,
    SudokuLevel.expert => 3.0,
  };

  static int _parSeconds(SudokuLevel l) => switch (l) {
    SudokuLevel.easy => 300,
    SudokuLevel.medium => 600,
    SudokuLevel.hard => 900,
    SudokuLevel.expert => 1500,
  };

  void _onLose() {
    _store.clearState(_id);
    setState(() {
      _showResult = true;
      _clearHint();
    });
  }

  void _continueWithoutLimit() {
    final g = _game;
    if (g == null) return;
    setState(() {
      g.mistakeLimit = false;
      _showResult = false;
    });
    _save();
  }

  // ---------- Ban phim may tinh ----------

  static final Map<LogicalKeyboardKey, int> _digitKeys = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  static final Map<LogicalKeyboardKey, (int, int)> _arrows = {
    LogicalKeyboardKey.arrowUp: (-1, 0),
    LogicalKeyboardKey.arrowDown: (1, 0),
    LogicalKeyboardKey.arrowLeft: (0, -1),
    LogicalKeyboardKey.arrowRight: (0, 1),
  };

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final g = _game;
    if (g == null) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final hw = HardwareKeyboard.instance;
    final ctrl = hw.isControlPressed || hw.isMetaPressed;
    if (ctrl && k == LogicalKeyboardKey.keyZ) {
      hw.isShiftPressed ? _redo() : _undo();
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyP) {
      _togglePause();
      return KeyEventResult.handled;
    }
    if (_paused) return KeyEventResult.ignored;
    final d = _digitKeys[k];
    if (d != null) {
      _digit(d);
      return KeyEventResult.handled;
    }
    final a = _arrows[k];
    if (a != null) {
      final cur = _sel ?? 40;
      final r = (cur ~/ 9 + a.$1 + 9) % 9;
      final c = (cur % 9 + a.$2 + 9) % 9;
      _select(r * 9 + c);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace ||
        k == LogicalKeyboardKey.delete ||
        k == LogicalKeyboardKey.digit0 ||
        k == LogicalKeyboardKey.numpad0) {
      _erase();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyN) {
      setState(() => _notes = !_notes);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyH) {
      _hint();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---------- Giao dien ----------

  Future<void> _openLevelSheet() async {
    final picked = await showModalBottomSheet<SudokuLevel>(
      context: context,
      backgroundColor: Candy.bgTop,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ván mới',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SudokuLevelPicker(
                stats: (l) => _store.stats(l.statsId),
                current: _game?.level,
                onPick: (l) => Navigator.pop(ctx, l),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) _startNew(picked);
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    final reduce = _reduce;
    // Man rong da co menu trai (Trang chu, Huong dan) va nut Moi: bo cac nut
    // trung lap tren AppBar.
    final wide = g != null && MediaQuery.sizeOf(context).width >= _wideMin;
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: wide
              ? null
              : BackButton(onPressed: () => context.go(_store.homeRoute)),
          title: wide
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 22),
                    SizedBox(width: 10),
                    Text('Sudoku'),
                  ],
                )
              : Text(_daily ? 'Sudoku · Thử thách ngày' : 'Sudoku'),
          actions: [
            const ScoreChip(),
            if (wide) _moonButton(),
            if (wide) _gearMenu(g),
            if (!wide) const HelpAction(gameId: 'sudoku'),
            if (g != null && !_daily && !wide)
              IconButton(
                tooltip: 'Ván mới',
                icon: const Icon(Icons.add_box_outlined),
                onPressed: _openLevelSheet,
              ),
            if (!wide)
              PopupMenuButton<String>(
                tooltip: 'Tuỳ chọn',
                onSelected: (v) {
                  if (v == 'limit') _setLimit(!_limitCfg);
                  if (v == 'restart') _restartSame();
                },
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(
                    value: 'limit',
                    checked: _limitCfg,
                    child: const Text('Giới hạn 3 lỗi'),
                  ),
                  if (g != null)
                    const PopupMenuItem(
                      value: 'restart',
                      child: ListTile(
                        leading: Icon(Icons.replay),
                        title: Text('Chơi lại đề này'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: SafeArea(
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: AnimatedSwitcher(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(
                key: ValueKey(_gen),
                child: g == null ? _pickerView() : _gameView(g),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickerView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: CandyButton(
                  onPressed: null,
                  colors: Candy.purple,
                  circle: true,
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.grid_on, size: 40),
                ),
              ),
              const SizedBox(height: 14),
              const Center(
                child: CandyRibbon(text: 'Chọn độ khó', colors: Candy.purple),
              ),
              const SizedBox(height: 14),
              SudokuLevelPicker(
                stats: (l) => _store.stats(l.statsId),
                onPick: _startNew,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gameView(SudokuGame g) {
    final s = Theme.of(context).colorScheme;
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, c) =>
              c.maxWidth >= _wideMin ? _wideMain(g, c) : _phoneMain(g),
        ),
        Positioned.fill(
          child: WinBanner(
            show: _showWin && !_showResult,
            title: 'Hoàn thành!',
            subtitle: formatClock(g.elapsed),
            points: _points,
          ),
        ),
        if (_showResult) ...[
          Positioned.fill(
            child: ColoredBox(color: s.scrim.withValues(alpha: 0.35)),
          ),
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _resultPanel(g),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _boardStack(SudokuGame g) {
    final reduce = _reduce;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Shake(
          key: _shakeKey,
          child: AnimatedSwitcher(
            duration: reduce
                ? Duration.zero
                : const Duration(milliseconds: 250),
            child: _paused
                ? _pauseCover()
                : SudokuBoard(
                    key: const ValueKey('board'),
                    game: g,
                    selected: _sel,
                    onTap: _select,
                    wave: _wave,
                    waveDelay: _waveDelay,
                    hintUnit: _hintUnit,
                    hintCell: _hintCell,
                    burst: _burst,
                    burstDelay: _burstDelay,
                  ),
          ),
        ),
        if (_toastMessages.isNotEmpty && !_paused)
          Positioned(
            top: -14,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: SudokuCompletionToast(
                  key: ValueKey(_toastId),
                  messages: _toastMessages,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _hintArea(SudokuGame g) {
    final s = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: _reduce ? Duration.zero : const Duration(milliseconds: 200),
      child: _hintText == null
          ? const SizedBox(width: double.infinity, height: 8)
          : _hintCard(s),
    );
  }

  Widget _phoneMain(SudokuGame g) {
    final remaining = [for (var d = 1; d <= 9; d++) 9 - g.countOf(d)];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoBar(g),
              const SizedBox(height: 8),
              _boardStack(g),
              _hintArea(g),
              FrostCard(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                radius: 26,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SudokuActions(
                      canUndo: g.canUndo && !_paused,
                      canRedo: g.canRedo && !_paused,
                      notesOn: _notes,
                      hintsLeft: g.hintsLeft,
                      onUndo: _undo,
                      onRedo: _redo,
                      onErase: _erase,
                      onNotes: _toggleNotes,
                      onHint: _hint,
                    ),
                    const SizedBox(height: 8),
                    SudokuNumPad(
                      remaining: remaining,
                      notesOn: _notes,
                      onDigit: _digit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleNotes() {
    setState(() => _notes = !_notes);
    Sfx.play(SfxKind.tap);
  }

  /// Nut mat trang / mat troi: doi nhanh giua giao dien sang va toi.
  Widget _moonButton() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
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
      ),
    );
  }

  /// Banh rang goc tren phai: gom ca menu dieu huong va tuy chon cua game.
  Widget _gearMenu(SudokuGame? g) {
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
      child: const Padding(
        padding: EdgeInsets.fromLTRB(8, 0, 12, 0),
        child: _GearFace(),
      ),
      onSelected: (v) {
        switch (v) {
          case 'home':
            context.go(_store.homeRoute);
          case 'stats':
            context.push('/stats');
          case 'settings':
            context.push('/settings');
          case 'help':
            showTutorial(context, _id);
          case 'limit':
            _setLimit(!_limitCfg);
          case 'restart':
            _restartSame();
        }
      },
      itemBuilder: (_) => [
        item('home', Icons.home_rounded, FrostColors.orange, 'Trang chủ'),
        item('stats', Icons.bar_chart_rounded, FrostColors.green, 'Thống kê'),
        item('settings', Icons.tune_rounded, FrostColors.blue, 'Cài đặt'),
        item('help', Icons.help_outline_rounded, FrostColors.pink, 'Hướng dẫn'),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: 'limit',
          checked: _limitCfg,
          child: const Text('Giới hạn 3 lỗi'),
        ),
        if (g != null)
          item('restart', Icons.replay, FrostColors.purple, 'Chơi lại đề này'),
      ],
    );
  }

  /// Cau noi nho goc duoi ben trai (chi man rong).
  Widget _quote() => const Align(
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

  /// Man rong (>= [_wideMin] px): menu trai, ban choi giua, bang dieu khien
  /// phai, va (>= [_statsMin] px) cot thanh tich.
  static const _wideMin = 1100.0;
  static const _statsMin = 1240.0;

  Widget _wideMain(SudokuGame g, BoxConstraints c) {
    final remaining = [for (var d = 1; d <= 9; d++) 9 - g.countOf(d)];
    final showStats = c.maxWidth >= _statsMin;
    final f = FrostStyle.of(context);
    const gap = 16.0;
    const sideW = 290.0;
    // Hai cot ngoai (menu trai, thanh tich phai) cung rong de the giua nam
    // dung giua man hinh.
    final outerW = showStats ? 250.0 : 190.0;
    final avail = c.maxWidth - 40 - outerW * 2 - gap * 2 - 40 - sideW - gap;
    // Ban vuong vua khung: tru tab do kho (~60), hang nut duoi (~80), le.
    final board = min(avail, c.maxHeight - 250).clamp(300.0, 640.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: c.maxHeight - 20),
        child: Row(
          children: [
            SizedBox(width: outerW, height: c.maxHeight - 20, child: _quote()),
            const SizedBox(width: gap),
            Expanded(
              child: Center(
                child: FrostCard(
                  radius: 32,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: board,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_daily) _levelTabs(g),
                            if (!_daily) const SizedBox(height: 14),
                            _boardStack(g),
                            _hintArea(g),
                            const SizedBox(height: 6),
                            _bottomBar(g),
                          ],
                        ),
                      ),
                      const SizedBox(width: gap),
                      SizedBox(
                        width: sideW,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _timerCard(g, f),
                            const SizedBox(height: gap),
                            _padCard(g, remaining),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: outerW,
              height: c.maxHeight - 20,
              child: showStats
                  ? Align(alignment: Alignment.topRight, child: _statsCard(f))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _padCard(SudokuGame g, List<int> remaining) => FrostCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SudokuNumGrid(remaining: remaining, notesOn: _notes, onDigit: _digit),
        const SizedBox(height: 10),
        Row(
          children: [
            _sideKey(Icons.backspace_outlined, 'Xoá', _erase, FrostColors.red),
            const SizedBox(width: 10),
            _sideKey(
              Icons.lightbulb_outline,
              'Gợi ý ${g.hintsLeft}',
              g.hintsLeft > 0 ? _hint : null,
              FrostColors.amber,
            ),
            const SizedBox(width: 10),
            _sideKey(
              _notes ? Icons.edit : Icons.edit_outlined,
              'Ghi chú',
              _toggleNotes,
              FrostColors.purple,
              selected: _notes,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _levelTabs(SudokuGame g) => Row(
    children: [
      for (final l in SudokuLevel.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FrostButton(
              key: ValueKey('sudoku-tab-${l.name}'),
              tint: _levelTint(l),
              selected: l == g.level,
              radius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
              onPressed: l == g.level ? null : () => _startNew(l),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(levelIcon(l), size: 18),
                    const SizedBox(width: 6),
                    Text(l.label),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Color _levelTint(SudokuLevel l) => switch (l) {
    SudokuLevel.easy => FrostColors.green,
    SudokuLevel.medium => FrostColors.blue,
    SudokuLevel.hard => FrostColors.orange,
    SudokuLevel.expert => FrostColors.red,
  };

  Widget _bottomBar(SudokuGame g) {
    Widget btn(
      IconData icon,
      String label,
      VoidCallback? onTap,
      Color tint, {
      bool primary = false,
    }) => Expanded(
      flex: primary ? 5 : 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
          width: double.infinity,
          child: FrostButton(
            tint: tint,
            primary: primary,
            onPressed: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon),
                  const SizedBox(width: 6),
                  Text(label, maxLines: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        if (!_daily)
          btn(Icons.refresh_rounded, 'Mới', _openLevelSheet, FrostColors.green),
        btn(
          Icons.undo,
          'Hoàn tác',
          g.canUndo && !_paused ? _undo : null,
          FrostColors.blue,
        ),
        btn(
          Icons.redo,
          'Làm lại',
          g.canRedo && !_paused ? _redo : null,
          FrostColors.indigo,
        ),
        btn(
          Icons.lightbulb_outline,
          'Gợi ý (${g.hintsLeft})',
          g.hintsLeft > 0 && !_paused ? _hint : null,
          FrostColors.orange,
          primary: true,
        ),
      ],
    );
  }

  Widget _sideKey(
    IconData icon,
    String label,
    VoidCallback? onTap,
    Color tint, {
    bool selected = false,
  }) => Expanded(
    child: FrostButton(
      tint: tint,
      selected: selected,
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 10),
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    ),
  );

  Widget _timerCard(SudokuGame g, FrostStyle f) => FrostCard(
    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
    child: Row(
      children: [
        const Icon(Icons.timer_outlined, size: 34, color: FrostColors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thời gian',
                style: TextStyle(color: f.subInk, fontWeight: FontWeight.w700),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _clock,
                builder: (_, v, _) => Text(
                  formatClock(v),
                  key: const ValueKey('sudoku-clock'),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        FrostButton(
          tint: FrostColors.orange,
          radius: 28,
          padding: const EdgeInsets.all(14),
          onPressed: g.isOver ? null : _togglePause,
          child: Tooltip(
            message: _paused ? 'Tiếp tục' : 'Tạm dừng',
            child: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _statsCard(FrostStyle f) {
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
              fontWeight: FontWeight.w900,
              fontSize: 17,
              color: f.accent,
            ),
          ),
        ],
      ),
    );
    var played = 0;
    var won = 0;
    for (final l in SudokuLevel.values) {
      final st = _store.stats(l.statsId);
      played += st.played;
      won += st.won;
    }
    final rate = played == 0 ? 0 : (won * 100 / played).round();
    return FrostCard(
      strong: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
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
          row('Tổng điểm', '${_ps.totalPoints}'),
          row('Đã hoàn thành', '$won'),
          row('Tỷ lệ đúng', '$rate%'),
          const Divider(),
          const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: FrostColors.orange),
              SizedBox(width: 8),
              Text(
                'Kỷ lục',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final l in SudokuLevel.values)
            row(
              l.label,
              _store.stats(l.statsId).best == null
                  ? '--:--'
                  : formatClock(_store.stats(l.statsId).best!),
            ),
        ],
      ),
    );
  }

  Widget _infoBar(SudokuGame g) {
    final bad = g.mistakes > 0;
    return FrostCard(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ValueListenableBuilder<int>(
                valueListenable: _clock,
                builder: (_, v, _) => GlassStat(
                  key: const ValueKey('sudoku-clock'),
                  icon: Icons.timer_outlined,
                  text: formatClock(v),
                ),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: FrostButton(
                selected: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                onPressed: () {},
                child: Text(
                  _daily ? 'Hôm nay · ${g.level.label}' : g.level.label,
                ),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('mis-${g.mistakes}'),
                tween: Tween(begin: bad ? 1.3 : 1, end: 1),
                duration: _reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: GlassStat(
                  icon: Icons.close_rounded,
                  colors: Candy.red,
                  text: g.mistakeLimit
                      ? 'Lỗi ${g.mistakes}/${SudokuGame.maxMistakes}'
                      : 'Lỗi ${g.mistakes}',
                ),
              ),
            ),
          ),
          FrostButton(
            onPressed: g.isOver ? null : _togglePause,
            radius: 24,
            padding: const EdgeInsets.all(9),
            child: Tooltip(
              message: _paused ? 'Tiếp tục' : 'Tạm dừng',
              child: Icon(
                _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pauseCover() {
    return CandyFrame(
      key: const ValueKey('pause'),
      padding: 5,
      child: AspectRatio(
        aspectRatio: 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePause,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: Candy.purple,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.pause_circle_outline,
                  size: 72,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tạm dừng',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                CandyButton(
                  onPressed: _togglePause,
                  colors: Candy.green,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded),
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
    );
  }

  Widget _hintCard(ColorScheme s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: PopIn(
      trigger: _hintText,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Candy.gold, width: 2),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Candy.cream, Candy.creamDeep],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              offset: Offset(0, 3),
              blurRadius: 3,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb, color: Candy.orange.last),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _hintText!,
                style: const TextStyle(
                  color: Candy.brown,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Đóng',
              visualDensity: VisualDensity.compact,
              color: Candy.brown,
              icon: const Icon(Icons.close),
              onPressed: () => setState(_clearHint),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _resultPanel(SudokuGame g) {
    final won = g.isWon;
    final String title;
    if (won) {
      title = _daily
          ? 'Xong thử thách hôm nay!'
          : 'Hoàn thành ${g.level.label}!';
    } else {
      title = 'Hết lượt sai';
    }
    return SudokuResultPanel(
      won: won,
      seconds: g.elapsed,
      mistakes: g.mistakes,
      mistakeLimit: g.mistakeLimit,
      hints: g.hintsUsed,
      best: won && !_daily ? _best : null,
      newRecord: won && _newRecord,
      title: title,
      actions: [
        if (!won)
          CandyButton(
            onPressed: _continueWithoutLimit,
            child: const Text('Chơi tiếp, bỏ giới hạn'),
          ),
        if (!won)
          CandyButton(
            onPressed: _restartSame,
            colors: Candy.orange,
            child: const Text('Chơi lại đề này'),
          ),
        CandyButton(
          key: const ValueKey('sudoku-result-next'),
          onPressed: _daily
              ? () => context.go(_store.homeRoute)
              : _backToPicker,
          colors: Candy.green,
          child: Text(_daily ? 'Về thử thách' : 'Ván mới'),
        ),
      ],
    );
  }
}

/// Mat nut banh rang: tron trang, icon xanh (noi tren nen troi).
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
