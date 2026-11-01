import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

@immutable
class AppAccentPalette extends ThemeExtension<AppAccentPalette> {
  final Color accent;

  const AppAccentPalette({required this.accent});

  @override
  AppAccentPalette copyWith({Color? accent}) {
    return AppAccentPalette(accent: accent ?? this.accent);
  }

  @override
  AppAccentPalette lerp(ThemeExtension<AppAccentPalette>? other, double t) {
    if (other is! AppAccentPalette) return this;
    return AppAccentPalette(
      accent: Color.lerp(accent, other.accent, t) ?? accent,
    );
  }
}

@immutable
class AppDensityMetrics extends ThemeExtension<AppDensityMetrics> {
  final double scale;

  const AppDensityMetrics({this.scale = 1.0});

  // Пропорциональные токены плотности интерфейса (от 0.5 до 1.5)
  double get cardPadding => 14.0 * scale;
  double get cardSpacing => 12.0 * scale;
  double get avatarSize => (66.0 * scale).clamp(38.0, 80.0);
  // Нижний бар должен сохранять удобную высоту для тапа и не давать оверфлоу тексту
  double get navBarHeight => (66.0 * scale).clamp(60.0, 78.0);
  double get iconSizeLarge => (28.0 * scale).clamp(18.0, 36.0);
  double get iconSizeMedium => (22.0 * scale).clamp(16.0, 28.0);

  @override
  AppDensityMetrics copyWith({double? scale}) {
    return AppDensityMetrics(scale: scale ?? this.scale);
  }

  @override
  AppDensityMetrics lerp(ThemeExtension<AppDensityMetrics>? other, double t) {
    if (other is! AppDensityMetrics) return this;
    return AppDensityMetrics(
      scale: scale + (other.scale - scale) * t,
    );
  }
}

Color appAccentOf(BuildContext context) {
  final palette = Theme.of(context).extension<AppAccentPalette>();
  return palette?.accent ?? Theme.of(context).colorScheme.primary;
}

AppDensityMetrics appDensityOf(BuildContext context) {
  final metrics = Theme.of(context).extension<AppDensityMetrics>();
  return metrics ?? const AppDensityMetrics();
}

/// Глобальная дизайн-система приложения.
///
/// Задача: единая база для цвета/типографики/скруглений/карточек/кнопок/полей,
/// чтобы дальше допиливать экраны без “зоопарка” стилей.
class AppTheme {
  AppTheme._();

  // ====== Tokens ======
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets cardPadding = EdgeInsets.all(14);

  static const _defaultSeed = Color(0xFF2868EC);

