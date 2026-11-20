import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'download_background_service.dart';

class ReleaseAssetInfo {
  final String name;
  final String downloadUrl;
  final int size;

  ReleaseAssetInfo({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  String get formattedSize {
    if (size <= 0) return '';
    final mb = size / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class AppReleaseInfo {
  final String tagName;
  final String version;
  final String title;
  final String releaseNotes;
  final ReleaseAssetInfo apkAsset;
  final DateTime? publishedAt;

  AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.releaseNotes,
    required this.apkAsset,
    this.publishedAt,
  });
}

class UpdateService {
  static const MethodChannel _channel =
      MethodChannel('com.animeview.anime_view/updater');

  static const String repoOwner = 'jirayusgoodlife';
  static const String repoName = 'emina-weiv';

  static final UpdateService instance = UpdateService._();
  UpdateService._();

  /// Notification notifier that emits when an update is available (or null if up to date)
  final ValueNotifier<AppReleaseInfo?> updateAvailable =
      ValueNotifier<AppReleaseInfo?>(null);

  /// Download state notifiers for global/background tracking
  final ValueNotifier<bool> isDownloading = ValueNotifier<bool>(false);
  final ValueNotifier<double> downloadProgress = ValueNotifier<double>(0.0);
  final ValueNotifier<int> downloadReceivedBytes = ValueNotifier<int>(0);
  final ValueNotifier<int> downloadTotalBytes = ValueNotifier<int>(0);
  final ValueNotifier<String?> downloadedFilePath =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> downloadError = ValueNotifier<String?>(null);
  final ValueNotifier<AppReleaseInfo?> activeDownloadingRelease =
      ValueNotifier<AppReleaseInfo?>(null);

  CancelToken? _cancelToken;
  DateTime? _lastNotificationUpdateTime;

  /// The latest version string discovered from GitHub Releases (e.g. '1.1.2')
  String? latestGitHubVersion;

  /// Retrieve current running app version and code
  Future<Map<String, dynamic>> getCurrentAppVersion() async {
    try {
      if (Platform.isAndroid) {
        final res = await _channel.invokeMethod<Map>('getAppVersion');
        if (res != null) {
          return Map<String, dynamic>.from(res);
        }
      }
    } catch (e) {
      debugPrint('Error getting native app version: $e');
    }
    return {'versionName': '1.3.2', 'versionCode': 11};
  }

  /// Check GitHub Releases for newer release
  Future<AppReleaseInfo?> checkForUpdate({String? currentVersion}) async {
    try {
      final current = currentVersion ??
          (await getCurrentAppVersion())['versionName'] as String? ??
          '1.0.0';

      final url = Uri.parse(
        'https://api.github.com/repos/$repoOwner/$repoName/releases/latest',
      );

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'EminaWeiv-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
            'GitHub release check returned status: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final title = data['name'] as String? ?? tagName;
      final body = data['body'] as String? ?? '';
      final publishedAtStr = data['published_at'] as String?;
      final publishedAt =
          publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final assets = data['assets'] as List<dynamic>? ?? [];
      ReleaseAssetInfo? apkAsset;

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkAsset = ReleaseAssetInfo(
            name: name,
            downloadUrl: asset['browser_download_url'] as String? ?? '',
            size: (asset['size'] as num?)?.toInt() ?? 0,
          );
          break;
        }
      }

      if (apkAsset == null || apkAsset.downloadUrl.isEmpty) {
        debugPrint('No APK asset found in latest GitHub release');
        return null;
      }

      final cleanLatestVersion = _cleanVersion(tagName);
      final cleanCurrentVersion = _cleanVersion(current);
      latestGitHubVersion = cleanLatestVersion;

      if (_isVersionNewer(cleanLatestVersion, cleanCurrentVersion)) {
        final release = AppReleaseInfo(
          tagName: tagName,
          version: cleanLatestVersion,
          title: title,
          releaseNotes: body,
          apkAsset: apkAsset,
          publishedAt: publishedAt,
        );
        updateAvailable.value = release;
        return release;
      }

      updateAvailable.value = null;
      return null;
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return null;
    }
  }

  /// Check if device permits installing unknown APKs
  Future<bool> canInstallUnknownPackages() async {
    if (!Platform.isAndroid) return false;
    try {
      final can =
          await _channel.invokeMethod<bool>('canInstallUnknownPackages');
      return can ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Android settings to enable installing unknown packages
  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openInstallSettings');
    } catch (e) {
      debugPrint('Error opening install settings: $e');
    }
  }

