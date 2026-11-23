import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/download_item.dart';
import '../models/isar_models.dart';
import '../models/quick_share_models.dart';
import '../services/quick_share_service.dart';
import '../theme/app_theme.dart';

class QuickShareSenderScreen extends StatefulWidget {
  final AnimeCollection anime;
  final List<DownloadItem> itemsToShare;

  const QuickShareSenderScreen({
    Key? key,
    required this.anime,
    required this.itemsToShare,
  }) : super(key: key);

  @override
  State<QuickShareSenderScreen> createState() => _QuickShareSenderScreenState();
}

class _QuickShareSenderScreenState extends State<QuickShareSenderScreen>
    with SingleTickerProviderStateMixin {
  final QuickShareService _quickShare = QuickShareService.instance;
  QuickShareHostInfo? _hostInfo;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<QuickShareTransferProgress>? _uploadSub;
  QuickShareTransferProgress? _latestProgress;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startHosting();
  }

  Future<void> _startHosting() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final info = await _quickShare.startHosting(
        anime: widget.anime,
        sharedItems: widget.itemsToShare,
      );

      _uploadSub = _quickShare.uploadProgressStream.listen((progress) {
        if (mounted) {
          setState(() {
            _latestProgress = progress;
          });
        }
      });

      if (mounted) {
        setState(() {
          _hostInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    _quickShare.stopHosting();
    _pulseController.dispose();
    super.dispose();
  }

  int get _totalSizeBytes =>
      widget.itemsToShare.fold(0, (sum, i) => sum + i.fileSizeBytes);

  String get _formattedTotalSize {
    final bytes = _totalSizeBytes;
    if (bytes <= 0) return '0 MB';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _confirmClose();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Quick Share (เครื่องส่ง)'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmClose,
          ),
          actions: [
            if (_hostInfo != null)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'รีสตาร์ตเซิร์ฟเวอร์แชร์',
                onPressed: _startHosting,
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accent),
                    SizedBox(height: 16),
                    Text(
                      'กำลังเริ่มเซิร์ฟเวอร์ Quick Share...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              size: 48, color: Colors.redAccent),
                          const SizedBox(height: 14),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _startHosting,
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองใหม่อีกครั้ง'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Anime Info Summary Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: widget.anime.coverUrl,
                                  width: 50,
                                  height: 70,
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
                                      widget.anime.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'แชร์ ${widget.itemsToShare.length} ตอน',
                                            style: const TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formattedTotalSize,
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11,
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

                        const SizedBox(height: 20),

                        // QR Code Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.card,
                                AppTheme.cardLight.withOpacity(0.6),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppTheme.accent.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.12),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'สแกน QR Code เพื่อรับ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'เปิดหน้า Quick Share บนเครื่องผู้รับ แล้วกด "สแกน QR Code"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // QR Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.all(12),
                                  child: QrImageView(
                                    data: _hostInfo!.qrPayload,
                                    version: QrVersions.auto,
                                    size: 210,
                                    gapless: true,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // IP Address & Copy
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.wifi,
                                        size: 16, color: AppTheme.accent),
                                    const SizedBox(width: 8),
                                    SelectableText(
                                      _hostInfo!.serverUrl,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(
                                            text: _hostInfo!.serverUrl));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('คัดลอกที่อยู่เซิร์ฟเวอร์แล้ว'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Icon(Icons.copy,
                                          size: 16, color: AppTheme.accent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Transfer / Broadcast Status Card
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            final isTransferring = _latestProgress != null &&
                                !_latestProgress!.isCompleted;
                            final isDone = _latestProgress != null &&
                                _latestProgress!.isCompleted;

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.green.withOpacity(0.15)
                                    : AppTheme.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDone
                                      ? Colors.green.withOpacity(0.4)
                                      : isTransferring
                                          ? AppTheme.accent
                                          : AppTheme.accent.withOpacity(0.3),
                                ),
                              ),
                              child: isDone
                                  ? Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            color: Colors.greenAccent, size: 28),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'ถ่ายโอนไฟล์สำเร็จแล้ว! 🎉',
                                                style: TextStyle(
                                                  color: Colors.greenAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'อีกเครื่องสามารถเปิดดูออฟไลน์ได้ทันที',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : isTransferring
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppTheme.accent,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _latestProgress!.statusText,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${_latestProgress!.speedMBs.toStringAsFixed(1)} MB/s',
                                                  style: const TextStyle(
                                                    color: AppTheme.accent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: LinearProgressIndicator(
                                                value: _latestProgress!
                                                    .currentEpisodePercent,
                                                minHeight: 7,
                                                color: AppTheme.accent,
                                                backgroundColor: Colors.white12,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${(_latestProgress!.currentEpisodePercent * 100).toInt()}%',
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  'กำลังส่งข้อมูลผ่านเครือข่าย Wi-Fi...',
                                                  style: const TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Transform.scale(
                                              scale: _pulseAnimation.value,
                                              child: Container(
                                                width: 12,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                  color: AppTheme.accent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'กำลังกระจายสัญญาณใน Wi-Fi (Nearby)...',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13.5,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'รอให้อีกเครื่องเปิดค้นหาหรือสแกน QR Code',
                                                    style: TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 11.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Close / Done Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _confirmClose,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('หยุดการแชร์ / ปิดหน้าต่าง'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              foregroundColor: Colors.white,
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

  Future<void> _confirmClose() async {
    final isTransferring =
        _latestProgress != null && !_latestProgress!.isCompleted;

    if (isTransferring) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('กำลังส่งข้อมูลอยู่',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const Text(
            'อีกเครื่องกำลังรับไฟล์อยู่ หากปิดหน้านี้การถ่ายโอนจะถูกยกเลิก ต้องการปิดหรือไม่?',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ส่งต่อ', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ปิดทันที',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
