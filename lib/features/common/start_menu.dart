import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:puzzle_hub/core/audio/sfx.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/games/game_registry.dart';

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

/// Câu phụ đề dưới tên game trên màn hỏi Tiếp tục / Chơi mới.
const _taglines = <String, String>{
  'sudoku': 'THỬ THÁCH TRÍ TUỆ',
  '2048': 'GỘP SỐ CHẠM ĐỈNH',
  'nonogram': 'GIẢI MÃ BỨC TRANH',
  'memory': 'THỬ TÀI GHI NHỚ',
  'minesweeper': 'SUY LUẬN TỪNG BƯỚC',
  'lights_out': 'THẮP SÁNG BÀN CỜ',
  'sliding': 'XẾP ĐÚNG CHỖ',
  'kakuro': 'TỔNG SỐ BÍ ẨN',
};

/// Ba dòng mô tả ngắn dưới hai nút.
const _blurbs = <String, List<String>>{
  'sudoku': [
    'Điền số 1–9 vào các ô trống.',
    'Mỗi hàng, mỗi cột và mỗi khối 3×3 không được trùng số.',
    'Chạm vào ô rồi chọn số ở bảng bên dưới.',
  ],
  '2048': [
    'Vuốt để gộp các ô giống nhau.',
    'Gộp liên tiếp để chạm tới ô 2048.',
    'Hết nước đi là thua.',
  ],
  'nonogram': [
    'Dựa vào số gợi ý để tô các ô.',
    'Số cho biết các đoạn ô liền nhau trong hàng và cột.',
    'Tô đúng hết để hiện bức tranh.',
  ],
  'memory': [
    'Lật thẻ và ghi nhớ vị trí.',
    'Ghép đủ các cặp giống nhau để thắng.',
    'Càng ít lượt, càng nhiều sao.',
  ],
  'minesweeper': [
    'Mở hết các ô an toàn.',
    'Số trên ô cho biết có bao nhiêu mìn xung quanh.',
    'Cắm cờ ô có mìn; mở trúng mìn là thua.',
  ],
  'lights_out': [
    'Bấm một đèn sẽ đảo đèn đó và 4 đèn kề bên.',
    'Tắt hết đèn để thắng.',
    'Càng ít lượt, càng nhiều sao.',
  ],
  'sliding': [
    'Trượt các ô vào chỗ trống để xếp đúng thứ tự.',
    'Chơi bằng số hoặc ghép thành bức tranh.',
    'Càng ít lượt càng tốt.',
  ],
  'kakuro': [
    'Điền số 1–9 sao cho mỗi đoạn cộng đúng tổng gợi ý.',
    'Trong một đoạn không được lặp số.',
    'Bí thì dùng gợi ý.',
  ],
};

const skyNavy = Color(0xFF1B3FA6);

/// Viền chữ bằng nhiều bóng đổ cùng màu: chỉ cần một widget [Text] (test tìm chữ
/// vẫn thấy đúng một).
List<Shadow> skyOutline(Color c, double r) => [
  // 24 hướng trên vòng ngoài + 12 hướng trên vòng trong: viền liền mạch, không
  // bị đứt nét ở chỗ cong / chéo của chữ.
  for (var i = 0; i < 24; i++)
    Shadow(
      color: c,
      offset: Offset(
        math.cos(i * math.pi / 12) * r,
        math.sin(i * math.pi / 12) * r,
      ),
    ),
  for (var i = 0; i < 12; i++)
    Shadow(
      color: c,
      offset: Offset(
        math.cos(i * math.pi / 6 + .26) * r * .55,
        math.sin(i * math.pi / 6 + .26) * r * .55,
      ),
    ),
];

/// Vỏ chung của màn đầu game: bảng sáng, huy hiệu nổi phía trên, tên game +
/// phụ đề, nút × ở góc; phần giữa do [children] quyết định.
class _StartShell extends StatelessWidget {
  const _StartShell({
    required this.gameId,
    required this.onClose,
    required this.children,
  });

