import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/anime_catalog_provider.dart';
import '../models/isar_models.dart';
import '../widgets/anime_grid_card.dart';
import '../widgets/anime_list_card.dart';
import '../widgets/sync_dialog.dart';
import '../screens/detail_screen.dart';
import '../screens/player_screen.dart';
import '../screens/search_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/downloads_screen.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/anime_action_sheet.dart';
import '../widgets/settings_sheet.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUpdateOnLaunch();
    });
  }

  Future<void> _checkUpdateOnLaunch() async {
    try {
      final versionInfo = await UpdateService.instance.getCurrentAppVersion();
      final currentVersion = versionInfo['versionName'] as String? ?? '1.0.0';
      final release = await UpdateService.instance.checkForUpdate(currentVersion: currentVersion);
      if (mounted && release != null) {
        UpdateDialog.show(context, releaseInfo: release, currentVersion: currentVersion);
      }
    } catch (_) {
      // Ignore background check on launch
    }
  }

  Future<void> _checkUpdateManually() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(width: 12),
            Text('กำลังตรวจสอบเวอร์ชันล่าสุด...'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final versionInfo = await UpdateService.instance.getCurrentAppVersion();
    final currentVersion = versionInfo['versionName'] as String? ?? '1.0.0';
    final release = await UpdateService.instance
        .checkForUpdate(currentVersion: currentVersion);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (release != null) {
      UpdateDialog.show(
        context,
        releaseInfo: release,
        currentVersion: currentVersion,
      );
    } else {
      final latest = UpdateService.instance.latestGitHubVersion ?? currentVersion;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'คุณกำลังใช้งานเวอร์ชันล่าสุดแล้ว\n(เวอร์ชันปัจจุบัน: v$currentVersion | ล่าสุดบน GitHub: v$latest)',
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnimeCatalogProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final allAnime = provider.filteredAnime;
    final continueWatching = provider.continueWatching;
    final heroAnime = provider.allAnime.isNotEmpty ? provider.allAnime.first : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: Builder(
          builder: (scaffoldCtx) => Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.textMain),
                tooltip: 'เมนู',
                onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
              ),
              ValueListenableBuilder<AppReleaseInfo?>(
                valueListenable: UpdateService.instance.updateAvailable,
                builder: (context, release, _) {
                  if (release == null) return const SizedBox.shrink();
                  return Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.8),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        title: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.5),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Icon(Icons.play_arrow, size: 20, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.textMain),
            tooltip: 'ค้นหา',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _AppDrawer(
        provider: provider,
        onCheckUpdate: _checkUpdateManually,
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : provider.allAnime.isEmpty
              ? _buildEmptyState(context, provider)
              : CustomScrollView(
                  slivers: [
                    // Top Hero Billboard Banner
                    if (heroAnime != null && provider.selectedGenre == 'ทั้งหมด')
                      SliverToBoxAdapter(
                        child: _buildHeroBillboard(context, heroAnime),
                      ),

                    // Continue Watching Section
                    if (continueWatching.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Row(
                            children: const [
                              Icon(Icons.history, color: AppTheme.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'กำลังรับชมต่อ',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 190,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: continueWatching.length,
                            itemBuilder: (context, index) {
                              return _buildContinueWatchingCard(context, continueWatching[index]);
                            },
                          ),
                        ),
                      ),
                    ],

                    // Genre Filter Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.availableGenres.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final genre = provider.availableGenres[index];
                              final isSelected = provider.selectedGenre == genre;

                              return ChoiceChip(
                                label: Text(
                                  genre,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textMuted,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AppTheme.primary,
                                backgroundColor: AppTheme.cardLight,
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primary : Colors.white12,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onSelected: (_) => provider.setSelectedGenre(genre),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Gallery Header with View Mode Toggle
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                provider.selectedGenre == 'ทั้งหมด'
                                    ? 'รายการทั้งหมด (${allAnime.length} เรื่อง)'
                                    : 'หมวดหมู่: ${provider.selectedGenre} (${allAnime.length} เรื่อง)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMain,
                                ),
                              ),
                            ),
                            // View Mode Toggle (3-Columns Grid vs List)
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.grid_view,
                                      size: 18,
                                      color: !settings.isListView ? AppTheme.accent : Colors.white38,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'แสดงแบบ 3 เรื่องต่อแถว',
                                    onPressed: () => settings.setListView(false),
                                  ),
                                  Container(width: 1, height: 16, color: Colors.white12),
                                  IconButton(
                                    icon: Icon(
                                      Icons.view_list,
                                      size: 20,
                                      color: settings.isListView ? AppTheme.accent : Colors.white38,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 34, minHeight: 32),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'แสดงแบบรายการ',
                                    onPressed: () => settings.setListView(true),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Gallery Content (3-Columns Grid or List)
                    settings.isListView
                        ? SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return AnimeListCard(anime: allAnime[index]);
                                },
                                childCount: allAnime.length,
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 0.56,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 14,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return AnimeGridCard(anime: allAnime[index]);
                                },
                                childCount: allAnime.length,
                              ),
                            ),
                          ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 30),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AnimeCatalogProvider provider) {
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
              child: const Icon(Icons.cloud_download_outlined, size: 54, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'ยังไม่มีข้อมูลหนังหรืออนิเมะในเครื่อง',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'เปิดโปรแกรม Python Studio ในคอมพิวเตอร์ของคุณเพื่อดึงตอนของหนัง จากนั้นกดปุ่ม "ซิงค์ข้อมูล" ด้านล่างนี้:',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 250,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final code = await Navigator.of(context).push<String>(
                    MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                  );
                  if (code != null && code.trim().isNotEmpty) {
                    await provider.setServerUrl(code.trim());
                    final res = await provider.syncNow(code.trim());
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('สแกน QR Code เชื่อมต่อ', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 250,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () => SyncDialog.show(context),
                icon: const Icon(Icons.tune, color: AppTheme.textMain),
                label: const Text('ตั้งค่า IP ด้วยตนเอง', style: TextStyle(color: AppTheme.textMain)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBillboard(BuildContext context, AnimeCollection anime) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(anime: anime)),
        );
      },
      child: Container(
        height: 280,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop image
              CachedNetworkImage(
                imageUrl: anime.backdropUrl ?? anime.coverUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.cardLight),
                errorWidget: (_, __, ___) => CachedNetworkImage(
                  imageUrl: anime.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),

              // Gradient Shade
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.95),
                    ],
                    stops: const [0.2, 0.6, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              // Text & Action Buttons
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (anime.genres.isNotEmpty)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              anime.genres.first,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (anime.rating != null && anime.rating!.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  anime.rating!,
                                  style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Text(
                      anime.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Action buttons
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            if (anime.episodes.isNotEmpty) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    anime: anime,
                                    initialEpisodeIndex: 0,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.play_arrow, size: 20),
                          label: const Text('เล่นเลย', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => DetailScreen(anime: anime)),
                            );
                          },
                          icon: const Icon(Icons.info_outline, size: 18, color: Colors.white),
                          label: const Text('ข้อมูลเพิ่มเติม', style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }

  Widget _buildContinueWatchingCard(BuildContext context, AnimeCollection anime) {
    final provider = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final epIndex = provider.getResumeEpisodeIndex(anime);
    final ep = anime.episodes.isNotEmpty && epIndex < anime.episodes.length
        ? anime.episodes[epIndex]
        : null;
    final prog = ep != null ? provider.getEpisodeProgress(anime.slug, ep.id ?? '') : null;
    final progressFactor = prog?.percentage ??
        (anime.lastWatchedPositionSeconds != null && anime.lastWatchedPositionSeconds! > 0 ? 0.3 : 0.0);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              anime: anime,
              initialEpisodeIndex: epIndex,
            ),
          ),
        );
      },
      onLongPress: () {
        AnimeActionSheet.show(context, anime);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: CachedNetworkImage(
                      imageUrl: ep?.thumbnailUrl ?? anime.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.cardLight),
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
                    ),
                  ),

                  // Top-Right Close Button (Remove from Continue Watching)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final prevEpId = anime.lastWatchedEpisodeId;
                          final prevPos = anime.lastWatchedPositionSeconds;
                          final prevDate = anime.lastWatchedAt;

                          await provider.removeFromContinueWatching(anime.slug);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ลบ "${anime.title}" ออกจากคิวรับชมต่อแล้ว'),
                                duration: const Duration(seconds: 4),
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
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: const Icon(Icons.close, color: Colors.white70, size: 14),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Red Progress bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 3.5,
                      color: Colors.white24,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progressFactor > 0 ? progressFactor.clamp(0.05, 1.0) : 0.0,
                        child: Container(color: AppTheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ep?.title ?? 'ตอนที่ ${epIndex + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppTheme.accent),
                        ),
                      ),
                      if (prog != null && prog.positionSeconds > 5) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${(progressFactor * 100).toInt()}%',
                          style: const TextStyle(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// เมนู hamburger - รวมการกระทำทั้งหมดของหน้าโฮม (ยกเว้นปุ่มค้นหาที่อยู่นอกเมนู)
class _AppDrawer extends StatelessWidget {
  final AnimeCatalogProvider provider;
  final VoidCallback onCheckUpdate;

  const _AppDrawer({
    Key? key,
    required this.provider,
    required this.onCheckUpdate,
  }) : super(key: key);

  static const TextStyle _tileStyle = TextStyle(
    color: AppTheme.textMain,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  Widget _badge(Widget icon, int count, {Color color = AppTheme.primary}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (count > 0)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _scanAndSync(BuildContext context) async {
    Navigator.of(context).pop(); // ปิดเมนูก่อน
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (code != null && code.trim().isNotEmpty) {
      await provider.setServerUrl(code.trim());
      final res = await provider.syncNow(code.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: res.success ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary.withOpacity(0.35),
                    AppTheme.background,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'AnimeView',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            // Downloads
            Consumer<DownloadProvider>(
              builder: (context, dlProv, _) => ListTile(
                leading: _badge(
                  const Icon(Icons.download_for_offline_outlined,
                      color: AppTheme.textMain),
                  dlProv.completedDownloads.length,
                ),
                title: const Text('วิดีโอที่ดาวน์โหลดไว้', style: _tileStyle),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                  );
                },
              ),
            ),

            // Hidden anime
            if (provider.hiddenCount > 0)
              ListTile(
                leading: _badge(
                  const Icon(Icons.visibility_off_outlined,
                      color: Colors.orangeAccent),
                  provider.hiddenCount,
                  color: Colors.orange,
                ),
                title: Text('รายการที่ซ่อนไว้ (${provider.hiddenCount})',
                    style: _tileStyle),
                onTap: () {
                  Navigator.of(context).pop();
                  AnimeActionSheet.showHiddenAnimeBottomSheet(context);
                },
              ),

            const Divider(color: Colors.white10, height: 24),

            // Sync
            ListTile(
              leading: provider.isSyncing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.accent),
                    )
                  : const Icon(Icons.sync, color: AppTheme.accent),
              title: Text(
                provider.isSyncing ? 'กำลังซิงค์ข้อมูล...' : 'ซิงค์ข้อมูล',
                style: _tileStyle,
              ),
              onTap: () {
                Navigator.of(context).pop();
                SyncDialog.show(context);
              },
            ),

            // QR connect
            ListTile(
              leading:
                  const Icon(Icons.qr_code_scanner, color: AppTheme.accent),
              title:
                  const Text('สแกน QR Code เพื่อเชื่อมต่อ', style: _tileStyle),
              onTap: () => _scanAndSync(context),
            ),

            const Divider(color: Colors.white10, height: 24),

            // App settings
            ListTile(
              leading: const Icon(Icons.tune, color: AppTheme.textMain),
              title: const Text('การตั้งค่าในแอป', style: _tileStyle),
              subtitle: const Text(
                'ปุ่มตอนต่อไป, การหมุนจอ',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onTap: () {
                Navigator.of(context).pop();
                AppSettingsSheet.show(context);
              },
            ),

            // Check Update
            ValueListenableBuilder<AppReleaseInfo?>(
              valueListenable: UpdateService.instance.updateAvailable,
              builder: (context, update, _) {
                final hasUpdate = update != null;
                final latest = UpdateService.instance.latestGitHubVersion;

                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.system_update_alt, color: AppTheme.accent),
                      if (hasUpdate)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      const Text('ตรวจสอบการอัปเดต', style: _tileStyle),
                      if (hasUpdate) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'มีอัปเดต',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: FutureBuilder<Map<String, dynamic>>(
                    future: UpdateService.instance.getCurrentAppVersion(),
                    builder: (context, snapshot) {
                      final v = snapshot.data?['versionName'] ?? '1.0.0';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เวอร์ชันปัจจุบัน: v$v',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          if (latest != null)
                            Text(
                              'ล่าสุดบน GitHub: v$latest',
                              style: TextStyle(
                                color: hasUpdate
                                    ? Colors.amber.shade300
                                    : Colors.white38,
                                fontSize: 10.5,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    onCheckUpdate();
                  },
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Text(
                'AnimeView - สตรีมมิ่งอนิเมะส่วนตัวของคุณ',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
