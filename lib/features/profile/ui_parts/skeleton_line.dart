part of '../../home/tab_profile.dart';

class _SkeletonLine extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonLine({required this.width, this.height = 12});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ShimmerSkeleton(
        width: width,
        height: height,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
