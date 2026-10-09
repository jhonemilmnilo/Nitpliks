import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../data/services/playback_database_service.dart';
import '../../../domain/models/media_models.dart';
import '../providers/video_enhancer_provider.dart';

/// State of the playback lifecycle
enum PlaybackStateStatus {
  initial,
  loadingRecord,
  seeking,
  ready,
  error,
}

/// Comprehensive, bulletproof playback controller
/// Isolates native MediaKit lifecycle and guarantees 100% reliable position persistence
class PlayerPlaybackController extends ChangeNotifier {
  /// Netflix/Prime-style resume recap helper:
  /// Rewinds 10 seconds on resume for context unless the video is near the beginning.
  static int calculateRewindResumeMs(int savedPositionMs, {int rewindSeconds = 10}) {
    if (savedPositionMs <= 5000) {
      return 0; // Less than 5s: start from scratch
    }
    final rewindMs = rewindSeconds * 1000;
    if (savedPositionMs <= rewindMs) {
      return 0; // Between 5s and 10s: clamp to start
    }
    return savedPositionMs - rewindMs;
  }

  final List<VideoModel> videos;
  int currentIndex;

  late final Player player;
  late final VideoController videoController;

  PlaybackStateStatus status = PlaybackStateStatus.initial;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double playbackSpeed = 1.0;
  VideoEnhanceMode enhanceMode = VideoEnhanceMode.off;
  Tracks tracks = const Tracks();
  Track selectedTrack = const Track();

  // Track the most reliable position even if streams are momentarily desynced
  int _targetResumeMs = 0;
  int _lastKnownValidPosMs = 0;
  int _lastAutosaveMs = 0;
  bool _isDisposed = false;
  bool _isExiting = false;

  // Stream Subscriptions
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<double>? _rateSub;
  StreamSubscription<Tracks>? _tracksSub;
  StreamSubscription<Track>? _trackSub;

  VideoModel get currentVideo => videos[currentIndex];
  bool get hasPrevious => currentIndex > 0;
  bool get hasNext => currentIndex < videos.length - 1;

  PlayerPlaybackController({
    required this.videos,
    required this.currentIndex,
    int initialPositionMs = 0,
    double initialSpeed = 1.0,
    VideoEnhanceMode initialEnhanceMode = VideoEnhanceMode.off,
  }) {
    playbackSpeed = initialSpeed;
    enhanceMode = initialEnhanceMode;
    if (initialPositionMs >= 2000) {
      _targetResumeMs = initialPositionMs;
      _lastKnownValidPosMs = initialPositionMs;
      position = Duration(milliseconds: initialPositionMs);
      debugPrint('⚡ [CONTROLLER CREATED] Synchronously initialized at resume point: $initialPositionMs ms');
    }

    // 1. Initialize Player with 32MB stream buffer
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );

