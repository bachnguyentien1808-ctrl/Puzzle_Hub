import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/core/ui/fx.dart';

/// Màn xem thử thẻ thắng / thua của từng game (không có nút dẫn tới, mở bằng
/// đường dẫn `/demo-ket-qua`). Số liệu là mẫu, dùng đúng tham số của game.
class ResultDemoScreen extends StatefulWidget {
  const ResultDemoScreen({super.key});

  @override
  State<ResultDemoScreen> createState() => _ResultDemoScreenState();
}

class _Demo {
  const _Demo(this.game, this.label, this.card);

  final String game;
  final String label;
  final WinBanner Function(VoidCallback close) card;
}

const _timeIcon = Icons.timer_off_rounded;

WinBanner _win({
  required VoidCallback close,
  required List<WinChip> chips,
  int stars = 3,
  String title = 'Hoàn thành!',
  String? subtitle,
  String? ribbon,
  int points = 820,
  String again = 'Ván mới',
}) => WinBanner(
  show: true,
  title: title,
  subtitle: subtitle,
  points: points,
  stars: stars,
  chips: chips,
  ribbon: ribbon,
  againLabel: again,
  onAgain: close,
  onExit: close,
);

WinBanner _lose({
  required VoidCallback close,
  required String title,
  required List<WinChip> chips,
  String? subtitle,
  String? ribbon,
  IconData? icon,
}) => WinBanner(
  show: true,
  lose: true,
  loseIcon: icon,
  title: title,
  subtitle: subtitle ?? 'Thử lại nhé!',
  stars: 0,
  chips: chips,
  ribbon: ribbon,
  onAgain: close,
  onExit: close,
);

List<WinChip> _tm(String t, [String? extra]) => [
  WinChip(Icons.timer_outlined, t),
  if (extra != null) WinChip(Icons.close_rounded, extra),
];

