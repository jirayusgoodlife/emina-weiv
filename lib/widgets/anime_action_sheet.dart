import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/isar_models.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/download_provider.dart';
import '../screens/detail_screen.dart';
import '../theme/app_theme.dart';

class AnimeActionSheet {
  /// Opens action sheet for a single anime
  static void show(BuildContext context, AnimeCollection anime) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AnimeActionSheetWidget(anime: anime),
    );
  }

  /// Opens the list of currently hidden anime
  static void showHiddenAnimeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _HiddenAnimeListSheet(),
    );
  }

  /// Shows confirmation dialog to delete an anime
  static Future<bool?> showDeleteConfirmDialog(
    BuildContext context,
    AnimeCollection anime, {
    VoidCallback? onDeleted,
  }) async {
    bool deleteFromServer = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ลบอนิเมะ / หนัง',
                    style: TextStyle(
                      color: AppTheme.textMain,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คุณแน่ใจหรือไม่ว่าต้องการลบเรื่อง "${anime.title}" ออกจากเครื่อง?',
                    style: const TextStyle(color: AppTheme.textMain, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      value: deleteFromServer,
                      activeColor: AppTheme.primary,
                      title: const Text(
                        'ลบออกจากเซิร์ฟเวอร์ด้วย (ถ้ามี)',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMain),
                      ),
                      subtitle: const Text(
                        'ป้องกันไม่ให้ซิงค์กลับมาอีกเมื่อเชื่อมต่อคอมพิวเตอร์',
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      onChanged: (val) {
                        setState(() {
                          deleteFromServer = val ?? true;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('ยกเลิก', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('ยืนยันลบ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final catalogProv = Provider.of<AnimeCatalogProvider>(context, listen: false);
      final dlProv = Provider.of<DownloadProvider>(context, listen: false);

      // Clean up downloads if any
      await dlProv.deleteAnimeDownloads(anime.slug);

      // Delete from catalog & server
      await catalogProv.deleteAnime(anime, deleteFromServer: deleteFromServer);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ลบเรื่อง "${anime.title}" เรียบร้อยแล้ว'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      onDeleted?.call();
      return true;
    }

    return false;
  }
}

class _AnimeActionSheetWidget extends StatelessWidget {
  final AnimeCollection anime;

  const _AnimeActionSheetWidget({Key? key, required this.anime}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnimeCatalogProvider>(context);
    final isHidden = provider.isAnimeHidden(anime.slug);
    final epCount = anime.episodes.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center drag handle
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

            // Anime summary row
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: anime.coverUrl,
                    width: 50,
                    height: 75,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppTheme.cardLight),
                    errorWidget: (_, __, ___) => Container(
                      color: AppTheme.cardLight,
                      child: const Icon(Icons.movie, color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (anime.rating != null && anime.rating!.isNotEmpty && anime.rating != 'N/A') ...[
                            const Icon(Icons.star, color: Colors.amber, size: 13),
                            const SizedBox(width: 3),
                            Text(
                              anime.rating!,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            '$epCount ตอน',
                            style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          if (anime.year != null && anime.year!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${anime.year}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                      if (isHidden) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ซ่อนอยู่',
                            style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),

            // Option 1: View details
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_outline, color: AppTheme.primary, size: 22),
              ),
              title: const Text('เปิดดูรายละเอียดและเล่น', style: TextStyle(color: AppTheme.textMain, fontSize: 14)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DetailScreen(anime: anime)),
                );
              },
            ),

            // Option 2: Hide / Unhide
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isHidden ? Colors.green : Colors.orange).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: isHidden ? Colors.greenAccent : Colors.orangeAccent,
                  size: 22,
                ),
              ),
              title: Text(
                isHidden ? 'ยกเลิกการซ่อนเรื่องนี้' : 'ซ่อนเรื่องนี้จากหน้ารวม',
                style: const TextStyle(color: AppTheme.textMain, fontSize: 14),
              ),
              subtitle: Text(
                isHidden
                  ? 'นำกลับมาแสดงในหน้าแรกและค้นหา'
                  : 'จะไม่แสดงในหน้าแรกและค้นหา แต่ยังอยู่ในคลัง',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              onTap: () async {
                Navigator.of(context).pop();
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
                        content: Text('ซ่อนเรื่อง "${anime.title}" เรียบร้อยแล้ว'),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'เลิกทำ',
                          textColor: AppTheme.accent,
                          onPressed: () {
                            provider.unhideAnime(anime.slug);
                          },
                        ),
                      ),
                    );
                  }
                }
              },
            ),

            // Option: Remove from Continue Watching
            if (anime.lastWatchedEpisodeId != null) ...[
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.playlist_remove, color: Colors.blueAccent, size: 22),
                ),
                title: const Text('ลบออกจากกำลังรับชมต่อ', style: TextStyle(color: AppTheme.textMain, fontSize: 14)),
                subtitle: const Text(
                  'เอาออกจากคิวรับชมต่อ โดยไม่ลบอนิเมะออกจากเครื่อง',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final prevEpId = anime.lastWatchedEpisodeId;
                  final prevPos = anime.lastWatchedPositionSeconds;
                  final prevDate = anime.lastWatchedAt;

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
                },
              ),
            ],

            // Option 3: Delete
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              ),
              title: const Text(
                'ลบเรื่องนี้',
                style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'ลบข้อมูลเรื่องและไฟล์ดาวน์โหลดออกจากเครื่อง',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              onTap: () {
                Navigator.of(context).pop();
                AnimeActionSheet.showDeleteConfirmDialog(context, anime);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HiddenAnimeListSheet extends StatelessWidget {
  const _HiddenAnimeListSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnimeCatalogProvider>(context);
    final hiddenList = provider.hiddenAnime;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center drag handle
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
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.visibility_off, color: Colors.orangeAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'รายการที่ซ่อนอยู่ (${hiddenList.length})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (hiddenList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.visibility_outlined, size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('ไม่มีรายการที่ซ่อนอยู่', style: TextStyle(color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              )
            else ...[
              Expanded(
                child: ListView.separated(
                  itemCount: hiddenList.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final item = hiddenList[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: item.coverUrl,
                          width: 42,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppTheme.cardLight),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.cardLight,
                            child: const Icon(Icons.movie, size: 20, color: Colors.white24),
                          ),
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${item.episodes.length} ตอน • ${item.status ?? ""}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.greenAccent, size: 20),
                            tooltip: 'ยกเลิกการซ่อน',
                            onPressed: () async {
                              await provider.unhideAnime(item.slug);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            tooltip: 'ลบ',
                            onPressed: () {
                              AnimeActionSheet.showDeleteConfirmDialog(context, item);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('ยกเลิกการซ่อนทั้งหมด'),
                  onPressed: () async {
                    await provider.unhideAll();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
