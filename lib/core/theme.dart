import 'package:flutter/material.dart';

/// Colours taken from the Tod Cleaning Services logo.
class Brand {
  Brand._();

  static const Color navy = Color(0xFF1F3F7A);
  static const Color navyDark = Color(0xFF0B2A5B);
  static const Color green = Color(0xFF5BA11D);
  static const Color blue = Color(0xFF2F6DB5);
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: Brand.navy,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: brightness == Brightness.light ? Brand.navy : const Color(0xFF9DB8EA),
      onPrimary: brightness == Brightness.light ? Colors.white : Brand.navyDark,
      secondary: Brand.green,
    );
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? const Color(0xFFF1F4F9) : const Color(0xFF0E1420),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? Colors.white : const Color(0xFF151C2B),
        foregroundColor: isLight ? Brand.navyDark : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : const Color(0xFF172033),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isLight ? const Color(0xFFE3E8F1) : const Color(0xFF263149),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : const Color(0xFF172033),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(isLight ? const Color(0xFFD5DCE8) : const Color(0xFF263149)),
        enabledBorder:
            _inputBorder(isLight ? const Color(0xFFD5DCE8) : const Color(0xFF263149)),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isLight ? Colors.white : const Color(0xFF151C2B),
        indicatorColor: Brand.navy.withValues(alpha: isLight ? 0.12 : 0.35),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: Brand.green, width: 3),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF172033),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: isLight ? Colors.white : const Color(0xFF172033),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Brand.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: Brand.green),
      dividerTheme: DividerThemeData(
        color: isLight ? const Color(0xFFE3E8F1) : const Color(0xFF263149),
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
