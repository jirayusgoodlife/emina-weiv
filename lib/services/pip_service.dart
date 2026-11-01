import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('com.animeview.anime_view/pip');
  static final ValueNotifier<bool> isPipMode = ValueNotifier<bool>(false);
  static bool _handlerInitialized = false;
  static void Function(String action)? onPipAction;

  static void initialize() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final isInPip = call.arguments == true;
        if (kDebugMode) {
          print('[PipService] onPipModeChanged: $isInPip');
        }
        isPipMode.value = isInPip;
      } else if (call.method == 'onPipAction') {
        final action = call.arguments as String?;
        if (kDebugMode) {
          print('[PipService] onPipAction: $action');
        }
        if (action != null) {
          onPipAction?.call(action);
        }
      }
    });
  }

  /// Check if Picture-in-Picture is supported on the current device (Android 8.0+)
  static Future<bool> isPipSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isPipSupported');
      return res ?? false;
    } catch (e) {
      if (kDebugMode) print('[PipService] isPipSupported error: $e');
      return false;
    }
  }

  /// Manually enter Picture-in-Picture mode with given aspect ratio and play state
  static Future<bool> enterPip({
    int numerator = 16,
    int denominator = 9,
    bool isPlaying = true,
  }) async {
    if (!Platform.isAndroid) return false;
    initialize();
    try {
      final res = await _channel.invokeMethod<bool>('enterPip', {
        'numerator': numerator,
        'denominator': denominator,
        'isPlaying': isPlaying,
      });
      return res ?? false;
    } catch (e) {
      if (kDebugMode) print('[PipService] enterPip error: $e');
      return false;
    }
  }

  /// Enable or disable automatic Picture-in-Picture when user presses Home or switches apps
  static Future<void> setAutoPip({
    required bool enabled,
    int numerator = 16,
    int denominator = 9,
    bool isPlaying = true,
  }) async {
    if (!Platform.isAndroid) return;
    initialize();
    try {
      await _channel.invokeMethod('setAutoPip', {
        'enabled': enabled,
        'numerator': numerator,
        'denominator': denominator,
        'isPlaying': isPlaying,
      });
    } catch (e) {
      if (kDebugMode) print('[PipService] setAutoPip error: $e');
    }
  }

  /// Update PiP play/pause action button dynamically
  static Future<void> updatePipActions({required bool isPlaying}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updatePipActions', {
        'isPlaying': isPlaying,
      });
    } catch (e) {
      if (kDebugMode) print('[PipService] updatePipActions error: $e');
    }
  }

  /// Get current screen brightness (0.0 to 1.0)
  static Future<double> getBrightness() async {
    if (!Platform.isAndroid) return 0.5;
    try {
      final res = await _channel.invokeMethod<double>('getBrightness');
      return res ?? 0.5;
    } catch (e) {
      if (kDebugMode) print('[PipService] getBrightness error: $e');
      return 0.5;
    }
  }

  /// Set window brightness (0.01 to 1.0)
  static Future<void> setBrightness(double value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setBrightness', {
        'brightness': value.clamp(0.01, 1.0),
      });
    } catch (e) {
      if (kDebugMode) print('[PipService] setBrightness error: $e');
    }
  }

  /// Reset window brightness back to system preference
  static Future<void> resetBrightness() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('resetBrightness');
    } catch (e) {
      if (kDebugMode) print('[PipService] resetBrightness error: $e');
    }
  }

  /// Get current system media volume (0.0 to 1.0)
  static Future<double> getVolume() async {
    if (!Platform.isAndroid) return 0.5;
    try {
      final res = await _channel.invokeMethod<double>('getVolume');
      return res ?? 0.5;
    } catch (e) {
      if (kDebugMode) print('[PipService] getVolume error: $e');
      return 0.5;
    }
  }

  /// Set system media volume (0.0 to 1.0)
  static Future<void> setVolume(double value) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('setVolume', {
        'volume': value.clamp(0.0, 1.0),
      });
    } catch (e) {
      if (kDebugMode) print('[PipService] setVolume error: $e');
    }
  }
}
