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
      // Bind to 127.0.0.1 on an available random port
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      if (kDebugMode) {
        print('[InAppProxy] Embedded stream proxy started on 127.0.0.1:$_port');
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

  /// Converts a direct stream URL into an in-app proxy loopback URL
  String getProxyUrl(String targetUrl) {
    if (_port == null) return targetUrl;
    final encoded = Uri.encodeComponent(targetUrl);
    return 'http://127.0.0.1:$_port/manifest.m3u8?url=$encoded';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    final targetUrl = request.uri.queryParameters['url'];

    // CORS headers
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

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

      // Rewrite manifest lines so ExoPlayer requests through In-App Proxy
      final lines = manifestBody.split('\n');
      final newLines = <String>[];
      final baseUri = Uri.parse(targetUrl);
      final proxyBase = 'http://127.0.0.1:$_port';

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
              trimmed.contains('.webp') ||
              trimmed.contains('.ts') ||
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
}
