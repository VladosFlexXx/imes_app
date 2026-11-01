import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../ui/app_haptics.dart';
import '../../ui/app_theme.dart';

enum RoomType {
  lecture,
  seminar,
  computer,
  admin,
  service,
}

class CampusRoom {
  final String number;
  final String name;
  final int floor;
  final RoomType type;
  final String locationTip;
  final String? features;

  const CampusRoom({
    required this.number,
    required this.name,
    required this.floor,
    required this.type,
    required this.locationTip,
    this.features,
  });
}

const List<CampusRoom> _kCampusRooms = [
  // 1 этаж
  CampusRoom(
    number: 'Гардероб',
    name: 'Центральный гардероб',
    floor: 1,
    type: RoomType.service,
    locationTip: 'Прямо напротив главного входа',
    features: 'Хранение верхней одежды и сменной обуви',
  ),
  CampusRoom(
    number: 'Буфет',
    name: 'Кафетерий и зона отдыха',
    floor: 1,
    type: RoomType.service,
    locationTip: '1 этаж, левое крыло от входа',
    features: 'Горячее питание, кофе, микроволновки, снеки',
  ),
  CampusRoom(
    number: 'Охрана',
    name: 'Пост охраны и бюро пропусков',
    floor: 1,
    type: RoomType.service,
    locationTip: 'При входе справа',
    features: 'Оформление пропусков, утерянные вещи',
  ),
  CampusRoom(
    number: 'Актовый зал',
    name: 'Большой актовый зал',
    floor: 1,
    type: RoomType.lecture,
    locationTip: '1 этаж, правое крыло',
    features: '250 мест, сцена, проектор, звук',
  ),
  CampusRoom(
    number: '101',
    name: 'Лекционная аудитория 101',
    floor: 1,
    type: RoomType.lecture,
    locationTip: '1 этаж, правый коридор',
    features: 'Проектор, микрофон, 60 мест',
  ),
  CampusRoom(
    number: '102',
    name: 'Приемная комиссия',
    floor: 1,
    type: RoomType.admin,
    locationTip: '1 этаж, возле актового зала',
    features: 'Консультации абитуриентов, подача документов',
  ),

  // 2 этаж
  CampusRoom(
    number: '201',
    name: 'Кабинет декана',
    floor: 2,
    type: RoomType.admin,
    locationTip: '2 этаж, по центру напротив лестницы',
    features: 'Приемные часы декана',
  ),
  CampusRoom(
    number: '204',
    name: 'Деканат и Учебный отдел',
    floor: 2,
    type: RoomType.admin,
    locationTip: '2 этаж, направо от лестницы',
    features: 'Справки, заявления, студенческие билеты, сессия',
  ),
  CampusRoom(
    number: '206',
    name: 'Бухгалтерия',
    floor: 2,
    type: RoomType.admin,
    locationTip: '2 этаж, налево по коридору',
    features: 'Договоры, оплата, квитанции',
  ),
  CampusRoom(
    number: '208',
    name: 'Семинарская аудитория 208',
    floor: 2,
    type: RoomType.seminar,
    locationTip: '2 этаж, правое крыло',
    features: '30 мест, интерактивная доска',
  ),
  CampusRoom(
    number: '210',
    name: 'Аудитория 210',
    floor: 2,
    type: RoomType.lecture,
    locationTip: '2 этаж, в конце правого коридора',
    features: 'Проектор, 45 мест',
  ),
  CampusRoom(
    number: '214',
    name: 'Семинарская 214',
    floor: 2,
    type: RoomType.seminar,
    locationTip: '2 этаж, левое крыло',
    features: 'Интерактивный экран, 25 мест',
  ),

  // 3 этаж
  CampusRoom(
    number: '301',
    name: 'Библиотека и коворкинг',
    floor: 3,
    type: RoomType.service,
    locationTip: '3 этаж, прямо от лестницы',
    features: 'Читальный зал, Wi-Fi, компьютеры для работы, тихая зона',
  ),
  CampusRoom(
    number: '305',
    name: 'Кафедра экономики и менеджмента',
    floor: 3,
    type: RoomType.admin,
    locationTip: '3 этаж, направо от лестницы',
    features: 'Преподавательская, консультации к курсовым и дипломам',
  ),
  CampusRoom(
    number: '308',
    name: 'Семинарская аудитория 308',
    floor: 3,
    type: RoomType.seminar,
    locationTip: '3 этаж, правое крыло',
    features: '35 мест, маркерная доска',
  ),
  CampusRoom(
    number: '310',
    name: 'Кафедра иностранных языков',
    floor: 3,
    type: RoomType.admin,
    locationTip: '3 этаж, налево по коридору',
    features: 'Лингафонный класс, преподаватели языков',
  ),
  CampusRoom(
    number: '312',
    name: 'Студенческий совет',
    floor: 3,
    type: RoomType.service,
    locationTip: '3 этаж, в конце левого коридора',
    features: 'Штаб студактива, настольные игры, встречи',
  ),
  CampusRoom(
    number: '315',
    name: 'Лекционная аудитория 315',
    floor: 3,
    type: RoomType.lecture,
    locationTip: '3 этаж, правое крыло',
    features: 'Проектор, кондиционер, 50 мест',
  ),

  // 4 этаж
  CampusRoom(
    number: '401',
    name: 'Компьютерный класс №1',
    floor: 4,
    type: RoomType.computer,
    locationTip: '4 этаж, направо от лестницы',
    features: '24 рабочих места ПК, специализированный софт 1С/Excel',
  ),
  CampusRoom(
    number: '402',
    name: 'Компьютерный класс №2 и IT-отдел',
    floor: 4,
    type: RoomType.computer,
    locationTip: '4 этаж, направо',
    features: '20 ПК, проектор, техподдержка ЭИОС',
  ),
  CampusRoom(
    number: '405',
    name: 'Большая поточная аудитория 405',
    floor: 4,
    type: RoomType.lecture,
    locationTip: '4 этаж, прямо по центру',
    features: 'Амфитеатр, 90 мест, 2 проектора, аудиосистема',
  ),
  CampusRoom(
    number: '410',
    name: 'Семинарская аудитория 410',
    floor: 4,
    type: RoomType.seminar,
    locationTip: '4 этаж, левое крыло',
    features: '30 мест, маркерная доска',
  ),
];

