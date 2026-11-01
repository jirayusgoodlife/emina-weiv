import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({Key? key}) : super(key: key);

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _hasScanned = false;
  bool _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _hasScanned = true;
        Navigator.of(context).pop(code.trim());
        break;
      }
    }
  }

  Future<void> _restartCamera() async {
    setState(() {
      _hasError = false;
    });
    try {
      await _controller.stop();
      await Future.delayed(const Duration(milliseconds: 250));
      await _controller.start();
    } catch (e) {
      debugPrint('[QrScanner] restart error: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleTorchSafe() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {}
  }

  Future<void> _switchCameraSafe() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  void _showManualInputDialog() {
    final textController = TextEditingController(text: 'http://192.168.1.18:8800');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.link, color: AppTheme.accent, size: 22),
            SizedBox(width: 10),
            Text(
              'กรอกที่อยู่เซิร์ฟเวอร์',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'กรอก URL หรือ IP ของเครื่องคอมพิวเตอร์ที่เปิด Anime Studio เช่น http://192.168.1.xxx:8800:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'http://192.168.1.xxx:8800',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppTheme.cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildDialogChip(textController, 'http://192.168.1.18:8800', 'Wi-Fi LAN'),
                _buildDialogChip(textController, 'http://10.0.2.2:8800', 'Emulator'),
                _buildDialogChip(textController, 'http://127.0.0.1:8800', 'Localhost'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ตกลงและเชื่อมต่อ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogChip(TextEditingController ctrl, String url, String label) {
    return InkWell(
      onTap: () => ctrl.text = url,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ),
    );
  }

  Widget _buildQuickIpChip(String url, String label) {
    return InkWell(
      onTap: () {
        if (!_hasScanned) {
          _hasScanned = true;
          Navigator.of(context).pop(url);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accent.withOpacity(0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi, color: AppTheme.accent, size: 14),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(MobileScannerException error) {
    _hasError = true;
    String message = 'ไม่สามารถเปิดกล้องได้';
    String hint = 'อาจเกิดจากยังไม่ได้รับสิทธิ์เข้าถึงกล้อง หรืออุปกรณ์ไม่มีกล้อง';

    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        message = 'ยังไม่ได้รับสิทธิ์เข้าถึงกล้อง';
        hint = 'กรุณาอนุญาตการเข้าถึงกล้องในการตั้งค่าแอปของอุปกรณ์ แล้วลองใหม่อีกครั้ง';
        break;
      case MobileScannerErrorCode.unsupported:
        message = 'อุปกรณ์นี้ไม่รองรับการเปิดกล้อง';
        hint = 'บน Emulator หรือเครื่องที่ไม่พบกล้อง สามารถกรอก IP โดยตรงได้ทันที';
        break;
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.controllerDisposed:
      case MobileScannerErrorCode.controllerUninitialized:
      case MobileScannerErrorCode.genericError:
        message = 'เกิดข้อผิดพลาดในการเปิดกล้อง';
        hint = error.errorDetails?.message ?? 'กรุณาลองใหม่อีกครั้ง หรือเลือกกรอก IP ด้วยตนเองด้านล่าง';
        break;
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(Icons.videocam_off_outlined, color: Colors.amber, size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _restartCamera,
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                    label: const Text('ลองเปิดใหม่', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white),
                    label: const Text('กรอก IP เอง', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Divider(color: Colors.white12),
              const SizedBox(height: 14),

              const Text(
                'หรือแตะเชื่อมต่อ IP ด่วนทันที:',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildQuickIpChip('http://192.168.1.18:8800', 'Wi-Fi (192.168.1.18)'),
                  _buildQuickIpChip('http://10.0.2.2:8800', 'Emulator (10.0.2.2)'),
                  _buildQuickIpChip('http://127.0.0.1:8800', 'Local (127.0.0.1)'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'สแกน QR Code เพื่อเชื่อมต่อ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'กรอก URL หรือ IP เอง',
            icon: const Icon(Icons.keyboard, color: Colors.white70),
            onPressed: _showManualInputDialog,
          ),
          IconButton(
            tooltip: 'เปิด/ปิดแฟลช',
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.amber);
                  default:
                    return const Icon(Icons.flash_off, color: Colors.white70);
                }
              },
            ),
            onPressed: _toggleTorchSafe,
          ),
          IconButton(
            tooltip: 'สลับกล้อง',
            icon: const Icon(Icons.cameraswitch, color: Colors.white70),
            onPressed: _switchCameraSafe,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return _buildErrorWidget(error);
            },
          ),

          // If no error, show scanner cutout overlay
          if (!_hasError) ...[
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.accent, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppTheme.primary, width: 4),
                            left: BorderSide(color: AppTheme.primary, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppTheme.primary, width: 4),
                            right: BorderSide(color: AppTheme.primary, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppTheme.primary, width: 4),
                            left: BorderSide(color: AppTheme.primary, width: 4),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppTheme.primary, width: 4),
                            right: BorderSide(color: AppTheme.primary, width: 4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Instruction Card
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner, color: AppTheme.accent, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'ส่องกล้องไปที่ QR Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'บนหน้าจอคอมพิวเตอร์ที่เปิด Anime Studio',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
