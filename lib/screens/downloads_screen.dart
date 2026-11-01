import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../models/isar_models.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/download_provider.dart';
import '../screens/player_screen.dart';
import '../theme/app_theme.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final downloadProvider = Provider.of<DownloadProvider>(context);
    final groups = downloadProvider.animeGroups;
    final totalDownloadsCount = downloadProvider.allDownloads.length;
    final completed = downloadProvider.completedDownloads;
    final failed = downloadProvider.failedDownloads;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('ดาวน์โหลดออฟไลน์'),
        actions: [
          if (failed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: 'ลบรายการที่ดาวน์โหลดไม่สำเร็จทั้งหมด',
              onPressed: () => _confirmDeleteAllFailed(context, downloadProvider),
            ),
          if (completed.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined, color: AppTheme.accent),
              tooltip: 'ล้างไฟล์หมดอายุ',
              onPressed: () async {
                await downloadProvider.checkAndCleanExpiredFiles();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ตรวจสอบและล้างไฟล์หมดอายุเรียบร้อยแล้ว'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: groups.isEmpty
          ? _buildEmptyState(context)
          : CustomScrollView(
              slivers: [
                // Storage and Expiration Rule Summary Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.card,
                          AppTheme.cardLight.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.storage, color: AppTheme.accent, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  downloadProvider.formattedTotalStorage,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'ใช้พื้นที่ในเครื่อง • ${groups.length} เรื่อง • $totalDownloadsCount ตอน',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.textMuted, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '• ดูจบแล้วจะลบอัตโนมัติใน 1 วัน (หากไม่ได้เลือกเก็บถาวร)\n• โหลดไว้แต่ไม่ดูจะลบใน 7 วัน\n• สามารถเลือก "ไม่ลบ จนกว่าจะลบเอง" หรือขยายเวลา (+7/+30 วัน) ได้ทั้งรายตอนและทั้งเรื่อง',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Grouped Anime Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'อนิเมะที่ดาวน์โหลดไว้ (${groups.length} เรื่อง)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        Text(
                          'รวม $totalDownloadsCount ตอน',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),

                // Anime Groups List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = groups[index];
                        return _buildAnimeGroupCard(context, group, downloadProvider);
                      },
                      childCount: groups.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildAnimeGroupCard(
    BuildContext context,
    DownloadedAnimeGroup group,
    DownloadProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: group.hasActiveDownloads
              ? AppTheme.accent.withOpacity(0.4)
              : group.failedCount > 0
                  ? Colors.redAccent.withOpacity(0.3)
                  : Colors.white10,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DownloadedAnimeDetailScreen(slug: group.animeSlug),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Anime Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: group.animeCoverUrl,
                    width: 60,
                    height: 84,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.cardLight),
                    errorWidget: (_, __, ___) => Container(
                      width: 60,
                      height: 84,
                      color: AppTheme.cardLight,
                      child: const Icon(Icons.movie, color: Colors.white30),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.animeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Status row: completed count & total storage & retention badge
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'ดาวน์โหลดแล้ว ${group.completedCount}/${group.episodes.length} ตอน',
                              style: const TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              group.formattedTotalSize,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ),
                          if (group.allKeepForever)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.teal.withOpacity(0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, size: 11, color: Colors.tealAccent),
                                  SizedBox(width: 3),
                                  Text(
                                    'เก็บถาวรทั้งเรื่อง',
                                    style: TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )
                          else if (group.anyKeepForever)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🔒 เก็บถาวร ${group.keepForeverCount}/${group.episodes.length} ตอน',
                                style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Downloading badge if any
                      if (group.hasActiveDownloads)
                        Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'กำลังดาวน์โหลด ${group.downloadingCount} ตอน...',
                              style: const TextStyle(fontSize: 11, color: AppTheme.accent),
                            ),
                          ],
                        )
                      else if (group.failedCount > 0)
                        Row(
                          children: [
                            const Icon(Icons.error_outline, size: 12, color: Colors.redAccent),
                            const SizedBox(width: 4),
                            Text(
                              'มี ${group.failedCount} ตอนไม่สำเร็จ (แตะเพื่อดู)',
                              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.more_time, color: AppTheme.accent, size: 20),
                  tooltip: 'ตั้งเวลาจัดเก็บทั้งเรื่อง',
                  onPressed: () => _showAnimeRetentionSheet(context, group, provider),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAllFailed(BuildContext context, DownloadProvider provider) {
    final count = provider.failedDownloads.length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบรายการที่ดาวน์โหลดไม่สำเร็จทั้งหมด', style: TextStyle(color: Colors.white)),
        content: Text(
          'คุณต้องการลบรายการที่ไม่สำเร็จทั้งหมด ($count ตอน) ออกจากคิวใช่หรือไม่?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              provider.deleteFailedDownloads();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบรายการที่ไม่สำเร็จทั้งหมด ($count ตอน) เรียบร้อยแล้ว'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ลบทั้งหมด', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(
                Icons.download_for_offline_outlined,
                size: 64,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ยังไม่มีวิดีโอที่ดาวน์โหลด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'คุณสามารถดาวน์โหลดตอนของอนิเมะเพื่อดูแบบออฟไลน์\nโดยไม่ต้องใช้อินเทอร์เน็ตได้จากหน้ารายละเอียดอนิเมะ',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('กลับไปเลือกดูอนิเมะ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drill-down screen for a specific downloaded anime collection
/// Episodes are strictly sorted by storyline / episodeNumber ascending
class DownloadedAnimeDetailScreen extends StatelessWidget {
  final String slug;

  const DownloadedAnimeDetailScreen({Key? key, required this.slug}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context);
    final group = provider.animeGroups.where((g) => g.animeSlug == slug).firstOrNull;

    if (group == null) {
      // All episodes for this anime deleted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Episodes are already sorted by episodeNumber in DownloadProvider.animeGroups
    final episodes = group.episodes;
    final firstCompletedIndex = episodes.indexWhere((e) => e.isCompleted);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(group.animeTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_time, color: AppTheme.accent),
            tooltip: 'ตั้งเวลาจัดเก็บทั้งเรื่อง',
            onPressed: () => _showAnimeRetentionSheet(context, group, provider),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            tooltip: 'ลบทุกตอนของเรื่องนี้',
            onPressed: () => _confirmDeleteAnime(context, group, provider),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Anime Header Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: group.animeCoverUrl,
                      width: 80,
                      height: 112,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.cardLight),
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 112,
                        color: AppTheme.cardLight,
                        child: const Icon(Icons.movie, color: Colors.white30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.animeTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'ดาวน์โหลดแล้ว ${group.completedCount}/${episodes.length} ตอน',
                          style: const TextStyle(fontSize: 12, color: AppTheme.accent),
                        ),
                        Text(
                          'พื้นที่ใช้งาน: ${group.formattedTotalSize}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (group.allKeepForever)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.teal.withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_outline, size: 11, color: Colors.tealAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      'เก็บถาวรทั้งเรื่อง (ไม่ลบเอง)',
                                      style: TextStyle(fontSize: 11, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else if (group.anyKeepForever)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '🔒 เก็บถาวร ${group.keepForeverCount}/${episodes.length} ตอน',
                                  style: const TextStyle(fontSize: 11, color: Colors.tealAccent),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (firstCompletedIndex != -1)
                              ElevatedButton.icon(
                                onPressed: () => _playOfflineEpisode(context, group, episodes[firstCompletedIndex]),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('เล่นออฟไลน์'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _showAnimeRetentionSheet(context, group, provider),
                              icon: const Icon(Icons.more_time, size: 16, color: AppTheme.accent),
                              label: const Text('ตั้งเวลาจัดเก็บทั้งเรื่อง'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                side: BorderSide(color: AppTheme.accent.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Episodes List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'รายการตอน (${episodes.length} ตอน)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const Text(
                    'เรียงตามเนื้อเรื่อง',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),

          // Episodes List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = episodes[index];
                  return _buildEpisodeCard(context, item, group, provider);
                },
                childCount: episodes.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(
    BuildContext context,
    DownloadItem item,
    DownloadedAnimeGroup group,
    DownloadProvider provider,
  ) {
    final isUrgent = item.isCompleted && !item.keepForever && item.remainingTime.inHours <= 24;
    final isFailed = item.status == DownloadStatus.failed;
    final isQueued = item.status == DownloadStatus.queued;
    final isDownloading = item.status == DownloadStatus.downloading;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.keepForever
              ? Colors.teal.withOpacity(0.35)
              : isUrgent
                  ? Colors.amber.withOpacity(0.35)
                  : isFailed
                      ? Colors.redAccent.withOpacity(0.35)
                      : isDownloading
                          ? AppTheme.accent.withOpacity(0.35)
                          : Colors.white10,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.isCompleted
                    ? Colors.green.withOpacity(0.12)
                    : isFailed
                        ? Colors.redAccent.withOpacity(0.12)
                        : AppTheme.cardLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: item.isCompleted
                      ? Colors.green.withOpacity(0.3)
                      : isFailed
                          ? Colors.redAccent.withOpacity(0.3)
                          : Colors.white12,
                ),
              ),
              child: Center(
                child: item.isCompleted
                    ? const Icon(Icons.check, color: Colors.green, size: 22)
                    : isFailed
                        ? const Icon(Icons.priority_high, color: Colors.redAccent, size: 22)
                        : Text(
                            '${item.episodeNumber.toInt()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                            ),
                          ),
              ),
            ),
            title: Text(
              item.episodeTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (isDownloading) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 4,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(item.progress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ] else if (isQueued) ...[
                  Row(
                    children: [
                      const Icon(Icons.hourglass_empty, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'กำลังรอคิว...',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade300),
                      ),
                    ],
                  ),
                ] else if (item.isCompleted) ...[
                  Row(
                    children: [
                      Text(
                        item.formattedFileSize,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: item.keepForever
                              ? Colors.teal.withOpacity(0.15)
                              : isUrgent
                                  ? Colors.amber.withOpacity(0.15)
                                  : AppTheme.cardLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: item.keepForever
                                ? Colors.teal.withOpacity(0.4)
                                : isUrgent
                                    ? Colors.amber.withOpacity(0.4)
                                    : Colors.white12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.keepForever ? Icons.lock_outline : Icons.schedule,
                              size: 11,
                              color: item.keepForever
                                  ? Colors.tealAccent
                                  : isUrgent
                                      ? Colors.amber
                                      : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.remainingTimeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: (item.keepForever || isUrgent) ? FontWeight.bold : FontWeight.normal,
                                color: item.keepForever
                                    ? Colors.tealAccent
                                    : isUrgent
                                        ? Colors.amber
                                        : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else if (isFailed) ...[
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'ดาวน์โหลดไม่สำเร็จ${item.errorMessage != null && item.errorMessage!.isNotEmpty ? ": ${item.errorMessage}" : ""}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: item.isDownloading || isQueued
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                    tooltip: 'ยกเลิก',
                    onPressed: () => provider.cancelDownload(item.episodeId),
                  )
                : isFailed
                    ? IconButton(
                        icon: const Icon(Icons.refresh, color: AppTheme.accent, size: 24),
                        tooltip: 'ดาวน์โหลดซ้ำ',
                        onPressed: () => _retryDownload(context, item, provider),
                      )
                    : IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: AppTheme.primary, size: 36),
                        tooltip: 'เล่นออฟไลน์',
                        onPressed: () => _playOfflineEpisode(context, group, item),
                      ),
            onTap: item.isCompleted
                ? () => _playOfflineEpisode(context, group, item)
                : isFailed
                    ? () => _retryDownload(context, item, provider)
                    : null,
          ),

          // Bottom Action Row
          if (item.isCompleted) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEpisodeRetentionSheet(context, item, group, provider),
                    icon: Icon(
                      item.keepForever ? Icons.lock_outline : Icons.more_time,
                      size: 16,
                      color: item.keepForever ? Colors.tealAccent : AppTheme.accent,
                    ),
                    label: Text(
                      item.keepForever ? 'ไม่ลบจนกว่าจะลบเอง (เปลี่ยน)' : 'ขยายเวลา / ไม่ลบเอง',
                      style: TextStyle(
                        color: item.keepForever ? Colors.tealAccent : AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteEpisode(context, item, provider),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text(
                      'ลบ',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isFailed) ...[
            const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _retryDownload(context, item, provider),
                    icon: const Icon(Icons.refresh, size: 16, color: AppTheme.accent),
                    label: const Text(
                      'ดาวน์โหลดซ้ำ',
                      style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteEpisode(context, item, provider),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                    label: const Text(
                      'ลบออก',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _retryDownload(
    BuildContext context,
    DownloadItem item,
    DownloadProvider provider,
  ) {
    final catalogProvider = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final existing = catalogProvider.allAnime.where((a) => a.slug == item.animeSlug);
    AnimeCollection anime;
    EpisodeEmbedded episode;

    if (existing.isNotEmpty) {
      anime = existing.first;
      final epMatch = anime.episodes.where((e) => e.id == item.episodeId);
      if (epMatch.isNotEmpty) {
        episode = epMatch.first;
      } else {
        episode = EpisodeEmbedded()
          ..id = item.episodeId
          ..title = item.episodeTitle
          ..episodeNumber = item.episodeNumber
          ..streamUrl = item.streamUrl;
      }
    } else {
      anime = AnimeCollection()
        ..slug = item.animeSlug
        ..title = item.animeTitle
        ..coverUrl = item.animeCoverUrl;
      episode = EpisodeEmbedded()
        ..id = item.episodeId
        ..title = item.episodeTitle
        ..episodeNumber = item.episodeNumber
        ..streamUrl = item.streamUrl;
      anime.episodes = [episode];
    }

    provider.retryDownload(
      item.episodeId,
      anime: anime,
      episode: episode,
      serverUrl: catalogProvider.serverUrl,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('กำลังเข้าคิวดาวน์โหลด "${item.animeTitle} - ${item.episodeTitle}" ใหม่อีกครั้ง...'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDeleteEpisode(BuildContext context, DownloadItem item, DownloadProvider provider) {
    final isFailed = item.status == DownloadStatus.failed;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isFailed ? 'ยืนยันการลบรายการ' : 'ยืนยันการลบไฟล์ออฟไลน์',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isFailed
              ? 'คุณต้องการลบรายการที่ดาวน์โหลดไม่สำเร็จ "${item.animeTitle} - ${item.episodeTitle}" ออกจากคิวใช่หรือไม่?'
              : 'คุณต้องการลบไฟล์ของ "${item.animeTitle} - ${item.episodeTitle}" ใช่หรือไม่?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              provider.deleteDownload(item.episodeId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบ "${item.animeTitle} - ${item.episodeTitle}" เรียบร้อยแล้ว'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ลบออก', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAnime(BuildContext context, DownloadedAnimeGroup group, DownloadProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบทุกตอนของเรื่องนี้', style: TextStyle(color: Colors.white)),
        content: Text(
          'คุณต้องการลบไฟล์ดาวน์โหลดทั้งหมดของ "${group.animeTitle}" (${group.episodes.length} ตอน) ใช่หรือไม่?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              provider.deleteAnimeDownloads(group.animeSlug);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบไฟล์ทั้งหมดของ "${group.animeTitle}" เรียบร้อยแล้ว'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('ลบทุกตอน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  static bool _isNavigatingToPlayer = false;

  void _playOfflineEpisode(BuildContext context, DownloadedAnimeGroup group, DownloadItem item) {
    if (_isNavigatingToPlayer) return;
    _isNavigatingToPlayer = true;
    final catalogProvider = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final existing = catalogProvider.allAnime.where((a) => a.slug == group.animeSlug);
    AnimeCollection anime;

    // Use existing collection or construct from downloaded episodes
    if (existing.isNotEmpty) {
      anime = existing.first;
    } else {
      anime = AnimeCollection()
        ..slug = group.animeSlug
        ..title = group.animeTitle
        ..coverUrl = group.animeCoverUrl
        ..episodes = group.episodes
            .map(
              (e) => EpisodeEmbedded()
                ..id = e.episodeId
                ..title = e.episodeTitle
                ..episodeNumber = e.episodeNumber
                ..streamUrl = e.streamUrl,
            )
            .toList();
    }

    final initialIndex = anime.episodes.indexWhere((e) => e.id == item.episodeId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          anime: anime,
          initialEpisodeIndex: initialIndex != -1 ? initialIndex : 0,
        ),
      ),
    ).then((_) {
      _isNavigatingToPlayer = false;
    });
  }
}

void _showAnimeRetentionSheet(
  BuildContext context,
  DownloadedAnimeGroup group,
  DownloadProvider provider,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          final isAllForever = group.allKeepForever;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: group.animeCoverUrl,
                          width: 44,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppTheme.cardLight),
                          errorWidget: (_, __, ___) => Container(
                            width: 44,
                            height: 60,
                            color: AppTheme.cardLight,
                            child: const Icon(Icons.movie, color: Colors.white30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.animeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ตั้งค่าระยะเวลาจัดเก็บทั้งเรื่อง (${group.episodes.length} ตอน)',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),

                  // Option 1: Keep Forever Toggle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isAllForever ? Colors.teal.withOpacity(0.12) : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAllForever ? Colors.teal.withOpacity(0.4) : Colors.white12,
                      ),
                    ),
                    child: SwitchListTile(
                      value: isAllForever,
                      activeColor: Colors.tealAccent,
                      title: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Colors.tealAccent, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'ไม่ลบ จนกว่าจะลบเอง',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      subtitle: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'เก็บไฟล์ทุกตอนไว้ถาวร ปิดระบบลบอัตโนมัติ',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),
                      onChanged: (val) async {
                        await provider.setAnimeKeepForever(group.animeSlug, val);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? 'ตั้งค่า "${group.animeTitle}" เป็นเก็บถาวร (ไม่ลบอัตโนมัติ) ทุกตอนแล้ว'
                                    : 'เปิดระบบลบอัตโนมัติตามปกติสำหรับ "${group.animeTitle}" แล้ว',
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: val ? Colors.teal : Colors.blueGrey,
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    'หรือขยายเวลาการเก็บไฟล์ทุกตอน:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),

                  // Option 2: +7 Days
                  ListTile(
                    leading: const Icon(Icons.more_time, color: AppTheme.accent),
                    title: const Text('ขยายเวลาทุกตอน +7 วัน', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('นับต่อจากวันหมดอายุเดิม', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () async {
                      await provider.extendAnimeExpiration(group.animeSlug, days: 7);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ขยายเวลาทุกตอนของ "${group.animeTitle}" เพิ่มอีก 7 วันเรียบร้อยแล้ว'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),

                  // Option 3: +30 Days
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined, color: AppTheme.accent),
                    title: const Text('ขยายเวลาทุกตอน +30 วัน (1 เดือน)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('เก็บต่อยาวนาน 1 เดือน', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () async {
                      await provider.extendAnimeExpiration(group.animeSlug, days: 30);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ขยายเวลาทุกตอนของ "${group.animeTitle}" เพิ่มอีก 30 วันเรียบร้อยแล้ว'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),

                  // Option 4: +90 Days
                  ListTile(
                    leading: const Icon(Icons.event_repeat_outlined, color: AppTheme.accent),
                    title: const Text('ขยายเวลาทุกตอน +90 วัน (3 เดือน)', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('เก็บต่อยาวนาน 3 เดือน', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () async {
                      await provider.extendAnimeExpiration(group.animeSlug, days: 90);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('ขยายเวลาทุกตอนของ "${group.animeTitle}" เพิ่มอีก 90 วันเรียบร้อยแล้ว'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

void _showEpisodeRetentionSheet(
  BuildContext context,
  DownloadItem item,
  DownloadedAnimeGroup group,
  DownloadProvider provider,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final isForever = item.keepForever;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                item.animeTitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.accent),
              ),
              const SizedBox(height: 2),
              Text(
                item.episodeTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'สถานะปัจจุบัน: ${item.remainingTimeText}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white12),

              // Option 1: Keep Forever Toggle for this episode
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isForever ? Colors.teal.withOpacity(0.12) : AppTheme.cardLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isForever ? Colors.teal.withOpacity(0.4) : Colors.white12,
                  ),
                ),
                child: SwitchListTile(
                  value: isForever,
                  activeColor: Colors.tealAccent,
                  title: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.tealAccent, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'ไม่ลบ จนกว่าจะลบเอง',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'เก็บตอนนี้ไว้ถาวร ปิดระบบลบอัตโนมัติ',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  onChanged: (val) async {
                    await provider.setEpisodeKeepForever(item.episodeId, val);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'ตั้งค่า "${item.episodeTitle}" เป็นเก็บถาวร (ไม่ลบอัตโนมัติ) แล้ว'
                                : 'เปิดระบบลบอัตโนมัติตามปกติสำหรับ "${item.episodeTitle}" แล้ว',
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: val ? Colors.teal : Colors.blueGrey,
                        ),
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 8),
              const Text(
                'หรือขยายเวลาการเก็บไฟล์ตอนนี้:',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),

              // Option 2: +7 Days
              ListTile(
                leading: const Icon(Icons.more_time, color: AppTheme.accent),
                title: const Text('ขยายเวลา +7 วัน', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('นับต่อจากวันหมดอายุเดิม', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () async {
                  await provider.extendExpiration(item.episodeId, days: 7);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('ขยายเวลา "${item.episodeTitle}" เพิ่มอีก 7 วันแล้ว'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),

              // Option 3: +30 Days
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined, color: AppTheme.accent),
                title: const Text('ขยายเวลา +30 วัน (1 เดือน)', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('เก็บต่อยาวนาน 1 เดือน', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () async {
                  await provider.extendExpiration(item.episodeId, days: 30);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('ขยายเวลา "${item.episodeTitle}" เพิ่มอีก 30 วันแล้ว'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),

              // Option 4: Apply to entire anime series
              const Divider(color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.all_inbox_outlined, color: AppTheme.primary),
                title: const Text('ตั้งค่าแบบเดียวกันกับทุกตอนในเรื่องนี้', style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('ปรับเวลาทุกตอนของ "${group.animeTitle}" (${group.episodes.length} ตอน)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showAnimeRetentionSheet(context, group, provider);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