  static Color _boostVibrantDarkColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    // В Material 3 Dark цвета обоев намеренно приглушаются до пастельных (~0.25 сатурации).
    // Режим "Активный" на OxygenOS/ColorOS использует сочный насыщенный акцент (~0.80 сатурации).
    final double boostedSat = (hsv.saturation * 2.5).clamp(0.76, 0.88);
    final double boostedVal = hsv.value.clamp(0.94, 1.0);
    return HSVColor.fromAHSV(1.0, hsv.hue, boostedSat, boostedVal).toColor();
  }

  static Color _boostVibrantLightColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    final double boostedSat = (hsv.saturation * 1.8).clamp(0.70, 0.90);
    final double boostedVal = (hsv.value * 0.90).clamp(0.70, 0.86);
    return HSVColor.fromAHSV(1.0, hsv.hue, boostedSat, boostedVal).toColor();
  }

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData light({
    Color seed = _defaultSeed,
    double uiScale = 1.0,
    ColorScheme? dynamicColorScheme,
  }) {
    final ColorScheme tunedColorScheme;
    final Color effectiveAccent;

    if (dynamicColorScheme != null) {
      final boostedPrimary = _boostVibrantLightColor(dynamicColorScheme.primary);
      effectiveAccent = boostedPrimary;
      tunedColorScheme = dynamicColorScheme.copyWith(
        primary: boostedPrimary,
        onPrimary: Colors.white,
      );
    } else {
      effectiveAccent = seed;
      tunedColorScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: tunedColorScheme,
    );

    final cs = base.colorScheme;

    // Более “чистые” фоны: не серый, а мягкий светлый
    const scaffoldBg = Color(0xFFF7F8FC);

    final text = _textTheme(base.textTheme, cs);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        AppAccentPalette(accent: effectiveAccent),
        AppDensityMetrics(scale: uiScale),
      ],
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: text,
      pageTransitionsTheme: _pageTransitionsTheme,

      // AppBar — плоский, без “жира”
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBg,
        foregroundColor: cs.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),

      // Карточки — единый стиль
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
        ),
      ),

      // Разделители
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: cs.outlineVariant.withOpacity(0.45),
      ),

      // BottomNavigationBar (у вас именно он)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withOpacity(0.62),
        selectedIconTheme: IconThemeData(color: cs.primary),
        unselectedIconTheme: IconThemeData(
          color: cs.onSurface.withOpacity(0.62),
        ),
        showUnselectedLabels: true,
      ),

      // Кнопки
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: cs.outlineVariant.withOpacity(0.65)),
          ),
          textStyle: WidgetStateProperty.all(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: cs.surface,
        hintStyle: text.bodyMedium?.copyWith(
          color: cs.onSurface.withOpacity(0.55),
        ),
        labelStyle: text.bodyMedium?.copyWith(
          color: cs.onSurface.withOpacity(0.75),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.error, width: 1.4),
        ),
      ),

      // Снэкбары — “взрослые”
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),

      // BottomSheet/Dialog — одинаковые скругления
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        contentTextStyle: text.bodyMedium,
      ),

      // ListTile — аккуратнее отступы
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        iconColor: cs.onSurface.withOpacity(0.78),
        titleTextStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: cs.onSurface.withOpacity(0.70),
        ),
      ),
    );
  }

  static ThemeData dark({
    Color seed = _defaultSeed,
    double uiScale = 1.0,
    bool amoled = false,
    ColorScheme? dynamicColorScheme,
  }) {
    final ColorScheme tunedColorScheme;
    final Color effectiveAccent;

    if (dynamicColorScheme != null) {
      final boostedPrimary = _boostVibrantDarkColor(dynamicColorScheme.primary);
      final boostedContainer = _boostVibrantDarkColor(dynamicColorScheme.primaryContainer);
      effectiveAccent = boostedPrimary;
      tunedColorScheme = dynamicColorScheme.copyWith(
        primary: boostedPrimary,
        primaryContainer: boostedContainer,
        onPrimary: Colors.white,
      );
    } else {
      effectiveAccent = seed;
      tunedColorScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
    }

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: tunedColorScheme,
    );

    final cs = base.colorScheme;

    // Тёмная тема: если AMOLED — чистый чёрный, иначе глубокий графит
    final scaffoldBg = amoled ? Colors.black : const Color(0xFF0E1116);
    final cardBg = amoled ? Colors.black : const Color(0xFF141924);
    final navBarBg = amoled ? Colors.black : const Color(0xFF121724);
    final sheetBg = amoled ? Colors.black : const Color(0xFF121724);
    final dialogBg = amoled ? Colors.black : const Color(0xFF141924);
    final cardBorder = amoled
        ? effectiveAccent.withValues(alpha: 0.35)
        : cs.outlineVariant.withValues(alpha: 0.22);
    final dividerColor = amoled
        ? Colors.black
        : cs.outlineVariant.withValues(alpha: 0.25);

    final text = _textTheme(base.textTheme, cs);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        AppAccentPalette(accent: effectiveAccent),
        AppDensityMetrics(scale: uiScale),
      ],
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: text,
      pageTransitionsTheme: _pageTransitionsTheme,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBg,
        foregroundColor: cs.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(
            color: cardBorder,
            width: amoled ? 1.2 : 1.0,
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: dividerColor,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: navBarBg,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withValues(alpha: 0.72),
        selectedIconTheme: IconThemeData(color: cs.primary),
        unselectedIconTheme: IconThemeData(
          color: cs.onSurface.withValues(alpha: 0.72),
        ),
        showUnselectedLabels: true,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          ),
          textStyle: WidgetStateProperty.all(
            text.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: cardBg,
        hintStyle: text.bodyMedium?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
        labelStyle: text.bodyMedium?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.78),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: cs.error, width: 1.4),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: amoled
              ? BorderSide(color: cardBorder, width: 1.2)
              : BorderSide.none,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: amoled
              ? BorderSide(color: cardBorder, width: 1.2)
              : BorderSide.none,
        ),
        titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        contentTextStyle: text.bodyMedium,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        iconColor: cs.onSurface.withValues(alpha: 0.82),
        titleTextStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: cs.onSurface.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme cs) {
    // Чуть сильнее иерархия + читаемость. Без подключения шрифтов.
    return base.copyWith(
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
        color: cs.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
        color: cs.onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.25),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.25),
      bodySmall: base.bodySmall?.copyWith(height: 1.25),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
