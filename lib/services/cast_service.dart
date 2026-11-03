import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CastDeviceInfo {
  final String id;
  final String name;
  final String host;
  final int port;
  final String model;

  const CastDeviceInfo({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.model = '',
  });

  factory CastDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return CastDeviceInfo(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Chromecast',
      host: map['host']?.toString() ?? '',
      port: (map['port'] as num?)?.toInt() ?? 8009,
      model: map['model']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastDeviceInfo && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CastService extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('com.animeview.anime_view/cast');

  static CastService? _instance;
  static CastService get instance => _instance ??= CastService._();

  CastService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  final List<CastDeviceInfo> _devices = [];
  List<CastDeviceInfo> get devices => List.unmodifiable(_devices);

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _connectedDeviceName = '';
  String get connectedDeviceName => _connectedDeviceName;

  String _connectedDeviceId = '';
  String get connectedDeviceId => _connectedDeviceId;

  String _mediaState = 'IDLE';
  String get mediaState => _mediaState;
  bool get isPlaying => _mediaState == 'PLAYING';
  bool get isPaused => _mediaState == 'PAUSED';
  bool get isBuffering => _mediaState == 'BUFFERING';

  Duration _currentPosition = Duration.zero;
  Duration get currentPosition => _currentPosition;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  String _currentMediaTitle = '';
  String get currentMediaTitle => _currentMediaTitle;

  String _currentMediaSubtitle = '';
  String get currentMediaSubtitle => _currentMediaSubtitle;

  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onCastDeviceFound':
        final data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          final device = CastDeviceInfo.fromMap(data);
          if (!_devices.any((d) => d.id == device.id)) {
            _devices.add(device);
            notifyListeners();
          }
        }
        break;

      case 'onCastDevicesUpdated':
        final list = call.arguments as List<dynamic>?;
        if (list != null) {
          _devices.clear();
          for (final item in list) {
            if (item is Map) {
              _devices.add(CastDeviceInfo.fromMap(item));
            }
          }
          notifyListeners();
        }
        break;

      case 'onCastConnectionChanged':
        final data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          _isConnected = data['connected'] as bool? ?? false;
          _connectedDeviceName = data['deviceName']?.toString() ?? '';
          _connectedDeviceId = data['deviceId']?.toString() ?? '';
          if (!_isConnected) {
            _mediaState = 'IDLE';
            _currentPosition = Duration.zero;
            _duration = Duration.zero;
            _currentMediaTitle = '';
            _currentMediaSubtitle = '';
          }
          notifyListeners();
        }
        break;

      case 'onCastMediaStatus':
        final data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          _mediaState = data['state']?.toString() ?? _mediaState;
          final posSeconds = (data['position'] as num?)?.toDouble() ?? 0.0;
          final durSeconds = (data['duration'] as num?)?.toDouble() ?? 0.0;
          _currentPosition = Duration(milliseconds: (posSeconds * 1000).toInt());
          if (durSeconds > 0) {
            _duration = Duration(milliseconds: (durSeconds * 1000).toInt());
          }
          notifyListeners();
        }
        break;

      case 'onCastVolumeChanged':
        // Volume updates from TV
        break;
    }
  }

  Future<void> startDiscovery() async {
    _isDiscovering = true;
    _devices.clear();
    notifyListeners();
    try {
      await _channel.invokeMethod('startDiscovery');
    } catch (e) {
      if (kDebugMode) print('[CastService] startDiscovery error: $e');
    }
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    notifyListeners();
    try {
      await _channel.invokeMethod('stopDiscovery');
    } catch (e) {
      if (kDebugMode) print('[CastService] stopDiscovery error: $e');
    }
  }

  Future<bool> connect(String deviceId) async {
    try {
      final success = await _channel.invokeMethod<bool>('connect', {'deviceId': deviceId});
      if (success == true) {
        final dev = _devices.firstWhere(
          (d) => d.id == deviceId,
          orElse: () => CastDeviceInfo(id: deviceId, name: 'Chromecast', host: '', port: 8009),
        );
        _isConnected = true;
        _connectedDeviceId = deviceId;
        _connectedDeviceName = dev.name;
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('[CastService] connect error: $e');
    }
    return false;
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (e) {
      if (kDebugMode) print('[CastService] disconnect error: $e');
    }
    _isConnected = false;
    _connectedDeviceName = '';
    _connectedDeviceId = '';
    _mediaState = 'IDLE';
    _currentPosition = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<bool> loadMedia({
    required String url,
    required String title,
    String subtitle = '',
    String thumbnailUrl = '',
    String contentType = 'video/mp4',
    Duration startPosition = Duration.zero,
  }) async {
    try {
      _currentMediaTitle = title;
      _currentMediaSubtitle = subtitle;
      _currentPosition = startPosition;
      _mediaState = 'BUFFERING';
      notifyListeners();

      final success = await _channel.invokeMethod<bool>('loadMedia', {
        'url': url,
        'title': title,
        'subtitle': subtitle,
        'thumbnailUrl': thumbnailUrl,
        'contentType': contentType,
        'startPosition': startPosition.inMilliseconds / 1000.0,
      });
      return success ?? false;
    } catch (e) {
      if (kDebugMode) print('[CastService] loadMedia error: $e');
      _mediaState = 'IDLE';
      notifyListeners();
      return false;
    }
  }

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
      _mediaState = 'PLAYING';
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[CastService] play error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
      _mediaState = 'PAUSED';
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[CastService] pause error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
      _mediaState = 'IDLE';
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('[CastService] stop error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      _currentPosition = position;
      notifyListeners();
      await _channel.invokeMethod('seek', {
        'position': position.inMilliseconds / 1000.0,
      });
    } catch (e) {
      if (kDebugMode) print('[CastService] seek error: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _channel.invokeMethod('setVolume', {
        'volume': volume.clamp(0.0, 1.0),
      });
    } catch (e) {
      if (kDebugMode) print('[CastService] setVolume error: $e');
    }
  }
}
