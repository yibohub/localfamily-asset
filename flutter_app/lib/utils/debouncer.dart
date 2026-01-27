import 'dart:async';
import 'package:flutter/foundation.dart';

/// 防抖工具类
///
/// 用于延迟执行函数，避免频繁触发（如搜索输入）
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({required this.delay});

  /// 调用此方法会取消之前的计时器并开始新的计时
  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// 立即执行并取消计时器
  void flush() {
    _timer?.cancel();
    _timer = null;
  }

  /// 取消当前计时器
  void cancel() {
    _timer?.cancel();
  }

  /// 释放资源
  void dispose() {
    _timer?.cancel();
  }
}
