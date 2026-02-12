part of '../../home/tab_profile.dart';

class _SkeletonCircle extends StatelessWidget {
  final double size;
  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: ShimmerSkeleton(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}
