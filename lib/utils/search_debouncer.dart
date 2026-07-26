import 'dart:async';
import 'package:flutter/foundation.dart';

// 延迟执行搜索操作，避免每次按键都触发全量过滤
class SearchDebouncer {
  Timer? _timer;
  final Duration delay;

  SearchDebouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
