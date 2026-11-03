import 'package:flutter_test/flutter_test.dart';
import 'package:anime_view/services/cast_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CastDeviceInfo Tests', () {
    test('CastDeviceInfo parses from Map correctly', () {
      final map = {
        'id': 'living-room-tv',
        'name': 'Living Room TV',
        'host': '192.168.1.100',
        'port': 8009,
        'model': 'Chromecast with Google TV',
      };

      final device = CastDeviceInfo.fromMap(map);

      expect(device.id, 'living-room-tv');
      expect(device.name, 'Living Room TV');
      expect(device.host, '192.168.1.100');
      expect(device.port, 8009);
      expect(device.model, 'Chromecast with Google TV');
    });

    test('CastDeviceInfo handles missing or null fields gracefully', () {
      final map = <String, dynamic>{};
      final device = CastDeviceInfo.fromMap(map);

      expect(device.id, '');
      expect(device.name, 'Chromecast');
      expect(device.host, '');
      expect(device.port, 8009);
      expect(device.model, '');
    });

    test('CastDeviceInfo equality is based on id', () {
      const dev1 = CastDeviceInfo(
        id: 'chromecast-1',
        name: 'Bedroom TV',
        host: '192.168.1.50',
        port: 8009,
      );

      const dev2 = CastDeviceInfo(
        id: 'chromecast-1',
        name: 'Different Name',
        host: '192.168.1.99',
        port: 8009,
      );

      const dev3 = CastDeviceInfo(
        id: 'chromecast-2',
        name: 'Bedroom TV',
        host: '192.168.1.50',
        port: 8009,
      );

      expect(dev1 == dev2, isTrue);
      expect(dev1 == dev3, isFalse);
      expect(dev1.hashCode, dev2.hashCode);
    });
  });

  group('CastService State Tests', () {
    test('Initial CastService state is clean and disconnected', () {
      final service = CastService.instance;

      expect(service.isConnected, isFalse);
      expect(service.connectedDeviceName, isEmpty);
      expect(service.connectedDeviceId, isEmpty);
      expect(service.mediaState, 'IDLE');
      expect(service.isPlaying, isFalse);
      expect(service.isPaused, isFalse);
      expect(service.isBuffering, isFalse);
      expect(service.currentPosition, Duration.zero);
      expect(service.duration, Duration.zero);
      expect(service.currentMediaTitle, isEmpty);
      expect(service.currentMediaSubtitle, isEmpty);
    });
  });
}
