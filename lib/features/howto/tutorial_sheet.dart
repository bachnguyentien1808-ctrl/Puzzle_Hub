import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/score_chip.dart';
import 'package:puzzle_hub/features/common/hub_panels.dart';
import 'package:puzzle_hub/features/common/start_menu.dart';
import 'package:puzzle_hub/features/howto/game_tutorials.dart';
import 'package:puzzle_hub/games/game_registry.dart';

GameInfo? _info(String id) {
  for (final g in gameRegistry) {
    if (g.id == id) return g;
  }
  return null;
}

/// Mo huong dan nhieu buoc + chu thich cua game [gameId].
Future<void> showTutorial(BuildContext context, String gameId) {
  final info = _info(gameId);
  final tut = gameTutorials[gameId];
  if (info == null || tut == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TutorialSheet(game: info, tutorial: tut),
  );
}

/// Nut "?" dat trong AppBar.actions cua man choi.
class HelpAction extends StatelessWidget {
  const HelpAction({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('help'),
      tooltip: 'Hướng dẫn và chú thích',
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => showTutorial(context, gameId),
    );
  }
}

/// Boc man choi: lan dau vao game se tu mo huong dan (chi mot lan).
class GameIntro extends ConsumerStatefulWidget {
  const GameIntro({required this.gameId, required this.child, super.key});

  final String gameId;
  final Widget child;

  @override
  ConsumerState<GameIntro> createState() => _GameIntroState();
}

class _GameIntroState extends ConsumerState<GameIntro> {
  /// Có ván đang chơi dở: hỏi Tiếp tục hay Chơi mới trước khi vào game.
  late bool _asking;

  @override
  void initState() {
    super.initState();
    final store = ref.read(progressStoreProvider);
    _asking = store.hasState(widget.gameId);
    if (!_asking) _maybeTutorial();
  }

  /// Lần đầu vào game tự mở hướng dẫn (chỉ một lần).
  void _maybeTutorial() {
    final store = ref.read(progressStoreProvider);
    if (store.tutorialSeen(widget.gameId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      store.markTutorialSeen(widget.gameId);
      showTutorial(context, widget.gameId);
    });
  }

  void _resume() {
    setState(() => _asking = false);
    _maybeTutorial();
  }

  Future<void> _startNew() async {
    // Chơi mới: bỏ ván dở trước khi game nạp, game sẽ mở màn chọn mức.
    await ref.read(progressStoreProvider).clearState(widget.gameId);
    if (!mounted) return;
    setState(() => _asking = false);
    _maybeTutorial();
  }

  @override
  Widget build(BuildContext context) {
    if (_asking) {
      return GameBackdrop(
        gameId: widget.gameId,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: const [SoundAction(), ScoreChip(), HubMenuAction()],
          ),
          body: StartChoicePanel(
            gameId: widget.gameId,
            keyPrefix: 'start',
            resumeSubtitle: 'Vào lại ván đang chơi dở',
            newSubtitle: 'Bỏ ván dở và bắt đầu ván mới',
            onResume: _resume,
            onNew: _startNew,
            onClose: () => context.go('/'),
          ),
        ),
      );
    }
    return GameBackdrop(gameId: widget.gameId, child: widget.child);
  }
}

class TutorialSheet extends StatefulWidget {
  const TutorialSheet({required this.game, required this.tutorial, super.key});

  final GameInfo game;
  final GameTutorial tutorial;

  @override
  State<TutorialSheet> createState() => _TutorialSheetState();
}

class _TutorialSheetState extends State<TutorialSheet> {
  final _page = PageController();
  int _i = 0;

  int get _count => widget.tutorial.steps.length + 1;
  bool get _last => _i == _count - 1;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (_last) {
      Navigator.of(context).pop();
      return;
    }
    _page.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_i == 0) return;
    _page.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Candy.forId(widget.game.id);
    final h = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: h * 0.78, maxWidth: 520),
          child: CandyFrame(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.game.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Bỏ qua',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _page,
                    onPageChanged: (v) => setState(() => _i = v),
                    children: [
                      for (final (n, s) in widget.tutorial.steps.indexed)
                        _StepPage(
                          step: s,
                          colors: colors,
                          index: n + 1,
                          total: widget.tutorial.steps.length,
                        ),
                      _LegendPage(tutorial: widget.tutorial),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var d = 0; d < _count; d++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: d == _i ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: d == _i ? Colors.amber : Colors.white30,
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_i > 0) ...[
                        Flexible(
                          child: CandyButton(
                            key: const Key('tutorial-back'),
                            onPressed: _back,
                            colors: Candy.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.chevron_left_rounded),
                                  SizedBox(width: 2),
                                  Text(
                                    'Quay lại',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: CandyButton(
                          key: const Key('tutorial-next'),
                          onPressed: _next,
                          colors: _last ? Candy.green : Candy.blue,
                          padding: EdgeInsets.symmetric(
                            horizontal: _i > 0 ? 18 : 40,
                            vertical: 12,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _last ? 'Bắt đầu chơi' : 'Tiếp',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
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
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.colors,
    required this.index,
    required this.total,
  });

  final TutorialStep step;
  final List<Color> colors;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Candy.gold, width: 3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: Candy.deep(colors),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(step.icon, size: 46, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Bước $index/$total',
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendPage extends StatelessWidget {
  const _LegendPage({required this.tutorial});

  final GameTutorial tutorial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Chú thích',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final l in tutorial.legend)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(width: 36, child: Center(child: l.leading)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.label,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          if (tutorial.tip != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates, color: Colors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mẹo: ${tutorial.tip}',
                      style: const TextStyle(color: Colors.white, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
