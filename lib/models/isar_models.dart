import 'package:isar_community/isar.dart';

part 'isar_models.g.dart';

@collection
class AnimeCollection {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String slug;

  late String title;
  late String coverUrl;
  String? backdropUrl;
  String? synopsis;
  String? rating;
  String? status;
  String? year;
  String? sourceUrl;

  List<String> genres = [];
  List<EpisodeEmbedded> episodes = [];

  DateTime updatedAt = DateTime.now();

  String? lastWatchedEpisodeId;
  int? lastWatchedPositionSeconds;
  DateTime? lastWatchedAt;
}

@embedded
class EpisodeEmbedded {
  String? id;
  double? episodeNumber;
  String? title;
  String? streamUrl;
  String? pageUrl;
  String? thumbnailUrl;
  String? duration;
}
