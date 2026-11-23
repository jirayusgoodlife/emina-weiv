import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anime_view/models/download_item.dart';
import 'package:anime_view/models/isar_models.dart';
import 'package:anime_view/models/quick_share_models.dart';
import 'package:anime_view/providers/download_provider.dart';
import 'package:anime_view/services/quick_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quick Share Models & Serialization', () {
    test('AnimeCollection and EpisodeEmbedded toMap / fromMap roundtrip', () {
      final anime = AnimeCollection()
        ..slug = 'solo-leveling'
        ..title = 'Solo Leveling'
        ..coverUrl = 'https://example.com/cover.jpg'
        ..backdropUrl = 'https://example.com/backdrop.jpg'
        ..synopsis = 'Sung Jin-woo begins his journey'
        ..rating = '9.2'
        ..status = 'Completed'
        ..year = '2024'
        ..sourceUrl = 'https://example.com/source'
        ..genres = ['Action', 'Fantasy']
        ..episodes = [
          EpisodeEmbedded()
            ..id = 'solo-leveling-ep-1'
            ..episodeNumber = 1.0
            ..title = 'ตอนที่ 1'
            ..streamUrl = 'https://example.com/stream1.m3u8'
            ..duration = '24:00',
          EpisodeEmbedded()
            ..id = 'solo-leveling-ep-2'
            ..episodeNumber = 2.0
            ..title = 'ตอนที่ 2'
            ..streamUrl = 'https://example.com/stream2.m3u8'
            ..duration = '23:45',
        ];

      final map = anime.toMap();
      expect(map['slug'], 'solo-leveling');
      expect(map['title'], 'Solo Leveling');
      expect(map['genres'], ['Action', 'Fantasy']);
      expect((map['episodes'] as List).length, 2);

      final restored = AnimeCollectionJson.fromMap(map);
      expect(restored.slug, 'solo-leveling');
      expect(restored.title, 'Solo Leveling');
      expect(restored.genres, ['Action', 'Fantasy']);
      expect(restored.episodes.length, 2);
      expect(restored.episodes[0].id, 'solo-leveling-ep-1');
      expect(restored.episodes[0].episodeNumber, 1.0);
      expect(restored.episodes[1].id, 'solo-leveling-ep-2');
    });

    test('QuickShareManifest toMap / fromMap roundtrip', () {
      final anime = AnimeCollection()
        ..slug = 'frieren'
        ..title = 'Frieren: Beyond Journey\'s End'
        ..coverUrl = 'https://example.com/frieren.jpg'
        ..genres = ['Adventure', 'Drama'];

      final sharedEp = QuickShareEpisodeItem(
        episodeId: 'frieren-ep-1',
        episodeNumber: 1.0,
        episodeTitle: 'ตอนที่ 1',
        fileSizeBytes: 120 * 1024 * 1024,
        streamUrl: 'https://example.com/frieren1.mp4',
        downloadUrl: '/quickshare/file/frieren-ep-1',
      );

      final manifest = QuickShareManifest(
        version: 1,
        deviceName: 'Pixel 8',
        anime: anime,
        sharedEpisodes: [sharedEp],
      );

      expect(sharedEp.formattedFileSize, '120.0 MB');
      expect(manifest.formattedTotalSize, '120.0 MB');

      final jsonMap = manifest.toMap();
      final restored = QuickShareManifest.fromMap(jsonMap);

      expect(restored.version, 1);
      expect(restored.deviceName, 'Pixel 8');
      expect(restored.anime.slug, 'frieren');
      expect(restored.sharedEpisodes.length, 1);
      expect(restored.sharedEpisodes.first.episodeId, 'frieren-ep-1');
      expect(restored.sharedEpisodes.first.fileSizeBytes, 120 * 1024 * 1024);
    });

    test('QuickShareService.parseServerUrlFromQr parses various URL inputs correctly', () {
      expect(
        QuickShareService.parseServerUrlFromQr('http://192.168.1.50:45678'),
        'http://192.168.1.50:45678',
      );
      expect(
        QuickShareService.parseServerUrlFromQr('http://192.168.1.50:45678/'),
        'http://192.168.1.50:45678',
      );
      expect(
        QuickShareService.parseServerUrlFromQr('192.168.1.50:45678'),
        'http://192.168.1.50:45678',
      );
      expect(
        QuickShareService.parseServerUrlFromQr('animequickshare://192.168.1.50:45678'),
        'http://192.168.1.50:45678',
      );
      // JSON format from QR code
      final jsonQr = jsonEncode({
        'type': 'anime_quick_share',
        'serverUrl': 'http://192.168.1.99:54321',
        'title': 'Test Anime',
      });
      expect(
        QuickShareService.parseServerUrlFromQr(jsonQr),
        'http://192.168.1.99:54321',
      );
    });
  });

  group('DownloadProvider Integration for Quick Share', () {
    test('addCompletedDownload registers completed item and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = DownloadProvider(prefs: prefs);

      final tempDir = Directory.systemTemp.createTempSync('qs_test_');
      final testFile = File('${tempDir.path}/test_ep1.ts');
      testFile.writeAsBytesSync(List.filled(1024 * 1024, 0xAA));

      final item = DownloadItem(
        episodeId: 'qs-test-ep-1',
        animeSlug: 'qs-anime',
        animeTitle: 'Quick Share Anime',
        animeCoverUrl: 'https://example.com/cover.jpg',
        episodeTitle: 'ตอนที่ 1',
        episodeNumber: 1.0,
        streamUrl: 'https://example.com/stream.m3u8',
        localFilePath: testFile.path,
        fileSizeBytes: testFile.lengthSync(),
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.addCompletedDownload(item);

      expect(notified, isTrue);
      expect(provider.isDownloaded('qs-test-ep-1'), isTrue);
      expect(provider.getDownload('qs-test-ep-1')?.fileSizeBytes, 1024 * 1024);
      expect(provider.animeGroups.length, 1);
      expect(provider.animeGroups.first.completedCount, 1);

      tempDir.deleteSync(recursive: true);
    });
  });

  group('QuickShareService Local Server Hosting', () {
    test('startHosting sets up HTTP endpoints and serves manifest and files correctly', () async {
      HttpOverrides.global = null;
      final tempDir = Directory.systemTemp.createTempSync('qs_server_test_');
      final dummyVideo = File('${tempDir.path}/ep1.ts');
      final dummyBytes = utf8.encode('DUMMY_VIDEO_STREAM_DATA_QUICK_SHARE');
      dummyVideo.writeAsBytesSync(dummyBytes);

      final anime = AnimeCollection()
        ..slug = 'test-slug'
        ..title = 'Test Quick Share Anime'
        ..coverUrl = 'https://example.com/test.jpg'
        ..genres = ['Action']
        ..episodes = [
          EpisodeEmbedded()
            ..id = 'ep-1'
            ..episodeNumber = 1.0
            ..title = 'ตอนที่ 1'
            ..streamUrl = 'https://example.com/ep1',
        ];

      final downloadItem = DownloadItem(
        episodeId: 'ep-1',
        animeSlug: 'test-slug',
        animeTitle: 'Test Quick Share Anime',
        animeCoverUrl: 'https://example.com/test.jpg',
        episodeTitle: 'ตอนที่ 1',
        episodeNumber: 1.0,
        streamUrl: 'https://example.com/ep1',
        localFilePath: dummyVideo.path,
        fileSizeBytes: dummyBytes.length,
        status: DownloadStatus.completed,
        progress: 1.0,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      final service = QuickShareService.instance;
      final hostInfo = await service.startHosting(
        anime: anime,
        sharedItems: [downloadItem],
        deviceName: 'TestHost',
      );

      expect(service.isHosting, isTrue);
      expect(hostInfo.port > 0, isTrue);
      expect(hostInfo.manifest.sharedEpisodes.length, 1);

      // Verify manifest endpoint
      final client = HttpClient();
      final manifestReq = await client.getUrl(Uri.parse('http://127.0.0.1:${hostInfo.port}/quickshare/manifest'));
      final manifestResp = await manifestReq.close();
      expect(manifestResp.statusCode, HttpStatus.ok);
      final manifestBody = await utf8.decodeStream(manifestResp);
      final manifestJson = jsonDecode(manifestBody) as Map<String, dynamic>;
      expect(manifestJson['deviceName'], 'TestHost');
      expect(manifestJson['anime']['slug'], 'test-slug');

      // Verify file streaming endpoint
      final fileReq = await client.getUrl(Uri.parse('http://127.0.0.1:${hostInfo.port}/quickshare/file/ep-1'));
      final fileResp = await fileReq.close();
      expect(fileResp.statusCode, HttpStatus.ok);
      expect(fileResp.headers.value(HttpHeaders.contentLengthHeader), '${dummyBytes.length}');
      final downloadedBytes = await fileResp.fold<List<int>>([], (prev, chunk) => prev..addAll(chunk));
      expect(utf8.decode(downloadedBytes), 'DUMMY_VIDEO_STREAM_DATA_QUICK_SHARE');

      // Stop hosting
      await service.stopHosting();
      expect(service.isHosting, isFalse);

      client.close();
      tempDir.deleteSync(recursive: true);
    });
  });
}
