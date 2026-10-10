import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/games/game_registry.dart';

/// Ô "Tiếp tục" đầu màn chọn mức: bấm để vào lại ván đang chơi dở. Không có
/// ván dở thì mờ đi và không bấm được.
class StartResumeCard extends StatelessWidget {
  const StartResumeCard({
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.emptyText = 'Chưa có ván đang chơi',
    super.key,
  });

  /// Mô tả ván dở (mức, thời gian còn lại...). Chỉ hiện khi [enabled].
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return CandyButton(
      colors: Candy.green,
      radius: 18,
      dim: !enabled,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      onPressed: enabled ? onTap : null,
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill_rounded, size: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tiếp tục', style: TextStyle(fontSize: 22)),
                  Text(
                    enabled ? subtitle : emptyText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow_rounded, size: 34),
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề nhóm trong màn chọn mức (vd. "Chơi mới").
class StartSectionLabel extends StatelessWidget {
  const StartSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 3)],
        ),
      ),
    );
  }
}

/// Mô tả trò chơi bằng chữ nhỏ ở cuối màn chọn mức.
class GameDescriptionNote extends StatelessWidget {
  const GameDescriptionNote({required this.gameId, super.key});

  final String gameId;

  @override
  Widget build(BuildContext context) {
    final game = gameRegistry.where((g) => g.id == gameId).firstOrNull;
    final text = game?.howTo ?? game?.subtitle;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      child: Text(
        text,
        key: const ValueKey('game-description'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 12,
          height: 1.4,
          shadows: [Shadow(color: Color(0x99000000), blurRadius: 3)],
        ),
      ),
    );
  }
}

/// Ô "Chơi mới" ở màn hỏi tiếp tục hay chơi mới.
class StartNewCard extends StatelessWidget {
  const StartNewCard({
    required this.onTap,
    this.subtitle = 'Bắt đầu một ván mới',
    super.key,
  });

  final VoidCallback onTap;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CandyButton(
      colors: Candy.orange,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      onPressed: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Row(
          children: [
            const Icon(Icons.add_circle_rounded, size: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chơi mới', style: TextStyle(fontSize: 22)),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 30),
          ],
        ),
      ),
    );
  }
}

/// Màn đầu tiên khi vào game: hỏi Tiếp tục ván dở hay Chơi mới (rồi mới tới
/// màn chọn mức). [resumeSubtitle] null = chưa có ván dở (ô Tiếp tục mờ).
/// Các khoá test: `<keyPrefix>-resume`, `<keyPrefix>-new`.
class StartChoicePanel extends StatelessWidget {
  const StartChoicePanel({
    required this.gameId,
    required this.keyPrefix,
    required this.resumeSubtitle,
    required this.onResume,
    required this.onNew,
    required this.onClose,
    this.newSubtitle = 'Bắt đầu một ván mới',
    super.key,
  });

  final String gameId;
  final String keyPrefix;
  final String? resumeSubtitle;
  final String newSubtitle;
  final VoidCallback onResume;
  final VoidCallback onNew;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final game = gameRegistry.where((g) => g.id == gameId).firstOrNull;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: GlassPanel(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: CandyButton(
                        onPressed: null,
                        colors: Candy.forId(gameId),
                        circle: true,
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          game?.icon ?? Icons.extension_rounded,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: CandyRibbon(
                        text: game?.title ?? 'Trò chơi',
                        colors: Candy.forId(gameId),
                      ),
                    ),
                    const SizedBox(height: 18),
                    StartResumeCard(
                      key: ValueKey('$keyPrefix-resume'),
                      enabled: resumeSubtitle != null,
                      subtitle: resumeSubtitle ?? '',
                      onTap: onResume,
                    ),
                    const SizedBox(height: 12),
                    StartNewCard(key: ValueKey('$keyPrefix-new'), onTap: onNew),
                    GameDescriptionNote(gameId: gameId),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: GlassCloseButton(onTap: onClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
