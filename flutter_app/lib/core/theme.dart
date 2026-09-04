import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 隐财 (Yincai) 应用主题配置
///
/// 品牌设计规范：Cryptic Sanctuary
/// - 翡翠绿 (#059669): 主品牌色，象征增长与安全
/// - 琥珀橙 (#F59E0B): 警告提示、高亮强调
class AppTheme {
  // ========== 品牌主色系 ==========
  /// 翡翠绿 - 主品牌色、导航栏、按钮
  static const Color primaryColor = successColor;

  /// 翡翠绿 - 成功状态、安全验证、增长指标
  static const Color successColor = Color(0xFF059669);

  /// 琥珀橙 - 警告提示、注意事项
  static const Color warningColor = Color(0xFFF59E0B);

  /// 错误色 - 错误状态
  static const Color errorColor = Color(0xFFDC2626);

  // ========== 数据展示专用色（高对比度，适配米白背景） ==========
  /// 资产金额色 - 深绿色，在米白背景 #FAF9F5 上清晰可见
  static const Color assetAmountColor = Color(0xFF2E7D32);

  /// 负债金额色 - 深红色，在米白背景上清晰可见
  static const Color liabilityAmountColor = Color(0xFFC62828);

  /// 盈利色 - 中国股市：红色表示盈利（鲜艳）
  static const Color profitColor = Color(0xFFD32F2F);

  /// 亏损色 - 中国股市：绿色表示亏损（鲜艳）
  static const Color lossColor = Color(0xFF388E3C);

  /// 净资产正值色 - 深绿色
  static const Color netAssetPositiveColor = Color(0xFF2E7D32);

  /// 净资产负值色 - 深红色
  static const Color netAssetNegativeColor = Color(0xFFB71C1C);

  // ========== 深色主题数据展示专用色（浅色，适配深色背景） ==========
  /// 资产金额色（深色主题）- 浅绿色，清晰醒目
  static const Color assetAmountColorDark = Color(0xFF66BB6A);

  /// 负债金额色（深色主题）- 浅红色
  static const Color liabilityAmountColorDark = Color(0xFFEF5350);

  /// 盈利色（深色主题）- 浅红色
  static const Color profitColorDark = Color(0xFFFF5252);

  /// 亏损色（深色主题）- 浅绿色
  static const Color lossColorDark = Color(0xFF81C784);

  /// 净资产正值色（深色主题）- 浅绿色
  static const Color netAssetPositiveColorDark = Color(0xFF81C784);

  /// 净资产负值色（深色主题）- 浅红色
  static const Color netAssetNegativeColorDark = Color(0xFFE57373);

  // ========== 品牌中性色系 ==========
  /// 深色 - 主要文字、深色背景
  static const Color textPrimary = Color(0xFF141413);

  /// 中灰 - 次要文字、分割线
  static const Color textSecondary = Color(0xFFB0AEA5);

  /// 浅灰 - 边框、禁用状态
  static const Color borderLight = Color(0xFFE8E6DC);

  /// 米白 - 卡片背景、浅色主题背景
  static const Color surfaceLight = Color(0xFFFAF9F5);

  // ========== 深色主题专用色 ==========
  /// 深色背景
  static const Color darkBackground = Color(0xFF0A0F1D);

  /// 深色表面
  static const Color darkSurface = Color(0xFF141C2F);

  /// 深色边框
  static const Color darkBorder = Color(0xFF2A3548);

  // ========== 浅色主题 ==========
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: defaultTargetPlatform == TargetPlatform.windows
          ? 'Microsoft YaHei' // Windows 中文字体
          : null, // 其他平台用系统默认中文字体
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: successColor,
        error: errorColor,
        surface: surfaceLight,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: borderLight),
        ),
        color: Colors.white,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.7,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ========== 深色主题 ==========
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: defaultTargetPlatform == TargetPlatform.windows
          ? 'Microsoft YaHei' // Windows 中文字体
          : null, // 其他平台用系统默认中文字体
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: successColor,
        error: errorColor,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onError: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: darkBorder),
        ),
        color: darkSurface,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.3,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.7,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Colors.white70,
          letterSpacing: -0.3,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.white70,
          letterSpacing: -0.2,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.white54,
          letterSpacing: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ========== 品牌信息 ==========
  /// 应用中文名
  static const String appName = '隐财';

  /// 品牌标语
  static const String tagline = '你的资产，只有你知道';

  /// 副标语
  static const String subtitle = '一本加密的家庭资产账本';
}
