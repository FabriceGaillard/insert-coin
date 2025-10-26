import 'package:flutter/material.dart';

/// Thème global de l'application.
///
/// Usage : import 'package:your_app/theme/app_theme.dart' puis
/// `MaterialApp(theme: AppTheme.darkTheme, ...)`.
///
/// Ce thème force un fond noir (`scaffoldBackgroundColor`) et des
/// couleurs de texte par défaut en blanc. Vous pouvez personnaliser
/// les couleurs dans `AppTheme.darkTheme` si besoin.
class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF141414),
    primaryColor: const Color(0xFFA5C7FA),
    // Réduire la taille cible tactile par défaut pour permettre des boutons
    // plus compacts (supprime l'espace vertical automatique)
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    // Rend les composants un peu plus compacts globalement
    visualDensity: VisualDensity.compact,

    typography: Typography.material2021().copyWith(
      englishLike: Typography.englishLike2021.apply(fontSizeFactor: 1.2),
      dense: Typography.dense2021.apply(fontSizeFactor: 1.2),
      tall: Typography.tall2021.apply(fontSizeFactor: 1.2),
    ),
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF141414),
      primary: Color(0xFFA5C7FA),
      onPrimary: Color(0xFF052C5E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF141414),
      elevation: 0,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 16),
      toolbarHeight: 56,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(const Color(0xFFA5C7FA)),
        foregroundColor: WidgetStateProperty.all(const Color(0xFF052C5E)),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        minimumSize: WidgetStateProperty.all(const Size(64, 32)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: WidgetStateProperty.all(const StadiumBorder()),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    ),
    // Le thème des dropdowns est géré directement dans le widget
  );
}
