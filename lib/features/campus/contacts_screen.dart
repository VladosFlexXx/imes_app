import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ui/app_haptics.dart';
import '../../ui/app_theme.dart';

class DepartmentContact {
  final String title;
  final String description;
  final String room;
  final String hours;
  final String? phone;
  final String? email;
  final String? telegram;
  final IconData icon;

  const DepartmentContact({
    required this.title,
    required this.description,
    required this.room,
    required this.hours,
    this.phone,
    this.email,
    this.telegram,
    required this.icon,
  });
}

const List<DepartmentContact> _kCampusContacts = [
  DepartmentContact(
    title: 'Деканат и Учебная часть',
    description: 'Организация обучения, перевод, отчисления, допуски к сессии',
    room: 'Каб. 204 (2 этаж)',
    hours: 'Пн–Пт: 09:00 – 18:00',
    phone: '+7 (499) 143-08-32',
    email: 'dekanat@imes.su',
    telegram: 'https://t.me/imes_dekanat',
    icon: Icons.school_rounded,
  ),
  DepartmentContact(
    title: 'Бухгалтерия и Договорной отдел',
    description: 'Оплата обучения, квитанции, справки об оплате, маткапитал',
    room: 'Каб. 206 (2 этаж)',
    hours: 'Пн–Пт: 10:00 – 17:00',
    phone: '+7 (499) 348-20-00',
    email: 'buh@imes.su',
    telegram: null,
    icon: Icons.account_balance_wallet_rounded,
  ),
  DepartmentContact(
    title: 'Техподдержка ЭИОС и IT',
    description: 'Доступ в личный кабинет, сброс паролей, ошибки сервисов',
    room: 'Каб. 402 (4 этаж)',
    hours: 'Пн–Пт: 09:30 – 18:00',
    phone: '+7 (499) 348-20-00',
    email: 'support@imes.su',
    telegram: 'https://t.me/imes_support_bot',
    icon: Icons.laptop_chromebook_rounded,
  ),
  DepartmentContact(
    title: 'Библиотека и ЭБС',
    description: 'Учебные пособия, методички, доступ к электронным базам',
    room: 'Каб. 301 (3 этаж)',
    hours: 'Пн–Пт: 10:00 – 17:30',
    phone: '+7 (499) 143-08-32',
    email: 'library@imes.su',
    telegram: null,
    icon: Icons.local_library_rounded,
  ),
  DepartmentContact(
    title: 'Приемная комиссия',
    description: 'Поступление, восстановление, магистратура, перевод из других вузов',
    room: 'Каб. 102 (1 этаж)',
    hours: 'Пн–Пт: 09:00 – 19:00, Сб: 10:00 – 15:00',
    phone: '+7 (499) 348-20-00',
    email: 'priem@imes.su',
    telegram: 'https://t.me/imes_official',
    icon: Icons.badge_rounded,
  ),
  DepartmentContact(
    title: 'Студенческий совет ИМЭС',
    description: 'Мероприятия, волонтерство, клубная жизнь, внеучебка',
    room: 'Каб. 312 (3 этаж)',
    hours: 'Пн–Пт: 12:00 – 18:00',
    phone: null,
    email: 'studsovet@imes.su',
    telegram: 'https://t.me/imes_stud',
    icon: Icons.groups_rounded,
  ),
];

class CampusContactsScreen extends StatefulWidget {
  const CampusContactsScreen({super.key});

  @override
  State<CampusContactsScreen> createState() => _CampusContactsScreenState();
}

class _CampusContactsScreenState extends State<CampusContactsScreen> {
  String _searchQuery = '';

  Future<void> _makeCall(String phone) async {
    AppHaptics.lightImpact();
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copy(phone, 'Номер скопирован');
    }
  }

  Future<void> _sendEmail(String email) async {
    AppHaptics.lightImpact();
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _copy(email, 'Email скопирован');
    }
  }

  Future<void> _openTg(String url) async {
    AppHaptics.lightImpact();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _copy(url, 'Ссылка скопирована');
    }
  }

  void _copy(String text, String toast) {
    AppHaptics.selectionClick();
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(toast),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = appAccentOf(context);

    final filtered = _kCampusContacts.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.room.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Контакты ИМЭС'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск отдела или кабинета...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1E2228)
                  : const Color(0xFFF1F3F7),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Ничего не найдено',
                  style: t.bodyMedium?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ),
          ] else ...[
            for (final c in filtered) ...[
              _ContactCard(
                contact: c,
                accent: accent,
                isDark: isDark,
                onCall: c.phone != null ? () => _makeCall(c.phone!) : null,
                onEmail: c.email != null ? () => _sendEmail(c.email!) : null,
                onTelegram: c.telegram != null ? () => _openTg(c.telegram!) : null,
                onCopyRoom: () => _copy(c.room, 'Кабинет скопирован'),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final DepartmentContact contact;
  final Color accent;
  final bool isDark;
  final VoidCallback? onCall;
  final VoidCallback? onEmail;
  final VoidCallback? onTelegram;
  final VoidCallback onCopyRoom;

  const _ContactCard({
    required this.contact,
    required this.accent,
    required this.isDark,
    this.onCall,
    this.onEmail,
    this.onTelegram,
    required this.onCopyRoom,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1A1D22) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                ),
                child: Icon(contact.icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.title,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.description,
                      style: t.bodySmall?.copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.65)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              InkWell(
                onTap: onCopyRoom,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isDark
                        ? const Color(0xFF252932)
                        : const Color(0xFFEEF2F8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        contact.room,
                        style: t.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isDark
                      ? const Color(0xFF252932)
                      : const Color(0xFFEEF2F8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      contact.hours,
                      style: t.labelSmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (onCall != null) ...[
                Expanded(
                  child: _ActionButton(
                    icon: Icons.phone_rounded,
                    label: 'Позвонить',
                    onTap: onCall!,
                    accent: accent,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (onEmail != null) ...[
                Expanded(
                  child: _ActionButton(
                    icon: Icons.mail_rounded,
                    label: 'Email',
                    onTap: onEmail!,
                    accent: accent,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (onTelegram != null) ...[
                Expanded(
                  child: _ActionButton(
                    icon: Icons.send_rounded,
                    label: 'Telegram',
                    onTap: onTelegram!,
                    accent: accent,
                    isDark: isDark,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: isDark ? 0.14 : 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

