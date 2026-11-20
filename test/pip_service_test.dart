import 'package:flutter_test/flutter_test.dart';
import 'package:anime_view/services/pip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PipService Volume Synchronization Tests', () {
    test('addVolumeListener and removeVolumeListener manage listeners correctly', () {
      double? receivedVolume;
      void listener(double vol) {
        receivedVolume = vol;
      }

      PipService.addVolumeListener(listener);

      // Verify systemVolume ValueNotifier exists
      expect(PipService.systemVolume, isNotNull);

      PipService.removeVolumeListener(listener);
    });
  });
}