final _demos = <_Demo>[
  _Demo(
    'Sudoku',
    'Thắng',
    (c) => _win(
      close: c,
      subtitle: 'Vừa',
      chips: _tm('05:12', '0 lỗi'),
      ribbon: 'Kỷ lục mới! 05:12',
    ),
  ),
  _Demo(
    'Sudoku',
    'Sai 3 lần',
    (c) => _lose(
      close: c,
      title: 'Bạn đã thua!',
      ribbon: 'Hết lượt sai',
      icon: Icons.heart_broken_rounded,
      chips: _tm('00:05', '3/3 lỗi'),
    ),
  ),
  _Demo(
    'Sudoku',
    'Hết giờ',
    (c) => _lose(
      close: c,
      title: 'Hết giờ!',
      icon: _timeIcon,
      chips: _tm('07:30', '1 lỗi'),
    ),
  ),
  _Demo(
    '2048',
    'Thắng',
    (c) => _win(
      close: c,
      title: 'Đã đạt 2048!',
      chips: [const WinChip(Icons.stars_rounded, '20480 điểm')],
      again: 'Tiếp tục',
    ),
  ),
  _Demo(
    '2048',
    'Hết nước đi',
    (c) => _lose(
      close: c,
      title: 'Hết nước đi',
      chips: [const WinChip(Icons.stars_rounded, '3560 điểm')],
    ),
  ),
  _Demo(
    'Nonogram',
    'Thắng',
    (c) => _win(
      close: c,
      subtitle: 'Trái tim',
      chips: _tm('00:15', '1 lỗi'),
      again: 'Chơi lại',
      points: 570,
    ),
  ),
  _Demo(
    'Nonogram',
    'Hết giờ',
    (c) => _lose(
      close: c,
      title: 'Hết giờ!',
      icon: _timeIcon,
      chips: _tm('06:15', '4 lỗi'),
    ),
  ),
  _Demo(
    'Tìm cặp',
    'Thắng',
    (c) => _win(
      close: c,
      chips: [
        const WinChip(Icons.touch_app_outlined, '18 lượt'),
        const WinChip(Icons.timer_outlined, '01:05'),
      ],
      ribbon: 'Kỷ lục mới! 18 lượt',
    ),
  ),
  _Demo(
    'Tìm cặp',
    'Hết giờ',
    (c) => _lose(
      close: c,
      title: 'Hết giờ!',
      icon: _timeIcon,
      chips: [
        const WinChip(Icons.touch_app_outlined, '31 lượt'),
        const WinChip(Icons.timer_outlined, '02:00'),
      ],
    ),
  ),
  _Demo(
    'Dò mìn',
    'Thắng',
    (c) => _win(
      close: c,
      title: 'Bạn đã thắng!',
      subtitle: 'Chúc mừng bạn đã hoàn thành màn chơi!',
      chips: [
        const WinChip(Icons.flag_rounded, '10'),
        const WinChip(Icons.timer_outlined, '01:20'),
      ],
      ribbon: 'Hoàn thành xuất sắc!',
      again: 'Chơi lại',
    ),
  ),
  _Demo(
    'Dò mìn',
    'Nổ mìn',
    (c) => _lose(
      close: c,
      title: 'Bạn đã thua!',
      subtitle: 'Đừng bỏ cuộc, thử lại nhé!',
      ribbon: 'Mìn đã phát nổ!',
      chips: [
        const WinChip(Icons.dangerous_rounded, '10 mìn'),
        const WinChip(Icons.timer_outlined, '00:42'),
      ],
    ),
  ),
  _Demo(
    'Dò mìn',
    'Hết giờ',
    (c) => _lose(
      close: c,
      title: 'Hết giờ!',
      icon: _timeIcon,
      ribbon: 'Hết thời gian!',
      chips: [
        const WinChip(Icons.dangerous_rounded, '10 mìn'),
        const WinChip(Icons.timer_outlined, '02:15'),
      ],
    ),
  ),
  _Demo(
    'Tắt đèn',
    'Thắng',
    (c) => _win(
      close: c,
      title: 'Tắt hết đèn!',
      chips: [
        const WinChip(Icons.touch_app_outlined, '9 lượt'),
        const WinChip(Icons.emoji_events_outlined, 'Tối ưu 7'),
      ],
      again: 'Chơi lại',
    ),
  ),
  _Demo(
    'Tắt đèn',
    'Hết giờ',
    (c) => _lose(
      close: c,
      title: 'Hết giờ!',
      icon: _timeIcon,
      chips: [
        const WinChip(Icons.touch_app_outlined, '14 lượt'),
        const WinChip(Icons.emoji_events_outlined, 'Tối ưu 7'),
      ],
    ),
  ),
  _Demo(
    'Xếp số',
    'Thắng',
    (c) => _win(
      close: c,
      chips: [
        const WinChip(Icons.touch_app_outlined, '84 lượt'),
        const WinChip(Icons.timer_outlined, '02:41'),
      ],
      ribbon: 'Kỷ lục mới!',
    ),
  ),
  _Demo(
    'Xếp số',
    'Hết giờ',
    (c) => _lose(
      close: c,
      title: 'Hết giờ!',
      icon: _timeIcon,
      chips: [
        const WinChip(Icons.touch_app_outlined, '120 lượt'),
        const WinChip(Icons.timer_outlined, '06:00'),
      ],
    ),
  ),
  _Demo(
    'Kakuro',
    'Thắng',
    (c) => _win(close: c, chips: _tm('06:48'), ribbon: 'Kỷ lục mới! 06:48'),
  ),
  _Demo(
    'Kakuro',
    'Hết giờ',
    (c) => _lose(
      close: c,
      title: 'Hết giờ!',
      icon: _timeIcon,
      chips: _tm('10:30'),
    ),
  ),
];

class _ResultDemoScreenState extends State<ResultDemoScreen> {
  _Demo? _open;

  void _close() => setState(() => _open = null);

  @override
  Widget build(BuildContext context) {
    final games = <String>[];
    for (final d in _demos) {
      if (!games.contains(d.game)) games.add(d.game);
    }
    return CandyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Xem thử thẻ thắng / thua'),
          leading: BackButton(onPressed: () => context.go('/')),
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final g in games)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final d in _demos.where((d) => d.game == g))
                              CandyButton(
                                colors: d.label == 'Thắng'
                                    ? Candy.green
                                    : Candy.red,
                                onPressed: () => setState(() => _open = d),
                                child: Text(d.label),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_open != null) Positioned.fill(child: _open!.card(_close)),
          ],
        ),
      ),
    );
  }
}
