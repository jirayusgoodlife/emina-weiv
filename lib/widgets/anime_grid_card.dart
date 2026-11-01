import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/isar_models.dart';
import '../screens/detail_screen.dart';
import '../theme/app_theme.dart';
import 'anime_action_sheet.dart';

class AnimeGridCard extends StatelessWidget {
  final AnimeCollection anime;

  const AnimeGridCard({
    Key? key,
    required this.anime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final epCount = anime.episodes.length;

    return GestureDetector(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Poster Image
                    CachedNetworkImage(
                      imageUrl: anime.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppTheme.cardLight,
                        child: const Center(
                          child: Icon(Icons.movie_outlined, color: Colors.white24, size: 36),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppTheme.cardLight,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white24, size: 36),
                        ),
                      ),
                    ),

                    // Top Rating Badge
                    if (anime.rating != null && anime.rating!.isNotEmpty && anime.rating != 'N/A')
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withOpacity(0.6), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 3),
                              Text(
                                anime.rating!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Top More Options Button
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => AnimeActionSheet.show(context, anime),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                        ),
                      ),
                    ),

                    // Bottom Episode Count Badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppTheme.accent.withOpacity(0.4), width: 0.6),
                        ),
                        child: Text(
                          '$epCount ตอน',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Title
          Text(
            anime.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 1),

          // Genres / Year
          Text(
            anime.genres.isNotEmpty ? anime.genres.take(2).join(' • ') : (anime.year ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
