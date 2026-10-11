import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx_player.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/features/howto/tutorial_sheet.dart';

const _ink = Color(0xFF1B2A4A);
const _accent = Color(0xFF3D5AFE);

/// Hien mot bang tha xuong goc tren ben phai (duoi AppBar), nen mo dan.
Future<void> _showDropdown(
  BuildContext context, {
  required WidgetBuilder builder,
  double top = 56,
  double width = 320,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: const Color(0x33000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, top, 12, 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: Material(
              type: MaterialType.transparency,
              child: builder(ctx),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a, _, child) {
      if (MediaQuery.disableAnimationsOf(ctx)) return child;
      return FadeTransition(
        opacity: a,
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(
            begin: .94,
            end: 1,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

/// Bang trang bo goc, bong mem: dung chung cho Thanh tich va Menu.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: dark ? const Color(0xFF1E2A44) : Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: dark ? Colors.white : _ink),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bang Thanh tich
// ---------------------------------------------------------------------------

/// Game dang mo (duong dan /play/ten-game), null neu khong o trong game.
String? _currentGameId(BuildContext context) {
  try {
    final path = GoRouter.of(context)
        .routeInformationProvider
        .value
        .uri
        .pathSegments;
    if (path.length >= 2 && path.first == 'play') return path[1];
  } on Object {
    return null;
  }
  return null;
}

/// Mở màn Thống kê / Cài đặt thành một trang riêng (cả ở trang chủ lẫn đang
/// trong game): không đè lên bàn chơi, quay lại thì về đúng chỗ cũ.
void _openPage(BuildContext context, {required String route}) {
  context.push(route);
}

// ---------------------------------------------------------------------------
// Nut + menu rang cua
// ---------------------------------------------------------------------------

/// Nut rang cua (tron, sang) trong AppBar cua man choi.
class HubMenuAction extends StatelessWidget {
  const HubMenuAction({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 8),
      child: Tooltip(
        message: 'Menu',
        child: Semantics(
          button: true,
          label: 'Menu',
          excludeSemantics: true,
          child: GestureDetector(
            key: const Key('hub-menu'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showHubMenu(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xE6FFFFFF),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_rounded,
                color: _accent,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút loa trên thanh trên của game: bấm để tắt/bật toàn bộ âm thanh
/// (nhạc nền lẫn hiệu ứng), dùng chung công tắc với trang chủ và Cài đặt.
class SoundAction extends StatelessWidget {
  const SoundAction({super.key});

  void _toggle(BuildContext context, {required bool on}) {
    try {
      ProviderScope.containerOf(context)
          .read(settingsProvider.notifier)
          .setSound(on: on);
    } on Object {
      // Không có kho cài đặt (test): đổi thẳng công tắc âm thanh.
      SfxEngine.enabled.value = on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SfxEngine.enabled,
      builder: (context, on, _) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Tooltip(
          message: on ? 'Tắt âm thanh' : 'Bật âm thanh',
          child: Semantics(
            button: true,
            label: on ? 'Tắt âm thanh' : 'Bật âm thanh',
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('sound-toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggle(context, on: !on),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xE6FFFFFF),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: on ? _accent : const Color(0xFFE53935),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu cua nut rang cua: Trang chu (chi o man choi), Thong ke, Cai dat,
/// Huong dan. Che do sang/toi chi chinh trong Cai dat.
Future<void> showHubMenu(
  BuildContext context, {
  double top = 56,
  bool showHome = true,
}) {
  return _showDropdown(
    context,
    top: top,
    width: 260,
    builder: (ctx) {
      return _Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHome)
              _MenuRow(
                icon: Icons.home_rounded,
                color: const Color(0xFFFF8A00),
                label: 'Trang chủ',
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go('/');
                },
              ),
            _MenuRow(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF22A06B),
              label: 'Thống kê',
              onTap: () {
                Navigator.of(ctx).pop();
                // Trong game: chỉ thống kê game đang chơi.
                final id = _currentGameId(context);
                _openPage(
                  context,
                  route: id == null ? '/stats' : '/stats?game=$id',
                );
              },
            ),
            // Cài đặt chỉ có ở trang chủ, không có trong game.
            if (_currentGameId(context) == null)
              _MenuRow(
                icon: Icons.tune_rounded,
                color: _accent,
                label: 'Cài đặt',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openPage(context, route: '/settings');
                },
              ),
            _MenuRow(
              icon: Icons.help_outline_rounded,
              color: const Color(0xFFE91E8C),
              label: 'Hướng dẫn',
              onTap: () {
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                // Trong game: huong dan thang game do; o trang chu: chon game.
                final id = _currentGameId(context);
                if (id != null) {
                  showTutorial(context, id);
                } else {
                  context.push('/guide');
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
