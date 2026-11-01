import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:provider/provider.dart';
import '../models/isar_models.dart';
import '../providers/anime_catalog_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../services/in_app_stream_proxy.dart';
import '../services/pip_service.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_sheet.dart';

class PlayerScreen extends StatefulWidget {
  final AnimeCollection anime;
  final int initialEpisodeIndex;

  const PlayerScreen({
    Key? key,
    required this.anime,
    required this.initialEpisodeIndex,
  }) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late int _currentEpisodeIndex;
  VideoPlayerController? _controller;
  VideoPlayerController? _initializingController;
  int _initEpoch = 0;
  bool _isDisposed = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;
  double _playbackSpeed = 1.0;
  BoxFit _videoFit = BoxFit.contain;
  bool _hasAutoAdvanced = false;
  bool _showResumeNotice = false;
  int _resumedFromSeconds = 0;
  Timer? _resumeNoticeTimer;
  bool _isOfflinePlayback = false;
  bool _isFullscreen = false;
  bool _autoRotate = true;
  bool _isPipMode = false;
  SettingsProvider? _settings;

  // Gesture controls (Left = Brightness, Right = Volume)
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _isDraggingBrightness = false;
  bool _isDraggingVolume = false;
  bool _showBrightnessIndicator = false;
  bool _showVolumeIndicator = false;
  Timer? _indicatorHideTimer;
  bool _lastReportedPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentEpisodeIndex = widget.initialEpisodeIndex;
    WakelockPlus.enable();

    // Initialize Picture-in-Picture
    PipService.initialize();
    PipService.isPipMode.addListener(_onPipModeChanged);
    PipService.onPipAction = _onPipAction;
    _updateAutoPip(true);

    // Initial brightness and volume levels
    PipService.getBrightness().then((b) {
      if (mounted) {
        setState(() {
          _currentBrightness = b;
        });
      }
    });
    PipService.getVolume().then((v) {
      if (mounted) {
        setState(() {
          _currentVolume = v;
        });
      }
    });

    // Follow the real device orientation (unless auto-rotate is turned off in settings)
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _settings = settings;
    _autoRotate = settings.autoRotate;
    settings.addListener(_onSettingsChanged);
    _applyOrientationPolicy();

    _initCurrentEpisode();

    // Auto save progress every 5 seconds
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  void _onPipAction(String action) {
    if (!mounted || _isDisposed) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (action == 'play') {
      c.play();
      PipService.updatePipActions(isPlaying: true);
      setState(() {});
    } else if (action == 'pause') {
      c.pause();
      PipService.updatePipActions(isPlaying: false);
      setState(() {});
    }
  }

  void _onPipModeChanged() {
    if (!mounted) return;
    final inPip = PipService.isPipMode.value;
    setState(() {
      _isPipMode = inPip;
    });
    if (inPip) {
      if (_controller != null && _controller!.value.isInitialized) {
        _controller!.play();
        PipService.updatePipActions(isPlaying: true);
      }
    }
  }

  void _updateAutoPip(bool enabled) {
    if (!mounted) return;
    int num = 16;
    int den = 9;
    final c = _controller;
    bool playing = true;
    if (c != null && c.value.isInitialized && c.value.size.width > 0 && c.value.size.height > 0) {
      num = c.value.size.width.toInt();
      den = c.value.size.height.toInt();
      playing = c.value.isPlaying;
    }
    PipService.setAutoPip(enabled: enabled, numerator: num, denominator: den, isPlaying: playing);
  }

