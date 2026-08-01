import 'package:fluent_ui/fluent_ui.dart';

// ── 기본 shimmer 애니메이션 래퍼 ──────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE8E8E8);
    final highlight = isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0.0, 0.5, 1.0],
            colors: [base, highlight, base],
            transform: _SlidingGradientTransform(slidePercent: _anim.value),
          ),
        ),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

// ── 카드 형태의 shimmer (width: infinity) ─────────────────────────────────────
class ShimmerCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final double borderRadius;

  const ShimmerCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ── 공통 shimmer 빌더 헬퍼 ───────────────────────────────────────────────────
class Shimmer extends StatelessWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;

  // 편의 생성자들
  static ShimmerBox box({
    double width = double.infinity,
    double height = 14,
    double radius = 6,
    Key? key,
  }) =>
      ShimmerBox(key: key, width: width, height: height, borderRadius: radius);

  static Widget circle({double size = 40, Key? key}) =>
      ShimmerBox(key: key, width: size, height: size, borderRadius: size / 2);
}

// ── 학생 목록 카드 shimmer ────────────────────────────────────────────────────
class StudentCardShimmer extends StatelessWidget {
  const StudentCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      children: [
        Row(
          children: [
            Shimmer.circle(size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.box(width: 100, height: 14),
                  const SizedBox(height: 6),
                  Shimmer.box(width: 160, height: 12),
                ],
              ),
            ),
            Shimmer.box(width: 60, height: 22, radius: 4),
          ],
        ),
        const SizedBox(height: 10),
        Shimmer.box(width: double.infinity, height: 12),
        const SizedBox(height: 6),
        Shimmer.box(width: 200, height: 12),
      ],
    );
  }
}

// ── 청소점검 스케줄 카드 shimmer ──────────────────────────────────────────────
class ScheduleCardShimmer extends StatelessWidget {
  const ScheduleCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      children: [
        Row(
          children: [
            Shimmer.box(width: 36, height: 36, radius: 4),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.box(width: 120, height: 13),
                  const SizedBox(height: 6),
                  Shimmer.box(width: 80, height: 11),
                ],
              ),
            ),
            Shimmer.box(width: 52, height: 22, radius: 4),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Shimmer.box(width: 70, height: 11),
            const SizedBox(width: 12),
            Shimmer.box(width: 90, height: 11),
          ],
        ),
      ],
    );
  }
}

// ── 신청 카드 shimmer ─────────────────────────────────────────────────────────
class RequestCardShimmer extends StatelessWidget {
  const RequestCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      children: [
        Row(
          children: [
            Shimmer.box(width: 18, height: 18, radius: 9),
            const SizedBox(width: 8),
            Expanded(child: Shimmer.box(width: 160, height: 14)),
            Shimmer.box(width: 52, height: 22, radius: 4),
          ],
        ),
        const SizedBox(height: 10),
        Shimmer.box(width: 140, height: 12),
        const SizedBox(height: 6),
        Shimmer.box(width: double.infinity, height: 12),
      ],
    );
  }
}

// ── 출석 이벤트 카드 shimmer ──────────────────────────────────────────────────
class AttendanceEventShimmer extends StatelessWidget {
  const AttendanceEventShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      children: [
        Row(
          children: [
            Expanded(child: Shimmer.box(width: 140, height: 15)),
            Shimmer.box(width: 56, height: 22, radius: 4),
          ],
        ),
        const SizedBox(height: 8),
        Shimmer.box(width: 100, height: 12),
        const SizedBox(height: 6),
        Shimmer.box(width: 160, height: 12),
      ],
    );
  }
}

// ── 출석 학생 행 shimmer ──────────────────────────────────────────────────────
class AttendanceRowShimmer extends StatelessWidget {
  const AttendanceRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE),
          ),
        ),
      ),
      child: Row(
        children: [
          Shimmer.circle(size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.box(width: 80, height: 13),
                const SizedBox(height: 5),
                Shimmer.box(width: 120, height: 11),
              ],
            ),
          ),
          Shimmer.box(width: 80, height: 28, radius: 4),
        ],
      ),
    );
  }
}

// ── 공지사항 카드 shimmer ─────────────────────────────────────────────────────
class NoticeCardShimmer extends StatelessWidget {
  const NoticeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      children: [
        Row(
          children: [
            Expanded(child: Shimmer.box(width: 200, height: 15)),
            Shimmer.box(width: 44, height: 11),
          ],
        ),
        const SizedBox(height: 8),
        Shimmer.box(width: double.infinity, height: 12),
        const SizedBox(height: 5),
        Shimmer.box(width: 240, height: 12),
        const SizedBox(height: 10),
        Row(
          children: [
            Shimmer.box(width: 80, height: 11),
            const SizedBox(width: 12),
            Shimmer.box(width: 60, height: 11),
          ],
        ),
      ],
    );
  }
}

// ── 시설신고 카드 shimmer ─────────────────────────────────────────────────────
class FacilityCardShimmer extends StatelessWidget {
  const FacilityCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      children: [
        Row(
          children: [
            Shimmer.box(width: 56, height: 22, radius: 4),
            const SizedBox(width: 8),
            Expanded(child: Shimmer.box(width: 140, height: 14)),
            Shimmer.box(width: 52, height: 22, radius: 4),
          ],
        ),
        const SizedBox(height: 10),
        Shimmer.box(width: double.infinity, height: 12),
        const SizedBox(height: 6),
        Row(
          children: [
            Shimmer.box(width: 80, height: 11),
            const SizedBox(width: 12),
            Shimmer.box(width: 100, height: 11),
          ],
        ),
      ],
    );
  }
}

// ── 게시판 카드 shimmer ───────────────────────────────────────────────────────
class BoardCardShimmer extends StatelessWidget {
  const BoardCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerCard(
      children: [
        Row(
          children: [
            Shimmer.box(width: 44, height: 20, radius: 4),
            const SizedBox(width: 8),
            Expanded(child: Shimmer.box(width: 180, height: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Shimmer.box(width: double.infinity, height: 12),
        const SizedBox(height: 5),
        Shimmer.box(width: 200, height: 12),
        const SizedBox(height: 10),
        Row(
          children: [
            Shimmer.box(width: 70, height: 11),
            const SizedBox(width: 10),
            Shimmer.box(width: 50, height: 11),
            const SizedBox(width: 10),
            Shimmer.box(width: 50, height: 11),
          ],
        ),
      ],
    );
  }
}

// ── 메시지 학생 행 shimmer ────────────────────────────────────────────────────
class MessageStudentRowShimmer extends StatelessWidget {
  const MessageStudentRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFEEEEEE),
          ),
        ),
      ),
      child: Row(
        children: [
          Shimmer.box(width: 18, height: 18, radius: 3),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.box(width: 80, height: 13),
                const SizedBox(height: 5),
                Shimmer.box(width: 140, height: 11),
              ],
            ),
          ),
          Shimmer.box(width: 48, height: 20, radius: 4),
        ],
      ),
    );
  }
}

// ── n개짜리 shimmer 리스트 빌더 ───────────────────────────────────────────────
class ShimmerList extends StatelessWidget {
  final Widget Function() itemBuilder;
  final int count;
  final EdgeInsets padding;

  const ShimmerList({
    super.key,
    required this.itemBuilder,
    this.count = 6,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, _) => itemBuilder(),
    );
  }
}
