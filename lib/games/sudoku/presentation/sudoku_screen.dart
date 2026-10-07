import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/score/scoring.dart';
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
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          leading: BackButton(onPressed: () => context.go(_store.homeRoute)),
          title: Text(_daily ? 'Sudoku · Thử thách ngày' : 'Sudoku'),
          actions: [
            const ScoreChip(),
            const HelpAction(gameId: 'sudoku'),
            if (g != null && !_daily)
              IconButton(
                tooltip: 'Ván mới',
                icon: const Icon(Icons.add_box_outlined),
                onPressed: _openLevelSheet,
              ),
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

  /// Man rong (>= [_wideMin] px): menu trai, ban choi giua, bang dieu khien
  /// phai, va (>= [_statsMin] px) cot thanh tich.
  static const _wideMin = 980.0;
  static const _statsMin = 1240.0;

  Widget _wideMain(SudokuGame g, BoxConstraints c) {
    final remaining = [for (var d = 1; d <= 9; d++) 9 - g.countOf(d)];
    final showStats = c.maxWidth >= _statsMin;
    final f = FrostStyle.of(context);
    const gap = 16.0;
    const railW = 190.0;
    const sideW = 300.0;
    const statsW = 250.0;
    final centerW =
        c.maxWidth -
        40 -
        railW -
        sideW -
        gap * 2 -
        (showStats ? statsW + gap : 0);
    // Ban vuong vua khung: tru the, tab do kho (~60), hang nut duoi (~80).
    final board = min(centerW - 40, c.maxHeight - 230).clamp(300.0, 640.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: railW, child: _rail()),
          const SizedBox(width: gap),
          Expanded(
            child: Center(
              child: SizedBox(
                width: board + 40,
                child: FrostCard(
                  radius: 28,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_daily) _levelTabs(g),
                      if (!_daily) const SizedBox(height: 14),
                      Center(
                        child: SizedBox(width: board, child: _boardStack(g)),
                      ),
                      _hintArea(g),
                      const SizedBox(height: 6),
                      _bottomBar(g),
                    ],
                  ),
                ),
              ),
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
                _notesCard(f),
                const SizedBox(height: gap),
                FrostCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SudokuNumGrid(
                        remaining: remaining,
                        notesOn: _notes,
                        onDigit: _digit,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _sideKey(Icons.backspace_outlined, 'Xoá', _erase),
                          const SizedBox(width: 10),
                          _sideKey(
                            Icons.lightbulb_outline,
                            'Gợi ý ${g.hintsLeft}',
                            g.hintsLeft > 0 ? _hint : null,
                          ),
                          const SizedBox(width: 10),
                          _sideKey(
                            _notes ? Icons.edit : Icons.edit_outlined,
                            'Ghi chú',
                            _toggleNotes,
                            selected: _notes,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showStats) ...[
            const SizedBox(width: gap),
            SizedBox(width: statsW, child: _statsCard(f)),
          ],
        ],
      ),
    );
  }

  Widget _rail() => FrostNavRail(
    items: [
      FrostNavItem(
        icon: Icons.home_rounded,
        label: 'Trang chủ',
        onTap: () => context.go(_store.homeRoute),
      ),
      FrostNavItem(
        icon: Icons.grid_on,
        label: 'Sudoku',
        selected: true,
        onTap: () {},
      ),
      FrostNavItem(
        icon: Icons.bar_chart_rounded,
        label: 'Thống kê',
        onTap: () => context.go('/stats'),
      ),
      FrostNavItem(
        icon: Icons.settings_rounded,
        label: 'Cài đặt',
        onTap: () => context.go('/settings'),
      ),
      FrostNavItem(
        icon: Icons.help_outline_rounded,
        label: 'Hướng dẫn',
        onTap: () => showTutorial(context, _id),
      ),
    ],
  );

  Widget _levelTabs(SudokuGame g) => Row(
    children: [
      for (final l in SudokuLevel.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FrostButton(
              key: ValueKey('sudoku-tab-${l.name}'),
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

  Widget _bottomBar(SudokuGame g) => Row(
    children: [
      if (!_daily)
        FrostButton(
          onPressed: _openLevelSheet,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded),
              SizedBox(width: 8),
              Text('Mới'),
            ],
          ),
        ),
      const SizedBox(width: 10),
      FrostButton(
        onPressed: g.canUndo && !_paused ? _undo : null,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.undo), SizedBox(width: 8), Text('Hoàn tác')],
        ),
      ),
      const SizedBox(width: 10),
      FrostButton(
        onPressed: g.canRedo && !_paused ? _redo : null,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(Icons.redo), SizedBox(width: 8), Text('Làm lại')],
        ),
      ),
      const Spacer(),
      FrostButton(
        primary: true,
        onPressed: g.hintsLeft > 0 && !_paused ? _hint : null,
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline),
            const SizedBox(width: 8),
            Text('Gợi ý (${g.hintsLeft})'),
          ],
        ),
      ),
    ],
  );

  Widget _sideKey(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool selected = false,
  }) => Expanded(
    child: FrostButton(
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
        Icon(Icons.timer_outlined, size: 34, color: f.accent),
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

  Widget _notesCard(FrostStyle f) => FrostCard(
    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
    child: Row(
      children: [
        Icon(Icons.edit_note_rounded, size: 28, color: f.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ghi chú',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              Text(
                'Bật để ghi số ứng viên vào ô.',
                style: TextStyle(color: f.subInk, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(value: _notes, onChanged: (_) => _toggleNotes()),
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
              style: TextStyle(color: f.subInk, fontWeight: FontWeight.w700),
            ),
          ),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: f.accent),
              const SizedBox(width: 8),
              const Text(
                'Thành tích',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          row('Tổng điểm', '${_ps.totalPoints}'),
          row('Đã hoàn thành', '$won'),
          row('Tỷ lệ đúng', '$rate%'),
          const Divider(),
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: f.accent),
              const SizedBox(width: 8),
              const Text(
                'Kỷ lục',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
