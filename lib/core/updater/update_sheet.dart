import 'package:flutter/material.dart';
import '../../ui/app_haptics.dart';
import 'app_update_service.dart';

enum _DownloadStatus { idle, downloading, completed, failed }

class UpdateSheet extends StatefulWidget {
  final AppReleaseInfo release;

  const UpdateSheet({super.key, required this.release});

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  _DownloadStatus _status = _DownloadStatus.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _savedFilePath;
  String? _errorMessage;

  void _startDownload() {
    AppHaptics.mediumImpact();
    setState(() {
      _status = _DownloadStatus.downloading;
      _progress = 0.0;
      _errorMessage = null;
    });

    AppUpdateService.instance.downloadApk(
      release: widget.release,
      onProgress: (p, rec, tot) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _receivedBytes = rec;
          _totalBytes = tot;
        });
      },
      onComplete: (filePath) async {
        if (!mounted) return;
        setState(() {
          _status = _DownloadStatus.completed;
          _savedFilePath = filePath;
        });
        AppHaptics.heavyImpact();
        await AppUpdateService.instance.installApk(filePath);
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _status = _DownloadStatus.failed;
          _errorMessage = 'Не удалось скачать файл: $err';
        });
      },
    );
  }

  String _formatMb(int bytes) {
    if (bytes <= 0) return '0 МБ';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  String _formatChangelog(String text) {
    var s = text.trim();
    if (s.isEmpty) {
      return 'В этом обновлении улучшена стабильность и исправлены ошибки.';
    }
    // Remove raw commit hash links or compare links if messy
    s = s.replaceAll(RegExp(r'\*\*Full Changelog\*\*:.*'), '').trim();
    // Clean markdown bold syntax (**text** -> text)
    s = s.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '');
    // Clean markdown link syntax ([text](url) -> text)
    s = s.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1) ?? '');
    // Clean inline code ticks (`code` -> code)
    s = s.replaceAll('`', '');
    return s.isEmpty ? 'В этом обновлении улучшена стабильность и исправлены ошибки.' : s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final release = widget.release;
    final changelog = _formatChangelog(release.changelog);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header icon + title + size
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: cs.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                ),
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: cs.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Доступно обновление',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v${release.version}',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (release.formattedSize.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            release.formattedSize,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Changelog card
          Text(
            'Что нового:',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                changelog,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF2C3240),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Progress or Error state
          if (_status == _DownloadStatus.downloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Загрузка обновления...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                Text(
                  '${_formatMb(_receivedBytes)} / ${_formatMb(_totalBytes)} (${(_progress * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (_status == _DownloadStatus.failed) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage ?? 'Ошибка загрузки',
                style: TextStyle(
                  color: cs.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          if (_status == _DownloadStatus.idle || _status == _DownloadStatus.failed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      AppHaptics.selectionClick();
                      Navigator.of(context).pop();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Позже'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _startDownload,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Обновить',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            )
          else if (_status == _DownloadStatus.completed)
            FilledButton.icon(
              onPressed: () {
                AppHaptics.selectionClick();
                if (_savedFilePath != null) {
                  AppUpdateService.instance.installApk(_savedFilePath!);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.install_mobile_rounded, size: 20),
              label: const Text(
                'Запустить установщик',
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

