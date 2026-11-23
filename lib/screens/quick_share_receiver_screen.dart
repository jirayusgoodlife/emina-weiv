import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/isar_models.dart';
import '../models/quick_share_models.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/download_provider.dart';
import '../services/isar_service.dart';
import '../services/quick_share_service.dart';
import '../theme/app_theme.dart';
import 'player_screen.dart';
import 'qr_scanner_screen.dart';

class QuickShareReceiverScreen extends StatefulWidget {
  final String? initialServerUrl;

  const QuickShareReceiverScreen({
    Key? key,
    this.initialServerUrl,
  }) : super(key: key);

  @override
  State<QuickShareReceiverScreen> createState() => _QuickShareReceiverScreenState();
}

class _QuickShareReceiverScreenState extends State<QuickShareReceiverScreen> {
  final QuickShareService _quickShare = QuickShareService.instance;
  StreamSubscription<List<QuickShareNearbyDevice>>? _discoverySub;
  List<QuickShareNearbyDevice> _nearbyDevices = [];

  bool _isConnecting = false;
  bool _isTransferring = false;
  bool _isCancelled = false;
  QuickShareManifest? _activeManifest;
  QuickShareTransferProgress? _transferProgress;
  String? _statusError;

  @override
  void initState() {
    super.initState();
    _startDiscovery();

    if (widget.initialServerUrl != null && widget.initialServerUrl!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connectToServer(widget.initialServerUrl!);
      });
    }
  }

  void _startDiscovery() {
    _discoverySub?.cancel();
    _discoverySub = _quickShare.discoverNearbyDevices().listen((devices) {
      if (mounted) {
        setState(() {
          _nearbyDevices = devices;
        });
      }
    });
  }

  @override
  void dispose() {
    _isCancelled = true;
    _discoverySub?.cancel();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      _connectToServer(scannedCode);
    }
  }

  Future<void> _manualInputUrl() async {
    // Check if we can prefill with hotspot host IP or local gateway
    final localIps = await QuickShareService.getLocalIpAddresses();
    String defaultIp = '192.168.43.1';
    for (final ip in localIps) {
      if (ip.startsWith('192.168.43.')) {
        defaultIp = '192.168.43.1';
        break;
      } else {
        final lastDot = ip.lastIndexOf('.');
        if (lastDot != -1 && !ip.startsWith('127.')) {
          defaultIp = '${ip.substring(0, lastDot)}.1';
        }
      }
    }
    final textController = TextEditingController(
        text: 'http://$defaultIp:${QuickShareService.defaultHttpPort}');
    if (!mounted) return;
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link, color: AppTheme.accent, size: 22),
            SizedBox(width: 10),
            Text('กรอกที่อยู่เซิร์ฟเวอร์ผู้ส่ง',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กรอก IP และ Port ที่แสดงบนหน้าจอเครื่องผู้ส่ง เช่น http://192.168.1.50:45678:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'http://192.168.1.xxx:PORT',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('เชื่อมต่อ'),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty && mounted) {
      _connectToServer(url);
    }
  }

  Future<void> _connectToServer(
    String rawUrl, {
    List<String>? candidateUrls,
  }) async {
    setState(() {
      _isConnecting = true;
      _statusError = null;
    });

    try {
      final manifest = await _quickShare.fetchManifest(
        rawUrl,
        candidateUrls: candidateUrls,
      );
      if (!mounted) return;

      final workingUrl = _quickShare.lastSuccessfulServerUrl ??
          QuickShareService.parseServerUrlFromQr(rawUrl);

      final isarService = Provider.of<IsarService>(context, listen: false);
      final existingAnime = await isarService.getAnimeBySlug(manifest.anime.slug);
      if (!mounted) return;
      final isNewAnime = existingAnime == null;

      setState(() {
        _isConnecting = false;
        _activeManifest = manifest;
      });
      _showTransferConfirmSheet(workingUrl, manifest, isNewAnime: isNewAnime);
    } catch (e) {
      if (mounted) {
        final errText = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _isConnecting = false;
          _statusError = errText;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการดึงข้อมูล: $errText'),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showTransferConfirmSheet(
    String serverUrl,
    QuickShareManifest manifest, {
    bool isNewAnime = true,
  }) {
    final catalog = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final isarService = Provider.of<IsarService>(context, listen: false);
    final downloadProv = Provider.of<DownloadProvider>(context, listen: false);

    final selectedEpIds = manifest.sharedEpisodes.map((e) => e.episodeId).toSet();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectedList = manifest.sharedEpisodes
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
                          child: manifest.anime.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: manifest.anime.coverUrl,
                                  width: 65,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      Container(color: AppTheme.cardLight),
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.movie, color: Colors.white30),
                                )
                              : Container(
                                  width: 65,
                                  height: 90,
                                  color: AppTheme.cardLight,
                                  child: const Icon(Icons.movie, color: Colors.white30),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manifest.anime.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (isNewAnime)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: Colors.green.withOpacity(0.4)),
                                  ),
                                  child: const Text(
                                    '✨ จะเพิ่มเข้าคลังใหม่โดยอัตโนมัติ',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '📌 มีเรื่องนี้ในคลังแล้ว (เพิ่มตอนใหม่)',
                                    style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                'จาก: ${manifest.deviceName}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white10),

                  // Select Episodes Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'เลือกตอนที่ต้องการรับ (${selectedList.length}/${manifest.sharedEpisodes.length} ตอน)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              if (selectedEpIds.length ==
                                  manifest.sharedEpisodes.length) {
                                selectedEpIds.clear();
                              } else {
                                selectedEpIds.addAll(manifest.sharedEpisodes
                                    .map((e) => e.episodeId));
                              }
                            });
                          },
                          child: Text(
                            selectedEpIds.length == manifest.sharedEpisodes.length
                                ? 'ยกเลิกทั้งหมด'
                                : 'เลือกทั้งหมด',
                            style: const TextStyle(
                                color: AppTheme.accent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Episode List
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: manifest.sharedEpisodes.length,
                      itemBuilder: (ctx, idx) {
                        final ep = manifest.sharedEpisodes[idx];
                        final isSelected = selectedEpIds.contains(ep.episodeId);
                        final isAlreadyDownloaded =
                            downloadProv.isDownloaded(ep.episodeId);

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
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
                              ep.episodeTitle,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              isAlreadyDownloaded
                                  ? 'ดาวน์โหลดแล้ว (${ep.formattedFileSize})'
                                  : ep.formattedFileSize,
                              style: TextStyle(
                                color: isAlreadyDownloaded
                                    ? Colors.greenAccent
                                    : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  selectedEpIds.add(ep.episodeId);
                                } else {
                                  selectedEpIds.remove(ep.episodeId);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(color: Colors.white10),

                  // Action Button
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
                                _startTransfer(
                                  serverUrl: serverUrl,
                                  manifest: manifest,
                                  selectedEpisodeIds: selectedEpIds.toList(),
                                  isarService: isarService,
                                  downloadProvider: downloadProv,
                                  animeCatalogProvider: catalog,
                                );
                              },
                        icon: const Icon(Icons.download_rounded),
                        label: Text(
                          selectedEpIds.isEmpty
                              ? 'กรุณาเลือกอย่างน้อย 1 ตอน'
                              : 'เริ่มรับ ${selectedList.length} ตอน (${formattedSize(totalBytes)})',
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

  Future<void> _startTransfer({
    required String serverUrl,
    required QuickShareManifest manifest,
    required List<String> selectedEpisodeIds,
    required IsarService isarService,
    required DownloadProvider downloadProvider,
    required AnimeCatalogProvider animeCatalogProvider,
  }) async {
    setState(() {
      _isTransferring = true;
      _isCancelled = false;
      _statusError = null;
      _transferProgress = null;
    });

    try {
      await _quickShare.receiveTransfer(
        serverUrl: serverUrl,
        manifest: manifest,
        selectedEpisodeIds: selectedEpisodeIds,
        isarService: isarService,
        downloadProvider: downloadProvider,
        animeCatalogProvider: animeCatalogProvider,
        isCancelled: () => _isCancelled,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _transferProgress = progress;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusError = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCompleted =
        _transferProgress != null && _transferProgress!.isCompleted;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Quick Share (เครื่องรับ)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.accent),
            tooltip: 'สแกน QR Code เพื่อรับ',
            onPressed: _isTransferring ? null : _scanQrCode,
          ),
          IconButton(
            icon: const Icon(Icons.link, color: Colors.white70),
            tooltip: 'กรอก IP เซิร์ฟเวอร์',
            onPressed: _isTransferring ? null : _manualInputUrl,
          ),
        ],
      ),
      body: _isConnecting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text('กำลังเชื่อมต่อเครื่องผู้ส่งและดึงรายการ...',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _isTransferring
              ? _buildTransferringView()
              : hasCompleted
                  ? _buildSuccessView()
                  : _buildDiscoveryView(),
    );
  }

  Widget _buildTransferringView() {
    final progress = _transferProgress;
    final speed = progress?.speedMBs ?? 0.0;
    final epPercent = progress?.currentEpisodePercent ?? 0.0;
    final overallPercent = progress?.overallPercent ?? 0.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.12),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                progress?.statusText ?? 'กำลังถ่ายโอนข้อมูลผ่าน Local Network...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ความเร็วการถ่ายโอน: ${speed.toStringAsFixed(1)} MB/s',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: epPercent,
                  minHeight: 10,
                  color: AppTheme.accent,
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(epPercent * 100).toInt()}% (ตอนนี้)',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  Text(
                    'รวม: ${(overallPercent * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isCancelled = true;
                  });
                },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('ยกเลิกการถ่ายโอน'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.12),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 68),
              const SizedBox(height: 16),
              const Text(
                'ถ่ายโอนสำเร็จแล้ว! 🎉',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'เพิ่ม ${_activeManifest?.anime.title ?? 'อนิเมะ'} เข้าคลังเรียบร้อยแล้ว สามารถเปิดดูแบบออฟไลน์ได้ทันทีโดยไม่ต้องต่ออินเทอร์เน็ต',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Action buttons
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final anime = _activeManifest?.anime;
                    if (anime != null && anime.episodes.isNotEmpty) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            anime: anime,
                            initialEpisodeIndex: 0,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  icon: const Icon(Icons.play_circle_filled_rounded),
                  label: const Text('เปิดดูทันที (Watch Now)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.folder_outlined),
                  label: const Text('กลับไปที่หน้ารายการดาวน์โหลด'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Scan Button
          Container(
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: AppTheme.accent, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'รับหนังผ่าน Local Network',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'รับไฟล์หนังและตอนที่ดาวน์โหลดแล้วจากอีกเครื่องผ่าน Wi-Fi ท้องถิ่นโดยตรง ไม่ต้องต่ออินเทอร์เน็ต และเพิ่มเข้าคลังให้อัตโนมัติ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _scanQrCode,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('สแกน QR Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.link, color: Colors.white70),
                      tooltip: 'กรอก IP เซิร์ฟเวอร์',
                      onPressed: _manualInputUrl,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_statusError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Nearby Discovered Devices
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.radar, color: AppTheme.accent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'อุปกรณ์ที่กำลังแชร์ในเครือข่าย',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_nearbyDevices.length} อุปกรณ์',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (_nearbyDevices.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'กำลังค้นหาอุปกรณ์ใกล้เคียงที่กำลังเปิดแชร์...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ตรวจสอบให้แน่ใจว่าทั้งสองเครื่องเชื่อมต่อ Wi-Fi เดียวกัน หรือกดปุ่ม "สแกน QR Code" ด้านบน',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11.5),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _connectToServer(
                          'http://192.168.43.1:${QuickShareService.defaultHttpPort}'),
                      icon: const Icon(Icons.wifi_tethering,
                          color: Colors.orangeAccent, size: 18),
                      label: const Text(
                        'เชื่อมต่อ Hotspot ด่วน (192.168.43.1)',
                        style: TextStyle(
                            color: Colors.orangeAccent, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: Colors.orangeAccent.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _nearbyDevices.length,
              itemBuilder: (ctx, idx) {
                final dev = _nearbyDevices[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phonelink_ring,
                            color: AppTheme.accent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev.animeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${dev.deviceName} • ${dev.episodesCount} ตอน',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _connectToServer(dev.serverUrl, candidateUrls: dev.candidateUrls),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('รับไฟล์'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
