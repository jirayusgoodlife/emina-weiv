class EpisodeProgress {
  final int positionSeconds;
  final int durationSeconds;
  final bool isCompleted;
  final DateTime updatedAt;

  const EpisodeProgress({
    required this.positionSeconds,
    required this.durationSeconds,
    this.isCompleted = false,
    required this.updatedAt,
  });

  double get percentage {
    if (durationSeconds <= 0) return 0.0;
    final p = positionSeconds / durationSeconds;
    return p.clamp(0.0, 1.0);
  }

  int get remainingSeconds => (durationSeconds - positionSeconds).clamp(0, durationSeconds);

  String get formattedRemaining {
    final rem = remainingSeconds;
    final m = rem ~/ 60;
    final s = rem % 60;
    if (m >= 60) {
      final h = m ~/ 60;
      final mRemain = m % 60;
      return 'เหลืออีก $h ชม. $mRemain นาที';
    } else if (m > 0) {
      return 'เหลืออีก $m นาที';
    } else {
      return 'เหลืออีก $s วินาที';
    }
  }

  String get formattedPosition {
    final h = positionSeconds ~/ 3600;
    final m = (positionSeconds % 3600) ~/ 60;
    final s = positionSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'pos': positionSeconds,
        'dur': durationSeconds,
        'completed': isCompleted,
        'time': updatedAt.millisecondsSinceEpoch,
      };

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeProgress(
      positionSeconds: json['pos'] as int? ?? 0,
      durationSeconds: json['dur'] as int? ?? 0,
      isCompleted: json['completed'] as bool? ?? false,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        json['time'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