  final String gameId;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final game = gameRegistry.where((g) => g.id == gameId).firstOrNull;
    final title = (game?.title ?? 'Trò chơi').toUpperCase();
    // Điện thoại: bảng phủ kín màn hình, sát hai bên và đáy.
    if (MediaQuery.sizeOf(context).width < 600) {
      final top = MediaQuery.paddingOf(context).top;
      final bottom = MediaQuery.paddingOf(context).bottom;
      return SkyScheme(
        palette: skyPaletteFor(gameId),
        child: LayoutBuilder(
          builder: (context, box) {
            final panelTop = top + 74;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: panelTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SkyPanel(
                    fullBleed: true,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(22, 96, 22, 24 + bottom),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: box.maxHeight - panelTop - 120 - bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TitleBlock(
                              title: title,
                              tagline: _taglines[gameId] ?? 'SẴN SÀNG CHƠI',
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Center(child: SkyMedallion(icon: game?.icon)),
                ),
                Positioned(
                  top: top + 98,
                  right: 18,
                  child: SkyCloseDisc(onTap: onClose),
                ),
              ],
            );
          },
        ),
      );
    }
    return SkyScheme(
      palette: skyPaletteFor(gameId),
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 74),
                  child: SkyPanel(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(30, 96, 30, 32),
                      // Bảng dài hơn: tối thiểu ~55% chiều cao màn, nội dung
                      // giãn đều (Bắt đầu chơi / Tiếp tục cùng độ dài).
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height * .55,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TitleBlock(
                              title: title,
                              tagline: _taglines[gameId] ?? 'SẴN SÀNG CHƠI',
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(child: SkyMedallion(icon: game?.icon)),
                ),
                Positioned(
                  top: 98,
                  right: 18,
                  child: SkyCloseDisc(onTap: onClose),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Màn đầu khi vào game CHƯA có ván dở: một nút lớn "BẮT ĐẦU CHƠI".
/// Khoá test: `<keyPrefix>-play`.
class StartPlayPanel extends StatelessWidget {
  const StartPlayPanel({
    required this.gameId,
    required this.keyPrefix,
    required this.onStart,
    required this.onClose,
    super.key,
  });

  final String gameId;
  final String keyPrefix;
  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final game = gameRegistry.where((g) => g.id == gameId).firstOrNull;
    final blurb = _blurbs[gameId] ?? [game?.subtitle ?? ''];
    return _StartShell(
      gameId: gameId,
      onClose: onClose,
      children: [
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _Capsule(
            key: ValueKey('$keyPrefix-play'),
            title: 'BẮT ĐẦU CHƠI',
            subtitle: null,
            icon: Icons.play_arrow_rounded,
            plainIcon: true,
            colors: const [
              Color(0xFF4FE3A0),
              Color(0xFF1FB979),
              Color(0xFF0E9A63),
            ],
            onTap: onStart,
          ),
        ),
        const SizedBox(height: 26),
        _TipBox(lines: blurb),
      ],
    );
  }
}

/// Màn hỏi khi vào game có ván dở: "Bạn có muốn tiếp tục chơi không?" với hai
/// lựa chọn Có (chơi tiếp) / Không (chơi ván mới). Hai nút viên thuốc cạnh
/// nhau, khung mẹo cuối bảng.
/// Các khoá test: `<keyPrefix>-yes`, `<keyPrefix>-no`.
class StartChoicePanel extends StatelessWidget {
  const StartChoicePanel({
    required this.gameId,
    required this.keyPrefix,
    required this.onYes,
    required this.onNo,
    required this.onClose,
    super.key,
  });

  final String gameId;
  final String keyPrefix;

  /// Có: chơi tiếp ván đang dở.
  final VoidCallback onYes;

