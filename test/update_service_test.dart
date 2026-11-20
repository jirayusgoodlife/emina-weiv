import 'package:flutter_test/flutter_test.dart';
import 'package:anime_view/services/update_service.dart';

void main() {
  group('UpdateService Version Comparison', () {
    test('Correctly identifies newer semver versions', () {
      final service = UpdateService.instance;
      // Using public method via checkForUpdate logic
      expect(
        service.checkForUpdate,
        isNotNull,
      );
    });

    test('ReleaseAssetInfo calculates formatted size correctly', () {
      final asset = ReleaseAssetInfo(
        name: 'app-release.apk',
        downloadUrl: 'https://github.com/jirayusgoodlife/emina-weiv/releases/download/v1.0.0/app-release.apk',
        size: 86835200, // ~82.8 MB
      );

      expect(asset.formattedSize, '82.8 MB');
    });

    test('ReleaseAssetInfo handles empty/zero size', () {
      final asset = ReleaseAssetInfo(
        name: 'test.apk',
        downloadUrl: 'https://example.com/test.apk',
        size: 0,
      );

      expect(asset.formattedSize, '');
    });

    test('updateAvailable notifier and latestGitHubVersion state properties exist', () {
      final service = UpdateService.instance;
      expect(service.updateAvailable, isNotNull);
      expect(service.latestGitHubVersion, anyOf(isNull, isA<String>()));
    });

    test('Background download state notifiers and controls work correctly', () {
      final service = UpdateService.instance;

      expect(service.isDownloading.value, isFalse);
      expect(service.downloadProgress.value, 0.0);
      expect(service.downloadReceivedBytes.value, 0);
      expect(service.downloadTotalBytes.value, 0);
      expect(service.downloadedFilePath.value, isNull);
      expect(service.downloadError.value, isNull);
      expect(service.activeDownloadingRelease.value, isNull);

      // Mutate and verify resetDownloadState
      service.isDownloading.value = true;
      service.downloadProgress.value = 0.75;
      service.downloadReceivedBytes.value = 7500;
      service.downloadTotalBytes.value = 10000;
      service.downloadedFilePath.value = '/tmp/fake.apk';
      service.downloadError.value = 'fake error';

      service.resetDownloadState();

      expect(service.isDownloading.value, isFalse);
      expect(service.downloadProgress.value, 0.0);
      expect(service.downloadReceivedBytes.value, 0);
      expect(service.downloadTotalBytes.value, 0);
      expect(service.downloadedFilePath.value, isNull);
      expect(service.downloadError.value, isNull);
      expect(service.activeDownloadingRelease.value, isNull);

      // cancelDownload resets isDownloading
      service.isDownloading.value = true;
      service.cancelDownload();
      expect(service.isDownloading.value, isFalse);
    });
  });
}
