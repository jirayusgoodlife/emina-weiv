import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/download_item.dart';
import '../models/isar_models.dart';
import '../models/quick_share_models.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/download_provider.dart';
import 'isar_service.dart';

class QuickShareHostInfo {
  final String serverUrl;
  final String qrPayload;
  final String ip;
  final int port;
  final QuickShareManifest manifest;

  QuickShareHostInfo({
    required this.serverUrl,
    required this.qrPayload,
    required this.ip,
    required this.port,
    required this.manifest,
  });
}

class QuickShareService {
  static QuickShareService? _instance;
  static QuickShareService get instance => _instance ??= QuickShareService._();

  QuickShareService._();

  HttpServer? _server;
  RawDatagramSocket? _beaconBroadcastSocket;
  Timer? _beaconTimer;
  QuickShareManifest? _activeManifest;
  final Map<String, DownloadItem> _sharedItems = {};
  String? _currentServerUrl;
  int _serverPort = 0;

  // Upload progress notification for sender
  final StreamController<QuickShareTransferProgress> _uploadProgressController =
      StreamController<QuickShareTransferProgress>.broadcast();
  Stream<QuickShareTransferProgress> get uploadProgressStream =>
      _uploadProgressController.stream;

  bool get isHosting => _server != null;
  String? get currentServerUrl => _currentServerUrl;
  QuickShareManifest? get activeManifest => _activeManifest;

  static const int udpBeaconPort = 45679;

  /// Find all IPv4 local network addresses (Wi-Fi, hotspot, Ethernet)
  static Future<List<String>> getLocalIpAddresses() async {
    final List<String> result = [];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !result.contains(addr.address)) {
            result.add(addr.address);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[QuickShare] Error getting IP addresses: $e');
    }

    // Sort IP addresses: prioritize common private LAN ranges (192.168.x.x, 10.x.x.x, 172.x.x.x)
    result.sort((a, b) {
      int score(String ip) {
        if (ip.startsWith('192.168.')) return 3;
        if (ip.startsWith('10.')) return 2;
        if (ip.startsWith('172.')) return 1;
        return 0;
      }
      return score(b).compareTo(score(a));
    });

