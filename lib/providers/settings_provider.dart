import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:shared_preferences/shared_preferences.dart';

/// ข้อมูลการตั้งค่าทั่วไปของแอปที่เก็บไว้ในเครื่อง (SharedPreferences)
class SettingsProvider extends ChangeNotifier {
  final SharedPreferences _prefs;

  static const String _prefShowNextButtonKey = 'pref_show_next_episode_button';
  static const String _prefNextLeadSecondsKey = 'pref_next_episode_lead_seconds';
  static const String _prefAutoRotateKey = 'pref_auto_rotate';
  static const String _prefCatalogViewModeKey = 'pref_catalog_view_mode';
  static const String _prefPlayerBrightnessKey = 'pref_player_brightness';
  static const String _prefPlayerVolumeKey = 'pref_player_volume';

  /// ค่าเริ่มต้น: แสดงปุ่ม "ตอนต่อไป" ตั้งแต่ 180 วินาทีสุดท้ายของตอน
  static const int defaultNextLeadSeconds = 180;
  static const bool defaultShowNextEpisodeButton = true;
  static const bool defaultAutoRotate = true;
  static const bool defaultIsListView = false;

  /// ทางเลือกช่วงเวลา (วินาที) ที่แสดงปุ่มดูลัดไปตอนต่อไป
  static const List<int> nextLeadOptions = [15, 30, 60, 90, 120, 180, 300];

  bool _showNextEpisodeButton = defaultShowNextEpisodeButton;
  int _nextLeadSeconds = defaultNextLeadSeconds;
  bool _autoRotate = defaultAutoRotate;
  bool _isListView = defaultIsListView;
  double? _playerBrightness;
  double? _playerVolume;

  SettingsProvider({required SharedPreferences prefs}) : _prefs = prefs {
    _showNextEpisodeButton =
        _prefs.getBool(_prefShowNextButtonKey) ?? defaultShowNextEpisodeButton;
    _nextLeadSeconds = _sanitizeLead(_prefs.getInt(_prefNextLeadSecondsKey));
    _autoRotate = _prefs.getBool(_prefAutoRotateKey) ?? defaultAutoRotate;
    _isListView = _prefs.getBool(_prefCatalogViewModeKey) ?? defaultIsListView;
    final savedBrightness = _prefs.getDouble(_prefPlayerBrightnessKey);
    if (savedBrightness != null) {
      _playerBrightness = savedBrightness.clamp(0.0, 1.0);
    }
    final savedVolume = _prefs.getDouble(_prefPlayerVolumeKey);
    if (savedVolume != null) {
      _playerVolume = savedVolume.clamp(0.0, 1.0);
    }
  }

  bool get showNextEpisodeButton => _showNextEpisodeButton;
  int get nextLeadSeconds => _nextLeadSeconds;
  bool get autoRotate => _autoRotate;
  bool get isListView => _isListView;
  double? get playerBrightness => _playerBrightness;
  double? get playerVolume => _playerVolume;

  Future<void> setListView(bool value) async {
    if (_isListView == value) return;
    _isListView = value;
    await _prefs.setBool(_prefCatalogViewModeKey, value);
    notifyListeners();
  }

  Future<void> toggleViewMode() async {
    await setListView(!_isListView);
  }

  /// ทิศทางจอที่อนุญาตตอนอยู่นอกโหมดเต็มจอ
  /// - เปิดหมุนจออัตโนมัติ: ปล่อยตามที่ผู้ใช้ถือมือถือ (แนวตั้ง หรือแนวนอนก็ได้)
  /// - ปิดหมุนจออัตโนมัติ: ล็อกไว้แค่แนวตั้ง
  List<DeviceOrientation> get normalOrientations => _autoRotate
      ? List<DeviceOrientation>.unmodifiable(DeviceOrientation.values)
      : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

