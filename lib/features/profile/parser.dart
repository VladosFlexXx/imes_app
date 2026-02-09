import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'models.dart';

class ProfileParser {
  static ({
    String fullName,
    String? avatarUrl,
    String? profileUrl,
    String? editUrl
  }) parseFromMy(String html) {
    final doc = html_parser.parse(html);

    // Ищем имя максимально аккуратно:
    // иногда .usertext может быть "Блоки" и т.п.
    final nameCandidates = <String?>[
      doc.querySelector('.usermenu .usertext')?.text,
      doc.querySelector('.navbar .usermenu .usertext')?.text,
      doc.querySelector('.usertext')?.text,
      doc.querySelector('header .usermenu .usertext')?.text,
      doc.querySelector('.user-menu .usertext')?.text,
    ];

    String name = '';
    for (final raw in nameCandidates.whereType<String>()) {
      final cleaned = _clean(raw);
      if (cleaned.isEmpty) continue;
      if (_looksNotAName(cleaned)) continue;
      if (_looksLikeFullName(cleaned)) {
        name = cleaned;
        break;
      }
      // если не похоже на ФИО, но всё равно адекватная строка — держим как запасной вариант
      if (name.isEmpty && cleaned.length < 80) {
        name = cleaned;
      }
    }

    if (name.isEmpty || _looksNotAName(name)) {
      final title = _clean(doc.querySelector('title')?.text ?? '');
      if (title.isNotEmpty && !_looksNotAName(title)) {
        name = title;
      }
    }

    if (name.length > 80) name = name.substring(0, 80);
    if (name.trim().isEmpty) name = 'Студент';

    // аватар
    final avatar = _extractAvatarFromDoc(doc);

    // ссылки
    String? profileUrl;
    String? editUrl;

    for (final a in doc.querySelectorAll('a')) {
      final href = a.attributes['href'];
      if (href == null) continue;

      if (profileUrl == null &&
          (href.contains('user/profile.php') || href.contains('/user/profile.php'))) {
        profileUrl = href;
      }
      if (editUrl == null &&
          (href.contains('user/edit.php') || href.contains('/user/edit.php'))) {
        editUrl = href;
      }
    }

    return (fullName: name, avatarUrl: avatar, profileUrl: profileUrl, editUrl: editUrl);
  }

  static String? parseAvatarFromProfilePage(String html) {
    final doc = html_parser.parse(html);
    return _extractAvatarFromDoc(doc);
  }

  /// Парсит ВСЕ поля со страницы редактирования профиля.
  static UserProfile parseEditPage(
    String html, {
    required String fallbackFullName,
    String? fallbackAvatarUrl,
  }) {
    final doc = html_parser.parse(html);

    // имя (иногда есть в заголовке)
    var fullName = fallbackFullName;
    final h2 = _clean(doc.querySelector('h2')?.text ?? '');
    if (h2.isNotEmpty && h2.length < 80 && !_looksNotAName(h2)) {
      fullName = h2;
    }

    // аватар
    final pageAvatar = _extractAvatarFromDoc(doc);
    final avatarUrl = (pageAvatar != null && pageAvatar.trim().isNotEmpty)
        ? pageAvatar
        : fallbackAvatarUrl;

    final fields = <String, String>{};

    // Moodle формы: .fitem (старый), .form-group (новый Bootstrap)
    final groups = doc.querySelectorAll('.fitem, .form-group');

    for (final g in groups) {
      final labelEl = g.querySelector('label');
      var label = _clean(labelEl?.text ?? '');
      if (label.isEmpty) continue;

      // чистим label от ":" и "*"
      label = label.replaceAll('*', '').trim();
      if (label.endsWith(':')) label = label.substring(0, label.length - 1).trim();
      if (label.isEmpty) continue;

      if (_looksSensitive(label)) continue;

      String value = '';

      // input value (берём первый "нормальный" input)
      final inputs = g.querySelectorAll('input');
      for (final input in inputs) {
        final type = (input.attributes['type'] ?? '').toLowerCase();
        if (type == 'password' || type == 'hidden') continue;

        final v = (input.attributes['value'] ?? '').toString();
        if (_clean(v).isNotEmpty) {
          value = v;
          break;
        }
      }

      // textarea
      if (value.isEmpty) {
        final ta = g.querySelector('textarea');
        if (ta != null) value = ta.text;
      }

      // select selected option
      if (value.isEmpty) {
        final select = g.querySelector('select');
        if (select != null) {
          final opt = select.querySelector('option[selected]');
          if (opt != null) value = opt.text;

          if (value.isEmpty) {
            // fallback: иногда selected не проставлен
            value = select.querySelector('option')?.text ?? '';
          }
        }
      }

      // статичное значение
      if (value.isEmpty) {
        final staticVal = g.querySelector(
          '.form-control-static, .fstatic, .text-muted, .felement',
        );
        if (staticVal != null) value = staticVal.text;
      }

      value = _clean(value);
      if (value.isEmpty) continue;

      fields[label] = value;
    }

    return UserProfile(
      fullName: fullName,
      avatarUrl: avatarUrl,
      fields: fields,
    );
  }