  void _enterPip() async {
    final c = _controller;
    int num = 16;
    int den = 9;
    bool playing = true;
    if (c != null && c.value.isInitialized && c.value.size.width > 0 && c.value.size.height > 0) {
      num = c.value.size.width.toInt();
      den = c.value.size.height.toInt();
      playing = c.value.isPlaying;
    }
    await PipService.enterPip(numerator: num, denominator: den, isPlaying: playing);
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      PipService.updatePipActions(isPlaying: false);
    } else {
      c.play();
      PipService.updatePipActions(isPlaying: true);
    }
    _startHideTimer();
    setState(() {});
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isPipMode || _isLoading || _errorMessage != null) return;
    final width = MediaQuery.of(context).size.width;
    _indicatorHideTimer?.cancel();
    if (details.globalPosition.dx < width / 2) {
      // Left side: Brightness
      _isDraggingBrightness = true;
      _isDraggingVolume = false;
      _showBrightnessIndicator = true;
      _showVolumeIndicator = false;
    } else {
      // Right side: Volume
      _isDraggingVolume = true;
      _isDraggingBrightness = false;
      _showVolumeIndicator = true;
      _showBrightnessIndicator = false;
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_isDraggingBrightness && !_isDraggingVolume) return;
    final height = MediaQuery.of(context).size.height;
    final delta = -details.delta.dy / (height * 0.6);

    if (_isDraggingBrightness) {
      _updateBrightness((_currentBrightness + delta).clamp(0.0, 1.0));
    } else if (_isDraggingVolume) {
      _updateVolume((_currentVolume + delta).clamp(0.0, 1.0));
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _isDraggingBrightness = false;
    _isDraggingVolume = false;
    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showBrightnessIndicator = false;
          _showVolumeIndicator = false;
        });
      }
    });
  }

  /// Extra dimming overlay opacity when brightness is set below 30% down to 0%
  /// allows ultra-low, soothing night viewing in pitch-dark rooms.
  double get _dimOverlayOpacity {
    if (_currentBrightness >= 0.30) return 0.0;
    return ((0.30 - _currentBrightness) / 0.30 * 0.85).clamp(0.0, 0.85);
  }

  void _updateBrightness(double val) {
    _currentBrightness = val.clamp(0.0, 1.0);
    final hwBrightness = _currentBrightness.clamp(0.001, 1.0);
    PipService.setBrightness(hwBrightness);
    setState(() {});
  }

  void _updateVolume(double val) {
    _currentVolume = val.clamp(0.0, 1.0);
    PipService.setVolume(_currentVolume);
    setState(() {});
  }

  IconData get _brightnessIcon {
    if (_currentBrightness <= 0.05) return Icons.bedtime;
    if (_currentBrightness < 0.35) return Icons.brightness_low;
    if (_currentBrightness < 0.70) return Icons.brightness_medium;
    return Icons.brightness_high;
  }

  IconData get _volumeIcon {
    if (_currentVolume <= 0.01) return Icons.volume_off;
    if (_currentVolume < 0.35) return Icons.volume_mute;
    if (_currentVolume < 0.70) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (PipService.isPipMode.value) {
      // In Picture-in-Picture mode, allow video to continue playing while using other apps!
      return;
    }
    // Pause video immediately when screen turns off or app is minimized/in background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _controller?.pause();
      _initializingController?.pause();
      _saveProgress();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _initEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    PipService.isPipMode.removeListener(_onPipModeChanged);
    PipService.setAutoPip(enabled: false);
    PipService.onPipAction = null;
    PipService.resetBrightness();
    _settings?.removeListener(_onSettingsChanged);
    _settings = null;
    _hideTimer?.cancel();
    _progressSaveTimer?.cancel();
    _resumeNoticeTimer?.cancel();
    _indicatorHideTimer?.cancel();
    _saveProgress();

    final c = _controller;
    _controller = null;
    if (c != null) {
      c.removeListener(_videoListener);
      try {
        c.pause();
      } catch (_) {}
      try {
        c.dispose();
      } catch (_) {}
    }

    final ic = _initializingController;
    _initializingController = null;
    if (ic != null && ic != c) {
      ic.removeListener(_videoListener);
      try {
        ic.pause();
      } catch (_) {}
      try {
        ic.dispose();
      } catch (_) {}
    }

    WakelockPlus.disable();

    // Restore orientation and system UI (follows the real device orientation
    // unless the user turned auto-rotate off, in which case we lock portrait)
    SystemChrome.setPreferredOrientations(_normalOrientations);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  EpisodeEmbedded get currentEpisode => widget.anime.episodes[_currentEpisodeIndex];
  bool get hasNextEpisode => _currentEpisodeIndex < widget.anime.episodes.length - 1;
  bool get hasPrevEpisode => _currentEpisodeIndex > 0;

  Future<void> _initCurrentEpisode() async {
    final epoch = ++_initEpoch;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasAutoAdvanced = false;
    });

    final oldController = _controller;
    _controller = null;
    if (oldController != null) {
      oldController.removeListener(_videoListener);
      try {
        await oldController.pause();
      } catch (_) {}
      try {
        await oldController.dispose();
      } catch (_) {}
    }

    final oldInit = _initializingController;
    _initializingController = null;
    if (oldInit != null && oldInit != oldController) {
      oldInit.removeListener(_videoListener);
      try {
        await oldInit.pause();
      } catch (_) {}
      try {
        await oldInit.dispose();
      } catch (_) {}
    }

    if (_isDisposed || !mounted || epoch != _initEpoch) return;

    _isOfflinePlayback = false;

    // Check if episode is downloaded for offline playback
    final downloadProv = Provider.of<DownloadProvider>(context, listen: false);
    final dlItem = downloadProv.getDownload(currentEpisode.id ?? '');
    final isOffline = dlItem != null && dlItem.isCompleted && File(dlItem.localFilePath).existsSync();

    VideoPlayerController? controller;

    if (isOffline) {
      _isOfflinePlayback = true;
      try {
        final file = File(dlItem.localFilePath);
        controller = VideoPlayerController.file(file);
        _initializingController = controller;
        await controller.initialize();
        if (_isDisposed || !mounted || epoch != _initEpoch) {
          controller.removeListener(_videoListener);
          try {
            await controller.pause();
          } catch (_) {}
          try {
            await controller.dispose();
          } catch (_) {}
          if (_initializingController == controller) _initializingController = null;
          return;
        }
        controller.setPlaybackSpeed(_playbackSpeed);
      } catch (e) {
        final failedCtrl = _initializingController ?? controller;
        _initializingController = null;
        if (failedCtrl != null) {
          try {
            await failedCtrl.pause();
          } catch (_) {}
          try {
            await failedCtrl.dispose();
          } catch (_) {}
        }
        if (mounted && epoch == _initEpoch) {
          setState(() {
            _errorMessage = 'ไม่สามารถเปิดไฟล์ออฟไลน์ได้: $e';
            _isLoading = false;
          });
        }
        return;
      }
    } else {
      final serverUrl = Provider.of<AnimeCatalogProvider>(context, listen: false).serverUrl;
      var streamUrl = currentEpisode.streamUrl?.trim() ?? '';
      if (streamUrl.isEmpty && (currentEpisode.pageUrl?.isNotEmpty ?? false)) {
        // Dynamic fallback: resolve directly via local server
        try {
          final res = await http.post(
            Uri.parse('$serverUrl/api/resolve_stream'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'page_url': currentEpisode.pageUrl}),
          ).timeout(const Duration(seconds: 12));
          if (_isDisposed || !mounted || epoch != _initEpoch) return;
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final resolved = data['stream_url']?.toString() ?? '';
            if (resolved.isNotEmpty) {
              streamUrl = resolved;
              currentEpisode.streamUrl = resolved;
            }
          }
        } catch (_) {}
      }

      if (_isDisposed || !mounted || epoch != _initEpoch) return;

      if (streamUrl.isEmpty) {
        if (mounted && epoch == _initEpoch) {
          setState(() {
            _errorMessage = 'ไม่มี URL สตรีมวิดีโอสำหรับตอนนี้ โปรดตรวจสอบใน Python Web Studio';
            _isLoading = false;
          });
        }
        return;
      }

      try {
        String effectiveServerUrl = serverUrl.replaceAll(RegExp(r'/+$'), '');
        if (effectiveServerUrl.contains('127.0.0.1') || effectiveServerUrl.contains('localhost')) {
          effectiveServerUrl = 'http://192.168.1.18:8800';
        }

        String playableUrl = streamUrl;

        // If stream is from animenani, 24playerhd, stream-aph, maimeorder or protected CDN, route via in-app stripping proxy (runs on phone)
        final lowerStream = streamUrl.toLowerCase();
        if (lowerStream.contains('animenani') ||
            lowerStream.contains('24playerhd') ||
            lowerStream.contains('orbitalkthai') ||
            lowerStream.contains('stream-aph') ||
            lowerStream.contains('qqhls') ||
            lowerStream.contains('flower.txt') ||
            lowerStream.contains('maimeorder') ||
            lowerStream.contains('animemami') ||
            lowerStream.endsWith('.txt') ||
            lowerStream.contains('/o/')) {
          if (!InAppStreamProxy.instance.isRunning) {
            await InAppStreamProxy.instance.start();
          }
          if (_isDisposed || !mounted || epoch != _initEpoch) return;
          playableUrl = InAppStreamProxy.instance.getProxyUrl(streamUrl);
        }

        final uri = Uri.parse(playableUrl);
        final isHls = playableUrl.contains('.m3u8') ||
            playableUrl.contains('/manifest') ||
            playableUrl.contains('flower.txt') ||
            lowerStream.contains('.m3u8') ||
            lowerStream.contains('flower.txt') ||
            lowerStream.contains('animenani') ||
            lowerStream.contains('24playerhd') ||
            lowerStream.contains('stream-aph') ||
            lowerStream.contains('maimeorder') ||
            lowerStream.contains('animemami') ||
            lowerStream.endsWith('.txt') ||
            lowerStream.contains('/o/');

        final netController = VideoPlayerController.networkUrl(
          uri,
          formatHint: isHls ? VideoFormat.hls : null,
        );
        controller = netController;
        _initializingController = netController;
        await netController.initialize();
        if (_isDisposed || !mounted || epoch != _initEpoch) {
          netController.removeListener(_videoListener);
          try {
            await netController.pause();
          } catch (_) {}
          try {
            await netController.dispose();
          } catch (_) {}
          if (_initializingController == netController) _initializingController = null;
          return;
        }
        netController.setPlaybackSpeed(_playbackSpeed);
      } catch (e) {
        final failedCtrl = _initializingController ?? controller;
        _initializingController = null;
        if (failedCtrl != null) {
          try {
            await failedCtrl.pause();
          } catch (_) {}
          try {
            await failedCtrl.dispose();
          } catch (_) {}
        }
        if (mounted && epoch == _initEpoch) {
          setState(() {
            _errorMessage = 'ไม่สามารถเล่นวิดีโอได้: $e';
            _isLoading = false;
          });
        }
        return;
      }
    }

    final activeController = controller;

    try {
      if (_isDisposed || !mounted || epoch != _initEpoch) {
        activeController.removeListener(_videoListener);
        try {
          await activeController.pause();
        } catch (_) {}
        try {
          await activeController.dispose();
        } catch (_) {}
        if (_initializingController == activeController) _initializingController = null;
        return;
      }

      // Check saved watch progress from provider
      final provider = Provider.of<AnimeCatalogProvider>(context, listen: false);
      final savedProg = provider.getEpisodeProgress(widget.anime.slug, currentEpisode.id ?? '');
      final savedPos = savedProg?.positionSeconds ??
          (widget.anime.lastWatchedEpisodeId == currentEpisode.id
              ? widget.anime.lastWatchedPositionSeconds
              : null);

      if (savedPos != null && savedPos > 5 && savedProg?.isCompleted != true) {
        final maxDur = activeController.value.duration.inSeconds;
        if (maxDur <= 0 || savedPos < maxDur - 10) {
          await activeController.seekTo(Duration(seconds: savedPos));
          if (_isDisposed || !mounted || epoch != _initEpoch) {
            activeController.removeListener(_videoListener);
            try {
              await activeController.pause();
            } catch (_) {}
            try {
              await activeController.dispose();
            } catch (_) {}
            if (_initializingController == activeController) _initializingController = null;
            return;
          }
          if (mounted && epoch == _initEpoch) {
            setState(() {
              _resumedFromSeconds = savedPos;
              _showResumeNotice = true;
            });
            _resumeNoticeTimer?.cancel();
            _resumeNoticeTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) setState(() => _showResumeNotice = false);
            });
          }
        }
      }

      if (_isDisposed || !mounted || epoch != _initEpoch) {
        activeController.removeListener(_videoListener);
        try {
          await activeController.pause();
        } catch (_) {}
        try {
          await activeController.dispose();
        } catch (_) {}
        if (_initializingController == activeController) _initializingController = null;
        return;
      }

      activeController.addListener(_videoListener);
      await activeController.play();

      if (_isDisposed || !mounted || epoch != _initEpoch) {
        activeController.removeListener(_videoListener);
        try {
          await activeController.pause();
        } catch (_) {}
        try {
          await activeController.dispose();
        } catch (_) {}
        if (_initializingController == activeController) _initializingController = null;
        return;
      }

      if (_initializingController == activeController) _initializingController = null;
      setState(() {
        _controller = activeController;
        _isLoading = false;
      });
      _updateAutoPip(true);
      _startHideTimer();
    } catch (e) {
      try {
        await activeController.pause();
      } catch (_) {}
      try {
        await activeController.dispose();
      } catch (_) {}
      if (_initializingController == activeController) _initializingController = null;
      if (_controller == activeController) _controller = null;
      if (mounted && epoch == _initEpoch) {
        setState(() {
          _errorMessage = 'ไม่สามารถเล่นวิดีโอได้: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final isPlaying = _controller!.value.isPlaying;
    if (_lastReportedPlaying != isPlaying) {
      _lastReportedPlaying = isPlaying;
      PipService.updatePipActions(isPlaying: isPlaying);
    }

    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;

    // Check for auto-advance when episode finishes
    if (dur > Duration.zero && pos >= dur && !_hasAutoAdvanced) {
      _hasAutoAdvanced = true;
      _saveProgress(forceCompleted: true);
      if (hasNextEpisode) {
        _playNextEpisode();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _saveProgress({bool forceCompleted = false}) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final pos = _controller!.value.position.inSeconds;
    final dur = _controller!.value.duration.inSeconds;
    if (pos > 0 && currentEpisode.id != null) {
      final provider = Provider.of<AnimeCatalogProvider>(context, listen: false);
      provider.updateWatchProgress(
        slug: widget.anime.slug,
        episodeId: currentEpisode.id!,
        positionSeconds: pos,
        durationSeconds: dur,
        forceCompleted: forceCompleted,
      );

      // Rule 1: หากดูจบแล้ว (หรือเกิน 90%) แจ้ง DownloadProvider เพื่อนับถอยหลังลบอัตโนมัติใน 1 วัน
      if (forceCompleted || (dur > 0 && pos >= (dur * 0.90))) {
        final downloadProv = Provider.of<DownloadProvider>(context, listen: false);
        downloadProv.markEpisodeWatched(currentEpisode.id!);
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  void _playNextEpisode() {
    if (hasNextEpisode) {
      _saveProgress();
      _controller?.pause();
      _initializingController?.pause();
      setState(() {
        _currentEpisodeIndex++;
      });
      _initCurrentEpisode();
    }
  }

  void _playPrevEpisode() {
    if (hasPrevEpisode) {
      _saveProgress();
      _controller?.pause();
      _initializingController?.pause();
      setState(() {
        _currentEpisodeIndex--;
      });
      _initCurrentEpisode();
    }
  }

  void _seekRelative(int seconds) {
    if (_controller == null) return;
    final current = _controller!.value.position;
    final target = current + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _controller!.value.duration ? _controller!.value.duration : target);
    _controller!.seekTo(clamped);
    _startHideTimer();
  }

  /// Orientations allowed when we are NOT forcing landscape fullscreen.
  List<DeviceOrientation> get _normalOrientations => _autoRotate
      ? List<DeviceOrientation>.unmodifiable(DeviceOrientation.values)
      : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown];

  /// Orientations allowed while in landscape fullscreen: accept BOTH
  /// landscape directions so the user can hold the phone either way-up and
  /// the video follows the physical orientation.
  List<DeviceOrientation> get _fullscreenOrientations => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ];

  void _applyOrientationPolicy() {
    SystemChrome.setPreferredOrientations(_normalOrientations);
  }

  void _enterFullscreen() {
    if (_isFullscreen) return;
    setState(() => _isFullscreen = true);
    // Force landscape so the video really rotates, and accept BOTH landscape
    // directions so the user can hold the phone left-side-up or right-side-up.
    SystemChrome.setPreferredOrientations(_fullscreenOrientations);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startHideTimer();
  }

  void _exitFullscreen() {
    if (!_isFullscreen) {
      // Still make sure the system bars come back and orientation is free again.
      _applyOrientationPolicy();
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
      _startHideTimer();
      return;
    }
    setState(() => _isFullscreen = false);
    _applyOrientationPolicy();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _startHideTimer();
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    final next = _settings?.autoRotate ?? true;
    if (next == _autoRotate) return;
    _autoRotate = next;
    // Re-apply the orientation policy only when we are not in fullscreen.
    if (!_isFullscreen) _applyOrientationPolicy();
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape ||
        screenSize.width > 600;
    final dur = _controller?.value.duration ?? Duration.zero;
    final pos = _controller?.value.position ?? Duration.zero;
    final remainingSeconds = dur.inSeconds - pos.inSeconds;
    // แสดงเฉพาะช่วงท้ายของตอน ตามช่วงเวลาที่ผู้ใช้ตั้งไว้ในหน้าตั้งค่า (ค่ามาตรฐาน 180 วินาที)
    final isInNextEpisodeWindow = dur > Duration.zero &&
        settings.shouldShowNextEpisodeButton(remainingSeconds) &&
        (dur.inSeconds <= settings.nextLeadSeconds ? pos.inSeconds > 10 : true);
    final showNextEpisodeButton =
        hasNextEpisode && !_isLoading && isInNextEpisodeWindow;

    if (_isPipMode) {
      final isPlaying = _controller?.value.isPlaying ?? false;
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _controller != null && _controller!.value.isInitialized
              ? GestureDetector(
                  onTap: _togglePlay,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                      if (!isPlaying)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    return PopScope(
      // While fullscreen, the system back button exits fullscreen first
      // (restoring the normal orientation policy) instead of leaving the screen.
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _isDisposed = true;
          _saveProgress();
          PipService.resetBrightness();
          final c = _controller;
          final ic = _initializingController;
          _controller = null;
          _initializingController = null;
          try { c?.pause(); } catch (_) {}
          try { c?.dispose(); } catch (_) {}
          if (ic != null && ic != c) {
            try { ic.pause(); } catch (_) {}
            try { ic.dispose(); } catch (_) {}
          }
        } else if (_isFullscreen) {
          // Blocked system-back press while fullscreen: behave exactly like the
          // exit-fullscreen button — restore orientations and system bars.
          _exitFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleControls,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video Surface
              Center(
                child: _controller != null && _controller!.value.isInitialized
                    ? FittedBox(
                        fit: _videoFit,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Software Extra-Dim Overlay (for ultra-low brightness in pitch-dark rooms)
              if (_dimOverlayOpacity > 0.0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(_dimOverlayOpacity),
                    ),
                  ),
                ),

              // Loading Indicator
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                ),

              // Error View
              if (_errorMessage != null)
                Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.primary, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _initCurrentEpisode,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองใหม่อีกครั้ง'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Floating "กำลังเล่นต่อจาก..." Notification Banner
              if (_showResumeNotice && !_isLoading && _errorMessage == null)
                Positioned(
                  top: 36,
                  left: 16,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xE6141824),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.6)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history, color: AppTheme.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'เล่นต่อจาก ${_formatDuration(Duration(seconds: _resumedFromSeconds))}',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              _controller?.seekTo(Duration.zero);
                              setState(() => _showResumeNotice = false);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'เริ่มใหม่',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() => _showResumeNotice = false),
                            child: const Icon(Icons.close, color: Colors.white60, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Next Episode Quick Button (Appears during the configured final window, only if a next episode exists)
              if (showNextEpisodeButton)
                Positioned(
                  bottom: _showControls ? 95 : 32,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _playNextEpisode,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0x66141824), // Faded subtle translucent dark background
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.skip_next,
                                color: Colors.white.withOpacity(0.85),
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'ตอนต่อไป (${_currentEpisodeIndex + 2})',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (remainingSeconds > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  remainingSeconds > 60
                                      ? '(${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')})'
                                      : '(${remainingSeconds}s)',
                                  style: TextStyle(
                                    color: AppTheme.accent.withOpacity(0.85),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Custom Controls Overlay
              if (_showControls && !_isLoading && _errorMessage == null)
                _buildControlsOverlay(pos, dur),

              // Left Slider (Brightness) with Scale & Numbers
              if ((_showBrightnessIndicator || (_showControls && isLandscape)) &&
                  !_isLoading &&
                  _errorMessage == null &&
                  !_isPipMode)
                _buildVerticalSliderHud(
                  isLeft: true,
                  icon: _brightnessIcon,
                  value: _currentBrightness,
                  label: 'ความสว่าง',
                  activeColor: Colors.amber,
                  gradientColors: [Colors.amber.shade700, Colors.amberAccent],
                  isDragging: _isDraggingBrightness,
                  onChanged: (newVal) {
                    _updateBrightness(newVal);
                    _startHideTimer();
                  },
                ),

              // Right Slider (Volume) with Scale & Numbers
              if ((_showVolumeIndicator || (_showControls && isLandscape)) &&
                  !_isLoading &&
                  _errorMessage == null &&
                  !_isPipMode)
                _buildVerticalSliderHud(
                  isLeft: false,
                  icon: _volumeIcon,
                  value: _currentVolume,
                  label: 'ระดับเสียง',
                  activeColor: AppTheme.accent,
                  gradientColors: [AppTheme.primary, AppTheme.accent],
                  isDragging: _isDraggingVolume,
                  onChanged: (newVal) {
                    _updateVolume(newVal);
                    _startHideTimer();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(Duration pos, Duration dur) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black87,
            Colors.transparent,
            Colors.transparent,
            Colors.black87,
          ],
          stops: [0.0, 0.25, 0.7, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                    onPressed: () {
                      if (_isFullscreen) {
                        _exitFullscreen();
                        return;
                      }
                      _isDisposed = true;
                      _saveProgress();
                      final c = _controller;
                      final ic = _initializingController;
                      _controller = null;
                      _initializingController = null;
                      try { c?.pause(); } catch (_) {}
                      try { c?.dispose(); } catch (_) {}
                      if (ic != null && ic != c) {
                        try { ic.pause(); } catch (_) {}
                        try { ic.dispose(); } catch (_) {}
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.anime.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isOfflinePlayback) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.offline_bolt, color: Colors.green, size: 12),
                                    SizedBox(width: 3),
                                    Text(
                                      'ออฟไลน์',
                                      style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          currentEpisode.title ?? 'ตอนที่ ${_currentEpisodeIndex + 1}',
                          style: const TextStyle(color: AppTheme.accent, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Episodes Drawer Button (if more than 1 episode)
                  if (widget.anime.episodes.length > 1) ...[
                    TextButton.icon(
                      onPressed: _showEpisodeSelectorSheet,
                      icon: const Icon(Icons.video_library_outlined, color: Colors.white, size: 16),
                      label: const Text('เลือกตอน', style: TextStyle(color: Colors.white, fontSize: 11)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white12,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],

                  // Download button & progress for current episode
                  Consumer<DownloadProvider>(
                    builder: (context, dlProv, _) {
                      final epId = currentEpisode.id ?? '';
                      final isDownloading = dlProv.isDownloading(epId);
                      final isDownloaded = dlProv.isDownloaded(epId);
                      final progress = dlProv.getProgress(epId);

                      if (isDownloading) {
                        return Tooltip(
                          message: 'กำลังโหลด ${(progress * 100).toInt()}% (แตะเพื่อยกเลิก)',
                          child: InkWell(
                            onTap: () => dlProv.cancelDownload(epId),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      value: progress > 0 ? progress : null,
                                      strokeWidth: 2.2,
                                      color: AppTheme.accent,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                  const Icon(Icons.close, size: 12, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      if (isDownloaded) {
                        return Tooltip(
                          message: 'ตอนนี้ดาวน์โหลดในเครื่องแล้ว',
                          child: IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 21),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: const EdgeInsets.all(4),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ตอนนี้มีไฟล์ออฟไลน์ในเครื่องเรียบร้อยแล้ว'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        );
                      }

                      return Tooltip(
                        message: 'ดาวน์โหลดตอนนี้ไว้ดูออฟไลน์',
                        child: IconButton(
                          icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white, size: 21),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: const EdgeInsets.all(4),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final catProv = Provider.of<AnimeCatalogProvider>(context, listen: false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'กำลังดาวน์โหลด ${currentEpisode.title ?? ""} ในพื้นหลัง...',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            dlProv.startDownload(
                              anime: widget.anime,
                              episode: currentEpisode,
                              serverUrl: catProv.serverUrl,
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // Picture-in-Picture Button
                  Tooltip(
                    message: 'เล่นแบบหน้าต่างลอย (Picture-in-Picture)',
                    child: IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white, size: 21),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: const EdgeInsets.all(4),
                      visualDensity: VisualDensity.compact,
                      onPressed: _enterPip,
                    ),
                  ),

                  // Speed & Fit popup
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white, size: 21),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: const EdgeInsets.all(4),
                    visualDensity: VisualDensity.compact,
                    onPressed: _showSettingsSheet,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Center Play/Pause & Skip Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous Episode (Only shown if series has multiple episodes and previous exists)
                if (widget.anime.episodes.length > 1) ...[
                  if (hasPrevEpisode)
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: _playPrevEpisode,
                    )
                  else
                    const SizedBox(width: 48),
                  const SizedBox(width: 8),
                ],

                // Replay 10s
                IconButton(
                  iconSize: 42,
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: () => _seekRelative(-10),
                ),
                const SizedBox(width: 24),

                // Play / Pause
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _controller?.value.isPlaying ?? false ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Forward 10s
                IconButton(
                  iconSize: 42,
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  onPressed: () => _seekRelative(10),
                ),

                // Next Episode (Only shown if series has multiple episodes and next exists)
                if (widget.anime.episodes.length > 1) ...[
                  const SizedBox(width: 8),
                  if (hasNextEpisode)
                    IconButton(
                      iconSize: 36,
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: _playNextEpisode,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ],
            ),

            const Spacer(),

            // Bottom Progress Slider & Timestamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbColor: AppTheme.primary,
                      activeTrackColor: AppTheme.primary,
                      inactiveTrackColor: Colors.white24,
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    ),
                    child: Slider(
                      value: dur.inMilliseconds > 0
                          ? pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble()
                          : 0.0,
                      max: dur.inMilliseconds.toDouble(),
                      onChanged: (val) {
                        _controller?.seekTo(Duration(milliseconds: val.toInt()));
                        _startHideTimer();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(pos),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          ' / ',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        Text(
                          _formatDuration(dur),
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const Spacer(),

                        // Aspect ratio (Fit / Cover) toggle
                        IconButton(
                          icon: Icon(
                            _videoFit == BoxFit.cover ? Icons.fit_screen : Icons.aspect_ratio,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: _videoFit == BoxFit.cover ? 'พอดีจอ (Fit)' : 'ขยายเต็มจอ (Cover)',
                          onPressed: () {
                            setState(() {
                              _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
                            });
                            _startHideTimer();
                          },
                        ),

                        // Fullscreen Landscape Toggle Button
                        IconButton(
                          icon: Icon(
                            _isFullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: _isFullscreen
                              ? 'ออกจากโหมดเต็มจอ'
                              : 'ดูเต็มจอ',
                          onPressed: _toggleFullscreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildVerticalSliderHud({
    required bool isLeft,
    required IconData icon,
    required double value,
    required String label,
    required Color activeColor,
    required List<Color> gradientColors,
    required bool isDragging,
    required Function(double) onChanged,
  }) {
    final percent = (value * 100).round();
    const trackHeight = 116.0;

    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 24 : null,
      right: isLeft ? null : 24,
      child: SafeArea(
        child: Center(
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 66,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xEB141824),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDragging ? activeColor.withOpacity(0.65) : Colors.white12,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Icon
                    Icon(icon, color: activeColor, size: 22),
                    const SizedBox(height: 4),

                    // Label (ความสว่าง / ระดับเสียง)
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Numerical Display (e.g. 85%)
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),

                    // Extra hint badge for 0%
                    if (isLeft && percent == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          'ต่ำสุด',
                          style: TextStyle(
                            color: Colors.amber.shade200,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (!isLeft && percent == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          'ปิดเสียง',
                          style: TextStyle(
                            color: Colors.redAccent.shade100,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Interactive Scale Track with Graduation Ticks & Numbers
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) {
                        _indicatorHideTimer?.cancel();
                        setState(() {
                          if (isLeft) {
                            _isDraggingBrightness = true;
                            _showBrightnessIndicator = true;
                          } else {
                            _isDraggingVolume = true;
                            _showVolumeIndicator = true;
                          }
                        });
                      },
                      onVerticalDragUpdate: (details) {
                        const trackTop = 8.0;
                        const effectiveHeight = trackHeight - 16.0;
                        final localY = (details.localPosition.dy - trackTop).clamp(0.0, effectiveHeight);
                        final newVal = 1.0 - (localY / effectiveHeight);
                        onChanged(newVal);
                      },
                      onVerticalDragEnd: (details) {
                        _onVerticalDragEnd(details);
                      },
                      onTapDown: (details) {
                        const trackTop = 8.0;
                        const effectiveHeight = trackHeight - 16.0;
                        final localY = (details.localPosition.dy - trackTop).clamp(0.0, effectiveHeight);
                        final newVal = 1.0 - (localY / effectiveHeight);
                        onChanged(newVal);
                      },
                      child: SizedBox(
                        width: 42,
                        height: trackHeight,
                        child: CustomPaint(
                          painter: ScaleSliderTrackPainter(
                            value: value,
                            activeColor: activeColor,
                            gradientColors: gradientColors,
                            isLeft: isLeft,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEpisodeSelectorSheet() {
    final provider = Provider.of<AnimeCatalogProvider>(context, listen: false);
    final progressMap = provider.getAnimeEpisodeProgress(widget.anime.slug);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: 380,
          decoration: const BoxDecoration(
            color: Color(0xFF141824),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ตอนทั้งหมด (${widget.anime.episodes.length} ตอน)',
                      style: const TextStyle(
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
              ),
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.anime.episodes.length,
                  itemBuilder: (context, index) {
                    final ep = widget.anime.episodes[index];
                    final isCurrent = index == _currentEpisodeIndex;
                    final prog = progressMap[ep.id];
                    final isCompleted = prog?.isCompleted ?? false;

                    return ListTile(
                      selected: isCurrent,
                      selectedTileColor: AppTheme.primary.withOpacity(0.15),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppTheme.primary
                              : (isCompleted ? Colors.green.withOpacity(0.2) : Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCurrent
                              ? Icons.play_arrow
                              : (isCompleted ? Icons.check : Icons.play_arrow_outlined),
                          color: isCompleted && !isCurrent ? Colors.green : Colors.white,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        ep.title ?? 'ตอนที่ ${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? AppTheme.primary : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                ep.duration ?? 'ตอนที่ ${ep.episodeNumber ?? (index + 1)}',
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                              if (isCompleted) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  '• ดูจบแล้ว',
                                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ] else if (prog != null && prog.positionSeconds > 5) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '• ค้างไว้ที่ ${prog.formattedPosition}',
                                  style: const TextStyle(color: AppTheme.accent, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          if (!isCompleted && prog != null && prog.percentage > 0) ...[
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: prog.percentage,
                                minHeight: 3,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Consumer<DownloadProvider>(
                        builder: (context, dlProv, _) {
                          final epId = ep.id ?? '';
                          final isDownloading = dlProv.isDownloading(epId);
                          final isDownloaded = dlProv.isDownloaded(epId);
                          final progress = dlProv.getProgress(epId);

                          if (isDownloading) {
                            return GestureDetector(
                              onTap: () => dlProv.cancelDownload(epId),
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: progress > 0 ? progress : null,
                                      strokeWidth: 2,
                                      color: AppTheme.accent,
                                      backgroundColor: Colors.white12,
                                    ),
                                    const Icon(Icons.close, size: 12, color: Colors.white70),
                                  ],
                                ),
                              ),
                            );
                          }

                          if (isDownloaded) {
                            return const Icon(Icons.check_circle, color: Colors.green, size: 22);
                          }

                          return IconButton(
                            icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white54, size: 22),
                            tooltip: 'โหลดตอนนี้ในพื้นหลัง',
                            onPressed: () {
                              final catProv = Provider.of<AnimeCatalogProvider>(context, listen: false);
                              dlProv.startDownload(
                                anime: widget.anime,
                                episode: ep,
                                serverUrl: catProv.serverUrl,
                              );
                            },
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        if (index != _currentEpisodeIndex) {
                          _saveProgress();
                          _controller?.pause();
                          _initializingController?.pause();
                          setState(() {
                            _currentEpisodeIndex = index;
                          });
                          _initCurrentEpisode();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF141824),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'การตั้งค่าการเล่น',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('ความเร็วในการเล่น', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                  final selected = _playbackSpeed == speed;
                  return ChoiceChip(
                    label: Text('${speed}x', style: TextStyle(color: selected ? Colors.white : Colors.white70)),
                    selected: selected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: Colors.white10,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _playbackSpeed = speed);
                        _controller?.setPlaybackSpeed(speed);
                        Navigator.of(context).pop();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('สัดส่วนภาพ', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  {'label': 'พอดีจอ (Fit)', 'fit': BoxFit.contain},
                  {'label': 'เต็มจอ (Cover)', 'fit': BoxFit.cover},
                  {'label': 'ยืดภาพ (Fill)', 'fit': BoxFit.fill},
                ].map((item) {
                  final fit = item['fit'] as BoxFit;
                  final selected = _videoFit == fit;
                  return ChoiceChip(
                    label: Text(item['label'] as String, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
                    selected: selected,
                    selectedColor: AppTheme.primary,
                    backgroundColor: Colors.white10,
                    onSelected: (val) {
                      if (val) {
                        setState(() => _videoFit = fit);
                        Navigator.of(context).pop();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 16),
              const NextEpisodeButtonSettingsSection(showResetButton: false),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 16),
              const AutoRotateSettingsSection(showDescription: false),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for vertical slider track with real graduation ticks and scale markings (0, 25, 50, 75, 100)
class ScaleSliderTrackPainter extends CustomPainter {
  final double value; // 0.0 to 1.0
  final Color activeColor;
  final List<Color> gradientColors;
  final bool isLeft;

  ScaleSliderTrackPainter({
    required this.value,
    required this.activeColor,
    required this.gradientColors,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const trackTop = 8.0;
    final effectiveHeight = size.height - 16.0;
    const trackLeft = 3.0;
    const trackWidth = 6.0;
    const trackRadius = Radius.circular(3.0);

    // 1. Inactive track background
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(trackLeft, trackTop, trackWidth, effectiveHeight),
      trackRadius,
    );
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    // 2. Active track fill (from bottom up)
    final clampedValue = value.clamp(0.0, 1.0);
    final fillHeight = effectiveHeight * clampedValue;
    if (fillHeight > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          trackLeft,
          trackTop + effectiveHeight - fillHeight,
          trackWidth,
          fillHeight,
        ),
        trackRadius,
      );
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: gradientColors,
        ).createShader(Rect.fromLTWH(trackLeft, trackTop, trackWidth, effectiveHeight))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(fillRect, gradientPaint);
    }

    // 3. Thumb Knob
    final thumbY = trackTop + effectiveHeight - (effectiveHeight * clampedValue);
    final thumbCenter = Offset(trackLeft + trackWidth / 2, thumbY);

    // Glow
    final glowPaint = Paint()
      ..color = activeColor.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(thumbCenter, 6.0, glowPaint);

    // Solid thumb
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(thumbCenter, 4.0, thumbPaint);

    final thumbBorderPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(thumbCenter, 4.0, thumbBorderPaint);

    // 4. Scale Graduations (Ticks and Numbers: 100, 75, 50, 25, 0)
    const tickStartX = trackLeft + trackWidth + 4.0;
    const scaleSteps = [1.0, 0.75, 0.50, 0.25, 0.0];
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final step in scaleSteps) {
      final y = trackTop + effectiveHeight - (effectiveHeight * step);
      final isMajor = (step == 1.0 || step == 0.50 || step == 0.0);
      final tickLength = isMajor ? 5.0 : 3.5;
      final isNear = (clampedValue - step).abs() < 0.12;

      tickPaint.color = isNear
          ? activeColor
          : (isMajor ? Colors.white.withOpacity(0.65) : Colors.white.withOpacity(0.3));
      tickPaint.strokeWidth = isMajor ? 1.5 : 1.0;

      canvas.drawLine(
        Offset(tickStartX, y),
        Offset(tickStartX + tickLength, y),
        tickPaint,
      );

      // Label text (100, 75, 50, 25, 0)
      final labelText = '${(step * 100).toInt()}';
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: isNear
              ? activeColor
              : (isMajor ? Colors.white.withOpacity(0.85) : Colors.white.withOpacity(0.45)),
          fontSize: 8.5,
          fontWeight: isMajor ? FontWeight.bold : FontWeight.w500,
          letterSpacing: -0.2,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(tickStartX + tickLength + 3.0, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ScaleSliderTrackPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.isLeft != isLeft;
  }
}