  /// Start downloading APK in background with foreground service notification and wakelock
  Future<String?> startDownload(
    AppReleaseInfo release, {
    void Function(double progress, int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (isDownloading.value) return downloadedFilePath.value;

    isDownloading.value = true;
    downloadProgress.value = 0.0;
    downloadReceivedBytes.value = 0;
    downloadTotalBytes.value = release.apkAsset.size;
    downloadedFilePath.value = null;
    downloadError.value = null;
    activeDownloadingRelease.value = release;
    _cancelToken = cancelToken ?? CancelToken();

    // Start background foreground service and wakelock
    await DownloadBackgroundService.requestNotificationPermission();
    await DownloadBackgroundService.startService(
      title: 'กำลังดาวน์โหลดอัปเดต v${release.version}',
      message: 'กำลังเริ่มการดาวน์โหลด...',
      progress: 0,
      max: 100,
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'emina_weiv_v${release.version}.apk';
      final savePath = '${tempDir.path}/$fileName';

      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        release.apkAsset.downloadUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          final progress =
              total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
          downloadProgress.value = progress;
          downloadReceivedBytes.value = received;
          if (total > 0) downloadTotalBytes.value = total;

          onProgress?.call(progress, received, total);

          // Throttled notification progress update (every 800ms)
          final now = DateTime.now();
          if (_lastNotificationUpdateTime == null ||
              now.difference(_lastNotificationUpdateTime!).inMilliseconds > 800 ||
              progress >= 1.0) {
            _lastNotificationUpdateTime = now;
            final percent = (progress * 100).toInt();
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMb =
                total > 0 ? (total / (1024 * 1024)).toStringAsFixed(1) : '?';
            DownloadBackgroundService.updateProgress(
              title: 'กำลังดาวน์โหลดอัปเดต v${release.version}',
              message: '$percent% ($recMb / $totMb MB)',
              progress: percent,
              max: 100,
            );
          }
        },
      );

      downloadedFilePath.value = savePath;
      isDownloading.value = false;

      // Stop service with completed summary and allow tapping notification to install
      await DownloadBackgroundService.stopService(
        summary: 'ดาวน์โหลดอัปเดต v${release.version} เสร็จแล้ว แตะเพื่อติดตั้ง',
        apkPath: savePath,
      );

      return savePath;
    } catch (e) {
      isDownloading.value = false;
      await DownloadBackgroundService.stopService();

      if (e is DioException && CancelToken.isCancel(e)) {
        downloadError.value = null;
      } else {
        downloadError.value = 'เกิดข้อผิดพลาดในการดาวน์โหลด: $e';
      }
      return null;
    } finally {
      _cancelToken = null;
    }
  }

  /// Cancel any active update download
  void cancelDownload() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel();
    }
    isDownloading.value = false;
    DownloadBackgroundService.stopService();
  }

  /// Reset the download state (e.g. after successful installation or dismissed error)
  void resetDownloadState() {
    isDownloading.value = false;
    downloadProgress.value = 0.0;
    downloadReceivedBytes.value = 0;
    downloadTotalBytes.value = 0;
    downloadedFilePath.value = null;
    downloadError.value = null;
    activeDownloadingRelease.value = null;
  }

  /// Download the APK with progress and launch the Android package installer
  Future<String> downloadApk(
    AppReleaseInfo release, {
    void Function(double progress, int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await startDownload(
      release,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    if (path == null) {
      throw Exception(downloadError.value ?? 'Download failed or canceled');
    }
    return path;
  }

  /// Trigger the installation of the downloaded APK
  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error launching APK installer: $e');
      rethrow;
    }
  }

  /// Utility to strip 'v' or 'V' and build numbers like '+1'
  String _cleanVersion(String v) {
    var s = v.trim();
    if (s.toLowerCase().startsWith('v')) {
      s = s.substring(1);
    }
    if (s.contains('+')) {
      s = s.split('+').first;
    }
    return s.trim();
  }

  /// Compares semantic version strings e.g. "1.0.1" > "1.0.0"
  bool _isVersionNewer(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final currentParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final maxLen = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      for (int i = 0; i < maxLen; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      return latest != current;
    }
  }
}
