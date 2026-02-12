import 'package:flutter/material.dart';

class ShimmerSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadiusGeometry borderRadius;

  const ShimmerSkeleton({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF252D3E) : const Color(0xFFE3E9F3);
    final hi = isDark ? const Color(0xFF3D4A64) : const Color(0xFFF7FAFF);

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final shift = -1.0 + (_controller.value * 2.6);
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(shift, -0.25),
                end: Alignment(shift + 1.0, 0.25),
                colors: [base, hi, base],
                stops: const [0.25, 0.5, 0.75],
              ).createShader(bounds);
            },
            child: Container(
              width: widget.width,
              height: widget.height,
              color: base,
            ),
          );
        },
      ),
    );
  }
}

class LoadingSkeletonStrip extends StatelessWidget {
  final double height;

  const LoadingSkeletonStrip({super.key, this.height = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      width: double.infinity,
      height: height,
      borderRadius: BorderRadius.circular(999),
    );
  }
}
