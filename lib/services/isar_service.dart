import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/isar_models.dart';

class SyncResult {
  final bool success;
  final int animeCount;
  final String message;

  SyncResult({
    required this.success,
    required this.animeCount,
    required this.message,
  });
}

class IsarService {
  final Isar _isar;

  IsarService(this._isar);

  static Future<IsarService> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final isar = await Isar.open(
      [AnimeCollectionSchema],
      directory: dir.path,
      name: 'anime_view_isar',
    );
    return IsarService(isar);
  }

  Isar get isar => _isar;

  // Query all anime sorted by recently updated
  Future<List<AnimeCollection>> getAllAnime() async {
    return await _isar.animeCollections.where().sortByUpdatedAtDesc().findAll();
  }

  // Get single anime by slug
  Future<AnimeCollection?> getAnimeBySlug(String slug) async {
    return await _isar.animeCollections.filter().slugEqualTo(slug).findFirst();
  }

  // Get continue watching list
  Future<List<AnimeCollection>> getContinueWatching() async {
    final list = await _isar.animeCollections
        .filter()
        .lastWatchedEpisodeIdIsNotNull()
        .findAll();

    // Sort by lastWatchedAt descending
    list.sort((a, b) {
      final aDate = a.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.lastWatchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return list;
  }

  // Update playback history
  Future<void> updatePlaybackProgress({
    required String slug,
    required String episodeId,
    required int positionSeconds,
  }) async {
    final anime = await getAnimeBySlug(slug);
    if (anime != null) {
      await _isar.writeTxn(() async {
        anime.lastWatchedEpisodeId = episodeId;
        anime.lastWatchedPositionSeconds = positionSeconds;
        anime.lastWatchedAt = DateTime.now();
        await _isar.animeCollections.put(anime);
      });
    }
  }

  // Remove from continue watching list
  Future<void> removeFromContinueWatching(String slug) async {
    final anime = await getAnimeBySlug(slug);
    if (anime != null) {
      await _isar.writeTxn(() async {
        anime.lastWatchedEpisodeId = null;
        anime.lastWatchedPositionSeconds = null;
        anime.lastWatchedAt = null;
        await _isar.animeCollections.put(anime);
      });
    }
  }

  // Restore continue watching (e.g. for undo)
  Future<void> restoreContinueWatching({
    required String slug,
    required String? episodeId,
    required int? positionSeconds,
    required DateTime? lastWatchedAt,
  }) async {
    final anime = await getAnimeBySlug(slug);
    if (anime != null) {
      await _isar.writeTxn(() async {
        anime.lastWatchedEpisodeId = episodeId;
        anime.lastWatchedPositionSeconds = positionSeconds;
        anime.lastWatchedAt = lastWatchedAt;
        await _isar.animeCollections.put(anime);
      });
    }
  }

  // Sync from Local Python Server
  Future<SyncResult> syncFromLocalServer(String serverBaseUrl) async {
    String cleanUrl = serverBaseUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.endsWith('/api/sync')) {
      cleanUrl = '$cleanUrl/api/sync';
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }

    try {
      final uri = Uri.parse(cleanUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return SyncResult(
          success: false,
          animeCount: 0,
          message: 'เซิร์ฟเวอร์ตอบกลับรหัส: ${response.statusCode}',
        );
      }

      final jsonMap = json.decode(utf8.decode(response.bodyBytes));
      final List<dynamic> data = jsonMap['data'] ?? [];

      int syncedCount = 0;

      await _isar.writeTxn(() async {
        // Collect server slugs to remove deleted anime from phone
        final serverSlugs = <String>{};

        for (final item in data) {
          final slug = item['slug']?.toString() ?? '';
          if (slug.isEmpty) continue;
          serverSlugs.add(slug);

          // Check if already in Isar
          final existing = await _isar.animeCollections.filter().slugEqualTo(slug).findFirst();
          final anime = existing ?? AnimeCollection();

          anime.slug = slug;
          anime.title = item['title']?.toString() ?? 'Untitled';
          anime.coverUrl = item['cover_url']?.toString() ?? '';
          anime.backdropUrl = item['backdrop_url']?.toString() ?? anime.coverUrl;
          anime.synopsis = item['synopsis']?.toString() ?? '';
          anime.rating = item['rating']?.toString() ?? 'N/A';
          anime.status = item['status']?.toString() ?? '';
          anime.year = item['year']?.toString() ?? '';
          anime.sourceUrl = item['source_url']?.toString() ?? '';
          anime.updatedAt = DateTime.now();

          // Genres
          if (item['genres'] is List) {
            anime.genres = (item['genres'] as List).map((g) => g.toString()).toList();
          }

          // Episodes (Server is authority)
          final epList = item['episodes'] as List<dynamic>? ?? [];
          anime.episodes = epList.map((epJson) {
            final ep = EpisodeEmbedded();
            final epNum = epJson['episode_number'];
            ep.id = epJson['id']?.toString() ?? '$slug-ep-$epNum';
            ep.episodeNumber = (epNum is num) ? epNum.toDouble() : 1.0;
            ep.title = epJson['title']?.toString() ?? 'ตอนที่ $epNum';
            ep.streamUrl = epJson['stream_url']?.toString() ?? '';
            ep.pageUrl = epJson['page_url']?.toString() ?? '';
            ep.thumbnailUrl = epJson['thumbnail_url']?.toString() ?? anime.coverUrl;
            ep.duration = epJson['duration']?.toString() ?? '';
            return ep;
          }).toList();

          await _isar.animeCollections.put(anime);
          syncedCount++;
        }

        // Clean up any anime on device that was deleted from local server
        final allLocal = await _isar.animeCollections.where().findAll();
        for (final localItem in allLocal) {
          if (!serverSlugs.contains(localItem.slug)) {
            await _isar.animeCollections.delete(localItem.id);
          }
        }
      });

      return SyncResult(
        success: true,
        animeCount: syncedCount,
        message: 'ซิงค์ข้อมูลสำเร็จ $syncedCount เรื่อง',
      );
    } catch (e) {
      if (kDebugMode) print('[SyncError] $e');
      return SyncResult(
        success: false,
        animeCount: 0,
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้: $e',
      );
    }
  }

  // Delete anime
  Future<void> deleteAnime(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.animeCollections.delete(id);
    });
  }
}
