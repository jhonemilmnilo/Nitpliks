/// Domain Entity: Video Item
class VideoModel {
  final String id;
  final String title;
  final String path;
  final Duration duration;
  final int sizeInBytes;
  final String parentFolder;
  final DateTime modifiedDate;
  final String? thumbnailPath;

  const VideoModel({
    required this.id,
    required this.title,
    required this.path,
    required this.duration,
    required this.sizeInBytes,
    required this.parentFolder,
    required this.modifiedDate,
    this.thumbnailPath,
  });

  /// Formatted duration string: HH:mm:ss or mm:ss
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formatted file size string (MB, GB)
  String get formattedSize {
    if (sizeInBytes >= 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Domain Entity: Folder containing multiple videos
class FolderModel {
  final String name;
  final String path;
  final List<VideoModel> videos;

  const FolderModel({
    required this.name,
    required this.path,
    required this.videos,
  });

  int get videoCount => videos.length;
}

/// Domain Entity: Recently played video with resume playback progress
class RecentPlayModel {
  final VideoModel video;
  final Duration lastPosition;
  final DateTime lastWatchedAt;

  const RecentPlayModel({
    required this.video,
    required this.lastPosition,
    required this.lastWatchedAt,
  });

  double get progressPercentage {
    if (video.duration.inMilliseconds == 0) return 0.0;
    return (lastPosition.inMilliseconds / video.duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String get remainingTimeFormatted {
    final remaining = video.duration - lastPosition;
    final minutes = remaining.inMinutes;
    if (minutes > 60) {
      return '${remaining.inHours}h ${remaining.inMinutes.remainder(60)}m left';
    }
    return '${minutes}m left';
  }
}
