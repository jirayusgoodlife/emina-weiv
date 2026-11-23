import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/download_item.dart';
import '../models/isar_models.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/download_provider.dart';
import '../screens/player_screen.dart';
import '../screens/quick_share_receiver_screen.dart';
import '../widgets/quick_share_dialogs.dart';
import '../theme/app_theme.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<DownloadProvider>(context, listen: false).refreshStorageSpace();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadProvider = Provider.of<DownloadProvider>(context);
    final groups = downloadProvider.animeGroups;
    final totalDownloadsCount = downloadProvider.allDownloads.length;
    final completed = downloadProvider.completedDownloads;
    final failed = downloadProvider.failedDownloads;
    final storageInfo = downloadProvider.deviceStorage;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('ดาวน์โหลดออฟไลน์'),
        actions: [
          if (failed.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.orangeAccent),
              tooltip: 'ดาวน์โหลดซ้ำที่ล้มเหลวใหม่ทั้งหมด (${failed.length} ตอน)',
              onPressed: () => _retryAllFailed(context, downloadProvider),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: 'ลบรายการที่ดาวน์โหลดไม่สำเร็จทั้งหมด',
              onPressed: () => _confirmDeleteAllFailed(context, downloadProvider),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.wifi_tethering, color: AppTheme.accent),
            tooltip: 'Quick Share (แชร์/รับหนังออฟไลน์)',
            onPressed: () => _showQuickShareHubSheet(context, downloadProvider),
          ),
          IconButton(
            icon: const Icon(Icons.speed, color: AppTheme.accent),
            tooltip: 'ความเร็วและการดาวน์โหลดพร้อมกัน (${downloadProvider.maxConcurrentDownloads} ตอน)',
            onPressed: () => _showConcurrencySettingsSheet(context, downloadProvider),
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
          ? _buildEmptyState(context, downloadProvider)
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        downloadProvider.formattedTotalStorage,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (storageInfo != null && storageInfo.isValid)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.disc_full, size: 12, color: Colors.greenAccent),
                                              const SizedBox(width: 4),
                                              Text(
                                                'ว่าง: ${storageInfo.formattedFree}',
                                                style: const TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'ใช้พื้นที่ในแอป • ${groups.length} เรื่อง • $totalDownloadsCount ตอน',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showConcurrencySettingsSheet(context, downloadProvider),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.bolt, size: 12, color: AppTheme.accent),
                                              const SizedBox(width: 3),
                                              Text(
                                                'โหลดพร้อมกัน: ${downloadProvider.maxConcurrentDownloads} ตอน',
                                                style: const TextStyle(
                                                  color: AppTheme.accent,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Device Remaining Storage Bar & Info
                        if (storageInfo != null && storageInfo.isValid) ...[
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: storageInfo.usedPercentage,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                storageInfo.freeBytes < 2 * 1024 * 1024 * 1024
                                    ? Colors.redAccent
                                    : AppTheme.accent,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'เครื่องใช้ไป ${storageInfo.formattedUsed} / ทั้งหมด ${storageInfo.formattedTotal}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                              Text(
                                'พื้นที่เครื่องเหลือ ${storageInfo.formattedFree}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ],
                          ),
                        ],

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

                // Failed Downloads Banner with Retry All Action
                if (failed.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ดาวน์โหลดไม่สำเร็จ ${failed.length} ตอน',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'แตะปุ่มเพื่อดาวน์โหลดซ้ำใหม่ทั้งหมด',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _retryAllFailed(context, downloadProvider),
                            icon: const Icon(Icons.replay, size: 15),
                            label: const Text(
                              'ดาวน์โหลดซ้ำทั้งหมด',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Incomplete / Small Downloads Warning Banner (< 35MB)
                if (downloadProvider.possiblyIncompleteDownloads.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'พบ ${downloadProvider.possiblyIncompleteDownloads.length} ตอนที่ไฟล์อาจไม่ครบ',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'ขนาดไฟล์น้อยกว่า 35MB อาจโหลดค้าง/ไม่เต็มเรื่อง',
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _redownloadAllIncomplete(context, downloadProvider),
                            icon: const Icon(Icons.refresh, size: 15),
                            label: const Text(
                              'โหลดใหม่ทั้งหมด',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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
                if (group.completedCount > 0)
                  IconButton(
                    icon: const Icon(Icons.wifi_tethering, color: AppTheme.accent, size: 20),
                    tooltip: 'Quick Share เรื่องนี้ไปยังเครื่องอื่น',
                    onPressed: () => _quickShareAnimeGroup(context, group),
                  ),
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

  Future<void> _retryAllFailed(BuildContext context, DownloadProvider provider) async {
    final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final count = await provider.retryAllFailedDownloads(
      availableAnime: catalog.allAnime,
      serverUrl: catalog.serverUrl,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? 'เริ่มดาวน์โหลดซ้ำ $count ตอนที่ล้มเหลวใหม่แล้ว...'
              : 'ไม่มีรายการที่ล้มเหลว'),
          backgroundColor: count > 0 ? Colors.green.shade800 : Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _redownloadAllIncomplete(BuildContext context, DownloadProvider provider) async {
    final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final count = await provider.redownloadPossiblyIncompleteDownloads(
      availableAnime: catalog.allAnime,
      serverUrl: catalog.serverUrl,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? 'เริ่มดาวน์โหลดใหม่ $count ตอนที่อาจไม่สมบูรณ์แล้ว...'
              : 'ไม่พบรายการที่ขนาดไฟล์ผิดปกติ'),
          backgroundColor: count > 0 ? Colors.green.shade800 : Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showConcurrencySettingsSheet(BuildContext context, DownloadProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF141824),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.speed, color: AppTheme.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ความเร็วและการโหลดพร้อมกัน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'เลือกจำนวนตอนที่ต้องการดาวน์โหลดพร้อมกัน หากอินเทอร์เน็ตความเร็วสูงหรือต่อ Wi-Fi สามารถเพิ่มเป็น 3-4 ตอนเพื่อให้โหลดเสร็จไวขึ้น',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                ...[
                  {
                    'count': 1,
                    'title': '1 ตอนพร้อมกัน',
                    'subtitle': 'ประหยัดแบนด์วิดท์ เหมาะสำหรับเน็ตความเร็วจำกัด',
                    'badge': 'เน็ตช้า',
                    'badgeColor': Colors.grey,
                  },
                  {
                    'count': 2,
                    'title': '2 ตอนพร้อมกัน',
                    'subtitle': 'สมดุลความเร็วและเสถียรภาพ',
                    'badge': 'มาตรฐาน',
                    'badgeColor': Colors.blueAccent,
                  },
                  {
                    'count': 3,
                    'title': '3 ตอนพร้อมกัน',
                    'subtitle': 'โหลดเร็วขึ้นอย่างเห็นได้ชัด เหมาะสำหรับ Wi-Fi ทั่วไป',
                    'badge': 'แนะนำ',
                    'badgeColor': AppTheme.accent,
                  },
                  {
                    'count': 4,
                    'title': '4 ตอนพร้อมกัน',
                    'subtitle': 'เต็มสปีด สำหรับเน็ตบ้านไฟเบอร์หรือเน็ตความเร็วสูงมาก',
                    'badge': 'เร็วสุด',
                    'badgeColor': Colors.greenAccent,
                  },
                ].map((opt) {
                  final count = opt['count'] as int;
                  final isSelected = provider.maxConcurrentDownloads == count;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withOpacity(0.1) : AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : Colors.white10,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Row(
                        children: [
                          Text(
                            opt['title'] as String,
                            style: TextStyle(
                              color: isSelected ? AppTheme.accent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (opt['badgeColor'] as Color).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              opt['badge'] as String,
                              style: TextStyle(
                                color: opt['badgeColor'] as Color,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        opt['subtitle'] as String,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppTheme.accent, size: 20)
                          : null,
                      onTap: () {
                        provider.setMaxConcurrentDownloads(count);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _quickShareAnimeGroup(BuildContext context, DownloadedAnimeGroup group) {
    final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
    final anime = realAnime ?? (AnimeCollection()
      ..slug = group.animeSlug
      ..title = group.animeTitle
      ..coverUrl = group.animeCoverUrl);

    final completed = group.episodes.where((e) => e.isCompleted).toList();
    QuickShareDialogs.showSelectAndShareSheet(
      context,
      anime: anime,
      completedItems: completed,
    );
  }

  void _showQuickShareHubSheet(BuildContext context, DownloadProvider provider) {
    final completedGroups = provider.animeGroups.where((g) => g.completedCount > 0).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF141824),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: AppTheme.accent, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Quick Share (Local Network)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'ถ่ายโอนหนังและตอนที่โหลดแล้วแบบ P2P ผ่าน Wi-Fi ท้องถิ่นโดยไม่ต้องใช้อินเทอร์เน็ต',
                  style: TextStyle(color: Colors.white60, fontSize: 12.5),
                ),
                const SizedBox(height: 20),

                // Option 1: Send
                InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (completedGroups.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ยังไม่มีหนังหรือตอนที่ดาวน์โหลดสำเร็จเพื่อแชร์'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (completedGroups.length == 1) {
                      _quickShareAnimeGroup(context, completedGroups.first);
                    } else {
                      _showPickAnimeToShareSheet(context, completedGroups);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.upload_rounded, color: AppTheme.accent, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ส่งหนังที่โหลดไว้ (Send)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'มี ${completedGroups.length} เรื่องพร้อมแชร์ • สร้าง QR Code และแชร์ผ่าน Wi-Fi',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 16),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Option 2: Receive
                InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuickShareReceiverScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.download_rounded, color: AppTheme.accent, size: 26),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'รับหนังจากเครื่องอื่น (Receive)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'สแกน QR Code หรือค้นหาอุปกรณ์ที่แชร์อยู่ในเครือข่าย',
                                style: TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: AppTheme.accent, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPickAnimeToShareSheet(BuildContext context, List<DownloadedAnimeGroup> groups) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF141824),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'เลือกเรื่องที่ต้องการแชร์',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groups.length,
                  itemBuilder: (c, idx) {
                    final g = groups[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: g.animeCoverUrl,
                            width: 38,
                            height: 52,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: AppTheme.cardLight),
                            errorWidget: (_, __, ___) => const Icon(Icons.movie, color: Colors.white30),
                          ),
                        ),
                        title: Text(
                          g.animeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${g.completedCount} ตอนที่โหลดแล้ว • ${g.formattedTotalSize}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _quickShareAnimeGroup(context, g);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildEmptyState(BuildContext context, DownloadProvider downloadProvider) {
    final storageInfo = downloadProvider.deviceStorage;

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
            if (storageInfo != null && storageInfo.isValid) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage, size: 16, color: Colors.greenAccent),
                    const SizedBox(width: 8),
                    Text(
                      'พื้นที่ว่างในเครื่องเหลือ: ${storageInfo.formattedFree} (จากทั้งหมด ${storageInfo.formattedTotal})',
                      style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
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
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuickShareReceiverScreen()),
                );
              },
              icon: const Icon(Icons.wifi_tethering, color: AppTheme.accent),
              label: const Text('รับหนังจากเครื่องอื่นผ่าน Quick Share'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent),
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
          if (group.failedCount > 0)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.orangeAccent),
              tooltip: 'ดาวน์โหลดตอนที่ล้มเหลวซ้ำ (${group.failedCount} ตอน)',
              onPressed: () async {
                final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
                final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
                final count = await provider.retryFailedDownloadsForAnime(
                  group.animeSlug,
                  anime: realAnime,
                  serverUrl: catalog.serverUrl,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('กำลังดาวน์โหลดซ้ำ $count ตอนที่ล้มเหลว...'),
                      backgroundColor: Colors.green.shade800,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          if (group.completedCount > 0)
            IconButton(
              icon: const Icon(Icons.wifi_tethering, color: AppTheme.accent),
              tooltip: 'Quick Share เรื่องนี้ไปยังเครื่องอื่น',
              onPressed: () {
                final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
                final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
                final anime = realAnime ?? AnimeCollection()
                  ..slug = group.animeSlug
                  ..title = group.animeTitle
                  ..coverUrl = group.animeCoverUrl;

                final completed = group.episodes.where((e) => e.isCompleted).toList();
                QuickShareDialogs.showSelectAndShareSheet(
                  context,
                  anime: anime,
                  completedItems: completed,
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accent),
            tooltip: 'ดาวน์โหลดใหม่ทุกตอน',
            onPressed: () => _confirmRedownloadAnime(context, group, provider),
          ),
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

          // Failed Episodes Warning Banner
          if (group.failedCount > 0)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'มี ${group.failedCount} ตอนที่ดาวน์โหลดไม่สำเร็จ',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
                        final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
                        final count = await provider.retryFailedDownloadsForAnime(
                          group.animeSlug,
                          anime: realAnime,
                          serverUrl: catalog.serverUrl,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('กำลังดาวน์โหลดซ้ำ $count ตอนที่ล้มเหลว...'),
                              backgroundColor: Colors.green.shade800,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.replay, size: 14),
                      label: const Text('ดาวน์โหลดซ้ำ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Possibly Incomplete Warning Banner for this anime
          if (group.hasPossiblyIncomplete)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'พบ ${group.possiblyIncompleteCount} ตอนที่ไฟล์อาจไม่ครบ (< 35MB)',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'สามารถกดเพื่อดาวน์โหลดใหม่ทับไฟล์เดิมได้',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
                        final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
                        int reCount = 0;
                        for (final ep in group.episodes.where((e) => e.isPossiblyIncomplete)) {
                          final realEp = realAnime?.episodes.where((e) => e.id == ep.episodeId).firstOrNull;
                          await provider.redownloadEpisode(
                            ep.episodeId,
                            anime: realAnime,
                            episode: realEp,
                            serverUrl: catalog.serverUrl,
                          );
                          reCount++;
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('กำลังดาวน์โหลดใหม่ $reCount ตอนที่อาจไม่ครบ...'),
                              backgroundColor: Colors.green.shade800,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('โหลดใหม่', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isPossiblyIncomplete ? Colors.amber : AppTheme.textMuted,
                          fontWeight: item.isPossiblyIncomplete ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (item.isPossiblyIncomplete) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 10, color: Colors.amber),
                              SizedBox(width: 3),
                              Text(
                                'อาจไม่ครบ',
                                style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
                        final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
                        final anime = realAnime ?? AnimeCollection()
                          ..slug = group.animeSlug
                          ..title = group.animeTitle
                          ..coverUrl = group.animeCoverUrl;

                        QuickShareDialogs.shareSingleEpisode(
                          context,
                          anime: anime,
                          item: item,
                        );
                      },
                      icon: const Icon(Icons.wifi_tethering, size: 16, color: AppTheme.accent),
                      label: const Text(
                        'Quick Share',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _confirmRedownloadEpisode(context, item, group, provider),
                    icon: Icon(
                      Icons.refresh,
                      size: 16,
                      color: item.isPossiblyIncomplete ? Colors.amber : AppTheme.accent,
                    ),
                    label: Text(
                      item.isPossiblyIncomplete ? 'โหลดใหม่ (ไฟล์ไม่ครบ)' : 'โหลดใหม่',
                      style: TextStyle(
                        color: item.isPossiblyIncomplete ? Colors.amber : AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEpisodeRetentionSheet(context, item, group, provider),
                    icon: Icon(
                      item.keepForever ? Icons.lock_outline : Icons.more_time,
                      size: 16,
                      color: item.keepForever ? Colors.tealAccent : AppTheme.accent,
                    ),
                    label: Text(
                      item.keepForever ? 'เก็บถาวร' : 'ขยายเวลา',
                      style: TextStyle(
                        color: item.keepForever ? Colors.tealAccent : AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    ),
                  ),
                ],
              ),
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

  void _confirmRedownloadEpisode(
    BuildContext context,
    DownloadItem item,
    DownloadedAnimeGroup group,
    DownloadProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ดาวน์โหลดตอนนี้ใหม่?', style: TextStyle(color: Colors.white)),
        content: Text(
          item.isPossiblyIncomplete
              ? 'ไฟล์ปัจจุบันมีขนาด ${item.formattedFileSize} ซึ่งอาจดาวน์โหลดไม่ครบเรื่อง ระบบจะลบไฟล์เก่าและเริ่มดาวน์โหลด "${item.episodeTitle}" ใหม่อีกครั้ง'
              : 'คุณต้องการลบไฟล์เดิม (${item.formattedFileSize}) และดาวน์โหลด "${item.episodeTitle}" ใหม่อีกครั้งใช่หรือไม่?',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
              final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
              final realEp = realAnime?.episodes.where((e) => e.id == item.episodeId).firstOrNull;
              await provider.redownloadEpisode(
                item.episodeId,
                anime: realAnime,
                episode: realEp,
                serverUrl: catalog.serverUrl,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เริ่มดาวน์โหลดใหม่: ${item.episodeTitle}...'),
                    backgroundColor: Colors.green.shade800,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('ดาวน์โหลดใหม่'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
        ],
      ),
    );
  }

  void _confirmRedownloadAnime(
    BuildContext context,
    DownloadedAnimeGroup group,
    DownloadProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ดาวน์โหลดใหม่ทุกตอน?', style: TextStyle(color: Colors.white)),
        content: Text(
          'ระบบจะดาวน์โหลดทุกตอนของ "${group.animeTitle}" (${group.episodes.length} ตอน) ใหม่อีกครั้งอย่างสมบูรณ์',
          style: const TextStyle(color: AppTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
              final realAnime = catalog.allAnime.where((a) => a.slug == group.animeSlug).firstOrNull;
              final count = await provider.redownloadAnime(
                group.animeSlug,
                anime: realAnime,
                serverUrl: catalog.serverUrl,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('เริ่มดาวน์โหลดใหม่ทั้งหมด $count ตอนแล้ว...'),
                    backgroundColor: Colors.green.shade800,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('ดาวน์โหลดใหม่'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
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
