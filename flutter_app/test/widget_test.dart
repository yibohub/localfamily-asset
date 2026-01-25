// Flutter widget test
//
// 测试 LocalFamily Asset 应用启动

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localfamily_asset/core/app.dart';
import 'package:localfamily_asset/providers/auth_provider.dart';
import 'package:localfamily_asset/providers/asset_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App starts and builds MaterialApp', (WidgetTester tester) async {
    // 构建完整的应用
    await tester.pumpWidget(const LocalFamilyAssetApp());

    // 验证 MaterialApp 存在
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Providers are available', (WidgetTester tester) async {
    // 构建应用
    await tester.pumpWidget(const LocalFamilyAssetApp());

    // 验证 Provider 可用
    expect(find.byType(ChangeNotifierProvider<AuthProvider>), findsWidgets);
    expect(find.byType(ChangeNotifierProvider<AssetProvider>), findsWidgets);
  });
}
