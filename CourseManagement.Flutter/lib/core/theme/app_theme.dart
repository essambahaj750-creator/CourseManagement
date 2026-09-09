import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const double mobile = 600;
  static const double desktop = 1024;

  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < desktop;
  static bool isDesktop(double width) => width >= desktop;
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static EdgeInsets page(double width) {
    if (AppBreakpoints.isMobile(width)) {
      return const EdgeInsets.fromLTRB(16, 18, 16, 108);
    }
    if (AppBreakpoints.isTablet(width)) {
      return const EdgeInsets.fromLTRB(24, 26, 24, 40);
    }
    return const EdgeInsets.fromLTRB(32, 32, 32, 48);
  }
}

abstract final class AppRadius {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 30;
  static const double pill = 999;
}

class AppTheme {
  static const navy = Color(0xFF07182F);
  static const navySoft = Color(0xFF102D51);
  static const blue = Color(0xFF2463EB);
  static const blueDark = Color(0xFF194FCB);
  static const cyan = Color(0xFF12B8A0);
  static const violet = Color(0xFF7159E8);
  static const danger = Color(0xFFD94A68);
  static const success = Color(0xFF169A74);
  static const warning = Color(0xFFE49B2D);
  static const ink = Color(0xFF10213D);
  static const text = Color(0xFF2B405E);
  static const muted = Color(0xFF71829B);
  static const subtle = Color(0xFF96A4B7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF8FAFD);
  static const background = Color(0xFFF4F7FB);
  static const border = Color(0xFFE2E9F2);
  static const borderStrong = Color(0xFFD5DFEC);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [navy, navySoft, Color(0xFF12536D)],
    stops: [0, .58, 1],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [blue, Color(0xFF3E82F8), cyan],
  );

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x1007182F),
          blurRadius: 28,
          offset: Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => const [
        BoxShadow(
          color: Color(0x1607182F),
          blurRadius: 50,
          offset: Offset(0, 20),
        ),
      ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      primary: blue,
      secondary: cyan,
      surface: surface,
      error: danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Cairo',
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: text,
            displayColor: ink,
          )
          .copyWith(
            displaySmall: const TextStyle(
              color: ink,
              fontSize: 36,
              height: 1.22,
              fontWeight: FontWeight.w900,
              letterSpacing: -.55,
            ),
            headlineLarge: const TextStyle(
              color: ink,
              fontSize: 32,
              height: 1.3,
              fontWeight: FontWeight.w900,
              letterSpacing: -.45,
            ),
            headlineMedium: const TextStyle(
              color: ink,
              fontSize: 26,
              height: 1.35,
              fontWeight: FontWeight.w900,
              letterSpacing: -.3,
            ),
            titleLarge: const TextStyle(
              color: ink,
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w900,
              letterSpacing: -.15,
            ),
            titleMedium: const TextStyle(
              color: ink,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w800,
            ),
            bodyLarge: const TextStyle(
              color: text,
              fontSize: 14,
              height: 1.75,
              fontWeight: FontWeight.w500,
            ),
            bodyMedium: const TextStyle(
              color: text,
              fontSize: 13,
              height: 1.7,
              fontWeight: FontWeight.w500,
            ),
            bodySmall: const TextStyle(
              color: muted,
              fontSize: 11,
              height: 1.65,
              fontWeight: FontWeight.w500,
            ),
            labelLarge: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xF7FFFFFF),
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        titleTextStyle: TextStyle(
          color: ink,
          fontFamily: 'Cairo',
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: blue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: border),
        ),
        labelStyle: const TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: const TextStyle(
          color: blue,
          fontWeight: FontWeight.w800,
        ),
        hintStyle: const TextStyle(color: subtle, fontSize: 12),
        prefixIconColor: muted,
        suffixIconColor: muted,
        errorStyle: const TextStyle(
          color: danger,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB8C8EA),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: Colors.white,
          foregroundColor: blue,
          shadowColor: const Color(0x1807182F),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: blue,
          side: const BorderSide(color: borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x1007182F),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        elevation: 0,
        backgroundColor: const Color(0xFCFFFFFF),
        indicatorColor: blue.withValues(alpha: .10),
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? blue : muted,
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? blue : muted,
            size: states.contains(WidgetState.selected) ? 23 : 22,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: navy,
        elevation: 0,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        modalBarrierColor: Color(0x6607182F),
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: borderStrong,
        dragHandleSize: Size(44, 4),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceMuted,
        selectedColor: blue.withValues(alpha: .09),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        secondaryLabelStyle: const TextStyle(
          color: blue,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: blue,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        side: const BorderSide(color: borderStrong, width: 1.2),
      ),
      radioTheme: const RadioThemeData(
        fillColor: WidgetStatePropertyAll(blue),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        waitDuration: const Duration(milliseconds: 350),
      ),
    );
  }
}