    // 2. Hardware Acceleration Controller
    videoController = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _bindStreamListeners();
  }

  void _bindStreamListeners() {
    // Playing state stream
    _playingSub = player.stream.playing.listen((playing) {
      if (_isDisposed) return;
      isPlaying = playing;
      notifyListeners();
    });

    // Rate stream
    _rateSub = player.stream.rate.listen((r) {
      if (_isDisposed) return;
      if (r > 0 && r != playbackSpeed) {
        playbackSpeed = r;
        notifyListeners();
      }
    });

    // Duration stream
    _durationSub = player.stream.duration.listen((dur) {
      if (_isDisposed) return;
      if (dur > Duration.zero) {
        duration = dur;
        notifyListeners();
      }
    });

    // Realtime Position stream - Single Source of Truth from native player
    _positionSub = player.stream.position.listen((pos) {
      if (_isDisposed) return;

      final posMs = pos.inMilliseconds;

      // During seeking/loading, do NOT accept 0ms startup ticks as valid position
      if (status != PlaybackStateStatus.ready) {
        return;
      }

      if (posMs > 0) {
        _lastKnownValidPosMs = posMs;
      }

      position = pos;
      notifyListeners();

      // Throttled autosave every 3 seconds during ACTIVE, READY playback only
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastAutosaveMs > 3000 && posMs >= 1000) {
        _lastAutosaveMs = now;
        _saveToDatabase(positionMs: posMs);
      }
    });

    // Video completed stream
    _completedSub = player.stream.completed.listen((completed) {
      if (_isDisposed) return;
      if (completed) {
        // Prevent spurious completion signals when video duration is 0 or still loading
        final totalMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : player.state.duration.inMilliseconds;
        final currentMs = getCurrentAccuratePositionMs();
        debugPrint('🎬 [PLAYBACK COMPLETED STREAM] received: $completed (current: $currentMs ms, duration: $totalMs ms)');
        
        if (totalMs > 3000 && currentMs >= (totalMs * 0.90)) {
          debugPrint('🎬 [PLAYBACK FINISHED] Video reached real end. Marking completed.');
          _saveToDatabase(positionMs: 0, reset: true);
          if (hasNext) {
            playNext();
          }
        } else {
          debugPrint('⚠️ [PLAYBACK COMPLETED IGNORED] Spurious completed signal during load/seek.');
        }
      }
    });

    // Tracks stream (subtitles, audio, video tracks)
    _tracksSub = player.stream.tracks.listen((t) {
      if (_isDisposed) return;
      tracks = t;
      notifyListeners();
    });

    // Active track stream
    _trackSub = player.stream.track.listen((t) {
      if (_isDisposed) return;
      selectedTrack = t;
      notifyListeners();
    });
  }

  /// Load and start the current video, cleanly resuming at the target position
  Future<void> initAndPlay() async {
    status = PlaybackStateStatus.loadingRecord;
    notifyListeners();

    try {
      int targetResumeMs = _targetResumeMs;

      // 1. Fetch saved record from SQLite if not already pre-seeded
      if (targetResumeMs == 0) {
        debugPrint('🎬 [PLAYBACK INIT] Checking DB record for path: ${currentVideo.path} (id: ${currentVideo.id})');
        final record = await PlaybackDatabaseService.instance.getPlaybackRecord(
          videoPath: currentVideo.path,
          videoId: currentVideo.id,
        );

        final savedPosMs = record?.lastPositionMs ?? 0;
        final isCompleted = record?.isCompleted ?? false;
        targetResumeMs = (!isCompleted) ? calculateRewindResumeMs(savedPosMs) : 0;

        _targetResumeMs = targetResumeMs;
        _lastKnownValidPosMs = targetResumeMs;
        if (targetResumeMs > 0) {
          position = Duration(milliseconds: targetResumeMs);
        } else {
          position = Duration.zero;
        }

        debugPrint('🎬 [PLAYBACK INIT] Record found: pos=$savedPosMs ms, isCompleted=$isCompleted -> targetResume=$targetResumeMs ms');
      } else {
        debugPrint('⚡ [PLAYBACK INIT] Fast-lane resume using pre-seeded position: $targetResumeMs ms');
      }

      status = PlaybackStateStatus.seeking;
      notifyListeners();

      if (targetResumeMs > 0) {
        final startOffset = Duration(milliseconds: targetResumeMs);
        debugPrint('🎬 [PLAYBACK INIT ACTIVE] Opening media for live pipeline seek at: $startOffset');

        // Step 1: Open video with playback active so MediaCodec pipelines are initialized
        await player.open(
          Media(currentVideo.path),
          play: true,
        );

        // Step 2: Wait until the hardware decoder is actively streaming packets (> 0ms)
        try {
          await player.stream.position
              .firstWhere((p) => p.inMilliseconds > 0)
              .timeout(const Duration(milliseconds: 2500));
          debugPrint('🎬 [PLAYBACK INIT ACTIVE] Decoder confirmed active. Performing instant seek...');
        } catch (_) {
          debugPrint('⚠️ [PLAYBACK INIT ACTIVE] Stream position wait timed out. Forcing seek.');
        }

        // Step 3: Seek on the active, decoding pipeline
        await player.seek(startOffset);

        // Step 4: Wait until the hardware position actually arrives at the resume window
        try {
          final arrivalThresholdMs = (targetResumeMs - 3000).clamp(0, targetResumeMs);
          await player.stream.position
              .firstWhere((p) => p.inMilliseconds >= arrivalThresholdMs)
              .timeout(const Duration(milliseconds: 2000));
          debugPrint('🎯 [PLAYBACK INIT ACTIVE] Native position confirmed arrived at resume point!');
        } catch (_) {
          debugPrint('⚠️ [PLAYBACK INIT ACTIVE] Arrival wait settled.');
        }
      } else {
        await player.open(Media(currentVideo.path), play: true);
      }

      // Update duration
      if (player.state.duration > Duration.zero) {
        duration = player.state.duration;
      } else if (currentVideo.duration > Duration.zero) {
        duration = currentVideo.duration;
      }

      // Sync position to the real player position
      if (player.state.position > Duration.zero) {
        position = player.state.position;
        _lastKnownValidPosMs = player.state.position.inMilliseconds;
      }

      // Apply persisted playback speed if customized
      if (playbackSpeed != 1.0) {
        await player.setRate(playbackSpeed);
      }

      // Apply persisted video enhancement mode
      if (enhanceMode != VideoEnhanceMode.off) {
        await applyVideoEnhancement(enhanceMode);
      }

      // Step 5: Only NOW mark status as ready to lift the black curtain
      status = PlaybackStateStatus.ready;
      isPlaying = player.state.playing;
      notifyListeners();
    } catch (e) {
      debugPrint('🚨 [PLAYBACK INIT ERROR] $e');
      status = PlaybackStateStatus.ready;
      await player.play();
      notifyListeners();
    }
  }

  /// Apply hardware-accelerated video enhancement profile (libmpv native filters)
  Future<void> applyVideoEnhancement(VideoEnhanceMode mode) async {
    enhanceMode = mode;
    notifyListeners();

    try {
      final nativePlayer = player.platform;
      // Access direct native mpv properties safely without breaking playback
      if (nativePlayer is NativePlayer) {
        switch (mode) {
          case VideoEnhanceMode.off:
            // Reset to pure natural hardware decoding
            await nativePlayer.setProperty('contrast', '0');
            await nativePlayer.setProperty('brightness', '0');
            await nativePlayer.setProperty('saturation', '0');
            await nativePlayer.setProperty('gamma', '0');
            await nativePlayer.setProperty('sharpen', '0');
            break;
          case VideoEnhanceMode.cinema:
            // Cinema Mode: Rich contrast, cinematic warmth, deep true blacks
            await nativePlayer.setProperty('contrast', '6');
            await nativePlayer.setProperty('brightness', '-2');
            await nativePlayer.setProperty('saturation', '8');
            await nativePlayer.setProperty('gamma', '-3');
            await nativePlayer.setProperty('sharpen', '0');
            break;
          case VideoEnhanceMode.vivid:
            // Vivid / Anime Mode: Punchy vibrance & crisp animated lines
            await nativePlayer.setProperty('contrast', '10');
            await nativePlayer.setProperty('brightness', '0');
            await nativePlayer.setProperty('saturation', '22');
            await nativePlayer.setProperty('gamma', '0');
            await nativePlayer.setProperty('sharpen', '1.0');
            break;
          case VideoEnhanceMode.superCrisp:
            // Super Crisp: Maximum edge definition & high clarity
            await nativePlayer.setProperty('contrast', '8');
            await nativePlayer.setProperty('brightness', '0');
            await nativePlayer.setProperty('saturation', '10');
            await nativePlayer.setProperty('gamma', '0');
            await nativePlayer.setProperty('sharpen', '2.0');
            break;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ENHANCER NOTICE] Filter application gracefully skipped: $e');
    }
  }

  /// Change playback speed in real-time
  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed = speed;
    notifyListeners();
    await player.setRate(speed);
  }

  /// Toggle Play / Pause with instant save on pause
  void togglePlayPause() {
    if (isPlaying) {
      player.pause();
      final currentMs = getCurrentAccuratePositionMs();
      _saveToDatabase(positionMs: currentMs);
    } else {
      player.play();
    }
  }

  /// Seek by relative delta seconds (e.g. +10s or -10s)
  Future<void> seekRelativeSeconds(int seconds) async {
    final currentMs = getCurrentAccuratePositionMs();
    final maxMs = duration.inMilliseconds;
    final targetMs = (currentMs + (seconds * 1000)).clamp(0, maxMs);
    final targetPos = Duration(milliseconds: targetMs);

    _targetResumeMs = targetMs;
    position = targetPos;
    _lastKnownValidPosMs = targetMs;
    notifyListeners();

    await player.seek(targetPos);
    _saveToDatabase(positionMs: targetMs);
  }

  /// Seek to absolute position (e.g. from scrubber drag)
  Future<void> seekTo(Duration target) async {
    _targetResumeMs = target.inMilliseconds;
    position = target;
    _lastKnownValidPosMs = target.inMilliseconds;
    notifyListeners();

    await player.seek(target);
    _saveToDatabase(positionMs: target.inMilliseconds);
  }

  /// Play next video in queue
  Future<void> playNext() async {
    if (!hasNext) return;
    await saveCurrentStateImmediate();
    currentIndex++;
    position = Duration.zero;
    _lastKnownValidPosMs = 0;
    notifyListeners();
    await initAndPlay();
  }

  /// Play previous video in queue
  Future<void> playPrevious() async {
    if (!hasPrevious) return;
    await saveCurrentStateImmediate();
    currentIndex--;
    position = Duration.zero;
    _lastKnownValidPosMs = 0;
    notifyListeners();
    await initAndPlay();
  }

  /// Get the single most accurate current millisecond timestamp
  int getCurrentAccuratePositionMs() {
    final nativeMs = player.state.position.inMilliseconds;
    if (nativeMs > 0) return nativeMs;
    if (position.inMilliseconds > 0) return position.inMilliseconds;
    return _lastKnownValidPosMs;
  }

  /// Internal save helper
  Future<void> _saveToDatabase({required int positionMs, bool reset = false}) async {
    if (_isDisposed) return;
    final durMs = duration.inMilliseconds > 0 ? duration.inMilliseconds : player.state.duration.inMilliseconds;

    await PlaybackDatabaseService.instance.savePlaybackState(
      video: currentVideo,
      positionMs: positionMs,
      durationMs: durMs,
      reset: reset,
    );
  }

  /// Immediate save execution (Used when app goes to background or user navigates back)
  Future<void> saveCurrentStateImmediate() async {
    final posMs = getCurrentAccuratePositionMs();
    if (posMs > 0) {
      debugPrint('🎬 [PLAYBACK SAVE IMMEDIATE] "${currentVideo.title}" saving: $posMs ms');
      await _saveToDatabase(positionMs: posMs);
    }
  }

  /// Prepare for screen exit: Guaranteed save handshake before disposing
  Future<void> prepareExit() async {
    if (_isExiting) return;
    _isExiting = true;
    try {
      // 1. Capture exact position FIRST before pausing
      final posMs = getCurrentAccuratePositionMs();
      debugPrint('🎬 [PLAYBACK EXIT HANDSHAKE] Persisting exact position before pause: $posMs ms');
      
      // 2. Pause immediately to prevent time drift
      await player.pause();

      // 3. Guarantee write to SQLite
      await _saveToDatabase(positionMs: posMs);
    } catch (e) {
      debugPrint('🚨 [PLAYBACK EXIT ERROR] $e');
    }
  }

  /// Select subtitle track or turn off (SubtitleTrack.no())
  Future<void> setSubtitleTrack(SubtitleTrack subtitleTrack) async {
    await player.setSubtitleTrack(subtitleTrack);
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _rateSub?.cancel();
    _tracksSub?.cancel();
    _trackSub?.cancel();
    player.dispose();
    super.dispose();
  }
}
