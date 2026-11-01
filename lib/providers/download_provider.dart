import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import '../models/isar_models.dart';

class DownloadedAnimeGroup {
  final String animeSlug;
  final String animeTitle;
  final String animeCoverUrl;
  final List<DownloadItem> episodes;

  DownloadedAnimeGroup({
    required this.animeSlug,
    required this.animeTitle,
    required this.animeCoverUrl,
    required this.episodes,
  });

  int get totalBytes => episodes.fold(0, (sum, ep) => sum + ep.fileSizeBytes);
  int get completedCount => episodes.where((e) => e.isCompleted).length;
  int get downloadingCount => episodes.where((e) => e.isDownloading).length;
  int get failedCount => episodes.where((e) => e.isFailed).length;
  bool get hasActiveDownloads => downloadingCount > 0;
  int get keepForeverCount => episodes.where((e) => e.keepForever).length;
  bool get allKeepForever => episodes.isNotEmpty && episodes.every((e) => e.keepForever);
  bool get anyKeepForever => episodes.any((e) => e.keepForever);

  String get formattedTotalSize {
    final bytes = totalBytes;
    if (bytes <= 0) return '0 MB';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _QueuedDownloadRequest {
  final AnimeCollection anime;
  final EpisodeEmbedded episode;
  final String? serverUrl;
  final Completer<void> completer;

  _QueuedDownloadRequest({
    required this.anime,
    required this.episode,
    this.serverUrl,
  }) : completer = Completer<void>();
}

class DownloadProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final Map<String, DownloadItem> _downloads = {};
  final Set<String> _cancelledIds = {};
  final List<_QueuedDownloadRequest> _downloadQueue = [];
  bool _isProcessingQueue = false;
  String? _activeEpisodeId;
  Timer? _expirationTimer;

  static const String _prefDownloadsKey = 'pref_downloaded_episodes_v1';

  static Map<String, String> _getCustomHeaders(String url) {
    final lower = url.toLowerCase();
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

  DownloadProvider({required SharedPreferences prefs}) : _prefs = prefs {
    _loadFromPrefs();
    // Periodically check and clean expired files every 15 minutes
    _expirationTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      checkAndCleanExpiredFiles();
    });
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }

