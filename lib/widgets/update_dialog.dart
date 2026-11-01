import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class UpdateDialog extends StatefulWidget {
  final AppReleaseInfo releaseInfo;
  final String currentVersion;

  const UpdateDialog({
    Key? key,
    required this.releaseInfo,
    required this.currentVersion,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required AppReleaseInfo releaseInfo,
    required String currentVersion,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        releaseInfo: releaseInfo,
        currentVersion: currentVersion,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  String? _downloadedFilePath;
  CancelToken? _cancelToken;
  bool _needsPermission = false;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = widget.releaseInfo.apkAsset.size;
      _cancelToken = CancelToken();
      _needsPermission = false;
    });

    try {
      final path = await UpdateService.instance.downloadApk(
        widget.releaseInfo,
        cancelToken: _cancelToken,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _receivedBytes = received;
              if (total > 0) _totalBytes = total;
            });
          }
        },
      );

      _downloadedFilePath = path;

      if (!mounted) return;

      // Check permission before launching installer
      final canInstall =
          await UpdateService.instance.canInstallUnknownPackages();
      if (!canInstall) {
        setState(() {
          _isDownloading = false;
          _needsPermission = true;
        });
        return;
      }

      await _install();
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && CancelToken.isCancel(e)) {
        setState(() {
          _isDownloading = false;
        });
        return;
      }
      setState(() {
        _isDownloading = false;
        _errorMessage = 'เกิดข้อผิดพลาดในการดาวน์โหลด: $e';
      });
    }
  }

  Future<void> _install() async {
    if (_downloadedFilePath == null) return;
    try {
      await UpdateService.instance.installApk(_downloadedFilePath!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'ไม่สามารถเปิดตัวติดตั้งได้: $e';
        });
      }
    }
  }

  Future<void> _requestPermissionAndInstall() async {
    await UpdateService.instance.openInstallPermissionSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'กรุณากดเปิดอนุญาตให้ติดตั้งแอปจากแหล่งนี้ แล้วกดย้อนกลับมาติดตั้ง'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.releaseInfo;

    return Dialog(
      backgroundColor: const Color(0xFF161A26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.88,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update,
                    color: AppTheme.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'พบเวอร์ชันใหม่!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v${widget.currentVersion} ➔ v${release.version}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 14),

            // Release Notes
            if (release.releaseNotes.isNotEmpty) ...[
              const Text(
                'รายละเอียดการอัปเดต:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    release.releaseNotes,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // File size
            if (release.apkAsset.size > 0 && !_isDownloading)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.file_download_outlined,
                        size: 16, color: Colors.white38),
                    const SizedBox(width: 6),
                    Text(
                      'ขนาดไฟล์: ${release.apkAsset.formattedSize}',
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ),

            // Downloading progress bar
            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white12,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  Text(
                    '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Needs Permission to Install Unknown Apps
            if (_needsPermission) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security, color: Colors.amber, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'ต้องการสิทธิ์การติดตั้ง',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'กรุณากดเปิดสิทธิ์ "ติดตั้งแอปที่ไม่รู้จัก" ในการตั้งค่าเพื่อดำเนินการต่อ',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _requestPermissionAndInstall,
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('เปิดการตั้งค่าสิทธิ์'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'ไว้ภายหลัง',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                if (_isDownloading)
                  TextButton(
                    onPressed: () {
                      _cancelToken?.cancel();
                    },
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                const SizedBox(width: 8),
                if (!_isDownloading && _downloadedFilePath == null)
                  ElevatedButton.icon(
                    onPressed: _startDownload,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('อัปเดตตอนนี้'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (!_isDownloading && _downloadedFilePath != null)
                  ElevatedButton.icon(
                    onPressed: _install,
                    icon: const Icon(Icons.install_mobile, size: 18),
                    label: const Text('ติดตั้งทันที'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