  /// Không: bỏ ván dở, chơi ván mới.
  final VoidCallback onNo;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final yes = _Capsule(
      key: ValueKey('$keyPrefix-yes'),
      title: 'Có',
      subtitle: 'Chơi tiếp ván đang chơi dở',
      icon: Icons.check_rounded,
      colors: const [Color(0xFF4FE3A0), Color(0xFF1FB979), Color(0xFF0E9A63)],
      onTap: onYes,
    );
    final no = _Capsule(
      key: ValueKey('$keyPrefix-no'),
      title: 'Không',
      subtitle: 'Bỏ ván dở, chơi ván mới',
      icon: Icons.close_rounded,
      colors: const [Color(0xFFFFC24A), Color(0xFFFF9A1F), Color(0xFFE56F0C)],
      onTap: onNo,
    );
    return _StartShell(
      gameId: gameId,
      onClose: onClose,
      children: [
        const SizedBox(height: 18),
        const _Question(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            // Rộng thì hai nút cạnh nhau, hẹp thì xếp dọc.
            if (box.maxWidth >= 480) {
              return Row(
                children: [
                  Expanded(child: yes),
                  const SizedBox(width: 14),
                  Expanded(child: no),
                ],
              );
            }
            return Column(children: [yes, const SizedBox(height: 12), no]);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Bảng màu + hình trang trí của trang/màn kiểu trời. Mỗi game có một bảng
/// riêng (xem [skyPaletteFor]) để màn vào game không bị nhàm.
class SkyPalette {
  const SkyPalette({
    required this.panel,
    required this.border,
    required this.glow,
    required this.medalA,
    required this.medalB,
    required this.discA,
    required this.discB,
    required this.discRing,
    required this.closeA,
    required this.closeB,
    required this.outline,
    required this.ink,
    required this.inkSoft,
    required this.accentA,
    required this.accentB,
    required this.cardBg,
    this.leaf = Icons.eco_rounded,
    this.leafColor = const Color(0xFF3DBE5C),
    this.flower = Icons.local_florist_rounded,
    this.isWarm = false,
  });

  /// Màu từ một góc màu [h] (0–360): mọi sắc độ suy ra cùng một tông.
  factory SkyPalette.hue(
    double h, {
    required IconData leaf,
    required Color leafColor,
    required IconData flower,
  }) {
    Color c(double s, double l, [double a = 1]) =>
        HSLColor.fromAHSL(a, h % 360, s, l).toColor();
    return SkyPalette(
      panel: [c(.9, .97, .95), c(.85, .90, .95), c(.75, .82, .95)],
      border: c(.85, .72),
      glow: c(.9, .72, .47),
      medalA: const Color(0xFFFFE9A8),
      medalB: c(.95, .68),
      discA: c(.9, .62),
      discB: c(.8, .34),
      discRing: c(.9, .88),
      closeA: c(.85, .64),
      closeB: c(.75, .44),
      outline: c(.75, .28),
      ink: c(.75, .28),
      inkSoft: c(.4, .45),
      accentA: c(1, .64),
      accentB: c(.8, .44),
      cardBg: c(.9, .99, .8),
      leaf: leaf,
      leafColor: leafColor,
      flower: flower,
    );
  }

  final List<Color> panel;
  final Color border;
  final Color glow;
  final Color medalA;
  final Color medalB;
  final Color discA;
  final Color discB;
  final Color discRing;
  final Color closeA;
  final Color closeB;
  final Color outline;
  final Color ink;
  final Color inkSoft;
  final Color accentA;
  final Color accentB;
  final Color cardBg;
  final IconData leaf;
  final Color leafColor;
  final IconData flower;
  final bool isWarm;

  /// Xanh trời (Sudoku và các trang Cài đặt / Thống kê / Hướng dẫn).
  static const sky = SkyPalette(
    panel: [Color(0xF2F2FAFF), Color(0xF2D4EAFF), Color(0xF2C2E0FF)],
    border: Color(0xFF8FD0FF),
    glow: Color(0x778FD0FF),
    medalA: Color(0xFFFFE9A8),
    medalB: Color(0xFF5FC4FF),
    discA: Color(0xFF4DA3FF),
    discB: Color(0xFF1646B8),
    discRing: Color(0xFFBFE9FF),
    closeA: Color(0xFF5DB8FF),
    closeB: Color(0xFF2C6FE0),
    outline: skyNavy,
    ink: skyNavy,
    inkSoft: Color(0xFF5B77B8),
    accentA: Color(0xFF4DB0FF),
    accentB: Color(0xFF1F6FE0),
    cardBg: Color(0xCCFFFFFF),
  );

  /// Đồng / vàng ấm (Tổng điểm, Thử thách), giống thẻ ngoài trang chủ.
  static const warm = SkyPalette(
    panel: [Color(0xF2FFF8EA), Color(0xF2FFE9C4), Color(0xF2F5D197)],
    border: Candy.gold,
    glow: Color(0x77E0A458),
    medalA: Color(0xFFFFF0B8),
    medalB: Color(0xFFE0A458),
    discA: Color(0xFFFFB347),
    discB: Color(0xFFC8661A),
    discRing: Color(0xFFFFE9A8),
    closeA: Color(0xFFFFA64D),
    closeB: Color(0xFFD35400),
    outline: Color(0xFF7A4A21),
    ink: Color(0xFF7A4A21),
    inkSoft: Color(0xFF9A6B3C),
    accentA: Color(0xFFFFB347),
    accentB: Color(0xFFD35400),
    cardBg: Color(0xE6FFFAF0),
    isWarm: true,
  );
}

/// Bảng màu riêng của từng game cho màn vào game: cùng màu với thẻ game
/// ngoài trang chủ ([Candy.forId]).
SkyPalette skyPaletteFor(String gameId) {
  final hue = HSLColor.fromColor(Candy.forId(gameId).last).hue;
  SkyPalette hued(IconData leaf, Color leafColor, IconData flower) =>
      SkyPalette.hue(hue, leaf: leaf, leafColor: leafColor, flower: flower);
  return switch (gameId) {
    'sudoku' => hued(
      Icons.grid_view_rounded,
      const Color(0xFF5C6BC0),
      Icons.looks_one_rounded,
    ),
    '2048' => hued(
      Icons.star_rounded,
      const Color(0xFFFFB300),
      Icons.bolt_rounded,
    ),
    'nonogram' => hued(
      Icons.brush_rounded,
      const Color(0xFFF08A1C),
      Icons.auto_awesome_rounded,
    ),
    'memory' => hued(
      Icons.favorite_rounded,
      const Color(0xFFFF4F9A),
      Icons.star_rounded,
    ),
    'minesweeper' => hued(
      Icons.flag_rounded,
      const Color(0xFFD7263D),
      Icons.bubble_chart_rounded,
    ),
    'lights_out' => hued(
      Icons.lightbulb_rounded,
      const Color(0xFFFFC107),
      Icons.nightlight_round,
    ),
    'sliding' => hued(
      Icons.extension_rounded,
      const Color(0xFFD7263D),
      Icons.auto_awesome_rounded,
    ),
    'kakuro' => hued(
      Icons.calculate_rounded,
      const Color(0xFF0F9D8F),
      Icons.tag_rounded,
    ),
    _ => SkyPalette.sky,
  };
}

/// Truyền bảng màu xuống các widget kiểu trời bên dưới.
class SkyScheme extends InheritedWidget {
  const SkyScheme({required this.palette, required super.child, super.key});

  final SkyPalette palette;

  static SkyPalette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkyScheme>()?.palette ??
      SkyPalette.sky;

  static bool warmOf(BuildContext context) => of(context).isWarm;

  /// Màu chữ đậm / chữ phụ theo bảng màu.
  static Color ink(BuildContext context) => of(context).ink;

  static Color inkSoft(BuildContext context) => of(context).inkSoft;

  @override
  bool updateShouldNotify(SkyScheme old) => old.palette != palette;
}

/// Khung bảng sáng, viền trắng, hai góc dưới có hình trang trí của game.
class SkyPanel extends StatelessWidget {
  const SkyPanel({required this.child, this.fullBleed = false, super.key});

  final Widget child;

  /// true: phủ kín bề ngang và xuống tận đáy (chỉ bo hai góc trên) — dùng trên
  /// điện thoại.
  final bool fullBleed;

  @override
  Widget build(BuildContext context) {
    final p = SkyScheme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: fullBleed
            ? const BorderRadius.vertical(top: Radius.circular(34))
            : BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.panel,
        ),
        border: Border.all(color: p.border, width: 4),
        boxShadow: [
          BoxShadow(color: p.glow, blurRadius: 24, spreadRadius: 1),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: fullBleed
              ? const BorderRadius.vertical(top: Radius.circular(30))
              : BorderRadius.circular(30),
          border: Border.all(color: const Color(0xAAFFFFFF), width: 2),
        ),
        child: Stack(
          children: [
            // Hình trang trí nằm DƯỚI nội dung: không che thẻ / chữ khi cuộn.
            const Positioned(left: 4, bottom: 2, child: _Foliage()),
            Positioned(
              right: 4,
              bottom: 2,
              child: Transform.flip(flipX: true, child: const _Foliage()),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Hình trang trí (lá + hoa, sao, tim... tuỳ game) ở góc dưới bảng.
class _Foliage extends StatelessWidget {
  const _Foliage();

  @override
  Widget build(BuildContext context) {
    final p = SkyScheme.of(context);
    return SizedBox(
      width: 58,
      height: 54,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Icon(p.leaf, size: 46, color: p.leafColor),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Icon(p.flower, size: 26, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Huy hiệu game nổi lên trên mép bảng: khung kim cương, hình trang trí hai bên.
class SkyMedallion extends StatelessWidget {
  const SkyMedallion({required this.icon, super.key});

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = SkyScheme.of(context);
    return SizedBox(
      width: 230,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            top: 52,
            child: Icon(p.leaf, size: 62, color: p.leafColor),
          ),
          Positioned(
            right: 8,
            top: 52,
            child: Transform.flip(
              flipX: true,
              child: Icon(p.leaf, size: 62, color: p.leafColor),
            ),
          ),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [p.medalA, p.medalB],
                ),
                border: Border.all(color: const Color(0xFFFFD66B), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: p.medalB.withValues(alpha: .55),
                    blurRadius: 16,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [p.discA, p.discB],
              ),
              border: Border.all(color: p.discRing, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              icon ?? Icons.extension_rounded,
              size: 70,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Giọt vàng trang trí hai bên tiêu đề.
class _Drops extends StatelessWidget {
  const _Drops({required this.flip});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    Widget drop(double angle, double size) => Transform.rotate(
      angle: angle,
      child: Icon(
        Icons.water_drop_rounded,
        size: size,
        color: const Color(0xFFFFC93C),
      ),
    );
    final sign = flip ? -1.0 : 1.0;
    return SizedBox(
      width: 34,
      height: 40,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: drop(sign * 0.9, 24)),
          Positioned(left: 8, top: 22, child: drop(sign * 1.9, 18)),
        ],
      ),
    );
  }
}

/// Tên game chữ trắng viền theo màu game, giọt vàng hai bên, nhãn phụ đề.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.tagline});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final p = SkyScheme.of(context);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Drops(flip: false),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 68,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  shadows: [
                    ...skyOutline(p.outline, 4),
                    const Shadow(
                      color: Color(0x88000000),
                      offset: Offset(0, 6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _Drops(flip: true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.accentA, p.accentB],
              ),
              border: Border.all(color: const Color(0xCCFFFFFF), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Gem(),
                  const SizedBox(width: 10),
                  Text(
                    tagline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const _Gem(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Gem extends StatelessWidget {
  const _Gem();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFFFFE066),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Câu hỏi lớn chữ đậm theo màu game viền trắng, giọt vàng hai bên. Luôn hai
/// dòng cố định, tự thu nhỏ vừa bề ngang (không cuộn, không rớt nhiều dòng).
class _Question extends StatelessWidget {
  const _Question();

  @override
  Widget build(BuildContext context) {
    final p = SkyScheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Drops(flip: false),
        const SizedBox(width: 6),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Bạn có muốn tiếp tục\nchơi không?',
              key: const ValueKey('start-question'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.ink,
                fontSize: 38,
                height: 1.15,
                fontWeight: FontWeight.w900,
                shadows: [
                  ...skyOutline(Colors.white, 3),
                  Shadow(
                    color: p.glow,
                    offset: const Offset(0, 4),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        const _Drops(flip: true),
      ],
    );
  }
}

/// Khung mẹo cuối bảng: bóng đèn, vạch đứng, mô tả cách chơi.
class _TipBox extends StatelessWidget {
  const _TipBox({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final p = SkyScheme.of(context);
    return Container(
      key: const ValueKey('game-description'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0x66FFFFFF),
        border: Border.all(color: const Color(0xAAFFFFFF), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.accentA, p.accentB],
              ),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          Container(
            width: 2,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: p.glow,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
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

/// Nút × tròn xanh viền trắng ở góc trên phải bảng.
class SkyCloseDisc extends StatelessWidget {
  const SkyCloseDisc({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = SkyScheme.of(context);
    return Tooltip(
      message: 'Đóng',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Sfx.play(SfxKind.back);
          onTap();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.closeA, p.closeB],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

/// Nút viên thuốc: vòng tròn biểu tượng bên trái, tên + mô tả, mũi tên bên phải.
class _Capsule extends StatefulWidget {
  const _Capsule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.plainIcon = false,
    super.key,
  });

  final String title;

  /// null: chỉ có tên nút (nút lớn "BẮT ĐẦU CHƠI").
  final String? subtitle;
  final IconData icon;

  /// true: biểu tượng không có vòng tròn bao quanh, to hơn.
  final bool plainIcon;

  /// Ba màu từ sáng (trên) đến đậm (dưới).
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  State<_Capsule> createState() => _CapsuleState();
}

class _CapsuleState extends State<_Capsule> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Sfx.play(SfxKind.click);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.fromLTRB(14, 12, 18, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(48),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(color: colors.last, offset: Offset(0, _down ? 2 : 5)),
              BoxShadow(
                color: colors[1].withValues(alpha: 0.4),
                blurRadius: 18,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  if (widget.plainIcon)
                    Icon(widget.icon, size: 76, color: Colors.white)
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 3,
                        ),
                      ),
                      child: Icon(widget.icon, size: 46, color: Colors.white),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Một dòng, tự thu nhỏ khi hẹp (điện thoại).
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: widget.plainIcon ? 40 : 32,
                              fontWeight: FontWeight.w900,
                              shadows: const [
                                Shadow(
                                  color: Color(0x88000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Color(0x66000000), blurRadius: 3),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.plainIcon)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
