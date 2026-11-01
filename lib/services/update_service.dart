import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
    return {'versionName': '1.1.1', 'versionCode': 5};
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

  /// Download the APK with progress and launch the Android package installer
  Future<String> downloadApk(
    AppReleaseInfo release, {
    void Function(double progress, int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
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
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          onProgress?.call(progress, received, total);
        } else {
          onProgress?.call(0.0, received, total);
        }
      },
    );

    return savePath;
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
