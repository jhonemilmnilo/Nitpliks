import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../app/theme/palette_provider.dart';
import '../../domain/models/media_models.dart';

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

  VideoModel get _currentVideo => widget.videos[_currentIndex];

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

    // 4. Listen to real-time playback streams
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _positionSub = _player.stream.position.listen((pos) {
      if (mounted && !_isDraggingScrubber) {
        setState(() => _position = pos);
      }
    });

    _durationSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    // 5. Open video & start auto-hide controls timer
    _openCurrentVideo();
    _startHideControlsTimer();
  }

  Future<void> _openCurrentVideo() async {
    try {
      await _player.open(Media(_currentVideo.path));
    } catch (e) {
      debugPrint('Error opening video ${_currentVideo.path}: $e');
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (!_showControls) return;

    _hideControlsTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _isPlaying && !_isDraggingScrubber) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
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
  void dispose() {
    _hideControlsTimer?.cancel();
    _playingSub.cancel();
    _bufferingSub.cancel();
    _positionSub.cancel();
    _durationSub.cancel();

    // Restore System UI & release wakelock
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Hardware Video Canvas
              Center(
                child: Video(
                  controller: _controller,
                  controls: NoVideoControls,
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

              // 3. Animated Minimal Controls Overlay
              IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
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
                      // TOP BAR: Back Button + Title
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
                      // CENTER CONTROLS: Play / Pause Button
                      // ──────────────────────────────────────────────
                      Center(
                        child: Material(
                          color: Colors.black45,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              _player.playOrPause();
                              _startHideControlsTimer();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Icon(
                                _isPlaying ? LucideIcons.pause : LucideIcons.play,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
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
            ],
          ),
        ),
      ),
    );
  }
}
