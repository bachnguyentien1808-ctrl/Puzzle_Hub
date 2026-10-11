import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:puzzle_hub/core/ui/candy.dart';
import 'package:puzzle_hub/features/common/start_menu.dart';

/// Khung trang dùng chung (Cài đặt, Thống kê, Hướng dẫn): bảng sáng màu trời,
/// huy hiệu nổi phía trên, tên trang chữ trắng viền xanh, nút × ở góc. Phần
/// [children] cuộn được bên trong bảng.
class SkyPage extends StatelessWidget {
  const SkyPage({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.onClose,
    this.warm = false,
    super.key,
  });

  /// true: bảng màu ấm đồng/vàng (Tổng điểm, Thử thách).
  final bool warm;

  final String title;
  final IconData icon;
  final String? subtitle;
  final List<Widget> children;

  /// Mặc định: quay lại trang trước, hoặc về trang chủ nếu không có.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    void close() {
      if (onClose != null) {
        onClose!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/');
      }
    }

    final outline = warm ? const Color(0xFF7A4A21) : skyNavy;
    return SkyScheme(
      palette: warm ? SkyPalette.warm : SkyPalette.sky,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 74),
                      child: SkyPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 92),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                shadows: [
                                  ...skyOutline(outline, 3.5),
                                  const Shadow(
                                    color: Color(0x88000000),
                                    offset: Offset(0, 5),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                            if (subtitle != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  6,
                                  20,
                                  0,
                                ),
                                child: Text(
                                  subtitle!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: warm
                                        ? const Color(0xFF9A6B3C)
                                        : const Color(0xFF3B5BA8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  4,
                                  20,
                                  28,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: children,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(child: SkyMedallion(icon: icon)),
                    ),
                    Positioned(
                      top: 94,
                      right: 18,
                      child: SkyCloseDisc(onTap: close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhãn nhóm trong trang: vòng tròn màu chứa biểu tượng + chữ xanh đậm.
class SkySection extends StatelessWidget {
  const SkySection(this.text, this.icon, {this.color = skyNavy, super.key});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.3)!, color],
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
            child: Icon(icon, size: 19, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: TextStyle(
              color: SkyScheme.ink(context),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ nội dung trắng mờ viền xanh, dùng chung cho các trang kiểu trời.
class SkyCard extends StatelessWidget {
  const SkyCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final warm = SkyScheme.warmOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: warm ? const Color(0xE6FFFAF0) : const Color(0xCCFFFFFF),
        border: Border.all(
          color: warm ? Candy.gold : const Color(0xFF8FD0FF),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Hạng huy hiệu: màu viền/ruột theo mức khó đạt.
enum SkyTier {
  bronze(Color(0xFFE8A06A), Color(0xFFB4642B)),
  silver(Color(0xFFCFD8E6), Color(0xFF8795AD)),
  gold(Color(0xFFFFD84A), Color(0xFFE59A12)),
  diamond(Color(0xFF8AE3FF), Color(0xFF2E7BE0));

  SkyTier(this.light, this.dark);

  final Color light;
  final Color dark;

  String get label => switch (this) {
    bronze => 'Đồng',
    silver => 'Bạc',
    gold => 'Vàng',
    diamond => 'Kim cương',
  };
}

/// Ô huy hiệu: huy chương tròn theo hạng (khoá thì xám + ổ khoá), tên, mô tả,
/// thanh tiến độ khi chưa đạt.
class SkyBadgeTile extends StatelessWidget {
  const SkyBadgeTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.value,
    required this.target,
    this.tier = SkyTier.gold,
    super.key,
  });

  final IconData icon;
  final String title;
  final String desc;
  final int value;
  final int target;
  final SkyTier tier;

  bool get unlocked => value >= target;

  @override
  Widget build(BuildContext context) {
    final on = unlocked;
    return SkyCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: on
                        ? [tier.light, tier.dark]
                        : const [Color(0xFFE3E8F0), Color(0xFFB6C0D0)],
                  ),
                  border: Border.all(
                    color: on ? Colors.white : const Color(0xFFD5DCE8),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: on
                          ? tier.dark.withValues(alpha: .55)
                          : const Color(0x22000000),
                      blurRadius: on ? 10 : 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  on ? icon : Icons.lock_rounded,
                  color: on ? Colors.white : const Color(0xFF8795AD),
                  size: 32,
                  shadows: on
                      ? const [Shadow(color: Color(0x66000000), blurRadius: 3)]
                      : null,
                ),
              ),
              if (on)
                const Positioned(
                  right: -4,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF3FA535),
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SkyScheme.ink(context),
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          Text(
            desc,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SkyScheme.inkSoft(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          if (on)
            Text(
              'Hạng ${tier.label}',
              style: TextStyle(
                color: tier.dark,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (value / target).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: SkyScheme.warmOf(context)
                    ? const Color(0xFFF2DFC0)
                    : const Color(0xFFD5E6FA),
                valueColor: AlwaysStoppedAnimation(tier.dark),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$value/$target',
              style: TextStyle(
                color: SkyScheme.inkSoft(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lưới huy hiệu 2 cột (điện thoại) hoặc 3 cột (màn rộng).
class SkyBadgeGrid extends StatelessWidget {
  const SkyBadgeGrid({required this.badges, super.key});

  final List<SkyBadgeTile> badges;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 520 ? 3 : 2;
        const gap = 10.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final b in badges) SizedBox(width: w, child: b)],
        );
      },
    );
  }
}
