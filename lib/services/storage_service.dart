import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DeviceStorageInfo {
  final int freeBytes;
  final int totalBytes;

  const DeviceStorageInfo({
    required this.freeBytes,
    required this.totalBytes,
  });

  bool get isValid => freeBytes > 0 && totalBytes > 0;

  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);

  String get formattedFree {
    if (freeBytes <= 0) return '0 MB';
    if (freeBytes >= 1024 * 1024 * 1024) {
      return '${(freeBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(freeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedTotal {
    if (totalBytes <= 0) return '0 MB';
    if (totalBytes >= 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedUsed {
    final used = usedBytes;
    if (used <= 0) return '0 MB';
    if (used >= 1024 * 1024 * 1024) {
      return '${(used / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(used / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  double get usedPercentage {
    if (totalBytes <= 0) return 0.0;
    return (usedBytes / totalBytes).clamp(0.0, 1.0);
  }

  double get freePercentage {
    if (totalBytes <= 0) return 0.0;
    return (freeBytes / totalBytes).clamp(0.0, 1.0);
  }
}

class StorageService {
  static const MethodChannel _channel = MethodChannel('com.animeview.anime_view/storage');

  /// Fetches device storage information
  static Future<DeviceStorageInfo> getDeviceStorage() async {
    // 1. Android implementation via MethodChannel
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getStorageSpace');
        if (result != null) {
          final free = (result['freeBytes'] as num?)?.toInt() ?? 0;
          final total = (result['totalBytes'] as num?)?.toInt() ?? 0;
          return DeviceStorageInfo(freeBytes: free, totalBytes: total);
        }
      } catch (e) {
        if (kDebugMode) print('[StorageService] Android error: $e');
      }
    }

    // 2. Linux / macOS desktop fallback (useful in dev/desktop testing)
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS)) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final res = await Process.run('df', ['-P', '-B1', dir.path]);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().trim().split('\n');
          if (lines.length >= 2) {
            final parts = lines[1].trim().split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final total = int.tryParse(parts[1]) ?? 0;
              final free = int.tryParse(parts[3]) ?? 0;
              if (total > 0 && free > 0) {
                return DeviceStorageInfo(freeBytes: free, totalBytes: total);
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('[StorageService] Desktop df error: $e');
      }
    }

    return const DeviceStorageInfo(freeBytes: 0, totalBytes: 0);
  }
}
