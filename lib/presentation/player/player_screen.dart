import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
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
  late final StreamSubscription<bool> _bufferingSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  late final StreamSubscription<bool> _completedSub;

  // Playback States
  bool _isPlaying = true;
  bool _isBuffering = false;
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
  bool _isScreenLocked = false;
  bool _isSpeedDrawerOpen = false;
  bool _isLandscape = false;

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

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
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

    // 6. Open video & start auto-hide controls timer
    _openCurrentVideo();
    _startHideControlsTimer();
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
    _bufferingSub.cancel();
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
                  // 1. Hardware Video Canvas with Dynamic Aspect Ratio Fit
                  Center(
                    child: Video(
                      controller: _controller,
                      controls: NoVideoControls,
                      fit: _aspectRatio,
                    ),
                  ),

                  // 2. Buffering Spinner
                  if (_isBuffering)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: CircularProgressIndicator(
                          color: palette.primary,
                          strokeWidth: 3,
                        ),
                      ),
                    ),

                  // 3. Floating HUD Overlays (Volume, Brightness, Seek)
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
                                    const SizedBox(width: 8),

                                    // Aspect Ratio Toggle Pill
                                    Material(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _cycleAspectRatio,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(_aspectRatioIcon, color: Colors.white, size: 16),
                                              const SizedBox(width: 5),
                                              Text(
                                                _aspectRatioLabel,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Rotate Screen Pill
                                    Material(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _toggleOrientation,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _isLandscape ? LucideIcons.smartphone : LucideIcons.rotateCcw,
                                                color: Colors.white,
                                                size: 15,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _isLandscape ? 'Portrait' : 'Rotate',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Playback Speed Pill (Opens Transparent Right Drawer)
                                    Material(
                                      color: _isSpeedDrawerOpen ? palette.primary.withValues(alpha: 0.3) : Colors.black45,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _toggleSpeedDrawer,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(LucideIcons.gauge, color: palette.primary, size: 15),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_playbackSpeed}x',
                                                style: TextStyle(
                                                  color: palette.primary,
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
                                ),
                              ),
                            ),
                          ),

                          // ──────────────────────────────────────────────
                          // CENTER CONTROLS: Previous, Play / Pause, Next
                          // ──────────────────────────────────────────────
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Previous Video Button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: _hasPrevious ? _playPrevious : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        LucideIcons.skipBack,
                                        color: _hasPrevious ? Colors.white : Colors.white24,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),

                                // Main Play / Pause Button
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
                                      padding: const EdgeInsets.all(20),
                                      child: Icon(
                                        _isPlaying ? LucideIcons.pause : LucideIcons.play,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),

                                // Next Video Button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: _hasNext ? _playNext : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        LucideIcons.skipForward,
                                        color: _hasNext ? Colors.white : Colors.white24,
                                        size: 28,
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

    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return Stack(
      children: [
        // 1. Outside Blocking Backdrop Barrier:
        // Absorbs touches so underlying controls won't be triggered, and terminates drawer on click
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeSpeedDrawer,
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),

        // 2. Right-Hand Transparent Glassmorphic Side Drawer
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 220,
          child: GestureDetector(
            // Prevent taps inside drawer from propagating to the outside dismiss barrier
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: palette.isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                    : const Color(0xFF1E293B).withValues(alpha: 0.90),
                border: const Border(
                  left: BorderSide(color: Colors.white12, width: 1),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.gauge, color: palette.primary, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Speed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _closeSpeedDrawer,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white12, height: 1),
                      const SizedBox(height: 8),

                      // Speed Items List
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: speeds.map((sp) {
                            final isSelected = _playbackSpeed == sp;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? palette.primary.withValues(alpha: 0.22)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(color: palette.primary.withValues(alpha: 0.5))
                                    : null,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    _player.setRate(sp);
                                    setState(() {
                                      _playbackSpeed = sp;
                                    });
                                    _closeSpeedDrawer();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${sp}x ${sp == 1.0 ? '(Normal)' : ''}',
                                          style: TextStyle(
                                            color: isSelected ? palette.primary : Colors.white,
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(LucideIcons.check, size: 16, color: palette.primary),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
