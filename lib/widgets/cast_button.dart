import 'package:flutter/material.dart';
import '../services/cast_service.dart';
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
    // Keep discovery running briefly or stop if not needed
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
                        isConnected ? 'เชื่อมต่อกับทีวีแล้ว' : 'ส่งภาพขึ้นจอทีวี (Chromecast)',
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
                      : 'เลือกอุปกรณ์ Google Cast / Android TV ในเครือข่าย Wi-Fi เดียวกัน',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),

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
                          'กำลังค้นหาอุปกรณ์ Chromecast...',
                          style: TextStyle(color: AppTheme.textMain, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'โปรดตรวจสอบว่ามือถือและทีวีต่อ Wi-Fi วงเดียวกัน',
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

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cardLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tv, color: AppTheme.accent, size: 24),
                          ),
                          title: Text(
                            device.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            device.model.isNotEmpty ? device.model : device.host,
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
