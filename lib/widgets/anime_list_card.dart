import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/isar_models.dart';
import '../screens/detail_screen.dart';
import '../theme/app_theme.dart';
import 'anime_action_sheet.dart';

class AnimeListCard extends StatelessWidget {
  final AnimeCollection anime;

  const AnimeListCard({
    Key? key,
    required this.anime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final epCount = anime.episodes.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetailScreen(anime: anime),
              ),
            );
          },
          onLongPress: () {
            AnimeActionSheet.show(context, anime);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 102,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: anime.coverUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.cardLight,
                            child: const Center(
                              child: Icon(Icons.movie_outlined, color: Colors.white24, size: 28),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.cardLight,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.white24, size: 28),
                            ),
                          ),
                        ),
                        // Rating Badge (top-left)
                        if (anime.rating != null && anime.rating!.isNotEmpty && anime.rating != 'N/A')
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.withOpacity(0.6), width: 0.6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    anime.rating!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textMain,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Meta Row (Episodes, Year, Status)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 0.6),
                            ),
                            child: Text(
                              '$epCount ตอน',
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (anime.year != null && anime.year!.isNotEmpty)
                            Text(
                              anime.year!,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          if (anime.status != null && anime.status!.isNotEmpty)
                            Text(
                              '• ${anime.status!}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Genres
                      if (anime.genres.isNotEmpty)
                        Text(
                          anime.genres.take(3).join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),

                // Trailing More Button
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white38, size: 20),
                  onPressed: () => AnimeActionSheet.show(context, anime),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

