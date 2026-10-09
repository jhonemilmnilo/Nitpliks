import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme/palette_provider.dart';
import '../../domain/models/media_models.dart';
import 'controllers/player_playback_controller.dart';
import 'providers/playback_speed_provider.dart';
import 'providers/video_enhancer_provider.dart';
import 'widgets/playback_speed_drawer.dart';
import 'widgets/subtitle_drawer.dart';
import 'widgets/video_enhancer_drawer.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  final int initialPositionMs;

  const PlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.initialPositionMs = 0,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> with WidgetsBindingObserver {
  late final PlayerPlaybackController _controller;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  BoxFit _aspectRatio = BoxFit.contain;
  bool _isExiting = false;
  bool _isDraggingScrubber = false;
  double _dragSliderValue = 0.0;

  // Horizontal Swipe-to-Seek Gesture State
  bool _isSwipingToSeek = false;
  int _swipeStartPosMs = 0;
  int _swipeSeekTargetMs = 0;
  double _accumulatedSwipeDx = 0.0;

  // Screen Lock Mode State
  bool _isScreenLocked = false;
  bool _showUnlockButton = false;
  Timer? _unlockButtonTimer;

  // Interactive Subtitle Drag & Pinch-to-Resize State
  double _subtitleScale = 1.0;
  double _baseSubtitleScale = 1.0;
  Offset _subtitleOffset = Offset.zero;
  Offset _dragStartSubtitleOffset = Offset.zero;
  bool _isInteractingWithSubtitle = false;
  List<String> _frozenSubtitleText = const [];

  // Multi-Touch Pointer Tracking for Seamless Pinch Anywhere
  final Map<int, Offset> _activePointers = {};
  double? _initialPinchDistance;
  double _pinchStartSubtitleScale = 1.0;

  // Vertical Slide Gesture State (Left: Brightness, Right: Volume)
  bool _isAdjustingBrightness = false;
  bool _isAdjustingVolume = false;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  Timer? _hideBrightnessHudTimer;
  Timer? _hideVolumeHudTimer;

  @override
  void initState() {
    super.initState();
    // 1. Keep display awake
    WakelockPlus.enable();

    // 2. Immersive sticky full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);

    // 3. Initialize clean modular playback controller with synchronous resume point and persisted speed & enhancement
    final initialSpeed = ref.read(playbackSpeedProvider);
    final initialEnhanceMode = ref.read(videoEnhanceProvider);
    _controller = PlayerPlaybackController(
      videos: widget.videos,
      currentIndex: widget.initialIndex,
      initialPositionMs: widget.initialPositionMs,
      initialSpeed: initialSpeed,
      initialEnhanceMode: initialEnhanceMode,
    );

    // 4. Start playback & resume state machine after the Flutter widget tree has mounted the native Surface/Texture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.initAndPlay();
      }
    });

    // 5. Initialize device brightness and volume
    _initHardwareControls();

    // 6. Auto hide controls timer
    _startHideControlsTimer();
  }

  Future<void> _initHardwareControls() async {
    try {
      _currentBrightness = await ScreenBrightness().application;
    } catch (_) {
      try {
        _currentBrightness = await ScreenBrightness().system;
      } catch (_) {
        _currentBrightness = 0.5;
      }
    }
    try {
      _currentVolume = await VolumeController.instance.getVolume();
    } catch (_) {
      _currentVolume = 0.5;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      // Save position instantly when app is backgrounded or minimized
      _controller.saveCurrentStateImmediate();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_showControls) return;

    _hideControlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _controller.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_isScreenLocked) {
      _showUnlockButtonTemporarily();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _lockScreen() {
    _hideControlsTimer?.cancel();
    setState(() {
      _isScreenLocked = true;
      _showControls = false;
    });
    _showUnlockButtonTemporarily();
  }

  void _unlockScreen() {
    _unlockButtonTimer?.cancel();
    setState(() {
      _isScreenLocked = false;
      _showUnlockButton = false;
      _showControls = true;
    });
    _startHideControlsTimer();
  }

  void _showUnlockButtonTemporarily() {
    _unlockButtonTimer?.cancel();
    setState(() => _showUnlockButton = true);
    _unlockButtonTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isScreenLocked) {
        setState(() => _showUnlockButton = false);
      }
    });
  }

  void _cycleAspectRatio() {
    _startHideControlsTimer();
    setState(() {
      if (_aspectRatio == BoxFit.contain) {
        _aspectRatio = BoxFit.cover;
      } else if (_aspectRatio == BoxFit.cover) {
        _aspectRatio = BoxFit.fill;
      } else {
        _aspectRatio = BoxFit.contain;
      }
    });
  }

  void _toggleOrientation() {
    _startHideControlsTimer();
    final orientation = MediaQuery.of(context).orientation;
    if (orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  /// Open file picker strictly filtered to subtitle formats (.srt, .ass, .vtt, .ssa, .sub)
  Future<void> _pickSubtitleFile() async {
    _hideControlsTimer?.cancel();
    debugPrint('🎬 [OPEN FILE TRIGGERED] Opening native file picker for subtitles...');
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'ass', 'vtt', 'ssa', 'sub'],
      );

      debugPrint('🎬 [OPEN FILE RESULT] Picked files: ${files.length}');

      if (files.isNotEmpty) {
        final filePath = files.first.path;
        final fileName = files.first.name;
        if (filePath != null) {
          await _controller.loadExternalSubtitleFile(filePath, title: fileName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded subtitle: $fileName'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e, stack) {
      debugPrint('🚨 [PICK SUBTITLE ERROR] $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _startHideControlsTimer();
    }
  }

  // --- Edge Vertical Slide Gestures (Left: Brightness, Right: Volume) ---
  Future<void> _onVerticalDragStart(DragStartDetails details) async {
    if (_isScreenLocked || _isInteractingWithSubtitle || _activePointers.length > 1) return;
    _hideControlsTimer?.cancel();

    final screenWidth = MediaQuery.of(context).size.width;
    final touchX = details.globalPosition.dx;

    // Left 35% of the screen -> Brightness
    if (touchX < screenWidth * 0.35) {
      _hideBrightnessHudTimer?.cancel();
      try {
        _currentBrightness = await ScreenBrightness().application;
      } catch (_) {
        try {
          _currentBrightness = await ScreenBrightness().system;
        } catch (_) {}
      }
      setState(() {
        _isAdjustingBrightness = true;
        _isAdjustingVolume = false;
      });
    }
    // Right 35% of the screen -> Volume
    else if (touchX > screenWidth * 0.65) {
      _hideVolumeHudTimer?.cancel();
      try {
        _currentVolume = await VolumeController.instance.getVolume();
      } catch (_) {}
      setState(() {
        _isAdjustingVolume = true;
        _isAdjustingBrightness = false;
      });
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isScreenLocked || _isInteractingWithSubtitle || _activePointers.length > 1) return;

    final screenHeight = MediaQuery.of(context).size.height;
    // Moving up decreases dy (negative delta), so inverted
    final deltaFraction = -details.primaryDelta! / (screenHeight * 0.6);

    if (_isAdjustingBrightness) {
      final newBrightness = (_currentBrightness + deltaFraction).clamp(0.0, 1.0);
      _currentBrightness = newBrightness;
      ScreenBrightness().setApplicationScreenBrightness(newBrightness);
      setState(() {});
    } else if (_isAdjustingVolume) {
      final newVolume = (_currentVolume + deltaFraction).clamp(0.0, 1.0);
      _currentVolume = newVolume;
      VolumeController.instance.showSystemUI = false;
      VolumeController.instance.setVolume(newVolume);
      setState(() {});
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isAdjustingBrightness) {
      _hideBrightnessHudTimer?.cancel();
      _hideBrightnessHudTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _isAdjustingBrightness = false);
        }
      });
    }

    if (_isAdjustingVolume) {
      _hideVolumeHudTimer?.cancel();
      _hideVolumeHudTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          setState(() => _isAdjustingVolume = false);
        }
      });
    }

    _startHideControlsTimer();
  }

  // --- Horizontal Swipe to Seek Gestures ---
  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isScreenLocked ||
        _isInteractingWithSubtitle ||
        _isAdjustingBrightness ||
        _isAdjustingVolume ||
        _activePointers.length > 1) {
      return;
    }
    _hideControlsTimer?.cancel();
    final currentMs = _controller.getCurrentAccuratePositionMs();
    setState(() {
      _isSwipingToSeek = true;
      _swipeStartPosMs = currentMs;
      _swipeSeekTargetMs = currentMs;
      _accumulatedSwipeDx = 0.0;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isScreenLocked ||
        _isInteractingWithSubtitle ||
        _isAdjustingBrightness ||
        _isAdjustingVolume ||
        _activePointers.length > 1 ||
        !_isSwipingToSeek) {
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    _accumulatedSwipeDx += details.primaryDelta ?? 0.0;

    // Gesture Tuning: Swiping full width of screen seeks ~90 seconds (or scaled proportionally)
    final totalDurationMs = _controller.duration.inMilliseconds > 0 
        ? _controller.duration.inMilliseconds 
        : 60000;
    final swipeSensitivitySeconds = (totalDurationMs > 300000) ? 120.0 : 60.0;
    final deltaSeconds = (_accumulatedSwipeDx / (screenWidth * 0.75)) * swipeSensitivitySeconds;
    final deltaMs = (deltaSeconds * 1000).toInt();

    final newTargetMs = (_swipeStartPosMs + deltaMs).clamp(0, totalDurationMs);

    setState(() {
      _swipeSeekTargetMs = newTargetMs;
    });
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    if (!_isSwipingToSeek) return;

    final targetMs = _swipeSeekTargetMs;
    setState(() {
      _isSwipingToSeek = false;
    });

    _startHideControlsTimer();

    // Execute single crisp seek to target position
    await _controller.seekTo(Duration(milliseconds: targetMs));
  }

  /// Guaranteed Safe Exit Handshake:
  /// Awaits SQLite database write before popping the navigation stack!
  Future<void> _handleExit() async {
    if (_isExiting) return;
    _isExiting = true;
    _hideControlsTimer?.cancel();

    // 1. Flush exact playback position to SQLite disk
    await _controller.prepareExit();

    // 2. Safe navigation pop
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideControlsTimer?.cancel();
    _unlockButtonTimer?.cancel();
    _hideBrightnessHudTimer?.cancel();
    _hideVolumeHudTimer?.cancel();
    try {
      ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {}

    // Restore System UI & release wakelock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.disable();

    _controller.dispose();
    super.dispose();
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
    final palette = ref.watch(paletteProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isScreenLocked) {
            _showUnlockButtonTemporarily();
            return;
          }
          _handleExit();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final position = _controller.position;
            final duration = _controller.duration;
            final currentVideo = _controller.currentVideo;
            final isPlaying = _controller.isPlaying;
            final isLoading = _controller.status == PlaybackStateStatus.loadingRecord ||
                _controller.status == PlaybackStateStatus.seeking;

            final maxDurationMs = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
            final currentPosMs = position.inMilliseconds.toDouble().clamp(0.0, maxDurationMs);

            return Listener(
              onPointerDown: (event) {
                _activePointers[event.pointer] = event.position;
                if (_activePointers.length >= 2 && _isInteractingWithSubtitle) {
                  // Initialize multi-touch pinch distance
                  final points = _activePointers.values.toList();
                  _initialPinchDistance = (points[0] - points[1]).distance;
                  _pinchStartSubtitleScale = _subtitleScale;
                }
              },
              onPointerMove: (event) {
                _activePointers[event.pointer] = event.position;
                // If user is interacting with subtitle and has 2+ fingers anywhere on screen
                if (_isInteractingWithSubtitle && _activePointers.length >= 2) {
                  final points = _activePointers.values.toList();
                  final currentDistance = (points[0] - points[1]).distance;
                  if (_initialPinchDistance != null && _initialPinchDistance! > 10) {
                    final scaleFactor = currentDistance / _initialPinchDistance!;
                    setState(() {
                      _subtitleScale = (_pinchStartSubtitleScale * scaleFactor).clamp(0.7, 2.5);
                    });
                  } else {
                    _initialPinchDistance = currentDistance;
                    _pinchStartSubtitleScale = _subtitleScale;
                  }
                }
              },
              onPointerUp: (event) {
                _activePointers.remove(event.pointer);
                if (_activePointers.length < 2) {
                  _initialPinchDistance = null;
                }
              },
              onPointerCancel: (event) {
                _activePointers.remove(event.pointer);
                if (_activePointers.length < 2) {
                  _initialPinchDistance = null;
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                onHorizontalDragStart: _onHorizontalDragStart,
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                  // 1. Hardware Video Canvas
                  Center(
                    child: Video(
                      controller: _controller.videoController,
                      controls: NoVideoControls,
                      fit: _aspectRatio,
                      subtitleViewConfiguration: const SubtitleViewConfiguration(
                        visible: false,
                      ),
                    ),
                  ),

                  // 2. Seamless Black Curtain & Shimmer Spinner while preparing resume point
                  // Ensures user NEVER sees a single frame of 00:00 before resume point locks in
                  if (isLoading)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Resuming playback...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 3. Swipe-to-Seek Floating Minimalist HUD (Text & Icons only)
                  if (_isSwipingToSeek)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _swipeSeekTargetMs >= _swipeStartPosMs
                                    ? LucideIcons.fastForward
                                    : LucideIcons.rewind,
                                color: palette.primary,
                                size: 36,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 10),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_swipeSeekTargetMs >= _swipeStartPosMs ? "+" : ""}${((_swipeSeekTargetMs - _swipeStartPosMs) / 1000).toInt()}s',
                                style: TextStyle(
                                  color: palette.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  shadows: const [
                                    Shadow(color: Colors.black87, blurRadius: 10),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_formatDuration(Duration(milliseconds: _swipeSeekTargetMs))} / ${_formatDuration(duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 10),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 3.1 Brightness Minimalist HUD (Vertically Centered on Left Edge - Pure Icon & Text)
                  if (_isAdjustingBrightness)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentBrightness > 0.5
                                  ? LucideIcons.sun
                                  : LucideIcons.sunMedium,
                              color: Colors.white,
                              size: 40,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 10, offset: Offset(1, 1)),
                                Shadow(color: Colors.black87, blurRadius: 14),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_currentBrightness * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 10, offset: Offset(1, 1)),
                                  Shadow(color: Colors.black87, blurRadius: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3.2 Volume Minimalist HUD (Vertically Centered on Right Edge - Pure Icon & Text)
                  if (_isAdjustingVolume)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _currentVolume == 0
                                  ? LucideIcons.volumeX
                                  : (_currentVolume < 0.5 ? LucideIcons.volume1 : LucideIcons.volume2),
                              color: Colors.white,
                              size: 40,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 10, offset: Offset(1, 1)),
                                Shadow(color: Colors.black87, blurRadius: 14),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${(_currentVolume * 100).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 10, offset: Offset(1, 1)),
                                  Shadow(color: Colors.black87, blurRadius: 14),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 4. INTERACTIVE DRAGGABLE & PINCH-TO-RESIZE SUBTITLE OVERLAY
                  if (_controller.selectedTrack.subtitle != SubtitleTrack.no() &&
                      ((_isInteractingWithSubtitle && _frozenSubtitleText.isNotEmpty && _frozenSubtitleText.any((s) => s.trim().isNotEmpty)) ||
                       (!_isInteractingWithSubtitle && _controller.subtitleText.isNotEmpty && _controller.subtitleText.any((s) => s.trim().isNotEmpty))))
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: _isScreenLocked,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: _subtitleOffset,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 56, left: 24, right: 24),
                              child: Listener(
                                onPointerDown: (_) {
                                  setState(() {
                                    _isInteractingWithSubtitle = true;
                                    _frozenSubtitleText = List.from(_controller.subtitleText);
                                  });
                                },
                                onPointerUp: (_) {
                                  if (_activePointers.isEmpty) {
                                    setState(() {
                                      _isInteractingWithSubtitle = false;
                                    });
                                  }
                                },
                                onPointerCancel: (_) {
                                  if (_activePointers.isEmpty) {
                                    setState(() {
                                      _isInteractingWithSubtitle = false;
                                    });
                                  }
                                },
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onDoubleTap: () {
                                    // Double-tap to reset position and scale
                                    setState(() {
                                      _subtitleOffset = Offset.zero;
                                      _subtitleScale = 1.0;
                                    });
                                  },
                                  onScaleStart: (details) {
                                    setState(() {
                                      _isInteractingWithSubtitle = true;
                                      if (_frozenSubtitleText.isEmpty) {
                                        _frozenSubtitleText = List.from(_controller.subtitleText);
                                      }
                                    });
                                    _baseSubtitleScale = _subtitleScale;
                                    _dragStartSubtitleOffset = _subtitleOffset;
                                  },
                                  onScaleUpdate: (details) {
                                    setState(() {
                                      // Pinch scale (bounded between 0.7x and 2.5x)
                                      _subtitleScale = (_baseSubtitleScale * details.scale).clamp(0.7, 2.5);
                                      // Drag offset
                                      _subtitleOffset = _dragStartSubtitleOffset + details.focalPointDelta;
                                      _dragStartSubtitleOffset = _subtitleOffset;
                                    });
                                  },
                                  onScaleEnd: (details) {
                                    setState(() {
                                      _isInteractingWithSubtitle = false;
                                    });
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: (_isInteractingWithSubtitle ? _frozenSubtitleText : _controller.subtitleText)
                                          .where((line) => line.trim().isNotEmpty)
                                          .map(
                                            (line) => Text(
                                              line,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: (18 * _subtitleScale).clamp(12.0, 45.0),
                                                fontWeight: FontWeight.bold,
                                                height: 1.25,
                                                shadows: const [
                                                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                                                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(-1, -1)),
                                                  Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 0)),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 3. Clean Animated Controls Overlay
                  AnimatedOpacity(
                    opacity: _isScreenLocked
                        ? (_showUnlockButton ? 1.0 : 0.0)
                        : (_showControls ? 1.0 : 0.0),
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: _isScreenLocked ? !_showUnlockButton : !_showControls,
                      child: Stack(
                        children: [
                          // Top & Bottom Gradients (only when fully unlocked)
                          if (!_isScreenLocked) ...[
                            // Top Gradient
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 110,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black87, Colors.transparent],
                                  ),
                                ),
                              ),
                            ),

                            // Bottom Gradient
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

                            // TOP BAR
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
                                          borderRadius: BorderRadius.circular(24),
                                          onTap: _handleExit,
                                          child: const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Icon(LucideIcons.arrowLeft, color: Colors.white, size: 24),
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
                                              currentVideo.title,
                                              maxLines: MediaQuery.of(context).orientation == Orientation.portrait ? 2 : 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              currentVideo.formattedSize,
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
                          ],

                          // CENTER CONTROLS
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Other playback controls (hidden via Opacity when locked so the lock button NEVER shifts its position)
                                IgnorePointer(
                                  ignoring: _isScreenLocked,
                                  child: Opacity(
                                    opacity: _isScreenLocked ? 0.0 : 1.0,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Previous
                                        IconButton(
                                          iconSize: 22,
                                          icon: Icon(
                                            LucideIcons.skipBack,
                                            color: _controller.hasPrevious ? Colors.white : Colors.white24,
                                          ),
                                          onPressed: _controller.hasPrevious
                                              ? () {
                                                  _startHideControlsTimer();
                                                  _controller.playPrevious();
                                                }
                                              : null,
                                        ),
                                        const SizedBox(width: 14),

                                        // Seek -10s
                                        IconButton(
                                          iconSize: 26,
                                          icon: const Icon(LucideIcons.rotateCcw, color: Colors.white),
                                          onPressed: () {
                                            _startHideControlsTimer();
                                            _controller.seekRelativeSeconds(-10);
                                          },
                                        ),
                                        const SizedBox(width: 14),

                                        // Main Play / Pause
                                        Material(
                                          color: palette.primary,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: () {
                                              _startHideControlsTimer();
                                              _controller.togglePlayPause();
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Icon(
                                                isPlaying ? LucideIcons.pause : LucideIcons.play,
                                                color: Colors.white,
                                                size: 26,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Seek +10s
                                        IconButton(
                                          iconSize: 26,
                                          icon: const Icon(LucideIcons.rotateCw, color: Colors.white),
                                          onPressed: () {
                                            _startHideControlsTimer();
                                            _controller.seekRelativeSeconds(10);
                                          },
                                        ),
                                        const SizedBox(width: 14),

                                        // Next
                                        IconButton(
                                          iconSize: 22,
                                          icon: Icon(
                                            LucideIcons.skipForward,
                                            color: _controller.hasNext ? Colors.white : Colors.white24,
                                          ),
                                          onPressed: _controller.hasNext
                                              ? () {
                                                  _startHideControlsTimer();
                                                  _controller.playNext();
                                                }
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                    ),
                                  ),
                                ),

                                // Unified Lock / Unlock Button (Always stays exactly right beside next button!)
                                IconButton(
                                  iconSize: 22,
                                  icon: Icon(
                                    _isScreenLocked ? LucideIcons.lock : LucideIcons.unlock,
                                    color: _isScreenLocked ? palette.primary : Colors.white,
                                  ),
                                  tooltip: _isScreenLocked ? 'Unlock Screen' : 'Lock Screen',
                                  onPressed: _isScreenLocked ? _unlockScreen : _lockScreen,
                                ),
                              ],
                            ),
                          ),

                          // BOTTOM TIMELINE & SCRUBBER (Only when unlocked)
                          if (!_isScreenLocked)
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 4,
                                      activeTrackColor: palette.primary,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: palette.primary,
                                      overlayColor: palette.primary.withValues(alpha: 0.2),
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    ),
                                    child: Slider(
                                      value: _isSwipingToSeek
                                          ? _swipeSeekTargetMs.toDouble().clamp(0.0, maxDurationMs)
                                          : (_isDraggingScrubber ? _dragSliderValue : currentPosMs),
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
                                      onChangeEnd: (val) async {
                                        setState(() {
                                          _isDraggingScrubber = false;
                                        });
                                        _startHideControlsTimer();
                                        await _controller.seekTo(Duration(milliseconds: val.toInt()));
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(
                                            _isSwipingToSeek
                                                ? Duration(milliseconds: _swipeSeekTargetMs)
                                                : position,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // BOTTOM ACTIONS (Rotate, Fit / Aspect Ratio, Speed Drawer)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Screen Rotate Button (Pure Icon)
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: _toggleOrientation,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.white24,
                                                ),
                                              ),
                                              child: const Icon(
                                                LucideIcons.screenShare,
                                                size: 15,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Aspect Ratio / Fit Button
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: _cycleAspectRatio,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: _aspectRatio != BoxFit.contain
                                                      ? palette.primary
                                                      : Colors.white24,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    LucideIcons.scan,
                                                    size: 14,
                                                    color: _aspectRatio != BoxFit.contain
                                                        ? palette.primary
                                                        : Colors.white,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    _aspectRatio == BoxFit.contain
                                                        ? 'Fit'
                                                        : (_aspectRatio == BoxFit.cover ? 'Crop' : 'Stretch'),
                                                    style: TextStyle(
                                                      color: _aspectRatio != BoxFit.contain
                                                          ? palette.primary
                                                          : Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // SPEED ADJUSTMENT BUTTON
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              _hideControlsTimer?.cancel();
                                              PlaybackSpeedDrawer.show(
                                                context,
                                                currentSpeed: _controller.playbackSpeed,
                                                onSpeedSelected: (newSpeed) {
                                                  _controller.setPlaybackSpeed(newSpeed);
                                                  _startHideControlsTimer();
                                                },
                                              ).then((_) {
                                                _startHideControlsTimer();
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: _controller.playbackSpeed != 1.0
                                                      ? palette.primary
                                                      : Colors.white24,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    LucideIcons.gauge,
                                                    size: 14,
                                                    color: _controller.playbackSpeed != 1.0
                                                        ? palette.primary
                                                        : Colors.white,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    _controller.playbackSpeed == 1.0
                                                        ? '1.0x'
                                                        : '${_controller.playbackSpeed}x',
                                                    style: TextStyle(
                                                      color: _controller.playbackSpeed != 1.0
                                                          ? palette.primary
                                                          : Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // VISUAL ENHANCER BUTTON (Quality booster)
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              _hideControlsTimer?.cancel();
                                              VideoEnhancerDrawer.show(
                                                context,
                                                currentMode: _controller.enhanceMode,
                                                onModeSelected: (newMode) {
                                                  _controller.applyVideoEnhancement(newMode);
                                                  _startHideControlsTimer();
                                                },
                                              ).then((_) {
                                                _startHideControlsTimer();
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: _controller.enhanceMode != VideoEnhanceMode.off
                                                      ? palette.primary
                                                      : Colors.white24,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    LucideIcons.sparkles,
                                                    size: 14,
                                                    color: _controller.enhanceMode != VideoEnhanceMode.off
                                                        ? palette.primary
                                                        : Colors.white,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    _controller.enhanceMode.label,
                                                    style: TextStyle(
                                                      color: _controller.enhanceMode != VideoEnhanceMode.off
                                                          ? palette.primary
                                                          : Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.3,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // SUBTITLE BUTTON (Captions & tracks drawer)
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              _hideControlsTimer?.cancel();
                                              SubtitleDrawer.show(
                                                context,
                                                tracks: _controller.tracks,
                                                selectedTrack: _controller.selectedTrack,
                                                onTrackSelected: (track) {
                                                  _controller.setSubtitleTrack(track);
                                                  _startHideControlsTimer();
                                                },
                                                onOpenFile: _pickSubtitleFile,
                                              ).then((_) {
                                                _startHideControlsTimer();
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: _controller.selectedTrack.subtitle != SubtitleTrack.no()
                                                      ? palette.primary
                                                      : Colors.white24,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    LucideIcons.subtitles,
                                                    size: 14,
                                                    color: _controller.selectedTrack.subtitle != SubtitleTrack.no()
                                                        ? palette.primary
                                                        : Colors.white,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    _controller.selectedTrack.subtitle != SubtitleTrack.no()
                                                        ? 'CC'
                                                        : 'Off',
                                                    style: TextStyle(
                                                      color: _controller.selectedTrack.subtitle != SubtitleTrack.no()
                                                          ? palette.primary
                                                          : Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.3,
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
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
}
