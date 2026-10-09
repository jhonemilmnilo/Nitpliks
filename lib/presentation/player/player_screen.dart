import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme/palette_provider.dart';
import '../../domain/models/media_models.dart';
import 'controllers/player_playback_controller.dart';
import 'providers/playback_speed_provider.dart';
import 'widgets/playback_speed_drawer.dart';

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

  @override
  void initState() {
    super.initState();
    // 1. Keep display awake
    WakelockPlus.enable();

    // 2. Immersive sticky full screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);

    // 3. Initialize clean modular playback controller with synchronous resume point and persisted speed
    final initialSpeed = ref.read(playbackSpeedProvider);
    _controller = PlayerPlaybackController(
      videos: widget.videos,
      currentIndex: widget.initialIndex,
      initialPositionMs: widget.initialPositionMs,
      initialSpeed: initialSpeed,
    );

    // 4. Start playback & resume state machine after the Flutter widget tree has mounted the native Surface/Texture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.initAndPlay();
      }
    });

    // 5. Auto hide controls timer
    _startHideControlsTimer();
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

  // --- Horizontal Swipe to Seek Gestures ---
  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isScreenLocked) return;
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
    if (_isScreenLocked || !_isSwipingToSeek) return;

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

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Hardware Video Canvas
                  Center(
                    child: Video(
                      controller: _controller.videoController,
                      controls: NoVideoControls,
                      fit: _aspectRatio,
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
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
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
            );
          },
        ),
      ),
    );
  }
}
