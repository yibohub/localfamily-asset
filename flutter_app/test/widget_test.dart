// Flutter widget test
//
// 测试 LocalFamily Asset 应用启动

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:localfamily_asset/core/app.dart';

void main() {
  testWidgets('App starts without error', (WidgetTester tester) async {
    // 构建应用并触发一帧
    await tester.pumpWidget(const LocalFamilyAssetApp());

    // 验证应用成功启动
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
