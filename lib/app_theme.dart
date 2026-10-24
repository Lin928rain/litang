import 'package:flutter/material.dart';

/// 上理红白配色。主色为占位的绛红，后续按校徽实际取色微调。
class AppColors {
  static const Color usstRed = Color(0xFFA31C1C);
  static const Color bg = Color(0xFFF6F6F8);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8A8A8E);
  static const Color redTint = Color(0x1FA31C1C); // 12% 红，用于标签底 / 选中态

  /// 绩点颜色分级（默认方案，之后可以按喜好调整）：
  /// ≥4.0 金色、≥3.5 绿色、≥3.0 蓝色、≥2.5 紫色，其余灰色。
  static Color gradeColor(double? gpa) {
    if (gpa == null) {
      return const Color(0xFF8A8A8E);
    }
    if (gpa >= 4.0) {
      return const Color(0xFFB8860B); // 金
    }
    if (gpa >= 3.5) {
      return const Color(0xFF2E8B57); // 绿
    }
    if (gpa >= 3.0) {
      return const Color(0xFF2E6FA3); // 蓝
    }
    if (gpa >= 2.5) {
      return const Color(0xFF6A4C93); // 紫
    }
    return const Color(0xFF8A8A8E); // 灰
  }
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.usstRed)
        .copyWith(primary: AppColors.usstRed);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.redTint,
      ),
    );
  }
}