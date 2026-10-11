import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/glass.dart';
import 'package:puzzle_hub/features/common/confirm_new_game.dart';

/// Khoi kinh lon cua man choi: dau khoi co mui ten quay lai + ten game, ben
/// duoi la noi dung (thanh thong tin, ban choi, nut dieu khien).
class GameBlock extends StatelessWidget {
  const GameBlock({
    required this.title,
    required this.onBack,
    required this.child,
    this.actions = const [],
    this.expand = false,
    this.confirmExit = true,
    this.fullBleed = false,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  /// true: trên điện thoại phủ kín màn hình (trang chọn ải / mức).
  final bool fullBleed;

  /// false: bấm quay lại thoát luôn, không hỏi (trang chọn ải/mức).
  final bool confirmExit;

  /// Cac chuc nang (diem, menu, hoan tac...) nam o ben phai dau khoi.
  final List<Widget> actions;

  /// true: khoi chiem het chieu cao cho phep, [child] duoc Expanded (dung khi
  /// noi dung co Expanded ben trong).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bleed = fullBleed && PickerFrame.mobile(context);
    final panel = GlassPanel(
      radius: bleed ? 0 : 30,
      padding: bleed
          ? PickerFrame.inner(
              context,
              const EdgeInsets.fromLTRB(12, 12, 12, 14),
            )
          : const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameBlockHeader(
            title: title,
            onBack: onBack,
            actions: actions,
            confirmExit: confirmExit,
          ),
          const SizedBox(height: 10),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
    return fullBleed ? KeepBackdropStill(child: panel) : panel;
  }
}

/// Hang dau khoi: nut tron mui ten + ten game + cac chuc nang ben phai. Di chuot
/// vao moi nut se hien chu giai thich (tooltip).
class GameBlockHeader extends StatelessWidget {
  const GameBlockHeader({
    required this.title,
    required this.onBack,
    this.actions = const [],
    this.confirmExit = true,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final List<Widget> actions;
  final bool confirmExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Quay lại',
          child: GestureDetector(
            key: const Key('game-back'),
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              Sfx.play(SfxKind.back);
              if (!confirmExit || await confirmExitGame(context)) onBack();
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .55),
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Ten game chiem do rong tu nhien (toi da 170), phan con lai danh cho
        // cac chuc nang, can phai va tu thu nho neu thieu cho.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: Color(0x88000000), blurRadius: 3)],
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(foregroundColor: Colors.white),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