  List<DownloadItem> get allDownloads => _downloads.values.toList();
  List<DownloadItem> get completedDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.completed).toList();
  List<DownloadItem> get failedDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.failed).toList();
  List<DownloadItem> get queuedDownloads =>
      _downloads.values.where((d) => d.status == DownloadStatus.queued).toList();

  String? get activeDownloadingEpisodeId => _activeEpisodeId;

  /// Returns downloads grouped by Anime collection, with episodes sorted by storyline (episodeNumber ascending)
  List<DownloadedAnimeGroup> get animeGroups {
    final Map<String, List<DownloadItem>> grouped = {};
    for (final item in _downloads.values) {
      grouped.putIfAbsent(item.animeSlug, () => []).add(item);
    }

    final List<DownloadedAnimeGroup> result = [];
    for (final entry in grouped.entries) {
      final eps = List<DownloadItem>.from(entry.value);
      // เรียงตามเนื้อเรื่อง (episodeNumber: 1, 2, 3...)
      eps.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

      final first = eps.first;
      result.add(DownloadedAnimeGroup(
        animeSlug: entry.key,
        animeTitle: first.animeTitle,
        animeCoverUrl: first.animeCoverUrl,
        episodes: eps,
      ));
    }

    // Sort groups: active downloads first, then by title
    result.sort((a, b) {
      if (a.hasActiveDownloads && !b.hasActiveDownloads) return -1;
      if (!a.hasActiveDownloads && b.hasActiveDownloads) return 1;
      return a.animeTitle.compareTo(b.animeTitle);
    });

    return result;
  }

  DownloadItem? getDownload(String episodeId) => _downloads[episodeId];

  bool isDownloaded(String episodeId) {
    final item = _downloads[episodeId];
    return item != null && item.status == DownloadStatus.completed && File(item.localFilePath).existsSync();
  }

  bool isDownloading(String episodeId) {
    final item = _downloads[episodeId];
    return item != null && item.isDownloading;
  }

  double getProgress(String episodeId) {
    final item = _downloads[episodeId];
    return item?.progress ?? 0.0;
  }

  int get totalStorageBytes {
    int total = 0;
    for (final item in completedDownloads) {
      total += item.fileSizeBytes;
    }
    return total;
  }

  String get formattedTotalStorage {
    final total = totalStorageBytes;
    if (total <= 0) return '0 MB';
    if (total >= 1024 * 1024 * 1024) {
      return '${(total / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _loadFromPrefs() {
    final raw = _prefs.getString(_prefDownloadsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            final item = DownloadItem.fromJson(entry);
            // Verify file still exists on disk if marked completed
            if (item.status == DownloadStatus.completed) {
              if (File(item.localFilePath).existsSync()) {
                _downloads[item.episodeId] = item;
              }
            } else if (item.status == DownloadStatus.downloading || item.status == DownloadStatus.queued) {
              // Mark interrupted downloads as failed so user can tap retry
              item.status = DownloadStatus.failed;
              item.errorMessage = 'การดาวน์โหลดถูกขัดจังหวะ (กดเพื่อลองใหม่)';
              _downloads[item.episodeId] = item;
            } else {
              _downloads[item.episodeId] = item;
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('[DownloadProvider] Error loading prefs: $e');
      }
    }
    checkAndCleanExpiredFiles();
  }

  Future<void> _saveToPrefs() async {
    final list = _downloads.values.map((d) => d.toJson()).toList();
    await _prefs.setString(_prefDownloadsKey, jsonEncode(list));
  }

  /// Automatically clean expired files according to auto-delete rules
  Future<void> checkAndCleanExpiredFiles() async {
    final now = DateTime.now();
    final toRemove = <String>[];

    for (final item in _downloads.values) {
      if (item.status == DownloadStatus.completed && !item.keepForever && item.expiresAt.isBefore(now)) {
        try {
          final file = File(item.localFilePath);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
        toRemove.add(item.episodeId);
      }
    }

    if (toRemove.isNotEmpty) {
      for (final id in toRemove) {
        _downloads.remove(id);
      }
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Rule 1: หากดูจบแล้ว และไม่มาดูอีกใน 1 วัน ก็จะลบอัตโนมัติ (ยกเว้นตั้งค่าไม่ให้ลบ keepForever)
  Future<void> markEpisodeWatched(String episodeId) async {
    final item = _downloads[episodeId];
    if (item != null && item.status == DownloadStatus.completed) {
      if (item.keepForever) return;
      item.completedWatchAt = DateTime.now();
      item.expiresAt = DateTime.now().add(const Duration(hours: 24));
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// ขยายวัน (Extend expiration by X days, defaults to 7 days)
  Future<void> extendExpiration(String episodeId, {int days = 7}) async {
    final item = _downloads[episodeId];
    if (item != null) {
      final base = item.expiresAt.isBefore(DateTime.now()) ? DateTime.now() : item.expiresAt;
      item.expiresAt = base.add(Duration(days: days));
      item.keepForever = false;
      item.completedWatchAt = null;
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// สลับหรือตั้งค่าว่าตอนนี้จะไม่ลบ จนกว่าจะลบเอง (Keep indefinitely)
  Future<void> setEpisodeKeepForever(String episodeId, bool keepForever) async {
    final item = _downloads[episodeId];
    if (item != null) {
      item.keepForever = keepForever;
      if (keepForever) {
        item.completedWatchAt = null;
      }
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// ตั้งค่าทุกตอนของเรื่องนี้ว่าไม่ลบ จนกว่าจะลบเอง (Keep anime story indefinitely)
  Future<void> setAnimeKeepForever(String animeSlug, bool keepForever) async {
    bool changed = false;
    for (final item in _downloads.values) {
      if (item.animeSlug == animeSlug) {
        item.keepForever = keepForever;
        if (keepForever) {
          item.completedWatchAt = null;
        }
        changed = true;
      }
    }
    if (changed) {
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// ขยายวันหมดอายุของทุกตอนในเรื่องนี้ (+days วัน)
  Future<void> extendAnimeExpiration(String animeSlug, {int days = 7}) async {
    bool changed = false;
    final now = DateTime.now();
    for (final item in _downloads.values) {
      if (item.animeSlug == animeSlug) {
        final base = item.expiresAt.isBefore(now) ? now : item.expiresAt;
        item.expiresAt = base.add(Duration(days: days));
        item.keepForever = false;
        item.completedWatchAt = null;
        changed = true;
      }
    }
    if (changed) {
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Queue an episode for sequential, multi-part download
  Future<void> startDownload({
    required AnimeCollection anime,
    required EpisodeEmbedded episode,
    String? serverUrl,
  }) async {
    final epId = episode.id;
    if (epId == null || epId.isEmpty) return;

    if (isDownloading(epId)) return;
    _cancelledIds.remove(epId);

    final docDir = await getApplicationDocumentsDirectory();
    final safeSlug = anime.slug.replaceAll(RegExp(r'[^\w\-]'), '_');
    final safeEpId = epId.replaceAll(RegExp(r'[^\w\-]'), '_');
    final downloadDir = Directory('${docDir.path}/downloads/$safeSlug');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }

    final localPath = '${downloadDir.path}/$safeEpId.ts';

    String safeCoverUrl = '';
    try {
      safeCoverUrl = anime.coverUrl;
    } catch (_) {}

    final streamUrl = episode.streamUrl?.trim() ?? '';

    final downloadItem = DownloadItem(
      episodeId: epId,
      animeSlug: anime.slug,
      animeTitle: anime.title,
      animeCoverUrl: safeCoverUrl,
      episodeTitle: episode.title ?? 'ตอนที่ ${episode.episodeNumber?.toInt() ?? 1}',
      episodeNumber: episode.episodeNumber ?? 1.0,
      streamUrl: streamUrl,
      localFilePath: localPath,
      status: DownloadStatus.queued,
      progress: 0.0,
      downloadedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    _downloads[epId] = downloadItem;
    await _saveToPrefs();
    notifyListeners();

    final req = _QueuedDownloadRequest(
      anime: anime,
      episode: episode,
      serverUrl: serverUrl,
    );
    _downloadQueue.add(req);

    // Process download queue sequentially (one episode at a time)
    _processQueue();

    // Await this specific request's turn
    await req.completer.future;
  }

  /// Background sequential queue processor
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_downloadQueue.isNotEmpty) {
        final req = _downloadQueue.removeAt(0);
        final epId = req.episode.id;
        if (epId == null || _cancelledIds.contains(epId)) {
          _cancelledIds.remove(epId);
          if (epId != null) _downloads.remove(epId);
          await _saveToPrefs();
          notifyListeners();
          if (!req.completer.isCompleted) req.completer.complete();
          continue;
        }

        _activeEpisodeId = epId;
        final item = _downloads[epId];
        if (item != null) {
          item.status = DownloadStatus.downloading;
          item.progress = 0.01;
          notifyListeners();
        }

        try {
          await _executeDownload(req.anime, req.episode, req.serverUrl);
        } catch (_) {}

        _activeEpisodeId = null;
        if (!req.completer.isCompleted) req.completer.complete();
      }
    } finally {
      _isProcessingQueue = false;
      _activeEpisodeId = null;
    }
  }

  /// Internal download execution logic
  Future<void> _executeDownload(
    AnimeCollection anime,
    EpisodeEmbedded episode,
    String? serverUrl,
  ) async {
    final epId = episode.id;
    if (epId == null) return;
    final downloadItem = _downloads[epId];
    if (downloadItem == null) return;

    final localPath = downloadItem.localFilePath;
    var streamUrl = downloadItem.streamUrl.trim();

    // If stream URL is empty, try resolving from local server
    if (streamUrl.isEmpty && (episode.pageUrl?.isNotEmpty ?? false) && serverUrl != null) {
      try {
        final cleanServer = serverUrl.replaceAll(RegExp(r'/+$'), '');
        final res = await http.post(
          Uri.parse('$cleanServer/api/resolve_stream'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'page_url': episode.pageUrl}),
        ).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final resolved = data['stream_url']?.toString() ?? '';
          if (resolved.isNotEmpty) {
            streamUrl = resolved;
            episode.streamUrl = resolved;
            downloadItem.streamUrl = resolved;
          }
        }
      } catch (_) {}
    }

    if (streamUrl.isEmpty) {
      downloadItem.status = DownloadStatus.failed;
      downloadItem.errorMessage = 'ไม่พบ URL สตรีมของตอนนี้';
      await _saveToPrefs();
      notifyListeners();
      return;
    }

    try {
      final lowerUrl = streamUrl.toLowerCase();
      bool isHls = lowerUrl.contains('.m3u8') ||
          lowerUrl.contains('flower.txt') ||
          lowerUrl.contains('qqhls') ||
          lowerUrl.contains('stream-aph') ||
          lowerUrl.contains('qqstream') ||
          lowerUrl.contains('animenani') ||
          lowerUrl.contains('24playerhd') ||
          lowerUrl.contains('maimeorder') ||
          lowerUrl.contains('animemami') ||
          lowerUrl.endsWith('.txt') ||
          lowerUrl.contains('/o/') ||
          lowerUrl.contains('manifest') ||
          lowerUrl.contains('playlist') ||
          lowerUrl.contains('file2/');

      // If unsure, peek the first 256 bytes to see if it starts with #EXTM3U
      if (!isHls) {
        try {
          final probeReq = http.Request('GET', Uri.parse(streamUrl))
            ..headers.addAll(_getCustomHeaders(streamUrl))
            ..headers['Range'] = 'bytes=0-256';
          final probeRes = await http.Client().send(probeReq).timeout(const Duration(seconds: 6));
          final probeBytes = await probeRes.stream.toBytes();
          final probeStr = utf8.decode(probeBytes, allowMalformed: true);
          if (probeStr.startsWith('#EXTM3U')) {
            isHls = true;
          }
        } catch (_) {}
      }

      if (isHls) {
        // Multi-connection parallel segments download
        await _downloadHlsStream(streamUrl, localPath, downloadItem);
      } else {
        // Multi-part parallel range chunk download
        await _downloadDirectStream(streamUrl, localPath, downloadItem);
      }

      if (_cancelledIds.contains(epId)) {
        throw Exception('Download cancelled');
      }

      final file = File(localPath);
      if (file.existsSync() && file.lengthSync() > 1024) {
        downloadItem.fileSizeBytes = file.lengthSync();
        downloadItem.status = DownloadStatus.completed;
        downloadItem.progress = 1.0;
        downloadItem.downloadedAt = DateTime.now();
        downloadItem.expiresAt = DateTime.now().add(const Duration(days: 7));
      } else {
        throw Exception('ไฟล์ดาวน์โหลดไม่สมบูรณ์ หรือมีขนาดเล็กเกินไป');
      }
    } catch (e) {
      if (_cancelledIds.contains(epId)) {
        _downloads.remove(epId);
        try {
          final f = File(localPath);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      } else {
        downloadItem.status = DownloadStatus.failed;
        downloadItem.errorMessage = e.toString().replaceAll('Exception:', '').trim();
      }
    }

    _cancelledIds.remove(epId);
    await _saveToPrefs();
    notifyListeners();
  }

  /// Multi-worker parallel segment downloader for HLS (like IDM)
  Future<void> _downloadHlsStream(
    String streamUrl,
    String localPath,
    DownloadItem item,
  ) async {
    final client = http.Client();
    IOSink? sink;
    try {
      // 1. Fetch playlist manifest
      final uri = Uri.parse(streamUrl);
      final res = await client.get(uri, headers: _getCustomHeaders(streamUrl)).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        throw Exception('Failed to fetch manifest (HTTP ${res.statusCode})');
      }

      String manifestBody = res.body;
      final trimmedBody = manifestBody.trim();
      if (trimmedBody.startsWith('{') && trimmedBody.contains('"p"')) {
        try {
          final parsed = jsonDecode(trimmedBody);
          if (parsed is Map && parsed.containsKey('p')) {
            manifestBody = utf8.decode(base64Decode(parsed['p'] as String));
          }
        } catch (_) {}
      }
      Uri baseUri = uri;

      // Check if master playlist and pick the best variant (highest bandwidth/resolution)
      if (manifestBody.contains('#EXT-X-STREAM-INF:')) {
        final lines = manifestBody.split('\n');
        String? bestVariantUrl;
        int maxScore = -1;

        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('#EXT-X-STREAM-INF:')) {
            int score = 0;
            final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
            if (bwMatch != null) {
              score = int.tryParse(bwMatch.group(1)!) ?? 0;
            }
            final resMatch = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
            if (resMatch != null) {
              final h = int.tryParse(resMatch.group(2)!) ?? 0;
              score += h * 10000;
            }

            for (int j = i + 1; j < lines.length; j++) {
              final nextLine = lines[j].trim();
              if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
                final candUrl = baseUri.resolve(nextLine).toString();
                if (candUrl.contains('1080')) {
                  score += 20000000;
                } else if (candUrl.contains('720')) {
                  score += 10000000;
                }

                if (score > maxScore || bestVariantUrl == null) {
                  maxScore = score;
                  bestVariantUrl = candUrl;
                }
                break;
              }
            }
          }
        }

        if (bestVariantUrl != null) {
          final subUri = Uri.parse(bestVariantUrl);
          final subRes = await client.get(subUri, headers: _getCustomHeaders(subUri.toString())).timeout(const Duration(seconds: 25));
          if (subRes.statusCode == 200) {
            manifestBody = subRes.body;
            final subTrimmed = manifestBody.trim();
            if (subTrimmed.startsWith('{') && subTrimmed.contains('"p"')) {
              try {
                final parsed = jsonDecode(subTrimmed);
                if (parsed is Map && parsed.containsKey('p')) {
                  manifestBody = utf8.decode(base64Decode(parsed['p'] as String));
                }
              } catch (_) {}
            }
            baseUri = subUri;
          }
        }
      }

      // Extract all segment URLs
      final lines = manifestBody.split('\n');
      final segmentUrls = <String>[];
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          segmentUrls.add(baseUri.resolve(trimmed).toString());
        }
      }

      if (segmentUrls.isEmpty) {
        throw Exception('No video segments found in playlist');
      }

      final targetFile = File(localPath);
      if (targetFile.existsSync()) targetFile.deleteSync();
      sink = targetFile.openWrite();

      final total = segmentUrls.length;
      final Map<int, Uint8List> completedBuffer = {};
      int nextDownloadIndex = 0;
      int nextWriteIndex = 0;
      int successfulSegments = 0;
      const int maxConcurrentWorkers = 5;

      void writeAvailable() {
        while (completedBuffer.containsKey(nextWriteIndex)) {
          var bytes = completedBuffer.remove(nextWriteIndex)!;
          if (bytes.isNotEmpty) {
            successfulSegments++;

            // Strip fake PNG/JPEG header if present (common in animenani / qqhls / stream-aph)
            if (bytes[0] != 0x47) {
              int tsStart = -1;
              if (bytes.length > 6455 + 188 && bytes[6455] == 0x47 && bytes[6455 + 188] == 0x47) {
                tsStart = 6455;
              } else {
                final searchLimit = bytes.length < 15000 ? bytes.length - 376 : 15000;
                for (int j = 0; j < searchLimit; j++) {
                  if (bytes[j] == 0x47 && bytes[j + 188] == 0x47 && bytes[j + 376] == 0x47) {
                    tsStart = j;
                    break;
                  }
                }
              }
              if (tsStart > 0) {
                bytes = bytes.sublist(tsStart);
              }
            }

            sink?.add(bytes);
          }
          nextWriteIndex++;
          item.progress = (nextWriteIndex / total).clamp(0.02, 0.99);

          // Notify listeners periodically
          if (nextWriteIndex % 5 == 0 || nextWriteIndex == total) {
            notifyListeners();
          }
        }
      }

      Future<void> worker() async {
        while (true) {
          if (_cancelledIds.contains(item.episodeId)) break;

          // Backpressure: If memory buffer has > 25 segments waiting to be written, wait
          if (completedBuffer.length > 25) {
            await Future.delayed(const Duration(milliseconds: 30));
            continue;
          }

          final currentIndex = nextDownloadIndex++;
          if (currentIndex >= total) break;

          final segUrl = segmentUrls[currentIndex];
          Uint8List? bytes;

          for (int attempt = 0; attempt < 3; attempt++) {
            if (_cancelledIds.contains(item.episodeId)) break;
            try {
              final segRes = await client.get(
                Uri.parse(segUrl),
                headers: _getCustomHeaders(segUrl),
              ).timeout(const Duration(seconds: 30));

              if (segRes.statusCode == 200 && segRes.bodyBytes.isNotEmpty) {
                bytes = segRes.bodyBytes;
                break;
              }
            } catch (_) {
              if (attempt < 2) {
                await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
              }
            }
          }

          if (_cancelledIds.contains(item.episodeId)) break;

          completedBuffer[currentIndex] = bytes ?? Uint8List(0);
          writeAvailable();
        }
      }

      final workerCount = total < maxConcurrentWorkers ? total : maxConcurrentWorkers;
      final workers = List.generate(workerCount, (_) => worker());
      await Future.wait(workers);
      writeAvailable();

      if (successfulSegments == 0) {
        throw Exception('Failed to download video segments');
      }

      await sink.flush();
    } finally {
      await sink?.close();
      client.close();
    }
  }

  /// Multi-part parallel chunk downloader for direct HTTP video (like IDM)
  Future<void> _downloadDirectStream(
    String streamUrl,
    String localPath,
    DownloadItem item,
  ) async {
    final client = http.Client();
    try {
      int totalLength = -1;
      bool supportsRanges = false;

      // Probe Content-Length and Range support
      try {
        final probeRes = await client.get(
          Uri.parse(streamUrl),
          headers: {
            ..._getCustomHeaders(streamUrl),
            'Range': 'bytes=0-0',
          },
        ).timeout(const Duration(seconds: 10));

        if (probeRes.statusCode == 206) {
          supportsRanges = true;
          final cr = probeRes.headers['content-range'];
          if (cr != null) {
            final match = RegExp(r'/(\d+)').firstMatch(cr);
            if (match != null) {
              totalLength = int.tryParse(match.group(1)!) ?? -1;
            }
          }
        }
      } catch (_) {}

      // If multi-part is supported and size >= 4MB, download in 4 concurrent parts
      if (supportsRanges && totalLength > 4 * 1024 * 1024) {
        await _downloadDirectMultiPart(streamUrl, localPath, item, totalLength, client);
      } else {
        await _downloadDirectSingleStream(streamUrl, localPath, item, client);
      }
    } finally {
      client.close();
    }
  }

  /// Multi-part segmented range downloader
  Future<void> _downloadDirectMultiPart(
    String streamUrl,
    String localPath,
    DownloadItem item,
    int totalLength,
    http.Client client,
  ) async {
    const int partCount = 4;
    final int partSize = totalLength ~/ partCount;
    final List<String> partPaths = [];
    final List<int> receivedPerPart = List.filled(partCount, 0);

    try {
      final futures = <Future<void>>[];

      for (int i = 0; i < partCount; i++) {
        final start = i * partSize;
        final end = (i == partCount - 1) ? totalLength - 1 : (i + 1) * partSize - 1;
        final partPath = '$localPath.part$i';
        partPaths.add(partPath);

        futures.add(() async {
          final partFile = File(partPath);
          if (partFile.existsSync()) partFile.deleteSync();
          final partSink = partFile.openWrite();

          try {
            final req = http.Request('GET', Uri.parse(streamUrl))
              ..headers.addAll(_getCustomHeaders(streamUrl))
              ..headers['Range'] = 'bytes=$start-$end';

            final res = await client.send(req);
            if (res.statusCode != 200 && res.statusCode != 206) {
              throw Exception('Part $i failed (HTTP ${res.statusCode})');
            }

            await for (final chunk in res.stream) {
              if (_cancelledIds.contains(item.episodeId)) break;
              partSink.add(chunk);
              receivedPerPart[i] += chunk.length;

              final totalReceived = receivedPerPart.fold(0, (sum, v) => sum + v);
              item.progress = (totalReceived / totalLength).clamp(0.01, 0.99);
              notifyListeners();
            }
            await partSink.flush();
          } finally {
            await partSink.close();
          }
        }());
      }

      await Future.wait(futures);

      if (_cancelledIds.contains(item.episodeId)) {
        throw Exception('Download cancelled');
      }

      // Merge all parts sequentially into the final file
      final targetFile = File(localPath);
      if (targetFile.existsSync()) targetFile.deleteSync();
      final finalSink = targetFile.openWrite();

      try {
        for (final pPath in partPaths) {
          final pFile = File(pPath);
          if (pFile.existsSync()) {
            await finalSink.addStream(pFile.openRead());
          }
        }
        await finalSink.flush();
      } finally {
        await finalSink.close();
      }
    } finally {
      // Clean up temporary parts
      for (final pPath in partPaths) {
        try {
          final f = File(pPath);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Fallback single-stream downloader
  Future<void> _downloadDirectSingleStream(
    String streamUrl,
    String localPath,
    DownloadItem item,
    http.Client client,
  ) async {
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(streamUrl))..headers.addAll(_getCustomHeaders(streamUrl));
      final res = await client.send(req);
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw Exception('Direct download failed (HTTP ${res.statusCode})');
      }
      final total = res.contentLength ?? 0;

      final targetFile = File(localPath);
      if (targetFile.existsSync()) targetFile.deleteSync();
      sink = targetFile.openWrite();

      int received = 0;
      await for (final chunk in res.stream) {
        if (_cancelledIds.contains(item.episodeId)) break;
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          item.progress = (received / total).clamp(0.01, 0.99);
          notifyListeners();
        }
      }
      await sink.flush();
    } finally {
      await sink?.close();
    }
  }

  /// Cancel an ongoing or queued download
  Future<void> cancelDownload(String episodeId) async {
    _cancelledIds.add(episodeId);

    // Remove from pending queue if not yet started
    _downloadQueue.removeWhere((r) {
      if (r.episode.id == episodeId) {
        if (!r.completer.isCompleted) r.completer.complete();
        return true;
      }
      return false;
    });

    final item = _downloads[episodeId];
    if (item != null) {
      try {
        final f = File(item.localFilePath);
        if (f.existsSync()) f.deleteSync();
        for (int i = 0; i < 8; i++) {
          final part = File('${item.localFilePath}.part$i');
          if (part.existsSync()) part.deleteSync();
        }
      } catch (_) {}
      _downloads.remove(episodeId);
      await _saveToPrefs();
      notifyListeners();
    }
  }

  /// Delete a downloaded file or failed download entry
  Future<void> deleteDownload(String episodeId) async {
    await cancelDownload(episodeId);
  }

  /// Delete all failed downloads
  Future<void> deleteFailedDownloads() async {
    final toRemove = <String>[];
    for (final item in _downloads.values) {
      if (item.status == DownloadStatus.failed) {
        try {
          final f = File(item.localFilePath);
          if (f.existsSync()) f.deleteSync();
          for (int i = 0; i < 8; i++) {
            final part = File('${item.localFilePath}.part$i');
            if (part.existsSync()) part.deleteSync();
          }
        } catch (_) {}
        toRemove.add(item.episodeId);
      }
    }
    for (final id in toRemove) {
      _downloads.remove(id);
    }
    await _saveToPrefs();
    notifyListeners();
  }

  /// Retry a failed or cancelled download
  Future<void> retryDownload(
    String episodeId, {
    AnimeCollection? anime,
    EpisodeEmbedded? episode,
    String? serverUrl,
  }) async {
    final item = _downloads[episodeId];
    if (item == null) return;
    if (isDownloading(episodeId)) return;

    AnimeCollection targetAnime;
    EpisodeEmbedded targetEpisode;

    if (anime != null && episode != null) {
      targetAnime = anime;
      targetEpisode = episode;
    } else {
      targetAnime = AnimeCollection()
        ..slug = item.animeSlug
        ..title = item.animeTitle
        ..coverUrl = item.animeCoverUrl;
      targetEpisode = EpisodeEmbedded()
        ..id = item.episodeId
        ..title = item.episodeTitle
        ..episodeNumber = item.episodeNumber
        ..streamUrl = item.streamUrl;
      targetAnime.episodes = [targetEpisode];
    }

    _cancelledIds.remove(episodeId);
    await startDownload(
      anime: targetAnime,
      episode: targetEpisode,
      serverUrl: serverUrl,
    );
  }

  /// Delete all downloads for a specific anime
  Future<void> deleteAnimeDownloads(String slug) async {
    final toRemove = <String>[];
    for (final item in _downloads.values) {
      if (item.animeSlug == slug) {
        try {
          final f = File(item.localFilePath);
          if (f.existsSync()) f.deleteSync();
          for (int i = 0; i < 8; i++) {
            final part = File('${item.localFilePath}.part$i');
            if (part.existsSync()) part.deleteSync();
          }
        } catch (_) {}
        toRemove.add(item.episodeId);
      }
    }
    for (final id in toRemove) {
      _downloads.remove(id);
    }
    await _saveToPrefs();
    notifyListeners();
  }
}
