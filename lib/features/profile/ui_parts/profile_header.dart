part of '../../home/tab_profile.dart';

class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;

  const _ProfileHeader({required this.profile});

  String _subtitleLine(UserProfile p) {
    final parts = <String>[];
    final group = p.group;
    final level = p.level;
    final eduForm = p.eduForm;

    if (group != null && group.trim().isNotEmpty) parts.add(group.trim());
    if (level != null && level.trim().isNotEmpty) parts.add(level.trim());
    if (eduForm != null && eduForm.trim().isNotEmpty) parts.add(eduForm.trim());

    return parts.isEmpty ? 'Профиль ЭИОС' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final t = Theme.of(context).textTheme;
    final accent = _profileAccent(context);

    if (p == null) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: const [
              Row(
                children: [
                  _SkeletonCircle(size: 62),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(width: 240, height: 22),
                        SizedBox(height: 8),
                        _SkeletonLine(width: 180, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14),
              _SkeletonLine(width: double.infinity, height: 10),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.88),
            accent.withValues(alpha: 0.66),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AuthAvatar(avatarUrl: p.avatarUrl, radius: 50),
          const SizedBox(height: 12),
          Text(
            p.fullName,
            textAlign: TextAlign.center,
            style: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.96),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _subtitleLine(p),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
