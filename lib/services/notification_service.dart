import 'dart:async';
import 'package:flutter/foundation.dart';

// 通知类型枚举
enum NotificationType { info, error }

// 单条通知数据模型
class AppNotification {
  final String id;
  final String message;
  final NotificationType type;
  int count; // 合并计数（默认 1）

  AppNotification({
    required this.id,
    required this.message,
    required this.type,
    this.count = 1,
  });
}

// 全局通知管理服务
class NotificationService extends ChangeNotifier {
  static const int maxVisible = 3;
  static const Duration _infoDuration = Duration(seconds: 3);
  static const Duration _errorDuration = Duration(seconds: 5);

  final List<AppNotification> _notifications = [];
  final Map<String, Timer> _timers = {};
  final Map<String, Duration> _remainingDurations = {};
  final Map<String, DateTime> _timerStartedAt = {};

  int _nextId = 0;

  // 当前活跃的通知列表
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  // 发送一条普通信息通知
  void info(String message) => _add(message, NotificationType.info);

  // 发送一条错误通知
  void error(String message) => _add(message, NotificationType.error);

  void _add(String message, NotificationType type) {
    // 检查是否已有相同消息 → 合并计数
    final existing = _findExisting(message, type);
    if (existing != null) {
      existing.count++;
      _resetTimer(existing);
      notifyListeners();
      return;
    }

    final notification = AppNotification(
      id: 'notification_${_nextId++}',
      message: message,
      type: type,
    );

    _notifications.add(notification);

    // 超过最大数量时移除最旧的
    while (_notifications.length > maxVisible) {
      final removed = _notifications.removeAt(0);
      _cancelTimer(removed.id);
    }

    _startTimer(notification);
    notifyListeners();
  }

  AppNotification? _findExisting(String message, NotificationType type) {
    for (final n in _notifications) {
      if (n.message == message && n.type == type) {
        return n;
      }
    }
    return null;
  }

  void _startTimer(AppNotification notification) {
    final duration = notification.type == NotificationType.error
        ? _errorDuration
        : _infoDuration;
    _cancelTimer(notification.id);
    _remainingDurations[notification.id] = duration;
    _timerStartedAt[notification.id] = DateTime.now();
    _timers[notification.id] = Timer(duration, () {
      dismiss(notification.id);
    });
  }

  void _resetTimer(AppNotification notification) {
    _startTimer(notification);
  }

  void _cancelTimer(String id) {
    _timers[id]?.cancel();
    _timers.remove(id);
    _remainingDurations.remove(id);
    _timerStartedAt.remove(id);
  }

  // 暂停指定通知的自动消失定时器（鼠标悬停时调用）
  void pauseTimer(String id) {
    final timer = _timers[id];
    if (timer == null || !timer.isActive) return;

    timer.cancel();
    final startedAt = _timerStartedAt[id];
    final totalDuration = _remainingDurations[id];
    if (startedAt != null && totalDuration != null) {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = totalDuration - elapsed;
      _remainingDurations[id] = remaining.isNegative
          ? Duration.zero
          : remaining;
    }
  }

  // 恢复指定通知的自动消失定时器（鼠标移出时调用）
  void resumeTimer(String id) {
    final remaining = _remainingDurations[id];
    if (remaining == null) return;

    _timerStartedAt[id] = DateTime.now();
    _timers[id] = Timer(remaining, () {
      dismiss(id);
    });
  }

  // 手动关闭一条通知
  void dismiss(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _cancelTimer(id);
    notifyListeners();
  }

  // 关闭所有通知
  void dismissAll() {
    for (final n in _notifications) {
      _cancelTimer(n.id);
    }
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final id in _timers.keys.toList()) {
      _timers[id]?.cancel();
    }
    _timers.clear();
    _remainingDurations.clear();
    _timerStartedAt.clear();
    super.dispose();
  }
}
