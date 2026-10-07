import 'package:photo_manager/photo_manager.dart';

/// Domain Entity: Lightweight Folder representation for fast scrolling
class DeviceFolderModel {
  final String id;
  final String name;
  final int videoCount;
  final DateTime? lastModified;

  const DeviceFolderModel({
    required this.id,
    required this.name,
    required this.videoCount,
    this.lastModified,
  });

  String get formattedDate {
    if (lastModified == null) return '';
    final now = DateTime.now();
    final difference = now.difference(lastModified!);

    if (difference.inDays == 0) {
      final hours = lastModified!.hour.toString().padLeft(2, '0');
      final minutes = lastModified!.minute.toString().padLeft(2, '0');
      return 'Today $hours:$minutes';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastModified!.year}-${lastModified!.month.toString().padLeft(2, '0')}-${lastModified!.day.toString().padLeft(2, '0')}';
    }
  }
}

/// Domain Entity: Video Item loaded on-demand
class VideoModel {
  final String id;
  final String title;
  final String path;
  final Duration duration;
  final int sizeInBytes;
  final String parentFolder;
  final DateTime modifiedDate;
  final String? thumbnailPath;
  final AssetEntity? asset;

  const VideoModel({
    required this.id,
    required this.title,
    required this.path,
    required this.duration,
    required this.sizeInBytes,
    required this.parentFolder,
    required this.modifiedDate,
    this.thumbnailPath,
    this.asset,
  });

  VideoModel copyWith({
    String? id,
    String? title,
    String? path,
    Duration? duration,
    int? sizeInBytes,
    String? parentFolder,
    DateTime? modifiedDate,
    String? thumbnailPath,
    AssetEntity? asset,
  }) {
    return VideoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      parentFolder: parentFolder ?? this.parentFolder,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      asset: asset ?? this.asset,
    );
  }

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

/// Legacy/Convenience Folder Model with videos list
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
