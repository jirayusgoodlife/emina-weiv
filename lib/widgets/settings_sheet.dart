import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';
import '../theme/app_theme.dart';

/// หน้าต่างตั้งค่าของแอป (เปิดจากหน้าแรก หรือจากเครื่องเล่นวิดีโอ)
class AppSettingsSheet {
  static Future<void> show(BuildContext context) async {
    final result = await showModalBottomSheet<AppReleaseInfo>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _AppSettingsSheet(),
    );

    if (result != null && context.mounted) {
      final versionInfo = await UpdateService.instance.getCurrentAppVersion();
      final currentVersion = versionInfo['versionName'] as String? ?? '1.0.0';
      if (context.mounted) {
        UpdateDialog.show(
          context,
          releaseInfo: result,
          currentVersion: currentVersion,
        );
      }
    }
  }
}

class _AppSettingsSheet extends StatelessWidget {
  const _AppSettingsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF141824),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ตั้งค่าของแอป',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            const NextEpisodeButtonSettingsSection(),
            const Divider(color: Colors.white10, height: 33),
            const AutoRotateSettingsSection(),
            const Divider(color: Colors.white10, height: 33),
            const _AppUpdateSection(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () =>
                  Provider.of<SettingsProvider>(context, listen: false)
                      .resetAppSettings(),
              icon: const Icon(Icons.settings_backup_restore,
                  size: 16, color: Colors.white54),
              label: const Text(
                'คืนค่าการตั้งค่าทั้งหมดเป็นค่าเริ่มต้น',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ส่วนตั้งค่าย่อย: ปุ่มดูลัดไปยังตอนถัดไป (ใช้ร่วมกันทั้งหน้าตั้งค่าและเครื่องเล่น)
class NextEpisodeButtonSettingsSection extends StatelessWidget {
  final bool showResetButton;

  const NextEpisodeButtonSettingsSection({
    Key? key,
    this.showResetButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ปุ่ม "ตอนต่อไป"',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'เลือกช่วงเวลาท้ายตอนที่จะแสดงปุ่มข้ามไปตอนต่อไป',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.showNextEpisodeButton,
          activeColor: AppTheme.primary,
          title: const Text(
            'แสดงปุ่มข้ามไปตอนต่อไป',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            settings.showNextEpisodeButton
                ? 'จะแสดงปุ่มเมื่อเหลือ ${SettingsProvider.leadLabel(settings.nextLeadSeconds)} ก่อนจบตอน'
                : 'ซ่อนปุ่มข้ามไปตอนต่อไป',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          onChanged: (val) => settings.setShowNextEpisodeButton(val),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: SettingsProvider.nextLeadOptions.map((seconds) {
            final selected = settings.nextLeadSeconds == seconds;
            return ChoiceChip(
              label: Text(
                SettingsProvider.leadLabel(seconds),
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
              selected: selected,
              selectedColor: AppTheme.primary,
              backgroundColor: Colors.white10,
              onSelected: (_) => settings.setNextLeadSeconds(seconds),
            );
          }).toList(),
        ),
        if (showResetButton) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => settings.resetNextEpisodeButtonSettings(),
            icon: const Icon(Icons.restore, size: 16, color: AppTheme.accent),
            label: const Text(
              'คืนค่าเริ่มต้น (180 วินาที)',
              style: TextStyle(color: AppTheme.accent, fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// ส่วนตั้งค่าย่อย: ให้แอปหมุนตามท่าทางการถือจริง ๆ
class AutoRotateSettingsSection extends StatelessWidget {
  final bool showDescription;

  const AutoRotateSettingsSection({Key? key, this.showDescription = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'การหมุนจอ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
          ),
        ),
        if (showDescription) ...[
          const SizedBox(height: 4),
          const Text(
            'เมื่อเปิดใช้งาน หน้าจอจะตามท่าที่คุณถือมือถือจริง ๆ - ถือแนวนอนก็เป็นแนวนอน ถือแนวตั้งก็กลับมาเป็นแนวตั้ง (รวมถึงหน้าหลักหลังออกจากเครื่องเล่น)',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.autoRotate,
          activeColor: AppTheme.primary,
          title: const Text(
            'หมุนจอตามมือถือ',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            settings.autoRotate
                ? 'เปิดใช้ - หน้าจอตามท่าถือจริง (ตั้ง/นอน)'
                : 'ปิดใช้ - ล็อกแนวตั้งไว้ก่อน',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          onChanged: (val) => settings.setAutoRotate(val),
        ),
      ],
    );
  }
}

class _AppUpdateSection extends StatefulWidget {
  const _AppUpdateSection({Key? key}) : super(key: key);

  @override
  State<_AppUpdateSection> createState() => _AppUpdateSectionState();
}

class _AppUpdateSectionState extends State<_AppUpdateSection> {
  bool _isChecking = false;

  Future<void> _checkUpdate() async {
    setState(() => _isChecking = true);
    final versionInfo = await UpdateService.instance.getCurrentAppVersion();
    final currentVersion = versionInfo['versionName'] as String? ?? '1.0.0';

    final release = await UpdateService.instance
        .checkForUpdate(currentVersion: currentVersion);

    if (!mounted) return;
    setState(() => _isChecking = false);

    final latestVer = UpdateService.instance.latestGitHubVersion ?? currentVersion;

    if (release != null) {
      if (!mounted) return;
      Navigator.of(context).pop(release);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'คุณกำลังใช้งานเวอร์ชันล่าสุดแล้ว\n(เวอร์ชันปัจจุบัน: v$currentVersion | ล่าสุดบน GitHub: v$latestVer)',
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
    return ValueListenableBuilder<AppReleaseInfo?>(
      valueListenable: UpdateService.instance.updateAvailable,
      builder: (context, update, _) {
        final hasUpdate = update != null;
        final latestGitHub = UpdateService.instance.latestGitHubVersion;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'การอัปเดตแอปพลิเคชัน',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasUpdate) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, size: 7, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'มีอัปเดตใหม่',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasUpdate ? Colors.amber.withOpacity(0.08) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasUpdate ? Colors.amber.withOpacity(0.4) : Colors.white10,
                  width: hasUpdate ? 1.2 : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: UpdateService.instance.getCurrentAppVersion(),
                      builder: (context, snapshot) {
                        final v = snapshot.data?['versionName'] ?? '1.0.0';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Emina Weiv',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (hasUpdate) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'NEW',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'เวอร์ชันปัจจุบัน: v$v',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11.5,
                              ),
                            ),
                            if (latestGitHub != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  hasUpdate
                                      ? 'ล่าสุดบน GitHub: v$latestGitHub (มีเวอร์ชันใหม่!)'
                                      : 'ล่าสุดบน GitHub: v$latestGitHub (เวอร์ชันล่าสุดแล้ว)',
                                  style: TextStyle(
                                    color: hasUpdate ? Colors.amber.shade300 : Colors.greenAccent.shade200,
                                    fontSize: 11,
                                    fontWeight: hasUpdate ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkUpdate,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            hasUpdate ? Icons.system_update_rounded : Icons.refresh,
                            size: 15,
                          ),
                    label: Text(
                      hasUpdate ? 'อัปเดตเลย' : 'ตรวจสอบ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasUpdate ? Colors.amber : AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}



