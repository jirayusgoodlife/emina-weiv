import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anime_view/providers/download_provider.dart';
import 'package:anime_view/models/download_item.dart';
import 'package:anime_view/models/isar_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider channel
  const MethodChannel pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    pathChannel,
    (MethodCall methodCall) async {
      return Directory.systemTemp.path;
    },
  );

  group('DownloadProvider Tests', () {
    late SharedPreferences prefs;
    late DownloadProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      provider = DownloadProvider(prefs: prefs);
    });

    tearDown(() {
      provider.dispose();
    });

    test('Initial download list is empty', () {
      expect(provider.allDownloads, isEmpty);
      expect(provider.completedDownloads, isEmpty);
      expect(provider.totalStorageBytes, 0);
      expect(provider.formattedTotalStorage, '0 MB');
    });

    test('isDownloading and isDownloaded report false for non-existent episodes', () {
      expect(provider.isDownloading('unknown-id'), isFalse);
      expect(provider.isDownloaded('unknown-id'), isFalse);
      expect(provider.getProgress('unknown-id'), 0.0);
    });

    test('startDownload handles empty stream URL without crashing', () async {
      final anime = AnimeCollection()
        ..slug = 'test-anime'
        ..title = 'Test Anime';
      final ep = EpisodeEmbedded()
        ..id = 'test-ep-1'
        ..title = 'ตอนที่ 1'
        ..streamUrl = '';

      await provider.startDownload(
        anime: anime,
        episode: ep,
      );

      final dl = provider.getDownload('test-ep-1');
      expect(dl, isNotNull);
      expect(dl!.status.toString(), contains('failed'));
      expect(dl.errorMessage, contains('ไม่พบ URL'));
    });

    test('cancelDownload removes item from provider', () async {
      final anime = AnimeCollection()
        ..slug = 'test-anime-2'
        ..title = 'Test Anime 2';
      final ep = EpisodeEmbedded()
        ..id = 'test-ep-2'
        ..title = 'ตอนที่ 2'
        ..streamUrl = '';

      await provider.startDownload(anime: anime, episode: ep);
      expect(provider.getDownload('test-ep-2'), isNotNull);

      await provider.cancelDownload('test-ep-2');
      expect(provider.getDownload('test-ep-2'), isNull);
    });

    test('deleteDownload removes failed download item', () async {
      final anime = AnimeCollection()
        ..slug = 'test-anime-3'
        ..title = 'Test Anime 3';
      final ep = EpisodeEmbedded()
        ..id = 'test-ep-3'
        ..title = 'ตอนที่ 3'
        ..streamUrl = '';

      await provider.startDownload(anime: anime, episode: ep);
      expect(provider.failedDownloads.length, 1);
      expect(provider.getDownload('test-ep-3'), isNotNull);

      await provider.deleteDownload('test-ep-3');
      expect(provider.getDownload('test-ep-3'), isNull);
      expect(provider.failedDownloads, isEmpty);
    });

    test('retryDownload restarts failed download', () async {
      final anime = AnimeCollection()
        ..slug = 'test-anime-4'
        ..title = 'Test Anime 4';
      final ep = EpisodeEmbedded()
        ..id = 'test-ep-4'
        ..title = 'ตอนที่ 4'
        ..streamUrl = '';

      await provider.startDownload(anime: anime, episode: ep);
      final failedItem = provider.getDownload('test-ep-4');
      expect(failedItem, isNotNull);
      expect(failedItem!.status.toString(), contains('failed'));

      // Retry
      await provider.retryDownload('test-ep-4', anime: anime, episode: ep);
      final retriedItem = provider.getDownload('test-ep-4');
      expect(retriedItem, isNotNull);
    });

    test('deleteFailedDownloads removes only failed downloads', () async {
      final anime = AnimeCollection()
        ..slug = 'test-anime-5'
        ..title = 'Test Anime 5';
      final ep1 = EpisodeEmbedded()
        ..id = 'test-ep-5-1'
        ..title = 'ตอนที่ 1'
        ..streamUrl = '';
      final ep2 = EpisodeEmbedded()
        ..id = 'test-ep-5-2'
        ..title = 'ตอนที่ 2'
        ..streamUrl = '';

      await provider.startDownload(anime: anime, episode: ep1);
      await provider.startDownload(anime: anime, episode: ep2);
      expect(provider.failedDownloads.length, 2);

      await provider.deleteFailedDownloads();
      expect(provider.failedDownloads, isEmpty);
      expect(provider.allDownloads, isEmpty);
    });

    test('animeGroups groups by animeSlug and sorts episodes by storyline (episodeNumber)', () async {
      final anime1 = AnimeCollection()
        ..slug = 'naruto'
        ..title = 'Naruto';
      final anime2 = AnimeCollection()
        ..slug = 'one-piece'
        ..title = 'One Piece';

      // Insert episodes out of order: Episode 3 first, then Episode 1, then Episode 2
      final ep3 = EpisodeEmbedded()
        ..id = 'naruto-ep-3'
        ..title = 'ตอนที่ 3'
        ..episodeNumber = 3.0
        ..streamUrl = '';
      final ep1 = EpisodeEmbedded()
        ..id = 'naruto-ep-1'
        ..title = 'ตอนที่ 1'
        ..episodeNumber = 1.0
        ..streamUrl = '';
      final ep2 = EpisodeEmbedded()
        ..id = 'naruto-ep-2'
        ..title = 'ตอนที่ 2'
        ..episodeNumber = 2.0
        ..streamUrl = '';
      final op1 = EpisodeEmbedded()
        ..id = 'op-ep-1'
        ..title = 'ตอนที่ 1'
        ..episodeNumber = 1.0
        ..streamUrl = '';

      await provider.startDownload(anime: anime1, episode: ep3);
      await provider.startDownload(anime: anime1, episode: ep1);
      await provider.startDownload(anime: anime1, episode: ep2);
      await provider.startDownload(anime: anime2, episode: op1);

      final groups = provider.animeGroups;
      expect(groups.length, 2);

      final narutoGroup = groups.firstWhere((g) => g.animeSlug == 'naruto');
      expect(narutoGroup.animeTitle, 'Naruto');
      expect(narutoGroup.episodes.length, 3);

      // Verify strict storyline ordering (ตอนที่ 1, 2, 3)
      expect(narutoGroup.episodes[0].episodeNumber, 1.0);
      expect(narutoGroup.episodes[1].episodeNumber, 2.0);
      expect(narutoGroup.episodes[2].episodeNumber, 3.0);
      expect(narutoGroup.episodes[0].episodeTitle, 'ตอนที่ 1');
      expect(narutoGroup.episodes[1].episodeTitle, 'ตอนที่ 2');
      expect(narutoGroup.episodes[2].episodeTitle, 'ตอนที่ 3');

      final opGroup = groups.firstWhere((g) => g.animeSlug == 'one-piece');
      expect(opGroup.episodes.length, 1);

      // Delete all downloads for anime1
      await provider.deleteAnimeDownloads('naruto');
      expect(provider.animeGroups.length, 1);
      expect(provider.animeGroups.first.animeSlug, 'one-piece');
    });

    test('keepForever serialization and properties work as expected', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 10));
      final item = DownloadItem(
        episodeId: 'test-forever-1',
        animeSlug: 'test-slug',
        animeTitle: 'Test Anime',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 1',
        episodeNumber: 1.0,
        streamUrl: 'http://test.com/stream.m3u8',
        localFilePath: '/tmp/test.ts',
        downloadedAt: past,
        expiresAt: past,
        status: DownloadStatus.completed,
        keepForever: true,
      );

      // Even if expiresAt is in past, keepForever prevents expiration
      expect(item.keepForever, isTrue);
      expect(item.isExpired, isFalse);
      expect(item.remainingTimeText, 'เก็บจนกว่าจะลบเอง');

      // JSON serialization
      final json = item.toJson();
      expect(json['keepForever'], isTrue);

      final restored = DownloadItem.fromJson(json);
      expect(restored.keepForever, isTrue);
      expect(restored.isExpired, isFalse);
      expect(restored.remainingTimeText, 'เก็บจนกว่าจะลบเอง');
    });

    test('Episode-level and Anime-level keepForever toggle and extend expiration', () async {
      final anime = AnimeCollection()
        ..slug = 'bleach'
        ..title = 'Bleach';

      final ep1 = EpisodeEmbedded()
        ..id = 'bleach-ep-1'
        ..title = 'ตอนที่ 1'
        ..episodeNumber = 1.0
        ..streamUrl = '';
      final ep2 = EpisodeEmbedded()
        ..id = 'bleach-ep-2'
        ..title = 'ตอนที่ 2'
        ..episodeNumber = 2.0
        ..streamUrl = '';

      await provider.startDownload(anime: anime, episode: ep1);
      await provider.startDownload(anime: anime, episode: ep2);

      final dl1 = provider.getDownload('bleach-ep-1')!;
      final dl2 = provider.getDownload('bleach-ep-2')!;
      dl1.status = DownloadStatus.completed;
      dl2.status = DownloadStatus.completed;

      // 1. Episode-level keepForever
      await provider.setEpisodeKeepForever('bleach-ep-1', true);
      expect(dl1.keepForever, isTrue);
      expect(dl2.keepForever, isFalse);

      var group = provider.animeGroups.firstWhere((g) => g.animeSlug == 'bleach');
      expect(group.keepForeverCount, 1);
      expect(group.allKeepForever, isFalse);
      expect(group.anyKeepForever, isTrue);

      // 2. Anime-level keepForever
      await provider.setAnimeKeepForever('bleach', true);
      expect(dl1.keepForever, isTrue);
      expect(dl2.keepForever, isTrue);

      group = provider.animeGroups.firstWhere((g) => g.animeSlug == 'bleach');
      expect(group.keepForeverCount, 2);
      expect(group.allKeepForever, isTrue);
      expect(group.anyKeepForever, isTrue);

      // 3. Mark episode watched does NOT overwrite keepForever episodes
      final expBefore = dl1.expiresAt;
      await provider.markEpisodeWatched('bleach-ep-1');
      expect(dl1.keepForever, isTrue);
      expect(dl1.expiresAt, expBefore);

      // 4. Extend anime expiration (+30 days)
      final oldExp = dl2.expiresAt;
      await provider.extendAnimeExpiration('bleach', days: 30);
      expect(dl1.keepForever, isFalse); // reset to timed expiration
      expect(dl2.keepForever, isFalse);
      expect(dl2.expiresAt.isAfter(oldExp.add(const Duration(days: 29))), isTrue);

      // 5. Check clean expired files does not remove keepForever files
      dl1.keepForever = true;
      dl1.expiresAt = DateTime.now().subtract(const Duration(days: 10)); // past expiration
      await provider.checkAndCleanExpiredFiles();
      expect(provider.getDownload('bleach-ep-1'), isNotNull);
    });

    test('downloadAllEpisodes queues all episodes and supports cancellation and helpers', () async {
      final anime = AnimeCollection()
        ..slug = 'naruto'
        ..title = 'Naruto';

      final ep1 = EpisodeEmbedded()
        ..id = 'naruto-1'
        ..title = 'ตอนที่ 1'
        ..episodeNumber = 1.0
        ..streamUrl = 'http://127.0.0.1:9999/naruto-1.m3u8';
      final ep2 = EpisodeEmbedded()
        ..id = 'naruto-2'
        ..title = 'ตอนที่ 2'
        ..episodeNumber = 2.0
        ..streamUrl = 'http://127.0.0.1:9999/naruto-2.m3u8';
      final ep3 = EpisodeEmbedded()
        ..id = 'naruto-3'
        ..title = 'ตอนที่ 3'
        ..episodeNumber = 3.0
        ..streamUrl = 'http://127.0.0.1:9999/naruto-3.m3u8';

      anime.episodes = [ep1, ep2, ep3];

      // Download all
      final queuedCount = await provider.downloadAllEpisodes(anime: anime);
      expect(queuedCount, 3);
      expect(provider.isAnimeDownloading('naruto'), isTrue);

      // Cancel all downloads
      await provider.cancelAnimeDownloads('naruto');
      expect(provider.isAnimeDownloading('naruto'), isFalse);
    });

    test('retryAllFailedDownloads and retryFailedDownloadsForAnime re-enqueue failed downloads', () async {
      final anime = AnimeCollection()
        ..slug = 'bleach-failed'
        ..title = 'Bleach Failed';

      final ep1 = EpisodeEmbedded()
        ..id = 'bf-1'
        ..title = 'ตอนที่ 1'
        ..episodeNumber = 1.0
        ..streamUrl = '';
      final ep2 = EpisodeEmbedded()
        ..id = 'bf-2'
        ..title = 'ตอนที่ 2'
        ..episodeNumber = 2.0
        ..streamUrl = '';

      anime.episodes = [ep1, ep2];
      await provider.startDownload(anime: anime, episode: ep1);
      await provider.startDownload(anime: anime, episode: ep2);

      expect(provider.failedDownloads.length, 2);

      // Retry all
      final retried = await provider.retryAllFailedDownloads(availableAnime: [anime]);
      expect(retried, 2);
    });

    test('setMaxConcurrentDownloads updates limit and persists in SharedPreferences', () async {
      expect(provider.maxConcurrentDownloads, DownloadProvider.defaultMaxConcurrentDownloads);
      await provider.setMaxConcurrentDownloads(4);
      expect(provider.maxConcurrentDownloads, 4);

      // Clamped to 1-5
      await provider.setMaxConcurrentDownloads(10);
      expect(provider.maxConcurrentDownloads, 5);
      await provider.setMaxConcurrentDownloads(0);
      expect(provider.maxConcurrentDownloads, 1);
    });

    test('isPossiblyIncomplete identifies files under 35MB', () {
      final normalItem = DownloadItem(
        episodeId: 'norm-1',
        animeSlug: 'test',
        animeTitle: 'Test Anime',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 1',
        episodeNumber: 1.0,
        streamUrl: 'http://example.com/1.m3u8',
        localFilePath: '/tmp/test1.mp4',
        fileSizeBytes: 150 * 1024 * 1024, // 150 MB
        status: DownloadStatus.completed,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      final smallItem = DownloadItem(
        episodeId: 'small-1',
        animeSlug: 'test',
        animeTitle: 'Test Anime',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 2',
        episodeNumber: 2.0,
        streamUrl: 'http://example.com/2.m3u8',
        localFilePath: '/tmp/test2.mp4',
        fileSizeBytes: 25 * 1024 * 1024, // 25 MB (incomplete)
        status: DownloadStatus.completed,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      final incompleteFailedItem = DownloadItem(
        episodeId: 'failed-1',
        animeSlug: 'test',
        animeTitle: 'Test Anime',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 3',
        episodeNumber: 3.0,
        streamUrl: 'http://example.com/3.m3u8',
        localFilePath: '/tmp/test3.mp4',
        fileSizeBytes: 25 * 1024 * 1024,
        status: DownloadStatus.failed,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      expect(normalItem.isPossiblyIncomplete, isFalse);
      expect(smallItem.isPossiblyIncomplete, isTrue);
      // Failed items are not considered "completed with small size"
      expect(incompleteFailedItem.isPossiblyIncomplete, isFalse);

      final group = DownloadedAnimeGroup(
        animeSlug: 'test',
        animeTitle: 'Test Anime',
        animeCoverUrl: '',
        episodes: [normalItem, smallItem],
      );
      expect(group.possiblyIncompleteCount, 1);
      expect(group.hasPossiblyIncomplete, isTrue);
    });

    test('redownloadEpisode and redownloadPossiblyIncompleteDownloads re-download incomplete items', () async {
      final anime = AnimeCollection()
        ..slug = 'one-piece-redownload'
        ..title = 'One Piece';

      final ep1 = EpisodeEmbedded()
        ..id = 'op-1'
        ..title = 'ตอนที่ 1'
        ..episodeNumber = 1.0
        ..streamUrl = 'http://127.0.0.1:9999/op-1.m3u8';
      final ep2 = EpisodeEmbedded()
        ..id = 'op-2'
        ..title = 'ตอนที่ 2'
        ..episodeNumber = 2.0
        ..streamUrl = 'http://127.0.0.1:9999/op-2.m3u8';

      anime.episodes = [ep1, ep2];

      final tempDir = Directory.systemTemp.createTempSync('op_test_');
      final f1 = File('${tempDir.path}/op1.mp4')..writeAsBytesSync([1, 2, 3]);
      final f2 = File('${tempDir.path}/op2.mp4')..writeAsBytesSync([1, 2, 3]);

      // Simulate ep1 completed but only 25MB
      final item1 = DownloadItem(
        episodeId: 'op-1',
        animeSlug: 'one-piece-redownload',
        animeTitle: 'One Piece',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 1',
        episodeNumber: 1.0,
        streamUrl: 'http://127.0.0.1:9999/op-1.m3u8',
        localFilePath: f1.path,
        fileSizeBytes: 25 * 1024 * 1024,
        status: DownloadStatus.completed,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      // Simulate ep2 completed normally (200MB)
      final item2 = DownloadItem(
        episodeId: 'op-2',
        animeSlug: 'one-piece-redownload',
        animeTitle: 'One Piece',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 2',
        episodeNumber: 2.0,
        streamUrl: 'http://127.0.0.1:9999/op-2.m3u8',
        localFilePath: f2.path,
        fileSizeBytes: 200 * 1024 * 1024,
        status: DownloadStatus.completed,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      // Inject items into SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pref_downloaded_episodes_v1',
        jsonEncode([item1.toJson(), item2.toJson()]),
      );

      // Create new provider loading this state
      final newProv = DownloadProvider(prefs: prefs);
      expect(newProv.isPossiblyIncomplete(newProv.getDownload('op-1')!), isTrue);
      expect(newProv.isPossiblyIncomplete(newProv.getDownload('op-2')!), isFalse);
      expect(newProv.possiblyIncompleteDownloads.length, 1);

      // Redownload incomplete files
      final retriedCount = await newProv.redownloadPossiblyIncompleteDownloads(availableAnime: [anime]);
      expect(retriedCount, 1);

      // Verify op-1 was re-downloaded (status changed from completed to failed because dummy URL, proving download attempted)
      expect(newProv.getDownload('op-1')?.status, DownloadStatus.failed);
      // op-2 was not incomplete, so it remains completed
      expect(newProv.getDownload('op-2')?.status, DownloadStatus.completed);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('redownloadAnime re-downloads all episodes of that anime', () async {
      final anime = AnimeCollection()
        ..slug = 'naruto-re'
        ..title = 'Naruto Re';

      final ep1 = EpisodeEmbedded()
        ..id = 'nre-1'
        ..title = 'ตอนที่ 1'
        ..episodeNumber = 1.0
        ..streamUrl = 'http://127.0.0.1:9999/nre-1.m3u8';
      final ep2 = EpisodeEmbedded()
        ..id = 'nre-2'
        ..title = 'ตอนที่ 2'
        ..episodeNumber = 2.0
        ..streamUrl = 'http://127.0.0.1:9999/nre-2.m3u8';

      anime.episodes = [ep1, ep2];

      final tempDir = Directory.systemTemp.createTempSync('nre_test_');
      final f1 = File('${tempDir.path}/nre1.mp4')..writeAsBytesSync([1, 2, 3]);
      final f2 = File('${tempDir.path}/nre2.mp4')..writeAsBytesSync([1, 2, 3]);

      final prefs = await SharedPreferences.getInstance();
      final item1 = DownloadItem(
        episodeId: 'nre-1',
        animeSlug: 'naruto-re',
        animeTitle: 'Naruto Re',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 1',
        episodeNumber: 1.0,
        streamUrl: 'http://127.0.0.1:9999/nre-1.m3u8',
        localFilePath: f1.path,
        fileSizeBytes: 25 * 1024 * 1024,
        status: DownloadStatus.completed,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
      final item2 = DownloadItem(
        episodeId: 'nre-2',
        animeSlug: 'naruto-re',
        animeTitle: 'Naruto Re',
        animeCoverUrl: '',
        episodeTitle: 'ตอนที่ 2',
        episodeNumber: 2.0,
        streamUrl: 'http://127.0.0.1:9999/nre-2.m3u8',
        localFilePath: f2.path,
        fileSizeBytes: 200 * 1024 * 1024,
        status: DownloadStatus.completed,
        downloadedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      await prefs.setString(
        'pref_downloaded_episodes_v1',
        jsonEncode([item1.toJson(), item2.toJson()]),
      );

      final prov = DownloadProvider(prefs: prefs);
      final redownloadCount = await prov.redownloadAnime('naruto-re', anime: anime);
      expect(redownloadCount, 2);
      // Both items were re-downloaded (status changed from completed to failed because dummy URL)
      expect(prov.getDownload('nre-1')?.status, DownloadStatus.failed);
      expect(prov.getDownload('nre-2')?.status, DownloadStatus.failed);

      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
