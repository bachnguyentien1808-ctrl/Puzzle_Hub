import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/game_logo.dart';
import 'package:puzzle_hub/features/common/sky_page.dart';
import 'package:puzzle_hub/features/common/start_menu.dart';
import 'package:puzzle_hub/features/howto/game_tutorials.dart';
import 'package:puzzle_hub/games/game_registry.dart';

/// Trang Hướng dẫn: đủ hướng dẫn và chú thích của mọi game, mỗi game một thẻ
/// bấm để mở ra / thu lại.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      title: 'Hướng dẫn',
      icon: Icons.help_outline_rounded,
      subtitle: 'Bấm vào từng trò chơi để xem cách chơi',
      children: [
        for (final g in gameRegistry)
          if (gameTutorials[g.id] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GameGuide(
                key: ValueKey('guide-${g.id}'),
                game: g,
                tutorial: gameTutorials[g.id]!,
                open: _open == g.id,
                onToggle: () =>
                    setState(() => _open = _open == g.id ? null : g.id),
              ),
            ),
      ],
    );
  }
}

class _GameGuide extends StatelessWidget {
  const _GameGuide({
    required this.game,
    required this.tutorial,
    required this.open,
    required this.onToggle,
    super.key,
  });

  final GameInfo game;
  final GameTutorial tutorial;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Candy.forId(game.id);
    return SkyCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
              child: Row(
                children: [
                  GameLogo(id: game.id, size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          game.title,
                          style: const TextStyle(
                            color: skyNavy,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          game.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF5B77B8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: skyNavy,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, step) in tutorial.steps.indexed)
                          _StepRow(index: i + 1, step: step, colors: colors),
                        if (tutorial.legend.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'Chú thích',
                            style: TextStyle(
                              color: skyNavy,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final item in tutorial.legend)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 38,
                                    child: Center(child: item.leading),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: const TextStyle(
                                        color: Color(0xFF2B4A9A),
                                        fontSize: 14,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        if (tutorial.tip != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            tutorial.tip!,
                            style: const TextStyle(
                              color: Color(0xFF5B77B8),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.colors,
  });

  final int index;
  final TutorialStep step;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(step.icon, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${step.title}',
                  style: const TextStyle(
                    color: skyNavy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.text,
                  style: const TextStyle(
                    color: Color(0xFF2B4A9A),
                    fontSize: 14,
                    height: 1.4,
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
