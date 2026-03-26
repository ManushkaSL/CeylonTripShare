import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  BuildContext? _rootContext;

  void setRootContext(BuildContext context) {
    _rootContext = context;
  }

  /// Show a simple snackbar notification
  void showNotification(
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (_rootContext == null) {
      debugPrint('⚠️ Root context not set for notifications');
      return;
    }

    ScaffoldMessenger.of(_rootContext!).showSnackBar(
      SnackBar(content: Text(message), duration: duration, action: action),
    );
  }

  /// Show a success notification
  void showSuccess(String message) {
    if (_rootContext == null) return;

    ScaffoldMessenger.of(_rootContext!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show an error notification
  void showError(String message) {
    if (_rootContext == null) return;

    ScaffoldMessenger.of(_rootContext!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show an info notification with action
  void showInfoWithAction(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    if (_rootContext == null) return;

    ScaffoldMessenger.of(_rootContext!).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Show a banner notification (styled differently)
  void showBanner(String message, {Color? backgroundColor}) {
    if (_rootContext == null) return;

    ScaffoldMessenger.of(_rootContext!).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor ?? Colors.blue,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// Clear all notifications
  void clearNotifications() {
    if (_rootContext != null) {
      ScaffoldMessenger.of(_rootContext!).clearSnackBars();
    }
  }
}
