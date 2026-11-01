part of '../../home/tab_profile.dart';

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _SkeletonCircle(size: 22),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonLine(width: 140, height: 14),
              SizedBox(height: 8),
              _SkeletonLine(width: double.infinity, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

