import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/download_item.dart';
import '../models/isar_models.dart';
import '../screens/quick_share_sender_screen.dart';
import '../theme/app_theme.dart';

class QuickShareDialogs {
  /// Start sharing a single episode immediately
  static void shareSingleEpisode(
    BuildContext context, {
    required AnimeCollection anime,
    required DownloadItem item,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickShareSenderScreen(
          anime: anime,
          itemsToShare: [item],
        ),
      ),
    );
  }

  /// Show sheet allowing user to select whether to share all completed episodes or specific ones
  static void showSelectAndShareSheet(
    BuildContext context, {
    required AnimeCollection anime,
    required List<DownloadItem> completedItems,
  }) {
    if (completedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีตอนที่ดาวน์โหลดสำเร็จเพื่อแชร์'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (completedItems.length == 1) {
      shareSingleEpisode(context, anime: anime, item: completedItems.first);
      return;
    }

    final selectedEpIds = completedItems.map((e) => e.episodeId).toSet();
    bool shareAll = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedList = completedItems
                .where((e) => selectedEpIds.contains(e.episodeId))
                .toList();
            final totalBytes =
                selectedList.fold(0, (sum, e) => sum + e.fileSizeBytes);

            String formattedSize(int bytes) {
              if (bytes >= 1024 * 1024 * 1024) {
                return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
              }
              return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF141824),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with Poster
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: anime.coverUrl,
                            width: 60,
                            height: 84,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: AppTheme.cardLight),
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.movie, color: Colors.white30),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'พร้อมแชร์ ${completedItems.length} ตอน',
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white10),

                  // Share Options: All vs Custom
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                shareAll = true;
                                selectedEpIds.addAll(
                                    completedItems.map((e) => e.episodeId));
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: shareAll
                                    ? AppTheme.accent.withOpacity(0.18)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: shareAll
                                      ? AppTheme.accent
                                      : Colors.white10,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.library_books,
                                      color: shareAll
                                          ? AppTheme.accent
                                          : Colors.white54,
                                      size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'แชร์ทั้งเรื่อง',
                                    style: TextStyle(
                                      color: shareAll
                                          ? Colors.white
                                          : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '(${completedItems.length} ตอน)',
                                    style: TextStyle(
                                      color: shareAll
                                          ? AppTheme.accent
                                          : Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                shareAll = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: !shareAll
                                    ? AppTheme.accent.withOpacity(0.18)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !shareAll
                                      ? AppTheme.accent
                                      : Colors.white10,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.checklist_rounded,
                                      color: !shareAll
                                          ? AppTheme.accent
                                          : Colors.white54,
                                      size: 20),
                                  const SizedBox(height: 4),
                                  Text(
                                    'เลือกเฉพาะตอน',
                                    style: TextStyle(
                                      color: !shareAll
                                          ? Colors.white
                                          : Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '(${selectedList.length} ตอนที่เลือก)',
                                    style: TextStyle(
                                      color: !shareAll
                                          ? AppTheme.accent
                                          : Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Episode List if custom selection
                  if (!shareAll) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'เลือกตอนที่ต้องการแชร์:',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (selectedEpIds.length ==
                                    completedItems.length) {
                                  selectedEpIds.clear();
                                } else {
                                  selectedEpIds.addAll(
                                      completedItems.map((e) => e.episodeId));
                                }
                              });
                            },
                            child: Text(
                              selectedEpIds.length == completedItems.length
                                  ? 'ยกเลิกทั้งหมด'
                                  : 'เลือกทั้งหมด',
                              style: const TextStyle(
                                  color: AppTheme.accent, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: completedItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = completedItems[idx];
                          final isSelected =
                              selectedEpIds.contains(item.episodeId);

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.accent.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accent.withOpacity(0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              activeColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              title: Text(
                                item.episodeTitle,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                item.formattedFileSize,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                              onChanged: (val) {
                                setSheetState(() {
                                  if (val == true) {
                                    selectedEpIds.add(item.episodeId);
                                  } else {
                                    selectedEpIds.remove(item.episodeId);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const Divider(color: Colors.white10),

                  // Start Share Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: selectedEpIds.isEmpty
                            ? null
                            : () {
                                Navigator.of(ctx).pop();
                                final itemsToSend = completedItems
                                    .where((e) =>
                                        selectedEpIds.contains(e.episodeId))
                                    .toList();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => QuickShareSenderScreen(
                                      anime: anime,
                                      itemsToShare: itemsToSend,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.wifi_tethering),
                        label: Text(
                          selectedEpIds.isEmpty
                              ? 'กรุณาเลือกอย่างน้อย 1 ตอน'
                              : 'เริ่มแชร์ ${selectedList.length} ตอน (${formattedSize(totalBytes)})',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
