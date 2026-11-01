import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/anime_catalog_provider.dart';
import '../screens/qr_scanner_screen.dart';
import '../theme/app_theme.dart';

class SyncDialog extends StatefulWidget {
  const SyncDialog({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SyncDialog(),
    );
  }

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  late TextEditingController _urlController;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AnimeCatalogProvider>(context, listen: false);
    _urlController = TextEditingController(text: provider.serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AnimeCatalogProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.sync, color: AppTheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'ซิงค์แคตตาล็อกหนัง (Isar)',
                    style: TextStyle(
                      fontSize: 18,
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
          const SizedBox(height: 14),
          const Text(
            'สแกน QR Code บนหน้าจอคอมพิวเตอร์ หรือกรอกที่อยู่ IP เพื่อซิงค์ข้อมูลหนังและตอนทั้งหมด:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),

          // Big QR Scan Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _openQrScanner,
              icon: const Icon(Icons.qr_code_scanner, color: AppTheme.accent),
              label: const Text(
                'สแกน QR Code จากคอมพิวเตอร์',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accent, width: 1.2),
                backgroundColor: AppTheme.accent.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Divider with "หรือ"
          Row(
            children: const [
              Expanded(child: Divider(color: Colors.white12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('หรือกรอก IP เอง', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.white12)),
            ],
          ),
          const SizedBox(height: 16),

          // URL Input
          TextField(
            controller: _urlController,
            style: const TextStyle(color: AppTheme.textMain, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'ที่อยู่เซิร์ฟเวอร์ (Server URL)',
              labelStyle: const TextStyle(color: AppTheme.textMuted),
              hintText: 'http://192.168.1.xxx:8800',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: AppTheme.cardLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.link, color: AppTheme.accent, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: AppTheme.accent, size: 20),
                tooltip: 'สแกน QR Code',
                onPressed: _openQrScanner,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Shortcut chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('http://192.168.1.18:8800', 'Wi-Fi LAN (192.168.1.18)'),
              _buildPresetChip('http://192.168.1.19:8800', 'LAN (192.168.1.19)'),
              _buildPresetChip('http://10.0.2.2:8800', 'Emulator'),
            ],
          ),
          const SizedBox(height: 20),

          // Status message if any
          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _isSuccess ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSuccess ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    color: _isSuccess ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green : Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Action Buttons
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: provider.isSyncing ? null : _handleSync,
              icon: provider.isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(provider.isSyncing ? 'กำลังซิงค์ข้อมูล...' : 'ซิงค์ข้อมูลเดี๋ยวนี้'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String url, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMain)),
      backgroundColor: AppTheme.cardLight,
      side: const BorderSide(color: Colors.white12),
      onPressed: () {
        setState(() {
          _urlController.text = url;
        });
      },
    );
  }

  Future<void> _handleSync() async {
    final provider = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    await provider.setServerUrl(url);
    final result = await provider.syncNow(url);

    setState(() {
      _isSuccess = result.success;
      _statusMessage = result.message;
    });

    if (result.success && mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _openQrScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (scannedCode != null && scannedCode.trim().isNotEmpty && mounted) {
      setState(() {
        _urlController.text = scannedCode.trim();
      });
      // Automatically trigger sync upon scanning!
      _handleSync();
    }
  }
}
