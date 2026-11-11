import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cast_service.dart';
import '../services/in_app_stream_proxy.dart';
import '../theme/app_theme.dart';

class CastButton extends StatelessWidget {
  final Color? color;
  final double size;
  final VoidCallback? onConnected;

  const CastButton({
    Key? key,
    this.color,
    this.size = 22,
    this.onConnected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CastService.instance,
      builder: (context, _) {
        final isConnected = CastService.instance.isConnected;
        final iconColor = isConnected
            ? AppTheme.accent
            : (color ?? Colors.white);

        return Tooltip(
          message: isConnected
              ? 'กำลังส่งภาพขึ้น: ${CastService.instance.connectedDeviceName}'
              : 'ส่งภาพและเสียงขึ้นจอทีวี (Chromecast)',
          child: IconButton(
            icon: Icon(
              isConnected ? Icons.cast_connected : Icons.cast,
              color: iconColor,
              size: size,
            ),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: const EdgeInsets.all(4),
            visualDensity: VisualDensity.compact,
            onPressed: () => showCastDeviceSheet(context, onConnected: onConnected),
          ),
        );
      },
    );
  }
}

Future<void> showCastDeviceSheet(
  BuildContext context, {
  VoidCallback? onConnected,
}) {
  CastService.instance.startDiscovery();

  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return _CastDeviceSheetContent(onConnected: onConnected);
    },
  ).whenComplete(() {
    CastService.instance.stopDiscovery();
  });
}

class _CastDeviceSheetContent extends StatefulWidget {
  final VoidCallback? onConnected;

  const _CastDeviceSheetContent({Key? key, this.onConnected}) : super(key: key);

  @override
  State<_CastDeviceSheetContent> createState() => _CastDeviceSheetContentState();
}

