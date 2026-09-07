// Flutter widget test
//
// 测试 LocalFamily Asset 应用启动

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:localfamily_asset/core/app.dart';
import 'package:localfamily_asset/providers/auth_provider.dart';
import 'package:localfamily_asset/providers/asset_provider.dart';
import 'package:localfamily_asset/providers/custom_type_provider.dart';
import 'package:localfamily_asset/providers/financial_provider.dart';
import 'package:localfamily_asset/providers/theme_provider.dart';

/// 注入全部 Provider 构建完整应用（与 main.dart 的装配一致）
Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AssetProvider()),
        ChangeNotifierProvider(create: (_) => FinancialProvider()),
        ChangeNotifierProvider(create: (_) => CustomTypeProvider()),
      ],
      child: const YincaiApp(),
    ),
  );
  // 冲掉启动页的延迟定时器与异步初始化
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('App starts and builds MaterialApp', (WidgetTester tester) async {
    await _pumpApp(tester);

    // 验证 MaterialApp 存在
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Providers are available', (WidgetTester tester) async {
    await _pumpApp(tester);

    final context = tester.element(find.byType(MaterialApp));
    // 验证 Provider 可用
    expect(context.read<ThemeProvider>(), isNotNull);
    expect(context.read<AuthProvider>(), isNotNull);
    expect(context.read<AssetProvider>(), isNotNull);
    expect(context.read<FinancialProvider>(), isNotNull);
    expect(context.read<CustomTypeProvider>(), isNotNull);
  });
}
