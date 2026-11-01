import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../models/isar_models.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/download_provider.dart';
import '../screens/player_screen.dart';
import '../widgets/anime_action_sheet.dart';
import '../theme/app_theme.dart';

class DetailScreen extends StatelessWidget {
  final AnimeCollection anime;

  const DetailScreen({
    Key? key,
    required this.anime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnimeCatalogProvider>(context);
    final downloadProvider = Provider.of<DownloadProvider>(context);

    final currentAnime = provider.allAnime.firstWhere(
      (a) => a.slug == anime.slug,
      orElse: () => anime,
    );
    final episodes = currentAnime.episodes;
    final progressMap = provider.getAnimeEpisodeProgress(currentAnime.slug);
    final resumeIndex = provider.getResumeEpisodeIndex(currentAnime);
    final lastEpId = currentAnime.lastWatchedEpisodeId;
    final hasProgress = lastEpId != null && episodes.isNotEmpty;

    final resumeEp = episodes.isNotEmpty && resumeIndex < episodes.length ? episodes[resumeIndex] : null;
    final resumeProg = resumeEp != null ? progressMap[resumeEp.id] : null;

    String playButtonLabel = 'เล่นตอนที่ 1';
    if (hasProgress && resumeEp != null) {
      if (resumeProg != null && resumeProg.positionSeconds > 5 && !resumeProg.isCompleted) {
        playButtonLabel = 'เล่นต่อ (${resumeEp.title ?? "ตอนที่ ${resumeIndex + 1}"} - ${resumeProg.formattedPosition})';
      } else {
        playButtonLabel = 'เล่นต่อ (${resumeEp.title ?? "ตอนที่ ${resumeIndex + 1}"})';
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // Collapsible Backdrop App Bar
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.background,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                color: AppTheme.card,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) async {
                  if (value == 'hide') {
                    final isHidden = provider.isAnimeHidden(anime.slug);
                    if (isHidden) {
                      await provider.unhideAnime(anime.slug);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ยกเลิกการซ่อนเรื่อง "${anime.title}" แล้ว'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else {
                      await provider.hideAnime(anime.slug);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ซ่อนเรื่อง "${anime.title}" แล้ว'),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'เลิกทำ',
                              textColor: AppTheme.accent,
                              onPressed: () => provider.unhideAnime(anime.slug),
                            ),
                          ),
                        );
                      }
                    }
                  } else if (value == 'remove_continue') {
                    final prevEpId = currentAnime.lastWatchedEpisodeId;
                    final prevPos = currentAnime.lastWatchedPositionSeconds;
                    final prevDate = currentAnime.lastWatchedAt;
                    await provider.removeFromContinueWatching(anime.slug);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ลบ "${anime.title}" ออกจากคิวรับชมต่อแล้ว'),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'เลิกทำ',
                            textColor: AppTheme.accent,
                            onPressed: () {
                              provider.restoreContinueWatching(
                                slug: anime.slug,
                                episodeId: prevEpId,
                                positionSeconds: prevPos,
                                lastWatchedAt: prevDate,
                              );
                            },
                          ),
                        ),
                      );
                    }
                  } else if (value == 'delete') {
                    AnimeActionSheet.showDeleteConfirmDialog(
                      context,
                      currentAnime,
                      onDeleted: () {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  }
                },
                itemBuilder: (context) {
                  final isHidden = provider.isAnimeHidden(anime.slug);
                  return [
                    PopupMenuItem(
                      value: 'hide',
                      child: Row(
                        children: [
                          Icon(
                            isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: isHidden ? Colors.greenAccent : Colors.orangeAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isHidden ? 'ยกเลิกการซ่อน' : 'ซ่อนเรื่องนี้',
                            style: const TextStyle(color: AppTheme.textMain, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    if (currentAnime.lastWatchedEpisodeId != null) ...[
                      const PopupMenuItem(
                        value: 'remove_continue',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_remove, color: Colors.blueAccent, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'ลบออกจากกำลังรับชมต่อ',
                              style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const PopupMenuDivider(height: 1),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'ลบเรื่องนี้',
                            style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: anime.backdropUrl ?? anime.coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.cardLight),
                    errorWidget: (_, __, ___) => CachedNetworkImage(
                      imageUrl: anime.coverUrl,
                      fit: BoxFit.cover,
                    ),
                  ),

                  // Gradient Overlays
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppTheme.background.withOpacity(0.4),
                          AppTheme.background,
                        ],
                        stops: const [0.4, 0.7, 1.0],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Center Play Overlay Icon
                  Center(
                    child: GestureDetector(
                      onTap: episodes.isNotEmpty
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    anime: anime,
                                    initialEpisodeIndex: resumeIndex,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.5),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow, size: 42, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    anime.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Meta Info Row (Rating, Year, Episodes, Status)
                  Row(
                    children: [
                      if (anime.rating != null && anime.rating!.isNotEmpty && anime.rating != 'N/A') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            border: Border.all(color: Colors.amber, width: 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                anime.rating!,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (anime.year != null && anime.year!.isNotEmpty) ...[
                        Text(
                          anime.year!,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cardLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${episodes.length} ตอน',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (anime.status != null && anime.status!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          anime.status!,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Big Play / Resume Button & Movie Download Bar
                  if (episodes.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                anime: currentAnime,
                                initialEpisodeIndex: resumeIndex,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: Text(
                          playButtonLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 6,
                        ),
                      ),
                    ),
                    if (episodes.length == 1) ...[
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final singleEp = episodes.first;
                          final epId = singleEp.id ?? '';
                          final isDownloading = downloadProvider.isDownloading(epId);
                          final isDownloaded = downloadProvider.isDownloaded(epId);
                          final dlItem = downloadProvider.getDownload(epId);
                          final progress = downloadProvider.getProgress(epId);

                          if (isDownloading) {
                            return SizedBox(
                              height: 44,
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => downloadProvider.cancelDownload(epId),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: AppTheme.accent.withOpacity(0.6)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        value: progress > 0 ? progress : null,
                                        strokeWidth: 2,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'กำลังดาวน์โหลด ${(progress * 100).toInt()}% (แตะเพื่อยกเลิก)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (isDownloaded && dlItem != null) {
                            return SizedBox(
                              height: 44,
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _showDownloadOptionsSheet(context, dlItem, downloadProvider),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.green.withOpacity(0.4)),
                                  backgroundColor: Colors.green.withOpacity(0.06),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'ดาวน์โหลดเก็บไว้ในเครื่องแล้ว (แตะเพื่อจัดการ)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'กำลังเริ่มดาวน์โหลด ${currentAnime.title}...',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                downloadProvider.startDownload(
                                  anime: currentAnime,
                                  episode: singleEp,
                                  serverUrl: provider.serverUrl,
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.05),
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_for_offline_outlined, size: 18, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'ดาวน์โหลดหนังเก็บไว้ดูออฟไลน์',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),

                  // Genres
                  if (anime.genres.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: anime.genres.map((g) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cardLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Text(
                            g,
                            style: const TextStyle(color: AppTheme.textMain, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Synopsis
                  if (anime.synopsis != null && anime.synopsis!.isNotEmpty) ...[
                    const Text(
                      'เรื่องย่อ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      anime.synopsis!,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Episodes Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ตอนทั้งหมด',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textMain,
                        ),
                      ),
                      Text(
                        '${episodes.length} ตอน',
                        style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Episodes List
          if (episodes.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'ยังไม่มีข้อมูลตอนสำหรับเรื่องนี้',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ep = episodes[index];
                    final isResumeTarget = hasProgress && index == resumeIndex;
                    final prog = progressMap[ep.id];
                    final isCompleted = prog?.isCompleted ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isResumeTarget
                            ? AppTheme.primary.withOpacity(0.08)
                            : (isCompleted ? Colors.white.withOpacity(0.03) : AppTheme.card),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isResumeTarget
                              ? AppTheme.primary.withOpacity(0.4)
                              : (isCompleted ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isResumeTarget
                                ? AppTheme.primary.withOpacity(0.2)
                                : (isCompleted ? Colors.green.withOpacity(0.15) : AppTheme.cardLight),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              isCompleted
                                  ? Icons.check_circle
                                  : (isResumeTarget ? Icons.play_arrow : Icons.play_circle_outline),
                              color: isCompleted
                                  ? Colors.green
                                  : (isResumeTarget ? AppTheme.primary : AppTheme.accent),
                              size: 24,
                            ),
                          ),
                        ),
                        title: Text(
                          ep.title ?? 'ตอนที่ ${index + 1}',
                          style: TextStyle(
                            color: isResumeTarget
                                ? AppTheme.primary
                                : (isCompleted ? AppTheme.textMuted : AppTheme.textMain),
                            fontWeight: isResumeTarget ? FontWeight.bold : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  ep.duration?.isNotEmpty == true ? ep.duration! : 'ตอนที่ ${index + 1}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                                if (isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ดูจบแล้ว',
                                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else if (prog != null && prog.positionSeconds > 5)
                                  Text(
                                    '• ${prog.formattedRemaining}',
                                    style: const TextStyle(color: AppTheme.accent, fontSize: 11),
                                  ),
                                if (ep.streamUrl?.isNotEmpty == true && !isCompleted && (prog == null || prog.positionSeconds <= 5))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'พร้อมดู',
                                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            // Download status subtitle
                            Builder(
                              builder: (_) {
                                final dlItem = downloadProvider.getDownload(ep.id ?? '');
                                if (dlItem != null && dlItem.isCompleted) {
                                  final isUrgent = dlItem.remainingTime.inHours <= 24;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.offline_pin,
                                          size: 13,
                                          color: isUrgent ? Colors.amber : Colors.greenAccent,
                                        ),
                                        Text(
                                          'ดูออฟไลน์ได้ • ${dlItem.remainingTimeText}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                                            color: isUrgent ? Colors.amber : Colors.greenAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            if (!isCompleted && prog != null && prog.percentage > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: prog.percentage,
                                  minHeight: 3.5,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDownloadAction(
                              context,
                              ep,
                              downloadProvider,
                              currentAnime,
                              provider,
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                anime: currentAnime,
                                initialEpisodeIndex: index,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: episodes.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadAction(
    BuildContext context,
    EpisodeEmbedded ep,
    DownloadProvider dlProv,
    AnimeCollection anime,
    AnimeCatalogProvider catalogProv,
  ) {
    final epId = ep.id ?? '';
    final isDownloading = dlProv.isDownloading(epId);
    final isDownloaded = dlProv.isDownloaded(epId);
    final dlItem = dlProv.getDownload(epId);

    if (isDownloading) {
      final progress = dlProv.getProgress(epId);
      return GestureDetector(
        onTap: () => dlProv.cancelDownload(epId),
        child: Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2.5,
                color: AppTheme.accent,
                backgroundColor: Colors.white12,
              ),
              const Icon(Icons.close, size: 14, color: Colors.white70),
            ],
          ),
        ),
      );
    }

    if (isDownloaded && dlItem != null) {
      return IconButton(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 22),
        tooltip: 'จัดการไฟล์ออฟไลน์',
        onPressed: () => _showDownloadOptionsSheet(context, dlItem, dlProv),
      );
    }

    if (dlItem != null && dlItem.status == DownloadStatus.failed) {
      return IconButton(
        icon: const Icon(Icons.error_outline, color: Colors.amber, size: 22),
        tooltip: 'ดาวน์โหลดไม่สำเร็จ: ${dlItem.errorMessage ?? "แตะเพื่อลองใหม่"}',
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('กำลังดาวน์โหลดใหม่: ${ep.title ?? ""}...'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          dlProv.startDownload(
            anime: anime,
            episode: ep,
            serverUrl: catalogProv.serverUrl,
          );
        },
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white54, size: 22),
      tooltip: 'ดาวน์โหลดเก็บไว้ดูออฟไลน์',
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กำลังเริ่มดาวน์โหลด ${ep.title ?? ""}...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        dlProv.startDownload(
          anime: anime,
          episode: ep,
          serverUrl: catalogProv.serverUrl,
        );
      },
    );
  }

  void _showDownloadOptionsSheet(
    BuildContext context,
    DownloadItem item,
    DownloadProvider dlProv,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF161B26),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.animeTitle} - ${item.episodeTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.storage, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Text('ขนาดไฟล์: ${item.formattedFileSize}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Text(item.remainingTimeText, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'ระบบจะลบไฟล์อัตโนมัติหากดูจบแล้วครบ 1 วัน หรือโหลดไว้แล้วครบ 7 วัน',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await dlProv.extendExpiration(item.episodeId, days: 7);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ขยายเวลาการเก็บไฟล์เพิ่มอีก 7 วันเรียบร้อยแล้ว'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.more_time, size: 18, color: AppTheme.accent),
                      label: const Text('ขยายเวลา (+7 วัน)', style: TextStyle(color: AppTheme.accent)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.accent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        dlProv.deleteDownload(item.episodeId);
                      },
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('ลบไฟล์นี้'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}
