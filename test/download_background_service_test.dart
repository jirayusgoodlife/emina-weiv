import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anime_view/services/download_background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.animeview.anime_view/download_service');
  final methodCalls = <MethodCall>[];

  setUp(() {
    DownloadBackgroundService.debugOverrideIsAndroid = true;
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      methodCalls.add(methodCall);
      if (methodCall.method == 'requestNotificationPermission') {
        return true;
      }
      return true;
    });
  });

  tearDown(() {
    DownloadBackgroundService.debugOverrideIsAndroid = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('DownloadBackgroundService invokes platform channels correctly', () async {
    // startService
    await DownloadBackgroundService.startService(
      title: 'กำลังดาวน์โหลด',
      message: 'ตอนที่ 1 (10%)',
      progress: 10,
      max: 100,
    );
    expect(DownloadBackgroundService.isServiceRunning, isTrue);

    // updateProgress
    await DownloadBackgroundService.updateProgress(
      title: 'กำลังดาวน์โหลด',
      message: 'ตอนที่ 1 (50%)',
      progress: 50,
      max: 100,
    );

    // stopService with apkPath
    await DownloadBackgroundService.stopService(
      summary: 'ดาวน์โหลดอัปเดตเสร็จแล้ว',
      apkPath: '/tmp/test.apk',
    );
    expect(DownloadBackgroundService.isServiceRunning, isFalse);

    // minimizeApp
    await DownloadBackgroundService.minimizeApp();

    // requestNotificationPermission
    final granted = await DownloadBackgroundService.requestNotificationPermission();
    expect(granted, isTrue);

    expect(methodCalls.map((c) => c.method).toList(), [
      'startService',
      'updateProgress',
      'stopService',
      'minimizeApp',
      'requestNotificationPermission',
    ]);
    final lastStop = methodCalls[2].arguments as Map;
    expect(lastStop['summary'], 'ดาวน์โหลดอัปเดตเสร็จแล้ว');
    expect(lastStop['apkPath'], '/tmp/test.apk');
  });
}