    if (result.isEmpty) {
      result.add('127.0.0.1');
    }
    return result;
  }

  /// Start Quick Share Server on Sender device
  Future<QuickShareHostInfo> startHosting({
    required AnimeCollection anime,
    required List<DownloadItem> sharedItems,
    String? deviceName,
  }) async {
    // If already hosting, stop previous session
    await stopHosting();

    _sharedItems.clear();
    final List<QuickShareEpisodeItem> episodeManifestItems = [];

    for (final item in sharedItems) {
      if (!item.isCompleted) continue;
      final file = File(item.localFilePath);
      if (!file.existsSync()) continue;

      _sharedItems[item.episodeId] = item;
      episodeManifestItems.add(QuickShareEpisodeItem(
        episodeId: item.episodeId,
        episodeNumber: item.episodeNumber,
        episodeTitle: item.episodeTitle,
        fileSizeBytes: item.fileSizeBytes > 0 ? item.fileSizeBytes : file.lengthSync(),
        streamUrl: item.streamUrl,
        downloadUrl: '/quickshare/file/${Uri.encodeComponent(item.episodeId)}',
      ));
    }

    if (episodeManifestItems.isEmpty) {
      throw Exception('ไม่พบไฟล์ตอนที่ดาวน์โหลดสำเร็จเพื่อแชร์');
    }

    final effectiveDeviceName = deviceName ?? 'AnimeView Device';
    final manifest = QuickShareManifest(
      version: 1,
      deviceName: effectiveDeviceName,
      anime: anime,
      sharedEpisodes: episodeManifestItems,
    );
    _activeManifest = manifest;

    // Bind HTTP server to random available port on all IPv4 interfaces
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _serverPort = _server!.port;

    final ips = await getLocalIpAddresses();
    final primaryIp = ips.first;
    _currentServerUrl = 'http://$primaryIp:$_serverPort';

    // QR Payload formatted with serverUrl
    final qrPayload = jsonEncode({
      'type': 'anime_quick_share',
      'version': 1,
      'serverUrl': _currentServerUrl,
      'title': anime.title,
      'slug': anime.slug,
      'episodesCount': episodeManifestItems.length,
      'deviceName': effectiveDeviceName,
    });

    // Start listening to HTTP requests
    _startHttpListener();

    // Start UDP Beacon broadcast on local Wi-Fi
    _startBeaconBroadcast(primaryIp, _serverPort, anime.title, episodeManifestItems.length, effectiveDeviceName);

    return QuickShareHostInfo(
      serverUrl: _currentServerUrl!,
      qrPayload: qrPayload,
      ip: primaryIp,
      port: _serverPort,
      manifest: manifest,
    );
  }

  void _startHttpListener() {
    _server?.listen((HttpRequest request) async {
      try {
        final path = request.uri.path;

        // Enable CORS
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        request.response.headers.set('Access-Control-Allow-Headers', '*');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        if (path == '/quickshare/manifest') {
          request.response.headers.contentType = ContentType.json;
          final jsonStr = jsonEncode(_activeManifest?.toMap() ?? {});
          request.response.write(jsonStr);
          await request.response.close();
          return;
        }

        if (path == '/quickshare/ping') {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'status': 'ok', 'app': 'AnimeView'}));
          await request.response.close();
          return;
        }

        if (path.startsWith('/quickshare/file/')) {
          final episodeId = Uri.decodeComponent(path.substring('/quickshare/file/'.length));
          final item = _sharedItems[episodeId];

          if (item == null) {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Episode not found');
            await request.response.close();
            return;
          }

          final file = File(item.localFilePath);
          if (!file.existsSync()) {
            request.response.statusCode = HttpStatus.notFound;
            request.response.write('Local file missing on sender device');
            await request.response.close();
            return;
          }

          final fileSize = file.lengthSync();
          request.response.headers.contentType = ContentType('video', 'mp2t');
          request.response.headers.set(HttpHeaders.contentLengthHeader, fileSize);
          request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

          int bytesSent = 0;
          final stopwatch = Stopwatch()..start();

          final stream = file.openRead();
          await request.response.addStream(stream.map((chunk) {
            bytesSent += chunk.length;
            final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
            final speedMBs = elapsedSec > 0 ? (bytesSent / (1024 * 1024)) / elapsedSec : 0.0;

            _uploadProgressController.add(QuickShareTransferProgress(
              currentEpisodeTitle: item.episodeTitle,
              currentEpisodeIndex: 1,
              totalEpisodes: _sharedItems.length,
              bytesReceived: bytesSent,
              totalBytesCurrentEpisode: fileSize,
              totalBytesAll: fileSize,
              totalBytesTransferred: bytesSent,
              currentEpisodePercent: (bytesSent / fileSize).clamp(0.0, 1.0),
              overallPercent: (bytesSent / fileSize).clamp(0.0, 1.0),
              speedMBs: speedMBs,
              statusText: 'กำลังส่ง ${item.episodeTitle}',
              isCompleted: bytesSent >= fileSize,
            ));

            return chunk;
          }));

          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      } catch (e) {
        if (kDebugMode) print('[QuickShareServer] Request error: $e');
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        } catch (_) {}
      }
    });
  }

  void _startBeaconBroadcast(
    String ip,
    int port,
    String animeTitle,
    int epCount,
    String deviceName,
  ) async {
    try {
      _beaconBroadcastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      _beaconBroadcastSocket?.broadcastEnabled = true;

      final beaconData = jsonEncode({
        'type': 'anime_quick_share',
        'serverUrl': 'http://$ip:$port',
        'title': animeTitle,
        'episodesCount': epCount,
        'deviceName': deviceName,
      });
      final bytes = utf8.encode(beaconData);

      _beaconTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        try {
          _beaconBroadcastSocket?.send(
            bytes,
            InternetAddress('255.255.255.255'),
            udpBeaconPort,
          );
        } catch (_) {}
      });
    } catch (e) {
      if (kDebugMode) print('[QuickShare] Error starting UDP beacon: $e');
    }
  }

  /// Stop hosting server
  Future<void> stopHosting() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;

    try {
      _beaconBroadcastSocket?.close();
    } catch (_) {}
    _beaconBroadcastSocket = null;

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _currentServerUrl = null;
    _activeManifest = null;
    _sharedItems.clear();
  }

  // ==========================================
  // RECEIVER CLIENT LOGIC
  // ==========================================

  /// Listen for nearby devices broadcasting on the local network
  Stream<List<QuickShareNearbyDevice>> discoverNearbyDevices() async* {
    final Map<String, QuickShareNearbyDevice> discovered = {};
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpBeaconPort,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (e) {
      if (kDebugMode) print('[QuickShareReceiver] Socket bind error: $e');
      return;
    }

    final controller = StreamController<List<QuickShareNearbyDevice>>();

    // Periodic cleanup of stale devices (> 5 seconds without beacon)
    final cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final now = DateTime.now();
      discovered.removeWhere((_, dev) => now.difference(dev.lastSeen).inSeconds > 5);
      if (!controller.isClosed) {
        controller.add(discovered.values.toList());
      }
    });

    socket.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final dg = socket?.receive();
        if (dg != null) {
          try {
            final str = utf8.decode(dg.data);
            final json = jsonDecode(str) as Map<String, dynamic>;
            if (json['type'] == 'anime_quick_share') {
              final serverUrl = json['serverUrl']?.toString() ?? '';
              if (serverUrl.isNotEmpty) {
                discovered[serverUrl] = QuickShareNearbyDevice(
                  deviceName: json['deviceName']?.toString() ?? 'AnimeView Device',
                  animeTitle: json['title']?.toString() ?? 'อนิเมะ',
                  episodesCount: (json['episodesCount'] as num?)?.toInt() ?? 1,
                  serverUrl: serverUrl,
                  lastSeen: DateTime.now(),
                );
                if (!controller.isClosed) {
                  controller.add(discovered.values.toList());
                }
              }
            }
          } catch (_) {}
        }
      }
    });

    try {
      yield* controller.stream;
    } finally {
      cleanupTimer.cancel();
      socket.close();
      await controller.close();
    }
  }

  /// Parse QR code string or URL into clean server URL
  static String parseServerUrlFromQr(String raw) {
    String clean = raw.trim();
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final json = jsonDecode(clean) as Map<String, dynamic>;
        if (json.containsKey('serverUrl')) {
          clean = json['serverUrl'].toString().trim();
        }
      } catch (_) {}
    }

    if (clean.startsWith('animequickshare://')) {
      clean = 'http://${clean.substring('animequickshare://'.length)}';
    } else if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }

    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  /// Fetch manifest from sender server
  Future<QuickShareManifest> fetchManifest(String serverUrl) async {
    final cleanUrl = parseServerUrlFromQr(serverUrl);
    final uri = Uri.parse('$cleanUrl/quickshare/manifest');

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('ไม่สามารถเชื่อมต่อเครื่องผู้ส่งได้ (รหัส: ${response.statusCode})');
    }

    final jsonMap = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return QuickShareManifest.fromMap(jsonMap);
  }

  /// Transfer selected episodes to Receiver device and save to Isar and DownloadProvider
  Future<void> receiveTransfer({
    required String serverUrl,
    required QuickShareManifest manifest,
    required List<String> selectedEpisodeIds,
    required IsarService isarService,
    required DownloadProvider downloadProvider,
    required AnimeCatalogProvider animeCatalogProvider,
    required void Function(QuickShareTransferProgress progress) onProgress,
    bool Function()? isCancelled,
  }) async {
    final cleanServerUrl = parseServerUrlFromQr(serverUrl);

    // Filter to selected episodes
    final episodesToDownload = manifest.sharedEpisodes
        .where((ep) => selectedEpisodeIds.contains(ep.episodeId))
        .toList();

    if (episodesToDownload.isEmpty) {
      throw Exception('ไม่ได้เลือกตอนที่จะรับ');
    }

    final totalBytesAll = episodesToDownload.fold(0, (sum, ep) => sum + ep.fileSizeBytes);
    int totalBytesTransferred = 0;

    // 1. Ensure Anime is saved into Receiver's Isar DB
    await isarService.saveOrUpdateAnime(manifest.anime);
    // Reload catalog so that library immediately reflects new anime
    await animeCatalogProvider.loadData();

    final docDir = await getApplicationDocumentsDirectory();
    final safeSlug = manifest.anime.slug.replaceAll(RegExp(r'[^\w\-]'), '_');
    final downloadDir = Directory('${docDir.path}/downloads/$safeSlug');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }

    final client = http.Client();

    try {
      for (int i = 0; i < episodesToDownload.length; i++) {
        if (isCancelled?.call() == true) {
          throw Exception('ยกเลิกการถ่ายโอนแล้ว');
        }

        final ep = episodesToDownload[i];
        final safeEpId = ep.episodeId.replaceAll(RegExp(r'[^\w\-]'), '_');
        final targetFilePath = '${downloadDir.path}/$safeEpId.ts';
        final tempFilePath = '$targetFilePath.qspart';

        final tempFile = File(tempFilePath);
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }

        final fileUri = Uri.parse('$cleanServerUrl${ep.downloadUrl}');
        final request = http.Request('GET', fileUri);
        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode != 200) {
          throw Exception('เกิดข้อผิดพลาดในการดาวน์โหลดตอน ${ep.episodeTitle} (รหัส: ${streamedResponse.statusCode})');
        }

        final expectedEpisodeBytes = streamedResponse.contentLength ?? ep.fileSizeBytes;
        final sink = tempFile.openWrite();

        int epBytesReceived = 0;
        final stopwatch = Stopwatch()..start();

        await for (final chunk in streamedResponse.stream) {
          if (isCancelled?.call() == true) {
            await sink.close();
            if (tempFile.existsSync()) tempFile.deleteSync();
            throw Exception('ยกเลิกการถ่ายโอนแล้ว');
          }

          sink.add(chunk);
          epBytesReceived += chunk.length;
          final currentTotalTransferred = totalBytesTransferred + epBytesReceived;

          final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
          final speedMBs = elapsedSec > 0 ? (epBytesReceived / (1024 * 1024)) / elapsedSec : 0.0;

          final epPercent = expectedEpisodeBytes > 0
              ? (epBytesReceived / expectedEpisodeBytes).clamp(0.0, 1.0)
              : 0.0;
          final overallPercent = totalBytesAll > 0
              ? (currentTotalTransferred / totalBytesAll).clamp(0.0, 1.0)
              : 0.0;

          onProgress(QuickShareTransferProgress(
            currentEpisodeTitle: ep.episodeTitle,
            currentEpisodeIndex: i + 1,
            totalEpisodes: episodesToDownload.length,
            bytesReceived: epBytesReceived,
            totalBytesCurrentEpisode: expectedEpisodeBytes,
            totalBytesAll: totalBytesAll,
            totalBytesTransferred: currentTotalTransferred,
            currentEpisodePercent: epPercent,
            overallPercent: overallPercent,
            speedMBs: speedMBs,
            statusText: 'กำลังรับ ${ep.episodeTitle} (${i + 1}/${episodesToDownload.length})',
          ));
        }

        await sink.flush();
        await sink.close();

        // Rename temp file to target path
        if (File(targetFilePath).existsSync()) {
          File(targetFilePath).deleteSync();
        }
        tempFile.renameSync(targetFilePath);

        totalBytesTransferred += epBytesReceived;

        // 2. Register into DownloadProvider on Receiver device
        final completedItem = DownloadItem(
          episodeId: ep.episodeId,
          animeSlug: manifest.anime.slug,
          animeTitle: manifest.anime.title,
          animeCoverUrl: manifest.anime.coverUrl,
          episodeTitle: ep.episodeTitle,
          episodeNumber: ep.episodeNumber,
          streamUrl: ep.streamUrl,
          localFilePath: targetFilePath,
          fileSizeBytes: File(targetFilePath).lengthSync(),
          status: DownloadStatus.completed,
          progress: 1.0,
          downloadedAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );

        await downloadProvider.addCompletedDownload(completedItem);
      }

      // Notify final completed progress
      onProgress(QuickShareTransferProgress(
        currentEpisodeTitle: 'เสร็จสิ้นทั้งหมด',
        currentEpisodeIndex: episodesToDownload.length,
        totalEpisodes: episodesToDownload.length,
        bytesReceived: totalBytesAll,
        totalBytesCurrentEpisode: totalBytesAll,
        totalBytesAll: totalBytesAll,
        totalBytesTransferred: totalBytesAll,
        currentEpisodePercent: 1.0,
        overallPercent: 1.0,
        speedMBs: 0.0,
        statusText: 'รับไฟล์และบันทึกเข้าเครื่องสำเร็จครบทุกตอนแล้ว!',
        isCompleted: true,
      ));
    } finally {
      client.close();
    }
  }
}
