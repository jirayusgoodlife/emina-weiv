import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anime_view/providers/settings_provider.dart';

void main() {
  group('SettingsProvider (ปุ่มตอนต่อไป)', () {
    test('ค่ามาตรฐานคือแสดงปุ่มในช่วง 180 วินาทีสุดท้าย', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      expect(settings.showNextEpisodeButton, isTrue);
      expect(settings.nextLeadSeconds, 180);
      expect(settings.shouldShowNextEpisodeButton(181), isFalse);
      expect(settings.shouldShowNextEpisodeButton(180), isTrue);
      expect(settings.shouldShowNextEpisodeButton(30), isTrue);
      expect(settings.shouldShowNextEpisodeButton(-1), isFalse);
    });

    test('เปลี่ยนค่าแล้วบันทึกลง SharedPreferences และแจ้ง listener', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      int notified = 0;
      settings.addListener(() => notified++);

      await settings.setNextLeadSeconds(30);
      expect(settings.nextLeadSeconds, 30);
      expect(settings.shouldShowNextEpisodeButton(31), isFalse);
      expect(settings.shouldShowNextEpisodeButton(30), isTrue);
      expect(prefs.getInt('pref_next_episode_lead_seconds'), 30);
      expect(notified, 1);

      await settings.setNextLeadSeconds(30); // ค่าเดิม -> ไม่แจ้ง listener ซ้ำ
      expect(notified, 1);

      await settings.setShowNextEpisodeButton(false);
      expect(settings.shouldShowNextEpisodeButton(5), isFalse);
      expect(prefs.getBool('pref_show_next_episode_button'), isFalse);
      expect(notified, 2);
    });

    test('อ่านค่าที่บันทึกไว้กลับมา และกรองค่าที่ไม่สมเหตุสมผล', () async {
      SharedPreferences.setMockInitialValues({
        'pref_next_episode_lead_seconds': 45,
        'pref_show_next_episode_button': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      expect(settings.nextLeadSeconds, 45);
      expect(settings.showNextEpisodeButton, isFalse);

      // ค่าเสียหาย -> กลับไปค่ามาตรฐาน 180
      SharedPreferences.setMockInitialValues({
        'pref_next_episode_lead_seconds': -10,
      });
      final prefs2 = await SharedPreferences.getInstance();
      final fallback = SettingsProvider(prefs: prefs2);
      expect(fallback.nextLeadSeconds, 180);

      // จำกัดช่วง 5-3600 วินาที
      await fallback.setNextLeadSeconds(1);
      expect(fallback.nextLeadSeconds, 5);
      await fallback.setNextLeadSeconds(99999);
      expect(fallback.nextLeadSeconds, 3600);
    });

    test('resetNextEpisodeButtonSettings กลับค่ามาตรฐาน 180 วินาที', () async {
      SharedPreferences.setMockInitialValues({
        'pref_next_episode_lead_seconds': 30,
        'pref_show_next_episode_button': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      await settings.resetNextEpisodeButtonSettings();

      expect(settings.nextLeadSeconds, 180);
      expect(settings.showNextEpisodeButton, isTrue);
      expect(prefs.getInt('pref_next_episode_lead_seconds'), isNull);
      expect(prefs.getBool('pref_show_next_episode_button'), isNull);
    });

    test('leadLabel แสดงหน่วยเวลาได้ถูกต้อง', () {
      expect(SettingsProvider.leadLabel(30), '30 วินาที');
      expect(SettingsProvider.leadLabel(180), '3 นาที');
      expect(SettingsProvider.leadLabel(90), '1 นาที 30 วินาที');
    });
  });

  group('SettingsProvider (การหมุนจอ)', () {
    test('ค่ามาตรฐานเปิดหมุนจออัตโนมัติ และอนุญาตทุกทิศทาง', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      expect(settings.autoRotate, isTrue);
      expect(settings.normalOrientations, contains(DeviceOrientation.portraitUp));
      expect(settings.normalOrientations, contains(DeviceOrientation.landscapeLeft));
      expect(settings.fullscreenOrientations,
          containsAll([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]));
      expect(settings.fullscreenOrientations, isNot(contains(DeviceOrientation.portraitUp)));
    });

    test('ปิดหมุนจอจะล็อกแค่แนวตั้ง และบันทึกลง SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      int notified = 0;
      settings.addListener(() => notified++);

      await settings.setAutoRotate(false);
      expect(settings.autoRotate, isFalse);
      expect(settings.normalOrientations,
          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
      expect(prefs.getBool('pref_auto_rotate'), isFalse);
      expect(notified, 1);

      await settings.setAutoRotate(false); // ค่าเดิม -> ไม่แจ้ง listener ซ้ำ
      expect(notified, 1);

      // อ่านค่าที่บันทึกไว้กลับมา
      final prefs2 = await SharedPreferences.getInstance();
      final reloaded = SettingsProvider(prefs: prefs2);
      expect(reloaded.autoRotate, isFalse);
    });

    test('resetAppSettings กลับค่าทั้งหมดรวมถึงการหมุนจอ', () async {
      SharedPreferences.setMockInitialValues({
        'pref_next_episode_lead_seconds': 30,
        'pref_show_next_episode_button': false,
        'pref_auto_rotate': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      await settings.resetAppSettings();

      expect(settings.autoRotate, isTrue);
      expect(settings.nextLeadSeconds, 180);
      expect(settings.showNextEpisodeButton, isTrue);
      expect(prefs.getBool('pref_auto_rotate'), isNull);
    });
  });

  group('SettingsProvider (โหมดแสดงผลหน้ารายการ Grid 3 เรื่อง / List)', () {
    test('ค่ามาตรฐานคือแบบ Grid (isListView = false)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      expect(settings.isListView, isFalse);
    });

    test('เปลี่ยนโหมดและบันทึกลง SharedPreferences ถูกต้อง', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs: prefs);

      int notified = 0;
      settings.addListener(() => notified++);

      await settings.setListView(true);
      expect(settings.isListView, isTrue);
      expect(prefs.getBool('pref_catalog_view_mode'), isTrue);
      expect(notified, 1);

      await settings.toggleViewMode();
      expect(settings.isListView, isFalse);
      expect(prefs.getBool('pref_catalog_view_mode'), isFalse);
      expect(notified, 2);

      // Reload from prefs
      final reloaded = SettingsProvider(prefs: prefs);
      expect(reloaded.isListView, isFalse);
    });
  });
}
