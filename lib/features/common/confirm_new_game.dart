import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/ui/candy.dart';

/// Hỏi "Bạn có muốn làm mới không?" trước khi bỏ ván đang chơi, theo kiểu
/// thẻ kẹo của ứng dụng. Trả về true nếu người chơi chọn Có.
Future<bool> confirmNewGame(BuildContext context) => _ask(
  context,
  title: 'Làm mới ván chơi?',
  message: 'Bạn có muốn làm mới không?\nVán đang chơi sẽ bị bỏ.',
  icon: Icons.refresh_rounded,
);

/// Hỏi "Bạn có chắc chắn muốn thoát không?" khi bấm mũi tên quay lại trong
/// game. Trả về true nếu người chơi chọn Có.
Future<bool> confirmExitGame(BuildContext context) => _ask(
  context,
  title: 'Thoát game?',
  message: 'Bạn có chắc chắn muốn thoát không?',
  icon: Icons.exit_to_app_rounded,
);

Future<bool> _ask(
  BuildContext context, {
  required String title,
  required String message,
  required IconData icon,
}) async {
  Sfx.play(SfxKind.open);
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _ConfirmCard(title: title, message: message, icon: icon),
  );
  return ok ?? false;
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: reduce ? 1 : 0.85, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: _card(context),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 38),
          padding: const EdgeInsets.fromLTRB(22, 52, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF6E3), Candy.cream],
            ),
            border: Border.all(color: Candy.bgTop, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x88000000),
                offset: Offset(0, 10),
                blurRadius: 22,
              ),
              BoxShadow(color: Colors.white30, spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Candy.brown,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Candy.brown,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: CandyButton(
                      key: const ValueKey('confirm-no'),
                      colors: Candy.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close_rounded),
                          SizedBox(width: 6),
                          Text('Không', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: CandyButton(
                      key: const ValueKey('confirm-yes'),
                      colors: Candy.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded),
                          SizedBox(width: 6),
                          Text('Có', style: TextStyle(fontSize: 18)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Biểu tượng tròn nhô lên trên mép thẻ.
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: Candy.orange,
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                offset: Offset(0, 5),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, size: 42, color: Colors.white),
        ),
      ],
    );
  }
}