class CampusFloorPlanScreen extends StatefulWidget {
  final String? initialRoom;

  const CampusFloorPlanScreen({super.key, this.initialRoom});

  @override
  State<CampusFloorPlanScreen> createState() => _CampusFloorPlanScreenState();
}

class _CampusFloorPlanScreenState extends State<CampusFloorPlanScreen> {
  int _selectedFloor = 1;
  String _searchQuery = '';
  String? _highlightedRoom;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoom != null && widget.initialRoom!.isNotEmpty) {
      final clean = _extractRoomNumber(widget.initialRoom!);
      _highlightedRoom = clean;
      final matched = _kCampusRooms.firstWhere(
        (r) => r.number.toLowerCase() == clean.toLowerCase(),
        orElse: () => _kCampusRooms.firstWhere(
          (r) => clean.toLowerCase().contains(r.number.toLowerCase()),
          orElse: () => _kCampusRooms.first,
        ),
      );
      _selectedFloor = matched.floor;
    }
  }

  String _extractRoomNumber(String raw) {
    final m = RegExp(r'\d{3}').firstMatch(raw);
    if (m != null) return m.group(0)!;
    return raw.trim();
  }

  IconData _iconForType(RoomType type) {
    switch (type) {
      case RoomType.lecture:
        return Icons.co_present_rounded;
      case RoomType.seminar:
        return Icons.groups_rounded;
      case RoomType.computer:
        return Icons.computer_rounded;
      case RoomType.admin:
        return Icons.admin_panel_settings_rounded;
      case RoomType.service:
        return Icons.storefront_rounded;
    }
  }

  String _labelForType(RoomType type) {
    switch (type) {
      case RoomType.lecture:
        return 'Лекционная';
      case RoomType.seminar:
        return 'Семинарская';
      case RoomType.computer:
        return 'Компьютерный класс';
      case RoomType.admin:
        return 'Администрация';
      case RoomType.service:
        return 'Сервис / Инфраструктура';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = appAccentOf(context);

    final isSearching = _searchQuery.trim().isNotEmpty;
    final filteredRooms = _kCampusRooms.where((r) {
      if (isSearching) {
        final q = _searchQuery.toLowerCase().trim();
        return r.number.toLowerCase().contains(q) ||
            r.name.toLowerCase().contains(q) ||
            r.locationTip.toLowerCase().contains(q) ||
            (r.features?.toLowerCase().contains(q) ?? false);
      }
      return r.floor == _selectedFloor;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Навигатор по корпусу'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Поиск аудитории (например, 204, 305, буфет)...',
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
          ),
          if (!isSearching) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (int floor = 1; floor <= 4; floor++) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.selectionClick();
                          setState(() => _selectedFloor = floor);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _selectedFloor == floor
                                ? accent
                                : (isDark
                                    ? const Color(0xFF1F232A)
                                    : const Color(0xFFE8ECF2)),
                            boxShadow: _selectedFloor == floor
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$floor этаж',
                            style: t.labelLarge?.copyWith(
                              color: _selectedFloor == floor
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: _selectedFloor == floor
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (floor < 4) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: filteredRooms.isEmpty
                ? Center(
                    child: Text(
                      'Аудитория не найдена',
                      style: t.bodyMedium?.copyWith(
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredRooms.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = filteredRooms[i];
                      final isTarget = _highlightedRoom != null &&
                          r.number.toLowerCase() == _highlightedRoom!.toLowerCase();

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: isDark ? const Color(0xFF1A1D22) : Colors.white,
                          border: Border.all(
                            color: isTarget
                                ? accent
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.08)),
                            width: isTarget ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isTarget
                                  ? accent.withValues(alpha: 0.25)
                                  : (isDark
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.04)),
                              blurRadius: isTarget ? 14 : 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                              ),
                              child: Icon(
                                _iconForType(r.type),
                                color: accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Ауд. ${r.number}',
                                        style: t.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          color: isDark
                                              ? const Color(0xFF262A32)
                                              : const Color(0xFFE9EDF4),
                                        ),
                                        child: Text(
                                          _labelForType(r.type),
                                          style: t.labelSmall?.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    r.name,
                                    style: t.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white.withValues(alpha: 0.90) : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.turn_right_rounded,
                                        size: 14,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${r.floor} этаж · ${r.locationTip}',
                                          style: t.bodySmall?.copyWith(
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (r.features != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      r.features!,
                                      style: t.labelSmall?.copyWith(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.45)
                                            : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
