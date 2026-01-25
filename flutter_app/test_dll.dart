/// DLL 加载测试
import 'dart:ffi';
import 'dart:io';

void main() {
  print('测试 DLL 加载...');
  print('当前目录: ${Directory.current.path}');

  try {
    // 尝试加载 DLL
    final dylib = DynamicLibrary.open('localfamily_asset_core.dll');
    print('✅ DLL 加载成功');

    // 尝试查找 init_app 函数
    final initApp = dylib.lookupFunction<Int32 Function(Pointer<Utf8>)>('init_app');
    print('✅ 找到 init_app 函数');

    print('所有测试通过！');
  } catch (e) {
    print('❌ 错误: $e');
  }
}
