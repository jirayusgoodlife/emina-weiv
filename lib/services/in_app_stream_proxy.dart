import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class InAppStreamProxy {
  static InAppStreamProxy? _instance;
  static InAppStreamProxy get instance => _instance ??= InAppStreamProxy._();

  HttpServer? _server;
  int? _port;

  InAppStreamProxy._();

  int? get port => _port;
  bool get isRunning => _server != null;

  static List<Map<String, dynamic>> _dynamicProxyRules = [];

  void updateProxyRules(List<dynamic> rules) {
    _dynamicProxyRules = rules.map((r) => Map<String, dynamic>.from(r as Map)).toList();
    if (kDebugMode) {
      print('[InAppProxy] Loaded ${_dynamicProxyRules.length} dynamic proxy rules from server');
    }
  }

  static bool shouldProxyUrl(String url) {
    final lower = url.toLowerCase();
    // 1. Check dynamic proxy rules from server
    for (final rule in _dynamicProxyRules) {
      final domains = (rule['match_domains'] as List<dynamic>?)?.map((d) => d.toString().toLowerCase()).toList() ?? [];
      if (domains.any((d) => lower.contains(d))) {
        return true;
      }
    }
    // 2. Built-in protected providers
    return lower.contains('animenani') ||
        lower.contains('24playerhd') ||
        lower.contains('orbitalkthai') ||
        lower.contains('stream-aph') ||
        lower.contains('qqhls') ||
        lower.contains('qqstream') ||
        lower.contains('flower.txt') ||
        lower.contains('maimeorder') ||
        lower.contains('animemami') ||
        lower.contains('fairyanime') ||
        lower.contains('tonytonychopper') ||
        lower.contains('getplay-cdn') ||
        lower.contains('ok-hd') ||
        lower.contains('ok-720') ||
        lower.contains('surrit') ||
        lower.contains('njavtv') ||
        lower.contains('missav') ||
        lower.contains('b-cdn') ||
        lower.contains('bunnycdn') ||
        lower.contains('fourhoi') ||
        lower.endsWith('.txt') ||
        lower.contains('/o/');
  }

  static Map<String, String> getCustomHeaders(String url) {
    final lower = url.toLowerCase();

    // 1. Dynamic proxy rules from synced custom sites (reverse order to prioritize custom rules)
    for (final rule in _dynamicProxyRules.reversed) {
      final domains = (rule['match_domains'] as List<dynamic>?)?.map((d) => d.toString().toLowerCase()).toList() ?? [];
      if (domains.any((d) => lower.contains(d))) {
        final headersRaw = rule['headers'] as Map<dynamic, dynamic>?;
        if (headersRaw != null && headersRaw.isNotEmpty) {
          final res = <String, String>{};
          headersRaw.forEach((k, v) => res[k.toString()] = v.toString());
          return res;
        }
      }
    }

    // 2. Built-in defaults
    if (lower.contains('surrit') ||
        lower.contains('njavtv') ||
        lower.contains('missav') ||
        lower.contains('b-cdn') ||
        lower.contains('bunnycdn') ||
        lower.contains('fourhoi')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
        'Referer': 'https://njavtv.com/',
        'Origin': 'https://njavtv.com',
        'Accept': '*/*',
      };
    }
    if (lower.contains('stream-aph') || lower.contains('qqhls') || lower.contains('qqstream')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://qqstream.stream-aph.xyz/',
        'Origin': 'https://qqstream.stream-aph.xyz',
        'Accept': '*/*',
      };
    }
    if (lower.contains('animenani')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://nya.animenani.com/',
        'Origin': 'https://nya.animenani.com',
        'Accept': '*/*',
      };
    }
    if (lower.contains('24playerhd') || lower.contains('orbitalkthai')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://main.24playerhd.com/',
        'Origin': 'https://main.24playerhd.com',
        'Accept': '*/*',
      };
    }
    if (lower.contains('anifume') || lower.contains('rukoluo')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://anifume.com/',
        'Accept': '*/*',
      };
    }
    if (lower.contains('fairyanime') || lower.contains('tonytonychopper')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://anime.tonytonychopper.net/',
        'Accept': '*/*',
      };
    }
    if (lower.contains('maimeorder') || lower.contains('animemami')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://animemami.xyz/',
        'Origin': 'https://animemami.xyz',
        'Accept': '*/*',
      };
    }
    if (lower.contains('getplay-cdn')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://getplay-cdn.com/',
        'Origin': 'https://getplay-cdn.com',
        'Accept': '*/*',
      };
    }
    if (lower.contains('ok-hd') || lower.contains('ok-720')) {
      return {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://ok-hd.com/',
        'Origin': 'https://ok-hd.com',
        'Accept': '*/*',
      };
    }
    return {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': '*/*',
    };
  }

  static Map<String, String> _getCustomHeaders(String url) => getCustomHeaders(url);

  Future<void> start() async {
    if (_server != null) return;

    try {
      // Bind to any IPv4 on an available random port (accessible locally and via LAN for Chromecast)
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _port = _server!.port;
      if (kDebugMode) {
        print('[InAppProxy] Embedded stream proxy started on 0.0.0.0:$_port');
      }

      _server!.listen(_handleRequest, onError: (e) {
        if (kDebugMode) print('[InAppProxy] Server error: $e');
      });
    } catch (e) {
      if (kDebugMode) print('[InAppProxy] Failed to bind: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  /// Finds the local LAN IPv4 address of this device (Wi-Fi)
  static Future<String?> getLanIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // 1. Prioritize Wi-Fi / WLAN interfaces
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('wlan') || name.contains('wifi') || name.contains('eth')) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback && !addr.address.startsWith('127.')) {
              return addr.address;
            }
          }
        }
      }

      // 2. Prioritize standard home Wi-Fi subnet (192.168.x.x)
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            return addr.address;
          }
        }
      }

      // 3. Fallback to any private LAN IPv4 (10.x, 172.x)
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback &&
              (addr.address.startsWith('10.') || addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }

      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return null;
  }

  /// Converts a direct stream URL into an in-app proxy loopback URL
  String getProxyUrl(String targetUrl) {
    if (_port == null) return targetUrl;
    final encoded = Uri.encodeComponent(targetUrl);
    return 'http://127.0.0.1:$_port/manifest.m3u8?url=$encoded';
  }

  /// Converts a stream URL into a LAN-accessible URL for Chromecast / TV
  Future<String> getLanCastUrl(String targetUrl) async {
    if (_port == null) return targetUrl;
    final ip = await getLanIp() ?? '127.0.0.1';
    final encoded = Uri.encodeComponent(targetUrl);
    final lower = targetUrl.toLowerCase();
    if (lower.contains('.mp4') || (!lower.contains('.m3u8') && !lower.contains('/manifest') && !lower.endsWith('.txt'))) {
      return 'http://$ip:$_port/media?url=$encoded';
    }
    return 'http://$ip:$_port/manifest.m3u8?url=$encoded';
  }

  /// Converts a local file path into a LAN-accessible streaming URL for Chromecast
  Future<String> getLanFileCastUrl(String filePath) async {
    if (_port == null) return filePath;
    final ip = await getLanIp() ?? '127.0.0.1';
    final encoded = Uri.encodeComponent(filePath);
    return 'http://$ip:$_port/local_file?path=$encoded';
  }

  /// Converts a local .ts file into a LAN-accessible HLS playlist URL for Chromecast
  Future<String> getLanFilePlaylistCastUrl(String filePath, {double durationSeconds = 1440.0}) async {
    if (_port == null) return filePath;
    final ip = await getLanIp() ?? '127.0.0.1';
    final encoded = Uri.encodeComponent(filePath);
    return 'http://$ip:$_port/local_playlist.m3u8?path=$encoded&dur=$durationSeconds';
  }

  // Web TV State & Remote Control
  final Map<String, dynamic> _webTvState = {
    'title': '',
    'subtitle': '',
    'streamUrl': '',
    'thumbnailUrl': '',
    'command': 'play',
    'seekTime': 0.0,
    'commandId': 0,
  };

  DateTime? _lastTvPing;
  bool get isWebTvActive =>
      _lastTvPing != null && DateTime.now().difference(_lastTvPing!).inSeconds < 6;

  double _tvReportedPosition = 0.0;
  double _tvReportedDuration = 0.0;
  String _tvReportedState = 'IDLE';

  double get tvPosition => _tvReportedPosition;
  double get tvDuration => _tvReportedDuration;
  String get tvState => _tvReportedState;

  void updateWebTvMedia({
    required String title,
    required String subtitle,
    required String streamUrl,
    String thumbnailUrl = '',
    double startPosition = 0.0,
  }) {
    _webTvState['title'] = title;
    _webTvState['subtitle'] = subtitle;
    _webTvState['streamUrl'] = streamUrl;
    _webTvState['thumbnailUrl'] = thumbnailUrl;
    _webTvState['command'] = 'load';
    _webTvState['seekTime'] = startPosition;
    _webTvState['commandId'] = ((_webTvState['commandId'] as int? ?? 0) + 1);
  }

  void sendWebTvCommand(String command, {double seekTime = 0.0}) {
    _webTvState['command'] = command;
    _webTvState['seekTime'] = seekTime;
    _webTvState['commandId'] = ((_webTvState['commandId'] as int? ?? 0) + 1);
  }

  Future<String> getWebTvUrl() async {
    final ip = await getLanIp() ?? '127.0.0.1';
    final p = _port ?? 8080;
    return 'http://$ip:$p/tv';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;

    // CORS headers
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', '*');
    request.response.headers.set('Access-Control-Expose-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (kDebugMode) {
      print('[InAppProxy] Request: ${request.method} ${request.uri.path}');
    }

    // Web TV Routes
    if (path == '/tv' || path == '/tv/' || path == '/watch') {
      await _serveWebTvPage(request);
      return;
    }

    if (path == '/tv/api/state') {
      _lastTvPing = DateTime.now();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(_webTvState));
      await request.response.close();
      return;
    }

    if (path == '/tv/api/report') {
      _lastTvPing = DateTime.now();
      try {
        final body = await utf8.decoder.bind(request).join();
        final data = jsonDecode(body);
        _tvReportedPosition = (data['currentTime'] as num?)?.toDouble() ?? _tvReportedPosition;
        _tvReportedDuration = (data['duration'] as num?)?.toDouble() ?? _tvReportedDuration;
        _tvReportedState = data['state']?.toString() ?? _tvReportedState;
      } catch (_) {}
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
      return;
    }

    // Handle offline file streaming for Chromecast
    if (path == '/local_playlist.m3u8' || path == '/local_playlist') {
      await _serveLocalPlaylist(request);
      return;
    }

    if (path == '/local_file') {
      final filePath = request.uri.queryParameters['path'];
      if (filePath == null || filePath.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing file path');
        await request.response.close();
        return;
      }
      final file = File(filePath);
      if (!file.existsSync()) {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('File not found');
        await request.response.close();
        return;
      }
      await _serveLocalFile(request, file);
      return;
    }

    final targetUrl = request.uri.queryParameters['url'];
    if (targetUrl == null || targetUrl.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing target url');
      await request.response.close();
      return;
    }

    try {
      if (path == '/manifest' || path == '/manifest.m3u8') {
        await _proxyManifest(request, targetUrl);
      } else if (path == '/segment' || path == '/segment.ts') {
        await _proxySegment(request, targetUrl);
      } else if (path == '/media' || path == '/video') {
        await _proxyDirectMedia(request, targetUrl);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    } catch (e) {
      if (kDebugMode) print('[InAppProxy] Error handling $path: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveLocalPlaylist(HttpRequest request) async {
    final filePath = request.uri.queryParameters['path'];
    if (filePath == null || filePath.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write('Missing file path');
      await request.response.close();
      return;
    }
    final file = File(filePath);
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('File not found');
      await request.response.close();
      return;
    }

    final fileLength = await file.length();
    final dur = double.tryParse(request.uri.queryParameters['dur'] ?? '1440') ?? 1440.0;
    final encoded = Uri.encodeComponent(filePath);

    // Target ~6 seconds per segment for fast buffering and low memory usage
    const targetSegDur = 6.0;
    final numSegs = ((dur > 0 ? dur : 1440.0) / targetSegDur).ceil().clamp(1, 10000);
    var bytesPerSeg = (fileLength / numSegs).ceil();
    // Align to 188-byte MPEG-TS packet boundary
    bytesPerSeg = (bytesPerSeg ~/ 188) * 188;
    if (bytesPerSeg < 188) bytesPerSeg = 188;

    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#EXT-X-VERSION:4');
    buffer.writeln('#EXT-X-PLAYLIST-TYPE:VOD');
    buffer.writeln('#EXT-X-TARGETDURATION:${targetSegDur.ceil() + 2}');
    buffer.writeln('#EXT-X-MEDIA-SEQUENCE:0');

    int currentOffset = 0;
    for (int i = 0; i < numSegs && currentOffset < fileLength; i++) {
      int segLen = bytesPerSeg;
      if (currentOffset + segLen > fileLength || i == numSegs - 1) {
        segLen = fileLength - currentOffset;
      }
      final segDur = (segLen / fileLength) * dur;

      buffer.writeln('#EXTINF:${segDur.toStringAsFixed(3)},');
      buffer.writeln('#EXT-X-BYTERANGE:$segLen@$currentOffset');
      buffer.writeln('local_file?path=$encoded');

      currentOffset += segLen;
    }
    buffer.writeln('#EXT-X-ENDLIST');

    final playlist = buffer.toString();

    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', '*');
    request.response.headers.set('Access-Control-Expose-Headers', '*');
    request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
    request.response.write(playlist);
    await request.response.close();
  }

  Future<void> _serveLocalFile(HttpRequest request, File file) async {
    try {
      final length = await file.length();
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final isTs = file.path.toLowerCase().endsWith('.ts');

      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', '*');
      request.response.headers.set(
        'Access-Control-Expose-Headers',
        'Content-Range, Content-Length, Accept-Ranges, Content-Type, *',
      );
      request.response.headers.set('Accept-Ranges', 'bytes');
      request.response.headers.contentType = isTs
          ? ContentType('video', 'mp2t')
          : ContentType('video', 'mp4');

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final range = rangeHeader.substring(6).split('-');
        final start = int.tryParse(range[0]) ?? 0;
        final end = (range.length > 1 && range[1].isNotEmpty)
            ? int.tryParse(range[1]) ?? (length - 1)
            : length - 1;

        final chunkSize = end - start + 1;
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set('Content-Range', 'bytes $start-$end/$length');
        request.response.contentLength = chunkSize;

        if (request.method == 'HEAD') {
          await request.response.close();
          return;
        }

        final stream = file.openRead(start, end + 1);
        await request.response.addStream(stream);
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = length;

        if (request.method == 'HEAD') {
          await request.response.close();
          return;
        }

        await request.response.addStream(file.openRead());
        await request.response.close();
      }
    } catch (e) {
      if (kDebugMode) print('[InAppProxy] Error serving local file: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _proxyManifest(HttpRequest request, String targetUrl) async {
    final uri = Uri.parse(targetUrl);
    final client = http.Client();

    try {
      final req = http.Request('GET', uri)..headers.addAll(_getCustomHeaders(targetUrl));
      final streamedRes = await client.send(req);
      final body = await streamedRes.stream.bytesToString();

      if (streamedRes.statusCode != 200) {
        request.response.statusCode = streamedRes.statusCode;
        request.response.write(body);
        await request.response.close();
        return;
      }

      String manifestBody = body;
      final trimmedBody = body.trim();
      if (trimmedBody.startsWith('{') && trimmedBody.contains('"p"')) {
        try {
          final parsed = jsonDecode(trimmedBody);
          if (parsed is Map && parsed.containsKey('p')) {
            final pStr = (parsed['p'] as String).replaceAll('\n', '').replaceAll('\r', '').trim();
            manifestBody = utf8.decode(base64Decode(base64.normalize(pStr)));
          }
        } catch (_) {}
      }

      // Rewrite manifest lines so ExoPlayer / Chromecast requests through In-App Proxy
      final lines = manifestBody.split('\n');
      final newLines = <String>[];
      final baseUri = Uri.parse(targetUrl);
      final hostHeader = request.headers.value(HttpHeaders.hostHeader) ?? '127.0.0.1:$_port';
      final proxyBase = 'http://$hostHeader';

      String lastTag = '';
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) {
          if (trimmed.startsWith('#EXTINF')) {
            lastTag = 'EXTINF';
          } else if (trimmed.startsWith('#EXT-X-STREAM-INF') || trimmed.startsWith('#EXT-X-MEDIA')) {
            lastTag = 'STREAM-INF';
          }
          newLines.add(line);
        } else {
          final resolved = baseUri.resolve(trimmed).toString();
          final encoded = Uri.encodeComponent(resolved);
          final path = Uri.tryParse(resolved)?.path.toLowerCase() ?? '';
          final isSeg = lastTag == 'EXTINF' ||
              path.endsWith('.webp') ||
              path.endsWith('.ts') ||
              path.endsWith('.m4s') ||
              path.endsWith('.mp4') ||
              path.endsWith('.jpeg') ||
              path.endsWith('.jpg') ||
              trimmed.contains('.webp') ||
              trimmed.contains('.ts') ||
              trimmed.contains('.jpeg') ||
              trimmed.contains('/file/hls');

          if (isSeg) {
            newLines.add('$proxyBase/segment.ts?url=$encoded');
          } else {
            newLines.add('$proxyBase/manifest.m3u8?url=$encoded');
          }
        }
      }

      final output = newLines.join('\n');
      request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
      if (request.method != 'HEAD') {
        request.response.write(output);
      }
      await request.response.close();
    } finally {
      client.close();
    }
  }

  Future<void> _proxySegment(HttpRequest request, String targetUrl) async {
    final uri = Uri.parse(targetUrl);
    final client = http.Client();

    try {
      final req = http.Request('GET', uri)..headers.addAll(_getCustomHeaders(targetUrl));
      if (request.headers['range'] != null && request.headers['range']!.isNotEmpty) {
        req.headers['range'] = request.headers['range']!.first;
      }
      final streamedRes = await client.send(req);
      final bytes = await streamedRes.stream.toBytes();

      if (streamedRes.statusCode != 200 && streamedRes.statusCode != 206) {
        request.response.statusCode = streamedRes.statusCode;
        request.response.add(bytes);
        await request.response.close();
        return;
      }

      Uint8List payload = bytes;

      // Animenani strip fake PNG header (typically at offset 6455)
      // MPEG-TS packets start with sync byte 0x47 and have 188-byte stride
      if (payload.isNotEmpty && payload[0] != 0x47) {
        int tsStart = -1;
        if (payload.length > 6455 + 188 &&
            payload[6455] == 0x47 &&
            payload[6455 + 188] == 0x47) {
          tsStart = 6455;
        } else {
          // Scan for 3 consecutive MPEG-TS sync bytes (188 bytes apart)
          final searchLimit = payload.length < 15000 ? payload.length - 376 : 15000;
          for (int i = 0; i < searchLimit; i++) {
            if (payload[i] == 0x47 &&
                payload[i + 188] == 0x47 &&
                payload[i + 376] == 0x47) {
              tsStart = i;
              break;
            }
          }
        }

        if (tsStart > 0) {
          payload = payload.sublist(tsStart);
        }
      }

      request.response.headers.set('Accept-Ranges', 'bytes');
      if (streamedRes.statusCode == 206) {
        request.response.statusCode = HttpStatus.partialContent;
        if (streamedRes.headers['content-range'] != null) {
          request.response.headers.set('Content-Range', streamedRes.headers['content-range']!);
        }
      }
      request.response.headers.contentType = ContentType('video', 'mp2t');
      request.response.contentLength = payload.length;
      if (request.method != 'HEAD') {
        request.response.add(payload);
      }
      await request.response.close();
    } finally {
      client.close();
    }
  }

  Future<void> _serveWebTvPage(HttpRequest request) async {
    const html = '''<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Anime View - Web TV</title>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@1.5.8/dist/hls.min.js"></script>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body, html {
      width: 100%; height: 100%;
      background-color: #06080d;
      color: #f1f5f9;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      overflow: hidden;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    #tv-container {
      position: relative;
      width: 100vw;
      height: 100vh;
      background: #000;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    video {
      width: 100%;
      height: 100%;
      max-height: 100vh;
      outline: none;
      background: #000;
      object-fit: contain;
    }
    #empty-state {
      position: absolute;
      inset: 0;
      background: radial-gradient(circle at center, #141b2d 0%, #06080d 100%);
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      padding: 32px;
      text-align: center;
      z-index: 50;
      transition: opacity 0.4s ease;
    }
    #empty-state.hidden {
      opacity: 0;
      pointer-events: none;
    }
    .tv-icon {
      width: 96px;
      height: 96px;
      background: linear-gradient(135deg, #6366f1 0%, #a855f7 100%);
      border-radius: 28px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 50px;
      box-shadow: 0 16px 40px rgba(99, 102, 241, 0.4);
      margin-bottom: 24px;
      animation: pulse 2.5s infinite;
    }
    @keyframes pulse {
      0% { transform: scale(1); }
      50% { transform: scale(1.05); box-shadow: 0 20px 50px rgba(168, 85, 247, 0.6); }
      100% { transform: scale(1); }
    }
    h1 {
      font-size: 34px;
      font-weight: 700;
      margin-bottom: 12px;
      letter-spacing: -0.5px;
    }
    .subtitle {
      font-size: 18px;
      color: #94a3b8;
      max-width: 600px;
      line-height: 1.6;
      margin-bottom: 30px;
    }
    .status-pill {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      background: rgba(34, 197, 94, 0.15);
      border: 1px solid rgba(34, 197, 94, 0.4);
      color: #4ade80;
      padding: 8px 20px;
      border-radius: 9999px;
      font-size: 15px;
      font-weight: 600;
    }
    .dot {
      width: 10px;
      height: 10px;
      background: #22c55e;
      border-radius: 50%;
      box-shadow: 0 0 10px #22c55e;
      animation: blink 1.5s infinite;
    }
    @keyframes blink {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.3; }
    }
    #top-bar {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      padding: 24px 36px;
      background: linear-gradient(180deg, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0) 100%);
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 40;
      pointer-events: none;
      transition: opacity 0.5s ease;
    }
    #top-bar.hide {
      opacity: 0;
    }
    .media-info {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .media-title {
      font-size: 22px;
      font-weight: 700;
      color: #ffffff;
      text-shadow: 0 2px 8px rgba(0,0,0,0.8);
    }
    .media-sub {
      font-size: 15px;
      color: #a855f7;
      font-weight: 600;
      text-shadow: 0 2px 6px rgba(0,0,0,0.8);
    }
    .badge {
      background: rgba(255,255,255,0.2);
      backdrop-filter: blur(8px);
      padding: 6px 14px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 0.5px;
    }
    #toast {
      position: absolute;
      bottom: 60px;
      background: rgba(15, 23, 42, 0.9);
      border: 1px solid rgba(255, 255, 255, 0.15);
      color: #fff;
      padding: 10px 24px;
      border-radius: 12px;
      font-size: 16px;
      font-weight: 600;
      z-index: 60;
      pointer-events: none;
      opacity: 0;
      transform: translateY(20px);
      transition: all 0.25s ease;
    }
    #toast.show {
      opacity: 1;
      transform: translateY(0);
    }
    .remote-hint {
      margin-top: 36px;
      font-size: 13px;
      color: #64748b;
      display: flex;
      gap: 20px;
    }
    .remote-key {
      background: rgba(255,255,255,0.1);
      padding: 4px 10px;
      border-radius: 6px;
      color: #cbd5e1;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div id="tv-container">
    <video id="tv-player" playsinline controls autoplay></video>

    <div id="top-bar">
      <div class="media-info">
        <div id="media-title" class="media-title">Anime View</div>
        <div id="media-sub" class="media-sub">Web TV Player</div>
      </div>
      <div class="badge">Web TV 4K</div>
    </div>

    <div id="empty-state">
      <div class="tv-icon">📺</div>
      <h1>Anime View — Web TV</h1>
      <p class="subtitle">
        เปิดเชื่อมต่อหน้าจอนี้ไว้ แล้วกลับไปที่มือถือของท่าน<br>
        เลือกเปิดตอนหรือวิดีโอ (ทั้งแบบดูสด หรือวิดีโอที่โหลดไว้) เพื่อเริ่มเล่นทันที
      </p>
      <div class="status-pill">
        <div class="dot"></div>
        <span>เชื่อมต่อสัญญาณพร้อมเล่นแล้ว</span>
      </div>
      <div class="remote-hint">
        <div><span class="remote-key">OK / Space</span> เล่น-หยุด</div>
        <div><span class="remote-key">◀ / ▶</span> กรอ 10 วิ</div>
        <div><span class="remote-key">▲ / ▼</span> ระดับเสียง</div>
        <div><span class="remote-key">F</span> เต็มจอ</div>
      </div>
    </div>

    <div id="toast"></div>
  </div>

  <script>
    const video = document.getElementById('tv-player');
    const emptyState = document.getElementById('empty-state');
    const topBar = document.getElementById('top-bar');
    const titleEl = document.getElementById('media-title');
    const subEl = document.getElementById('media-sub');
    const toastEl = document.getElementById('toast');

    let hls = null;
    let lastCommandId = -1;
    let currentStreamUrl = '';
    let hideTimer = null;
    let toastTimer = null;

    function showToast(msg) {
      toastEl.innerText = msg;
      toastEl.classList.add('show');
      clearTimeout(toastTimer);
      toastTimer = setTimeout(() => toastEl.classList.remove('show'), 1800);
    }

    function showTopBar() {
      topBar.classList.remove('hide');
      clearTimeout(hideTimer);
      hideTimer = setTimeout(() => {
        if (!video.paused) topBar.classList.add('hide');
      }, 3500);
    }

    document.addEventListener('mousemove', showTopBar);
    document.addEventListener('keydown', showTopBar);

    function loadSource(url, seekTime = 0) {
      if (!url) return;
      currentStreamUrl = url;
      emptyState.classList.add('hidden');
      showTopBar();

      const isHls = url.includes('.m3u8') || url.includes('/local_playlist');

      if (isHls && window.Hls && Hls.isSupported()) {
        if (hls) hls.destroy();
        hls = new Hls({
          enableWorker: true,
          lowLatencyMode: false,
          maxBufferLength: 30,
        });
        hls.loadSource(url);
        hls.attachMedia(video);
        hls.on(Hls.Events.MANIFEST_PARSED, () => {
          if (seekTime > 0) video.currentTime = seekTime;
          video.play().catch(e => console.log('Autoplay deferred:', e));
        });
        hls.on(Hls.Events.ERROR, (event, data) => {
          if (data.fatal) {
            console.warn('HLS fatal error:', data);
            switch (data.type) {
              case Hls.ErrorTypes.NETWORK_ERROR:
                hls.startLoad();
                break;
              case Hls.ErrorTypes.MEDIA_ERROR:
                hls.recoverMediaError();
                break;
              default:
                hls.destroy();
                break;
            }
          }
        });
      } else if (isHls && video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = url;
        video.onloadedmetadata = () => {
          if (seekTime > 0) video.currentTime = seekTime;
          video.play().catch(e => {});
        };
      } else {
        video.src = url;
        if (seekTime > 0) video.currentTime = seekTime;
        video.play().catch(e => {});
      }
    }

    async function pollState() {
      try {
        const res = await fetch('/tv/api/state');
        if (!res.ok) return;
        const state = await res.json();

        if (state.streamUrl && state.streamUrl.trim() !== '') {
          if (titleEl.innerText !== state.title && state.title) {
            titleEl.innerText = state.title;
          }
          if (subEl.innerText !== state.subtitle && state.subtitle) {
            subEl.innerText = state.subtitle;
          }

          if (state.commandId !== lastCommandId) {
            lastCommandId = state.commandId;

            if (state.command === 'load' || currentStreamUrl !== state.streamUrl) {
              loadSource(state.streamUrl, state.seekTime || 0);
            } else if (state.command === 'play') {
              video.play().catch(() => {});
              showToast('▶ เล่น');
            } else if (state.command === 'pause') {
              video.pause();
              showToast('⏸ หยุดชั่วคราว');
            } else if (state.command === 'seek') {
              if (typeof state.seekTime === 'number') {
                video.currentTime = state.seekTime;
                showToast('ข้ามไปยัง ' + Math.floor(state.seekTime) + 's');
              }
            }
          }
        } else if (!currentStreamUrl) {
          emptyState.classList.remove('hidden');
        }
      } catch (err) {
        // network or server idle
      }
    }

    setInterval(pollState, 1000);
    pollState();

    // Report playback to phone
    setInterval(() => {
      if (!currentStreamUrl) return;
      fetch('/tv/api/report', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          currentTime: video.currentTime || 0,
          duration: video.duration || 0,
          state: video.paused ? 'PAUSED' : 'PLAYING'
        })
      }).catch(() => {});
    }, 1500);

    // TV Remote D-Pad / Keyboard controls
    document.addEventListener('keydown', (e) => {
      switch (e.keyCode || e.which) {
        case 32: // Space
        case 13: // Enter / OK
          if (video.paused) {
            video.play().catch(() => {});
            showToast('▶ เล่น');
          } else {
            video.pause();
            showToast('⏸ หยุดชั่วคราว');
          }
          e.preventDefault();
          break;
        case 37: // Left
          video.currentTime = Math.max(0, video.currentTime - 10);
          showToast('⏪ -10 วินาที');
          e.preventDefault();
          break;
        case 39: // Right
          video.currentTime = Math.min((video.duration || 999999), video.currentTime + 10);
          showToast('⏩ +10 วินาที');
          e.preventDefault();
          break;
        case 38: // Up
          video.volume = Math.min(1.0, video.volume + 0.1);
          showToast('🔊 ระดับเสียง ' + Math.round(video.volume * 100) + '%');
          e.preventDefault();
          break;
        case 40: // Down
          video.volume = Math.max(0.0, video.volume - 0.1);
          showToast('🔉 ระดับเสียง ' + Math.round(video.volume * 100) + '%');
          e.preventDefault();
          break;
        case 70: // 'F'
          if (!document.fullscreenElement) {
            document.documentElement.requestFullscreen().catch(() => {});
          } else {
            document.exitFullscreen().catch(() => {});
          }
          break;
      }
    });

    // Auto-enter fullscreen on first tap for TV browsers
    document.addEventListener('click', () => {
      if (!document.fullscreenElement && currentStreamUrl) {
        document.documentElement.requestFullscreen().catch(() => {});
      }
    });
  </script>
</body>
</html>
''';

    request.response.headers.contentType = ContentType.html;
    request.response.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    request.response.write(html);
    await request.response.close();
  }

  Future<void> _proxyDirectMedia(HttpRequest request, String targetUrl) async {
    final uri = Uri.parse(targetUrl);
    final client = http.Client();

    try {
      final req = http.Request(request.method, uri)..headers.addAll(_getCustomHeaders(targetUrl));
      if (request.headers['range'] != null && request.headers['range']!.isNotEmpty) {
        req.headers['range'] = request.headers['range']!.first;
      }

      final streamedRes = await client.send(req);
      request.response.statusCode = streamedRes.statusCode;

      streamedRes.headers.forEach((key, val) {
        final lower = key.toLowerCase();
        if (lower != 'content-length' &&
            lower != 'content-type' &&
            lower != 'access-control-allow-origin' &&
            lower != 'connection') {
          request.response.headers.set(key, val);
        }
      });

      request.response.headers.set('Accept-Ranges', 'bytes');
      if (streamedRes.headers['content-range'] != null) {
        request.response.headers.set('Content-Range', streamedRes.headers['content-range']!);
      }
      if (streamedRes.headers['content-type'] != null) {
        request.response.headers.set('Content-Type', streamedRes.headers['content-type']!);
      } else {
        request.response.headers.contentType = ContentType('video', 'mp4');
      }
      if (streamedRes.contentLength != null && streamedRes.contentLength! > 0) {
        request.response.contentLength = streamedRes.contentLength!;
      }

      if (request.method != 'HEAD') {
        await request.response.addStream(streamedRes.stream);
      }
      await request.response.close();
    } finally {
      client.close();
    }
  }
}