  static bool _looksSensitive(String label) {
    final l = label.toLowerCase();
    return l.contains('пароль') ||
        l.contains('password') ||
        l.contains('token') ||
        l.contains('токен') ||
        l.contains('csrf');
  }

  static bool _looksNotAName(String s) {
    final l = s.toLowerCase().trim();

    // частые ложные значения на /my/
    const bad = {
      'блоки',
      'навигация',
      'меню',
      'профиль',
      'настройки',
      'выход',
      'войти',
      'eios',
      'эиос',
      'moodle',
    };
    if (bad.contains(l)) return true;

    // если похоже на заголовок страницы/раздела, а не на имя
    if (l.length <= 3) return true;
    if (l.contains('http') || l.contains('://')) return true;

    return false;
  }

  static bool _looksLikeFullName(String s) {
    final parts = s.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    if (parts.length < 2) return false;

    // если слишком много слов — скорее не ФИО
    if (parts.length > 5) return false;

    // хотя бы 2 "нормальных" слова длиной 2+
    final okWords = parts.where((p) => p.length >= 2).length;
    if (okWords < 2) return false;

    // без цифр
    if (RegExp(r'\d').hasMatch(s)) return false;

    return true;
  }

  static String? _extractAvatarFromDoc(dom.Document doc) {
    final candidates = <dom.Element?>[
      doc.querySelector('.usermenu img.userpicture'),
      doc.querySelector('.userpicture img'),
      doc.querySelector('.avatar.current img'),
      doc.querySelector('.userprofile img.userpicture'),
      doc.querySelector('.page-context-header img.userpicture'),
      doc.querySelector('img.userpicture'),
      doc.querySelector('.usermenu img'),
    ];

    for (final el in candidates.whereType<dom.Element>()) {
      final direct = _extractImageUrlFromElement(el);
      if (direct != null) return direct;
    }

    // Иногда аватар задается как background-image на span/div.
    final bgCandidates = doc.querySelectorAll(
      '.avatar.current, .usermenu .avatar, .userpicture, [style*="background-image"]',
    );
    for (final el in bgCandidates) {
      final bg = _extractBackgroundImage(el.attributes['style']);
      if (bg != null) return bg;
    }

    return null;
  }

  static String? _extractImageUrlFromElement(dom.Element el) {
    final src = _clean(el.attributes['src'] ?? '');
    if (src.isNotEmpty) return src;

    final dataSrc = _clean(el.attributes['data-src'] ?? '');
    if (dataSrc.isNotEmpty) return dataSrc;

    final srcset = _clean(el.attributes['srcset'] ?? '');
    if (srcset.isNotEmpty) {
      final first = srcset.split(',').first.trim().split(' ').first.trim();
      if (first.isNotEmpty) return first;
    }

    return _extractBackgroundImage(el.attributes['style']);
  }

  static String? _extractBackgroundImage(String? style) {
    final s = style ?? '';
    if (s.isEmpty) return null;
    final m = RegExp(
      r'background-image\s*:\s*url\(([^)]+)\)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m == null) return null;
    var url = _clean(m.group(1) ?? '');
    if (url.startsWith('"') && url.endsWith('"') && url.length > 1) {
      url = url.substring(1, url.length - 1);
    } else if (url.startsWith("'") && url.endsWith("'") && url.length > 1) {
      url = url.substring(1, url.length - 1);
    }
    return url.isEmpty ? null : url;
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
