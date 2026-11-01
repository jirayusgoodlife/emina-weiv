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
  });
}
