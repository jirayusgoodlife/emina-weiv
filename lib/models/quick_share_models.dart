import '../models/isar_models.dart';

extension AnimeCollectionJson on AnimeCollection {
  Map<String, dynamic> toMap() {
    return {
      'slug': slug,
      'title': title,
      'coverUrl': coverUrl,
      'backdropUrl': backdropUrl,
      'synopsis': synopsis,
      'rating': rating,
      'status': status,
      'year': year,
      'sourceUrl': sourceUrl,
      'genres': genres,
      'episodes': episodes.map((e) => e.toMap()).toList(),
    };
  }

  static AnimeCollection fromMap(Map<String, dynamic> map) {
    final anime = AnimeCollection();
    anime.slug = map['slug']?.toString() ?? '';
    anime.title = map['title']?.toString() ?? 'Untitled';
    anime.coverUrl = map['coverUrl']?.toString() ?? '';
    anime.backdropUrl = map['backdropUrl']?.toString();
    anime.synopsis = map['synopsis']?.toString();
    anime.rating = map['rating']?.toString();
    anime.status = map['status']?.toString();
    anime.year = map['year']?.toString();
    anime.sourceUrl = map['sourceUrl']?.toString();
    if (map['genres'] is List) {
      anime.genres = (map['genres'] as List).map((g) => g.toString()).toList();
    }
    if (map['episodes'] is List) {
      anime.episodes = (map['episodes'] as List)
          .whereType<Map>()
          .map((e) => EpisodeEmbeddedJson.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    anime.updatedAt = DateTime.now();
    return anime;
  }
}

extension EpisodeEmbeddedJson on EpisodeEmbedded {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'episodeNumber': episodeNumber,
      'title': title,
      'streamUrl': streamUrl,
      'pageUrl': pageUrl,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
    };
  }

  static EpisodeEmbedded fromMap(Map<String, dynamic> map) {
    final ep = EpisodeEmbedded();
    ep.id = map['id']?.toString();
    ep.episodeNumber = (map['episodeNumber'] as num?)?.toDouble() ?? 1.0;
    ep.title = map['title']?.toString();
    ep.streamUrl = map['streamUrl']?.toString();
    ep.pageUrl = map['pageUrl']?.toString();
    ep.thumbnailUrl = map['thumbnailUrl']?.toString();
    ep.duration = map['duration']?.toString();
    return ep;
  }
}

class QuickShareEpisodeItem {
  final String episodeId;
  final double episodeNumber;
  final String episodeTitle;
  final int fileSizeBytes;
  final String streamUrl;
  final String downloadUrl;

  QuickShareEpisodeItem({
    required this.episodeId,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.fileSizeBytes,
    required this.streamUrl,
    required this.downloadUrl,
  });

  Map<String, dynamic> toMap() => {
        'episodeId': episodeId,
        'episodeNumber': episodeNumber,
        'episodeTitle': episodeTitle,
        'fileSizeBytes': fileSizeBytes,
        'streamUrl': streamUrl,
        'downloadUrl': downloadUrl,
      };

  factory QuickShareEpisodeItem.fromMap(Map<String, dynamic> map) => QuickShareEpisodeItem(
        episodeId: map['episodeId']?.toString() ?? '',
        episodeNumber: (map['episodeNumber'] as num?)?.toDouble() ?? 1.0,
        episodeTitle: map['episodeTitle']?.toString() ?? '',
        fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
        streamUrl: map['streamUrl']?.toString() ?? '',
        downloadUrl: map['downloadUrl']?.toString() ?? '',
      );

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 MB';
    if (fileSizeBytes >= 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class QuickShareManifest {
  final int version;
  final String deviceName;
  final AnimeCollection anime;
  final List<QuickShareEpisodeItem> sharedEpisodes;

  QuickShareManifest({
    this.version = 1,
    required this.deviceName,
    required this.anime,
    required this.sharedEpisodes,
  });

  int get totalSizeBytes => sharedEpisodes.fold(0, (sum, ep) => sum + ep.fileSizeBytes);

  String get formattedTotalSize {
    final bytes = totalSizeBytes;
    if (bytes <= 0) return '0 MB';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'deviceName': deviceName,
        'anime': anime.toMap(),
        'sharedEpisodes': sharedEpisodes.map((e) => e.toMap()).toList(),
      };

  factory QuickShareManifest.fromMap(Map<String, dynamic> map) => QuickShareManifest(
        version: (map['version'] as num?)?.toInt() ?? 1,
        deviceName: map['deviceName']?.toString() ?? 'AnimeView Device',
        anime: AnimeCollectionJson.fromMap(
            Map<String, dynamic>.from(map['anime'] as Map? ?? {})),
        sharedEpisodes: ((map['sharedEpisodes'] as List<dynamic>?) ?? [])
            .whereType<Map>()
            .map((e) => QuickShareEpisodeItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class QuickShareNearbyDevice {
  final String deviceName;
  final String animeTitle;
  final int episodesCount;
  final String serverUrl;
  final List<String> candidateUrls;
  final DateTime lastSeen;

  QuickShareNearbyDevice({
    required this.deviceName,
    required this.animeTitle,
    required this.episodesCount,
    required this.serverUrl,
    this.candidateUrls = const [],
    required this.lastSeen,
  });
}

class QuickShareTransferProgress {
  final String currentEpisodeTitle;
  final int currentEpisodeIndex;
  final int totalEpisodes;
  final int bytesReceived;
  final int totalBytesCurrentEpisode;
  final int totalBytesAll;
  final int totalBytesTransferred;
  final double currentEpisodePercent; // 0.0 - 1.0
  final double overallPercent; // 0.0 - 1.0
  final double speedMBs;
  final String statusText;
  final bool isCompleted;
  final String? errorMessage;

  QuickShareTransferProgress({
    required this.currentEpisodeTitle,
    required this.currentEpisodeIndex,
    required this.totalEpisodes,
    required this.bytesReceived,
    required this.totalBytesCurrentEpisode,
    required this.totalBytesAll,
    required this.totalBytesTransferred,
    required this.currentEpisodePercent,
    required this.overallPercent,
    required this.speedMBs,
    required this.statusText,
    this.isCompleted = false,
    this.errorMessage,
  });
}
