enum DownloadStatus {
  idle,
  queued,
  downloading,
  completed,
  failed,
  cancelled,
}

class DownloadItem {
  final String episodeId;
  final String animeSlug;
  final String animeTitle;
  final String animeCoverUrl;
  final String episodeTitle;
  final double episodeNumber;
  String streamUrl;
  String localFilePath;
  int fileSizeBytes;
  double progress; // 0.0 to 1.0
  DownloadStatus status;
  DateTime downloadedAt;
  DateTime expiresAt;
  bool keepForever;
  DateTime? completedWatchAt;
  String? errorMessage;

  DownloadItem({
    required this.episodeId,
    required this.animeSlug,
    required this.animeTitle,
    required this.animeCoverUrl,
    required this.episodeTitle,
    required this.episodeNumber,
    required this.streamUrl,
    required this.localFilePath,
    this.fileSizeBytes = 0,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    required this.downloadedAt,
    required this.expiresAt,
    this.keepForever = false,
    this.completedWatchAt,
    this.errorMessage,
  });

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading || status == DownloadStatus.queued;
  bool get isQueued => status == DownloadStatus.queued;
  bool get isFailed => status == DownloadStatus.failed;

  bool get isExpired {
    if (!isCompleted) return false;
    if (keepForever) return false;
    return DateTime.now().isAfter(expiresAt);
  }

  Duration get remainingTime {
    if (keepForever) return const Duration(days: 99999);
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) return Duration.zero;
    return expiresAt.difference(now);
  }

  String get remainingTimeText {
    if (!isCompleted) return '';
    if (keepForever) return 'เก็บจนกว่าจะลบเอง';
    final rem = remainingTime;
    if (rem == Duration.zero) return 'หมดอายุแล้ว (พร้อมลบ)';

    if (rem.inDays >= 1) {
      final days = rem.inDays;
      final hours = rem.inHours % 24;
      return hours > 0 ? 'จะลบในอีก $days วัน $hours ชม.' : 'จะลบในอีก $days วัน';
    } else if (rem.inHours >= 1) {
      final hours = rem.inHours;
      final mins = rem.inMinutes % 60;
      return mins > 0 ? 'จะลบในอีก $hours ชม. $mins นาที' : 'จะลบในอีก $hours ชม.';
    } else {
      final mins = rem.inMinutes;
      return 'จะลบในอีก $mins นาที';
    }
  }

  String get formattedFileSize {
    if (fileSizeBytes <= 0) return '0 MB';
    if (fileSizeBytes >= 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
        'episodeId': episodeId,
        'animeSlug': animeSlug,
        'animeTitle': animeTitle,
        'animeCoverUrl': animeCoverUrl,
        'episodeTitle': episodeTitle,
        'episodeNumber': episodeNumber,
        'streamUrl': streamUrl,
        'localFilePath': localFilePath,
        'fileSizeBytes': fileSizeBytes,
        'progress': progress,
        'status': status.index,
        'downloadedAt': downloadedAt.millisecondsSinceEpoch,
        'expiresAt': expiresAt.millisecondsSinceEpoch,
        'keepForever': keepForever,
        'completedWatchAt': completedWatchAt?.millisecondsSinceEpoch,
        'errorMessage': errorMessage,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      episodeId: json['episodeId'] as String? ?? '',
      animeSlug: json['animeSlug'] as String? ?? '',
      animeTitle: json['animeTitle'] as String? ?? '',
      animeCoverUrl: json['animeCoverUrl'] as String? ?? '',
      episodeTitle: json['episodeTitle'] as String? ?? '',
      episodeNumber: (json['episodeNumber'] as num?)?.toDouble() ?? 1.0,
      streamUrl: json['streamUrl'] as String? ?? '',
      localFilePath: json['localFilePath'] as String? ?? '',
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: DownloadStatus.values[(json['status'] as int? ?? 0).clamp(0, DownloadStatus.values.length - 1)],
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        json['downloadedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        json['expiresAt'] as int? ?? DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
      ),
      keepForever: json['keepForever'] as bool? ?? false,
      completedWatchAt: json['completedWatchAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedWatchAt'] as int)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