  /// ทิศทางจอตอนอยู่ในโหมดเต็มจอ (แนวนอนทั้งสองด้าน)
  List<DeviceOrientation> get fullscreenOrientations => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];

  /// ปุ่ม "ตอนต่อไป" ควรถูกแสดงหรือไม่ เมื่อเทียบกับเวลาที่เหลือของตอน
  bool shouldShowNextEpisodeButton(int remainingSeconds) {
    if (!_showNextEpisodeButton) return false;
    if (remainingSeconds < 0) return false;
    return remainingSeconds <= _nextLeadSeconds;
  }

  Future<void> setShowNextEpisodeButton(bool value) async {
    if (_showNextEpisodeButton == value) return;
    _showNextEpisodeButton = value;
    if (value == defaultShowNextEpisodeButton) {
      await _prefs.remove(_prefShowNextButtonKey);
    } else {
      await _prefs.setBool(_prefShowNextButtonKey, value);
    }
    notifyListeners();
  }

  Future<void> setNextLeadSeconds(int seconds) async {
    final sanitized = _sanitizeLead(seconds);
    if (_nextLeadSeconds == sanitized) return;
    _nextLeadSeconds = sanitized;
    if (sanitized == defaultNextLeadSeconds) {
      await _prefs.remove(_prefNextLeadSecondsKey);
    } else {
      await _prefs.setInt(_prefNextLeadSecondsKey, sanitized);
    }
    notifyListeners();
  }

  Future<void> setAutoRotate(bool value) async {
    if (_autoRotate == value) return;
    _autoRotate = value;
    if (value == defaultAutoRotate) {
      await _prefs.remove(_prefAutoRotateKey);
    } else {
      await _prefs.setBool(_prefAutoRotateKey, value);
    }
    notifyListeners();
  }

  /// บันทึกค่าความสว่างที่ผู้ใช้ปรับไว้ใน Player (0.0 - 1.0) เพื่อจำไว้ใช้กับทุกเรื่อง
  Future<void> setPlayerBrightness(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (_playerBrightness == clamped) return;
    _playerBrightness = clamped;
    await _prefs.setDouble(_prefPlayerBrightnessKey, clamped);
    notifyListeners();
  }

  /// บันทึกค่าระดับเสียงที่ผู้ใช้ปรับไว้ใน Player (0.0 - 1.0) เพื่อจำไว้ใช้กับทุกเรื่อง
  Future<void> setPlayerVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (_playerVolume == clamped) return;
    _playerVolume = clamped;
    await _prefs.setDouble(_prefPlayerVolumeKey, clamped);
    notifyListeners();
  }

  /// คืนค่าการตั้งค่าทั้งหมดของแอปไปค่ามาตรฐาน
  Future<void> resetAppSettings() async {
    await setShowNextEpisodeButton(defaultShowNextEpisodeButton);
    await setNextLeadSeconds(defaultNextLeadSeconds);
    await setAutoRotate(defaultAutoRotate);
  }

  /// ตั้งค่ากลับไปค่าเริ่มต้น (180 วินาทีสุดท้าย และเปิดแสดงปุ่ม)
  Future<void> resetNextEpisodeButtonSettings() async {
    _showNextEpisodeButton = defaultShowNextEpisodeButton;
    _nextLeadSeconds = defaultNextLeadSeconds;
    await _prefs.remove(_prefShowNextButtonKey);
    await _prefs.remove(_prefNextLeadSecondsKey);
    notifyListeners();
  }

  /// แปลงเป็น "30 วินาที" / "3 นาที" ให้อ่านง่ายใน UI
  static String leadLabel(int seconds) {
    if (seconds < 60) return '$seconds วินาที';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (rest == 0) return '$minutes นาที';
    return '$minutes นาที $rest วินาที';
  }

  static int _sanitizeLead(int? seconds) {
    if (seconds == null || seconds <= 0) return defaultNextLeadSeconds;
    // จำกัดช่วงไว้ให้สมเหตุผล (ไม่น้อยกว่า 5 วินาที / ไม่เกิน 1 ชั่วโมง)
    if (seconds < 5) return 5;
    if (seconds > 3600) return 3600;
    return seconds;
  }
}
