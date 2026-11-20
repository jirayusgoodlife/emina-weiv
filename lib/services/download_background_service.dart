import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DownloadBackgroundService {
  static const MethodChannel _channel = MethodChannel('com.animeview.anime_view/download_service');
  static bool _isServiceRunning = false;

  @visibleForTesting
  static bool debugOverrideIsAndroid = false;

  static bool get _isAndroid => debugOverrideIsAndroid || (!kIsWeb && Platform.isAndroid);

  static bool get isServiceRunning => _isServiceRunning;

  /// Start Android foreground service with download notification and wakelock
  static Future<void> startService({
    required String title,
    required String message,
    int progress = 0,
    int max = 100,
  }) async {
    if (!_isAndroid) return;
    try {
      _isServiceRunning = true;
      await _channel.invokeMethod('startService', {
        'title': title,
        'message': message,
        'progress': progress,
        'max': max,
      });
    } catch (e) {
      if (kDebugMode) print('[DownloadBackgroundService] startService error: $e');
    }
  }

  /// Update foreground service notification progress and content
  static Future<void> updateProgress({
    required String title,
    required String message,
    required int progress,
    int max = 100,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('updateProgress', {
        'title': title,
        'message': message,
        'progress': progress,
        'max': max,
      });
    } catch (e) {
      if (kDebugMode) print('[DownloadBackgroundService] updateProgress error: $e');
    }
  }

  /// Stop foreground service, optionally showing a completed summary notification and APK installer intent
  static Future<void> stopService({String? summary, String? apkPath}) async {
    if (!_isAndroid) return;
    try {
      _isServiceRunning = false;
      await _channel.invokeMethod('stopService', {
        'summary': summary,
        if (apkPath != null) 'apkPath': apkPath,
      });
    } catch (e) {
      if (kDebugMode) print('[DownloadBackgroundService] stopService error: $e');
    }
  }

  /// Send application to background (minimize) without killing the process
  static Future<void> minimizeApp() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('minimizeApp');
    } catch (e) {
      if (kDebugMode) print('[DownloadBackgroundService] minimizeApp error: $e');
    }
  }

  /// Request POST_NOTIFICATIONS runtime permission on Android 13+
  static Future<bool> requestNotificationPermission() async {
    if (!_isAndroid) return true;
    try {
      final res = await _channel.invokeMethod<bool>('requestNotificationPermission');
      return res ?? true;
    } catch (e) {
      return true;
    }
  }
}