class _CastDeviceSheetContentState extends State<_CastDeviceSheetContent> {
  String? _connectingDeviceId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CastService.instance,
      builder: (context, _) {
        final cast = CastService.instance;
        final isConnected = cast.isConnected;
        final devices = cast.devices;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title row
                Row(
                  children: [
                    Icon(
                      isConnected ? Icons.cast_connected : Icons.cast,
                      color: isConnected ? AppTheme.accent : AppTheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isConnected ? 'เชื่อมต่อกับทีวีแล้ว' : 'ส่งภาพขึ้นจอทีวี',
                        style: const TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (cast.isDiscovering)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  isConnected
                      ? 'กำลังเชื่อมต่อกับ "${cast.connectedDeviceName}"'
                      : 'เลือก Smart TV (Samsung, LG, Sony) หรือ Google Cast ในวง Wi-Fi เดียวกัน',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Web TV Option Card
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accent.withOpacity(0.18),
                        AppTheme.primary.withOpacity(0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.language, color: AppTheme.accent, size: 24),
                    ),
                    title: const Row(
                      children: [
                        Text(
                          'เปิดดูผ่านเบราว์เซอร์ทีวี (Web TV)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text(
                      'เปิด URL บนทีวีทุกรุ่น (Samsung, LG, Sony, PC) เล่นได้ทั้งไฟล์ออฟไลน์และออนไลน์',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.accent),
                    onTap: () {
                      Navigator.of(context).pop();
                      showWebTvDialog(context);
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // If currently connected
                if (isConnected) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tv, color: AppTheme.accent, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cast.connectedDeviceName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (cast.currentMediaTitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  cast.currentMediaTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            await cast.disconnect();
                            if (mounted) nav.pop();
                          },
                          icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                          label: const Text(
                            'ยกเลิกเชื่อมต่อ',
                            style: TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Device list
                if (devices.isEmpty && !isConnected) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.wifi_tethering, color: AppTheme.textMuted, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'กำลังค้นหาทีวีในเครือข่าย Wi-Fi...',
                          style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'โปรดตรวจสอบว่ามือถือและทีวีต่อ Wi-Fi วงเดียวกัน\n(หรือแตะ "เปิดดูผ่านเบราว์เซอร์ทีวี" ด้านบนเพื่อดูได้ทันที)',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ] else if (!isConnected) ...[
                  const Text(
                    'อุปกรณ์ที่พบ:',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isConnecting = _connectingDeviceId == device.id;
                        final typeLabel = device.isDlna ? 'Smart TV' : 'Google Cast';
                        final subtitleText = device.model.isNotEmpty
                            ? '${device.model} • $typeLabel'
                            : typeLabel;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cardLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              device.isDlna ? Icons.tv : Icons.cast,
                              color: AppTheme.accent,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            device.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            subtitleText,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          trailing: isConnecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.accent,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
                          onTap: isConnecting
                              ? null
                              : () async {
                                  final nav = Navigator.of(context);
                                  setState(() => _connectingDeviceId = device.id);
                                  final success = await cast.connect(device.id);
                                  if (!mounted) return;
                                  setState(() => _connectingDeviceId = null);
                                  if (success) {
                                    widget.onConnected?.call();
                                    nav.pop();
                                  }
                                },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => cast.startDiscovery(),
                      icon: const Icon(Icons.refresh, size: 16, color: AppTheme.textMuted),
                      label: const Text(
                        'ค้นหาใหม่',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Opens the Web TV Dialog / Sheet
Future<void> showWebTvDialog(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _WebTvDialogContent(),
  );
}

class _WebTvDialogContent extends StatefulWidget {
  const _WebTvDialogContent({Key? key}) : super(key: key);

  @override
  State<_WebTvDialogContent> createState() => _WebTvDialogContentState();
}

class _WebTvDialogContentState extends State<_WebTvDialogContent> {
  Timer? _timer;
  String? _tvUrl;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadUrl() async {
    final url = await InAppStreamProxy.instance.getWebTvUrl();
    if (mounted) {
      setState(() => _tvUrl = url);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTvActive = InAppStreamProxy.instance.isWebTvActive;
    final tvState = InAppStreamProxy.instance.tvState;
    final tvPos = InAppStreamProxy.instance.tvPosition;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language, color: AppTheme.accent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'เปิดดูผ่านเบราว์เซอร์ทีวี (Web TV)',
                        style: TextStyle(
                          color: AppTheme.textMain,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'เปิดได้ทุกอุปกรณ์ที่มี Browser ในวง Wi-Fi เดียวกัน',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isTvActive
                    ? Colors.green.withOpacity(0.12)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isTvActive
                      ? Colors.green.withOpacity(0.4)
                      : Colors.white12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isTvActive ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isTvActive
                          ? 'ทีวีกำลังเชื่อมต่ออยู่ (${tvState == 'PLAYING' ? 'กำลังเล่น' : 'หยุดชั่วคราว'})'
                          : 'รอเปิดเบราว์เซอร์บนทีวีตามที่อยู่ด้านล่าง...',
                      style: TextStyle(
                        color: isTvActive ? Colors.green : AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // URL Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'พิมพ์ที่อยู่นี้ลงในเบราว์เซอร์ของทีวี:',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _tvUrl ?? 'กำลังตรวจสอบ IP...',
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (_tvUrl != null)
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _tvUrl!));
                            setState(() => _copied = true);
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) setState(() => _copied = false);
                            });
                          },
                          icon: Icon(
                            _copied ? Icons.check : Icons.copy,
                            size: 16,
                            color: _copied ? Colors.green : AppTheme.accent,
                          ),
                          label: Text(
                            _copied ? 'คัดลอกแล้ว' : 'คัดลอก',
                            style: TextStyle(
                              color: _copied ? Colors.green : AppTheme.accent,
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.accent.withOpacity(0.12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Remote Controls (If TV active or ready)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardLight.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                    tooltip: 'กรอถอยหลัง 10 วิ',
                    onPressed: () {
                      InAppStreamProxy.instance.sendWebTvCommand(
                        'seek',
                        seekTime: (tvPos - 10).clamp(0.0, 999999.0),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      tvState == 'PLAYING' ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: AppTheme.accent,
                      size: 40,
                    ),
                    tooltip: tvState == 'PLAYING' ? 'หยุดชั่วคราว' : 'เล่นต่อ',
                    onPressed: () {
                      InAppStreamProxy.instance.sendWebTvCommand(
                        tvState == 'PLAYING' ? 'pause' : 'play',
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                    tooltip: 'กรอไปข้างหน้า 10 วิ',
                    onPressed: () {
                      InAppStreamProxy.instance.sendWebTvCommand(
                        'seek',
                        seekTime: tvPos + 10,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Instructions Guide
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '💡 คำแนะนำการใช้งาน:',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. เปิดเบราว์เซอร์บนทีวี (Samsung Internet, LG Web Browser, Android TV Chrome/TV Bro หรือเบราว์เซอร์ในคอม)\n'
                    '2. พิมพ์ที่อยู่เว็บข้างต้น แล้วกด Enter\n'
                    '3. วิดีโอจะขึ้นจอทีวีทันที รองรับไฟล์ออฟไลน์ (.ts/.mp4) เต็ม 100% โดยไม่ต้องพึ่ง Google Play Services',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.5),
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
