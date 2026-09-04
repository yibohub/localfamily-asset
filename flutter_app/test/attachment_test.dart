// 附件功能单元测试（纯 Dart 逻辑部分）
//
// FFI 依赖 Rust 动态库，单元测试环境不可用；
// 这里覆盖 UI 层可独立验证的纯函数逻辑。

import 'package:flutter_test/flutter_test.dart';

import 'package:localfamily_asset/core/ffi_bridge.dart';

void main() {
  group('AttachmentInfo', () {
    test('fromJson 解析 FFI JSON 字段', () {
      final info = AttachmentInfo.fromJson({
        'id': 'att-1',
        'assetId': 'asset-1',
        'fileName': '保单照片.jpg',
        'fileSize': 1024,
        'mimeType': 'image/jpeg',
        'createdAt': 1700000000,
      });

      expect(info.id, 'att-1');
      expect(info.assetId, 'asset-1');
      expect(info.fileName, '保单照片.jpg');
      expect(info.fileSize, 1024);
      expect(info.mimeType, 'image/jpeg');
      expect(info.createdAt, 1700000000);
    });

    test('fromJson 允许 mimeType 为 null', () {
      final info = AttachmentInfo.fromJson({
        'id': 'att-2',
        'assetId': 'asset-1',
        'fileName': '未知文件',
        'fileSize': 0,
        'mimeType': null,
        'createdAt': 1700000001,
      });

      expect(info.mimeType, isNull);
    });
  });
}
