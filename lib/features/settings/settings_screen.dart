import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/settings/app_settings.dart';
import 'package:puzzle_hub/core/storage/progress_store.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';
import 'package:puzzle_hub/features/common/shell_widgets.dart';
import 'package:puzzle_hub/features/common/sky_page.dart';
import 'package:puzzle_hub/features/common/start_menu.dart' show skyNavy;
import 'package:puzzle_hub/games/game_registry.dart';

const appVersion = '1.0.0';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final c = ref.read(settingsProvider.notifier);
    return SkyPage(
      title: 'Cài đặt',
      icon: Icons.settings_rounded,
      subtitle: 'Giao diện, âm thanh và dữ liệu của bạn',
      children: [
        const _Header('Giao diện', Icons.palette_rounded),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Sáng'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Tối'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Tự động'),
                    ),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) {
                    GameFx.tap();
                    c.setThemeMode(v.first);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'Sáng: ban ngày · Tối: ban đêm · Tự động: đổi theo '
                  'giờ thật (sáng, chiều, tối)',
                  style: TextStyle(color: _inkSoft, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _Header('Phản hồi', Icons.notifications_active_rounded),
        _Panel(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Âm thanh'),
                value: s.sound,
                onChanged: (v) async {
                  await c.setSound(on: v);
                  if (v) Sfx.play(SfxKind.success);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.vibration),
                title: const Text('Rung'),
                value: s.haptics,
                onChanged: (v) async {
                  await c.setHaptics(on: v);
                  GameFx.success();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _Header('Dữ liệu', Icons.storage_rounded),
        _Panel(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.slideshow_outlined),
                title: const Text('Xem lại giới thiệu'),
                onTap: () async {
                  await c.resetOnboarding();
                  if (!context.mounted) return;
                  // Dang mo de len man choi: dong lop truoc.
                  if (ModalRoute.of(context) is PopupRoute) {
                    Navigator.of(context).pop();
                  }
                  context.go('/');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: _danger),
                title: const Text(
                  'Xóa toàn bộ tiến độ',
                  style: TextStyle(color: _danger, fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Thống kê, kỷ lục, chuỗi ngày, ván dở'),
                onTap: () =>
                    confirmReset(context, ref.read(progressStoreProvider)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const _Header('Giới thiệu', Icons.info_rounded),
        _Panel(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Puzzle Hub'),
            subtitle: Text(
              'Phiên bản $appVersion · ${gameRegistry.length} trò chơi',
            ),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Puzzle Hub',
              applicationVersion: appVersion,
              applicationIcon: const IconTile(icon: Icons.extension_rounded),
              applicationLegalese: '© 2026 ALODEV',
              children: const [
                SizedBox(height: 12),
                Text(
                  'Tuyển tập trò chơi trí tuệ chơi ngoại tuyến. '
                  'Không quảng cáo, không thu thập dữ liệu.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> confirmReset(BuildContext context, ProgressStore store) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline),
      title: const Text('Xóa toàn bộ tiến độ?'),
      content: const Text(
        'Thống kê, kỷ lục, chuỗi ngày và các ván đang chơi dở sẽ mất, không khôi phục được.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  if (ok ?? false) {
    await store.resetAll();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa toàn bộ tiến độ')));
    }
  }
}

const _ink = Color(0xFF1B3FA6);
const _inkSoft = Color(0xFF5B77B8);
const _danger = Color(0xFFC62828);

/// Nhãn nhóm: vòng tròn màu chứa biểu tượng + chữ xanh đậm.
class _Header extends StatelessWidget {
  const _Header(this.text, this.icon);

  final String text;
  final IconData icon;

  static const _colors = {
    'Giao diện': Color(0xFFB04BE8),
    'Phản hồi': Color(0xFFFF8A00),
    'Dữ liệu': Color(0xFF22A06B),
    'Giới thiệu': Color(0xFF2E7BE0),
  };

  @override
  Widget build(BuildContext context) =>
      SkySection(text, icon, color: _colors[text] ?? skyNavy);
}

/// Khung kem chua cac dieu khien Material; ep mau nau de doc o ca theme toi.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final themed = base.copyWith(
      listTileTheme: const ListTileThemeData(
        textColor: _ink,
        iconColor: _ink,
        titleTextStyle: TextStyle(
          color: _ink,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
        subtitleTextStyle: TextStyle(color: _inkSoft, fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF8FB4E8),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? Candy.green.last
              : const Color(0xFFD7E6FA),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Color(0xFF8FD0FF)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(_ink),
          iconColor: const WidgetStatePropertyAll(_ink),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w800),
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: Color(0xFF8FD0FF), width: 2),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected)
                ? Candy.orange.first
                : Colors.transparent,
          ),
        ),
      ),
    );
    return SkyCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Theme(
        data: themed,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
