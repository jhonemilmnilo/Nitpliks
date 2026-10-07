import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../app/theme/app_palettes.dart';
import '../../app/theme/palette_provider.dart';
import '../../domain/models/media_models.dart';

enum _GestureType { none, brightness, volume, seek }

class PlayerScreen extends ConsumerStatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late int _currentIndex;

  // Stream Subscriptions
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _completedSub;

  // Playback States
  bool _isPlaying = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Controls Overlay States
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isDraggingScrubber = false;
  double _dragSliderValue = 0.0;

  // Hardware Gestures & HUD States
  _GestureType _activeGesture = _GestureType.none;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  Duration _seekTargetPosition = Duration.zero;
  int _seekDeltaSeconds = 0;
  Timer? _hudDismissTimer;

  // Double Tap Feedback States
  bool _showDoubleTapLeft = false;
  bool _showDoubleTapRight = false;
  Timer? _doubleTapAnimTimer;

  // Pro Player Features (Phase 5 & Enhancements)
  BoxFit _aspectRatio = BoxFit.contain;
  double _playbackSpeed = 1.0;
  bool _rememberSpeed = true;
  bool _isEnhanced = false;
  bool _isScreenLocked = false;
  bool _isSpeedDrawerOpen = false;
  bool _isLandscape = false;

  static const String _prefRememberSpeedKey = 'nitpliks_remember_playback_speed';
  static const String _prefCachedSpeedKey = 'nitpliks_cached_playback_speed';
  static const String _prefEnhanceKey = 'nitpliks_video_enhance_enabled';

  VideoModel get _currentVideo => widget.videos[_currentIndex];
  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex < widget.videos.length - 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // 1. Keep display awake
    WakelockPlus.enable();

    // 2. Hide Status & Navigation bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // 3. Initialize hardware-accelerated MediaKit player
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );

    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    // 4. Initial hardware values
    _initHardwareControls();

    // 5. Listen to real-time playback streams
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _positionSub = _player.stream.position.listen((pos) {
      if (mounted && !_isDraggingScrubber && _activeGesture != _GestureType.seek) {
        setState(() => _position = pos);
      }
    });

    _durationSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    // Auto-play next video in folder when finished
    _completedSub = _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        if (_hasNext) {
          _playNext();
        }
      }
    });

    // 6. Load cached speed preferences & open video
    _initSpeedPreferencesAndOpen();
    _startHideControlsTimer();
  }

  Future<void> _initSpeedPreferencesAndOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool(_prefRememberSpeedKey) ?? true;
      final cachedRate = prefs.getDouble(_prefCachedSpeedKey) ?? 1.0;
      final enhanced = prefs.getBool(_prefEnhanceKey) ?? false;

      if (mounted) {
        setState(() {
          _rememberSpeed = remember;
          _playbackSpeed = remember ? cachedRate : 1.0;
          _isEnhanced = enhanced;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }

    await _openCurrentVideo();
  }

  Future<void> _saveSpeedPreferences({required double speed, required bool remember}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefRememberSpeedKey, remember);
      if (remember) {
        await prefs.setDouble(_prefCachedSpeedKey, speed);
      }
    } catch (e) {
      debugPrint('Error saving speed preferences: $e');
    }
  }

  void _toggleVideoEnhance() {
    _startHideControlsTimer();
    final newEnhance = !_isEnhanced;
    setState(() {
      _isEnhanced = newEnhance;
    });

    _applyNativeVideoEnhancement(newEnhance);

    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_prefEnhanceKey, newEnhance);
    });
  }

  Future<void> _applyNativeVideoEnhancement(bool enable) async {
    try {
      final nativePlayer = _player.platform as dynamic;
      if (enable) {
        // 1. Hardware Contrast & Color Vibrance/Saturation
        await nativePlayer?.setProperty('contrast', '15');
        await nativePlayer?.setProperty('saturation', '20');
        await nativePlayer?.setProperty('gamma', '3');
        // 2. Hardware Unsharp Mask filter for real edge sharpening & clarity
        await nativePlayer?.setProperty('vf', 'unsharp=5:0.8:5:0.8');
      } else {
        // Reset to raw default values
        await nativePlayer?.setProperty('contrast', '0');
        await nativePlayer?.setProperty('saturation', '0');
        await nativePlayer?.setProperty('gamma', '0');
        await nativePlayer?.setProperty('vf', '');
      }
    } catch (e) {
      debugPrint('Error applying native video enhancement: $e');
    }
  }

  Future<void> _initHardwareControls() async {
    try {
      _currentBrightness = await ScreenBrightness.instance.application;
    } catch (_) {
      _currentBrightness = 0.5;
    }

    try {
      _currentVolume = await VolumeController.instance.getVolume();
      VolumeController.instance.showSystemUI = false;
    } catch (_) {
      _currentVolume = 0.5;
    }
  }

  Future<void> _openCurrentVideo() async {
    try {
      await _player.open(Media(_currentVideo.path));
      // Apply persisted or default playback speed
      final targetRate = _rememberSpeed ? _playbackSpeed : 1.0;
      await _player.setRate(targetRate);
      if (mounted && !_rememberSpeed && _playbackSpeed != 1.0) {
        setState(() => _playbackSpeed = 1.0);
      }
      // Apply persisted native video enhancement
      if (_isEnhanced) {
        _applyNativeVideoEnhancement(true);
      }
    } catch (e) {
      debugPrint('Error opening video ${_currentVideo.path}: $e');
    }
  }

  void _playPrevious() {
    if (!_hasPrevious) return;
    setState(() {
      _currentIndex--;
      _position = Duration.zero;
    });
    _openCurrentVideo();
    _startHideControlsTimer();
  }

  void _playNext() {
    if (!_hasNext) return;
    setState(() {
      _currentIndex++;
      _position = Duration.zero;
    });
    _openCurrentVideo();
    _startHideControlsTimer();
  }

  void _seekRelativeSeconds(int seconds) {
    _startHideControlsTimer();
    final currentMs = _position.inMilliseconds;
    final maxMs = _duration.inMilliseconds;
    final targetMs = (currentMs + (seconds * 1000)).clamp(0, maxMs);
    final targetPos = Duration(milliseconds: targetMs);

    // Optimistic UI update for instant zero-lag response
    setState(() {
      _position = targetPos;
    });

    // Fast direct asynchronous seek to native mpv
    _player.seek(targetPos);
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_showControls) return;

    _hideControlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isPlaying && !_isDraggingScrubber && _activeGesture == _GestureType.none) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    if (_isScreenLocked) {
      setState(() => _showControls = !_showControls);
      return;
    }
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _cycleAspectRatio() {
    _startHideControlsTimer();
    setState(() {
      if (_aspectRatio == BoxFit.contain) {
        _aspectRatio = BoxFit.cover; // Zoom / Fill
      } else if (_aspectRatio == BoxFit.cover) {
        _aspectRatio = BoxFit.fill; // Stretch
      } else if (_aspectRatio == BoxFit.fill) {
        _aspectRatio = BoxFit.none; // 100% Original
      } else {
        _aspectRatio = BoxFit.contain; // Fit to screen
      }
    });
  }

  String get _aspectRatioLabel {
    switch (_aspectRatio) {
      case BoxFit.cover:
        return 'Zoom (Crop)';
      case BoxFit.fill:
        return 'Stretch';
      case BoxFit.none:
        return 'Original (100%)';
      case BoxFit.contain:
      default:
        return 'Fit to Screen';
    }
  }

  IconData get _aspectRatioIcon {
    switch (_aspectRatio) {
      case BoxFit.cover:
        return LucideIcons.zoomIn;
      case BoxFit.fill:
        return LucideIcons.maximize2;
      case BoxFit.none:
        return LucideIcons.minimize2;
      case BoxFit.contain:
      default:
        return LucideIcons.scan;
    }
  }

  void _toggleOrientation() {
    _startHideControlsTimer();
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  void _toggleSpeedDrawer() {
    _hideControlsTimer?.cancel();
    setState(() {
      _isSpeedDrawerOpen = !_isSpeedDrawerOpen;
    });
    if (!_isSpeedDrawerOpen) {
      _startHideControlsTimer();
    }
  }

  void _closeSpeedDrawer() {
    if (_isSpeedDrawerOpen) {
      setState(() {
        _isSpeedDrawerOpen = false;
      });
      _startHideControlsTimer();
    }
  }

  void _toggleScreenLock() {
    setState(() {
      _isScreenLocked = !_isScreenLocked;
      if (_isScreenLocked) {
        _showControls = false;
        _isSpeedDrawerOpen = false;
      }
    });
  }

  // ──────────────────────────────────────────────
  // GESTURE HANDLERS (Brightness, Volume, Seek, Double Tap)
  // ──────────────────────────────────────────────

  void _onDoubleTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (_isScreenLocked) return;
    final screenWidth = constraints.maxWidth;
    final isLeft = details.localPosition.dx < (screenWidth / 2);

    _doubleTapAnimTimer?.cancel();

    if (isLeft) {
      final target = _position - const Duration(seconds: 10);
      final clamped = target < Duration.zero ? Duration.zero : target;
      _player.seek(clamped);
      setState(() {
        _position = clamped;
        _showDoubleTapLeft = true;
        _showDoubleTapRight = false;
      });
    } else {
      final target = _position + const Duration(seconds: 10);
      final clamped = target > _duration ? _duration : target;
      _player.seek(clamped);
      setState(() {
        _position = clamped;
        _showDoubleTapRight = true;
        _showDoubleTapLeft = false;
      });
    }

    _doubleTapAnimTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showDoubleTapLeft = false;
          _showDoubleTapRight = false;
        });
      }
    });
  }

  void _onVerticalDragStart(DragStartDetails details, BoxConstraints constraints) {
    if (_isScreenLocked) return;
    _hideControlsTimer?.cancel();
    final screenWidth = constraints.maxWidth;
    final isLeft = details.localPosition.dx < (screenWidth / 2);

    setState(() {
      _activeGesture = isLeft ? _GestureType.brightness : _GestureType.volume;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_isScreenLocked) return;
    final screenHeight = constraints.maxHeight;
    // Moving up decreases dy, which should increase brightness/volume
    final delta = -details.primaryDelta! / screenHeight;

    if (_activeGesture == _GestureType.brightness) {
      final newVal = (_currentBrightness + delta * 1.5).clamp(0.0, 1.0);
      setState(() => _currentBrightness = newVal);
      ScreenBrightness.instance.setApplicationScreenBrightness(newVal);
    } else if (_activeGesture == _GestureType.volume) {
      final newVal = (_currentVolume + delta * 1.5).clamp(0.0, 1.0);
      setState(() => _currentVolume = newVal);
      VolumeController.instance.setVolume(newVal);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isScreenLocked) return;
    _dismissHudAfterDelay();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isScreenLocked) return;
    _hideControlsTimer?.cancel();
    setState(() {
      _activeGesture = _GestureType.seek;
      _seekTargetPosition = _position;
      _seekDeltaSeconds = 0;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;
    // Scale horizontal distance: full screen drag sweeps 90 seconds
    final secondsDelta = (details.primaryDelta! / screenWidth) * 90;
    final newDelta = _seekDeltaSeconds + secondsDelta.toInt();

    final maxMs = _duration.inMilliseconds;
    final targetMs = (_position.inMilliseconds + (newDelta * 1000)).clamp(0, maxMs);

    setState(() {
      _seekDeltaSeconds = newDelta;
      _seekTargetPosition = Duration(milliseconds: targetMs);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_activeGesture == _GestureType.seek) {
      _player.seek(_seekTargetPosition);
      setState(() {
        _position = _seekTargetPosition;
      });
    }
    _dismissHudAfterDelay();
  }

  void _dismissHudAfterDelay() {
    _hudDismissTimer?.cancel();
    _hudDismissTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _activeGesture = _GestureType.none;
        });
        _startHideControlsTimer();
      }
    });
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
  void dispose() {
    _hideControlsTimer?.cancel();
    _hudDismissTimer?.cancel();
    _doubleTapAnimTimer?.cancel();
    _playingSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();
    _completedSub.cancel();

    // Restore System UI & release wakelock & system volume UI & reset orientation
    VolumeController.instance.showSystemUI = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.disable();

    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);

    // Calculated position for slider (safe clamped)
    final double maxDurationMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final double currentPosMs = _position.inMilliseconds.toDouble().clamp(0.0, maxDurationMs);
    final double sliderValue = _isDraggingScrubber ? _dragSliderValue : currentPosMs;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onDoubleTapDown: (details) => _onDoubleTapDown(details, constraints),
              onVerticalDragStart: (details) => _onVerticalDragStart(details, constraints),
              onVerticalDragUpdate: (details) => _onVerticalDragUpdate(details, constraints),
              onVerticalDragEnd: _onVerticalDragEnd,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, constraints),
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Hardware Video Canvas with Dynamic Aspect Ratio Fit (Enhanced via native libmpv engine)
                  Center(
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: _aspectRatio,
                    ),
                  ),

                  // 2. Floating HUD Overlays (Volume, Brightness, Seek)
                  _buildFloatingHudOverlay(palette),

                  // 4. Double Tap Feedback Indicators
                  _buildDoubleTapIndicators(),

                  // 5. Floating Screen Lock / Unlock Button (Left side)
                  _buildLockToggleButton(palette),

                  // 6. Animated Minimal Controls Overlay (Hidden when screen is locked)
                  IgnorePointer(
                    ignoring: !_showControls || _isScreenLocked,
                    child: AnimatedOpacity(
                      opacity: (_showControls && !_isScreenLocked) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: Stack(
                        children: [
                          // Top dark gradient overlay for readable text
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 100,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                            ),
                          ),

                          // Bottom dark gradient overlay for scrubber
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 120,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [Colors.black87, Colors.transparent],
                                ),
                              ),
                            ),
                          ),

                          // ──────────────────────────────────────────────
                          // TOP BAR: Back Button + Title + Speed + Aspect Ratio
                          // ──────────────────────────────────────────────
                          SafeArea(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Row(
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => Navigator.pop(context),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _currentVideo.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _currentVideo.formattedSize,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.7),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ──────────────────────────────────────────────
                          // CENTER CONTROLS: Previous, -10s, Play/Pause, +10s, Next
                          // ──────────────────────────────────────────────
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 1. Previous Video Button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: _hasPrevious ? _playPrevious : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        LucideIcons.skipBack,
                                        color: _hasPrevious ? Colors.white : Colors.white24,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // 2. 10s Skip Back Button
                                Material(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(24),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => _seekRelativeSeconds(-10),
                                    child: const Padding(
                                      padding: EdgeInsets.all(9),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.rotateCcw, color: Colors.white, size: 18),
                                          SizedBox(width: 3),
                                          Text(
                                            '10',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // 3. Main Play / Pause Button (Compact & Sleek)
                                Material(
                                  color: Colors.black45,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      _player.playOrPause();
                                      _startHideControlsTimer();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Icon(
                                        _isPlaying ? LucideIcons.pause : LucideIcons.play,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // 4. 10s Skip Forward Button
                                Material(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(24),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: () => _seekRelativeSeconds(10),
                                    child: const Padding(
                                      padding: EdgeInsets.all(9),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '10',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(width: 3),
                                          Icon(LucideIcons.rotateCw, color: Colors.white, size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // 5. Next Video Button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(24),
                                    onTap: _hasNext ? _playNext : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        LucideIcons.skipForward,
                                        color: _hasNext ? Colors.white : Colors.white24,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ──────────────────────────────────────────────
                          // BOTTOM BAR: Scrubber + Elapsed / Total Time
                          // ──────────────────────────────────────────────
                          SafeArea(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Scrubber Slider
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3.5,
                                        activeTrackColor: palette.primary,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: palette.primary,
                                        overlayColor: palette.primary.withValues(alpha: 0.2),
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      ),
                                      child: Slider(
                                        value: sliderValue,
                                        min: 0.0,
                                        max: maxDurationMs,
                                        onChangeStart: (val) {
                                          _hideControlsTimer?.cancel();
                                          setState(() {
                                            _isDraggingScrubber = true;
                                            _dragSliderValue = val;
                                          });
                                        },
                                        onChanged: (val) {
                                          setState(() {
                                            _dragSliderValue = val;
                                          });
                                        },
                                        onChangeEnd: (val) {
                                          final newPos = Duration(milliseconds: val.toInt());
                                          _player.seek(newPos);
                                          setState(() {
                                            _isDraggingScrubber = false;
                                            _position = newPos;
                                          });
                                          _startHideControlsTimer();
                                        },
                                      ),
                                    ),

                                    // Timestamp indicators
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _isDraggingScrubber
                                                ? _formatDuration(Duration(milliseconds: _dragSliderValue.toInt()))
                                                : _formatDuration(_position),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _formatDuration(_duration),
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.7),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // ── BOTTOM ACTION DOCK ──
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // 1. Aspect Ratio Icon Button
                                          Material(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Tooltip(
                                              message: _aspectRatioLabel,
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(10),
                                                onTap: _cycleAspectRatio,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(9.0),
                                                  child: Icon(_aspectRatioIcon, color: Colors.white, size: 18),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // 2. Rotate Screen Icon Button
                                          Material(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(10),
                                              onTap: _toggleOrientation,
                                              child: Padding(
                                                padding: const EdgeInsets.all(9.0),
                                                child: Icon(
                                                  _isLandscape ? LucideIcons.smartphone : LucideIcons.rotateCcw,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // 3. Visual Clarity / AI Enhance Button
                                          Material(
                                            color: _isEnhanced
                                                ? palette.primary.withValues(alpha: 0.35)
                                                : Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            child: Tooltip(
                                              message: _isEnhanced ? 'Visual Enhance (Vivid HDR): ON' : 'Visual Enhance: OFF',
                                              child: InkWell(
                                                borderRadius: BorderRadius.circular(10),
                                                onTap: _toggleVideoEnhance,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(9.0),
                                                  child: Icon(
                                                    LucideIcons.sparkles,
                                                    color: _isEnhanced ? palette.primary : Colors.white,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // 4. Playback Speed Icon Button (Opens Transparent Right Drawer)
                                          Material(
                                            color: _isSpeedDrawerOpen
                                                ? palette.primary.withValues(alpha: 0.35)
                                                : Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(10),
                                              onTap: _toggleSpeedDrawer,
                                              child: Padding(
                                                padding: const EdgeInsets.all(9.0),
                                                child: Icon(
                                                  LucideIcons.gauge,
                                                  color: _isSpeedDrawerOpen ? palette.primary : Colors.white,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 7. Transparent Speed Side Drawer & Blocking Barrier (Terminates on outside tap)
                  _buildSpeedDrawerOverlay(palette),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFloatingHudOverlay(AppPalette palette) {
    if (_activeGesture == _GestureType.none) {
      return const SizedBox.shrink();
    }

    IconData icon;
    String label;
    double progress = 0.0;

    switch (_activeGesture) {
      case _GestureType.brightness:
        icon = _currentBrightness > 0.6
            ? LucideIcons.sun
            : (_currentBrightness > 0.2 ? LucideIcons.sunMedium : LucideIcons.moon);
        final percent = (_currentBrightness * 100).toInt();
        label = '$percent%';
        progress = _currentBrightness;
        break;

      case _GestureType.volume:
        icon = _currentVolume == 0
            ? LucideIcons.volumeX
            : (_currentVolume > 0.5 ? LucideIcons.volume2 : LucideIcons.volume1);
        final percent = (_currentVolume * 100).toInt();
        label = '$percent%';
        progress = _currentVolume;
        break;

      case _GestureType.seek:
        final isForward = _seekDeltaSeconds >= 0;
        icon = isForward ? LucideIcons.fastForward : LucideIcons.rewind;
        final sign = isForward ? '+' : '';
        label = '$sign${_seekDeltaSeconds}s (${_formatDuration(_seekTargetPosition)})';
        break;

      default:
        return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
            if (_activeGesture == _GestureType.brightness || _activeGesture == _GestureType.volume) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleTapIndicators() {
    return Stack(
      children: [
        // Left Double Tap (-10s)
        if (_showDoubleTapLeft)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 140,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white24, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.rewind, color: Colors.white, size: 36),
                    SizedBox(height: 6),
                    Text(
                      '-10 sec',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Right Double Tap (+10s)
        if (_showDoubleTapRight)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 140,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.white24],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.fastForward, color: Colors.white, size: 36),
                    SizedBox(height: 6),
                    Text(
                      '+10 sec',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLockToggleButton(AppPalette palette) {
    // Only visible when controls are visible OR when screen is currently locked
    final shouldShow = _showControls || _isScreenLocked;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      left: shouldShow ? 16 : -60,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: shouldShow ? 1.0 : 0.0,
          child: Material(
            color: _isScreenLocked ? palette.primary : Colors.black45,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _toggleScreenLock,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  _isScreenLocked ? LucideIcons.lock : LucideIcons.unlock,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedDrawerOverlay(AppPalette palette) {
    if (!_isSpeedDrawerOpen) return const SizedBox.shrink();

    final presetRow1 = [0.25, 0.5, 1.0, 1.25];
    final presetRow2 = [1.5, 2.0, 4.0, 8.0];

    return Stack(
      children: [
        // 1. Outside Blocking Backdrop Barrier:
        // Absorbs touches so underlying controls won't be triggered, and terminates drawer on click
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeSpeedDrawer,
            child: Container(
              color: Colors.black.withValues(alpha: 0.40),
            ),
          ),
        ),

        // 2. Right-Hand Transparent Side Drawer (Matching Exact Device Screenshot)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width * 0.48
              : 320,
          child: GestureDetector(
            // Prevent taps inside drawer from propagating to the outside dismiss barrier
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                border: const Border(
                  left: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: [← Back Arrow] Speed
                      Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: _closeSpeedDrawer,
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Speed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Large Speed Readout: 1.00x, 0.95x, 0.96x
                      Center(
                        child: Text(
                          '${_playbackSpeed.toStringAsFixed(2)}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Continuous Precision Slider
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3.0,
                          activeTrackColor: palette.primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                          overlayColor: palette.primary.withValues(alpha: 0.2),
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8.0,
                            elevation: 2.0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                        ),
                        child: Slider(
                          value: _playbackSpeed.clamp(0.25, 8.0),
                          min: 0.25,
                          max: 8.0,
                          onChanged: (val) {
                            // Round to 2 decimal places for continuous micro-precision (.95x, .96x)
                            final microRate = (val * 100).round() / 100;
                            _player.setRate(microRate);
                            setState(() => _playbackSpeed = microRate);
                            _saveSpeedPreferences(
                              speed: microRate,
                              remember: _rememberSpeed,
                            );
                          },
                        ),
                      ),

                      // Slider Boundary Labels: 0.25 & 8.0
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '0.25',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            Text(
                              '8.0',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Preset Pills Row 1: [0.25x] [0.5x] [1x] [1.25x]
                      Row(
                        children: presetRow1.map((rate) {
                          final isSelected = (_playbackSpeed - rate).abs() < 0.01;
                          final label = rate == 1.0 ? '1x' : '${rate}x';
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Material(
                                color: isSelected ? palette.primary : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    _player.setRate(rate);
                                    setState(() => _playbackSpeed = rate);
                                    _saveSpeedPreferences(
                                      speed: rate,
                                      remember: _rememberSpeed,
                                    );
                                  },
                                  child: Container(
                                    height: 38,
                                    alignment: Alignment.center,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Preset Pills Row 2: [1.5x] [2x] [4x] [8x]
                      Row(
                        children: presetRow2.map((rate) {
                          final isSelected = (_playbackSpeed - rate).abs() < 0.01;
                          final label = (rate == 2.0 || rate == 4.0 || rate == 8.0)
                              ? '${rate.toInt()}x'
                              : '${rate}x';
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: Material(
                                color: isSelected ? palette.primary : Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    _player.setRate(rate);
                                    setState(() => _playbackSpeed = rate);
                                    _saveSpeedPreferences(
                                      speed: rate,
                                      remember: _rememberSpeed,
                                    );
                                  },
                                  child: Container(
                                    height: 38,
                                    alignment: Alignment.center,
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Spacer(),

                      // Advanced Settings Row (Remember Speed Toggle)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Remember Speed',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Apply across all videos',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: _rememberSpeed,
                                activeThumbColor: palette.primary,
                                activeTrackColor: palette.primary.withValues(alpha: 0.4),
                                inactiveThumbColor: Colors.white60,
                                inactiveTrackColor: Colors.white12,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  setState(() => _rememberSpeed = val);
                                  _saveSpeedPreferences(
                                    speed: _playbackSpeed,
                                    remember: val,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
