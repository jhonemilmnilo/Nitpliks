import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/data/services/device_media_service.dart';
import 'package:video_player/domain/models/media_models.dart';

/// Provider for fast folder scanning on home screen
final deviceFoldersProvider = FutureProvider<DeviceMediaResult>((ref) async {
  return await DeviceMediaService.fetchFolders();
});

/// StateNotifier managing videos for a folder with in-memory targeted mutation (Zero reload flicker)
class FolderVideosNotifier extends StateNotifier<AsyncValue<List<VideoModel>>> {
  final String folderId;

  FolderVideosNotifier(this.folderId) : super(const AsyncValue.loading()) {
    loadVideos();
  }

  Future<void> loadVideos() async {
    try {
      final videos = await DeviceMediaService.fetchVideosInFolder(folderId);
      if (mounted) {
        state = AsyncValue.data(videos);
      }
    } catch (e, stack) {
      if (mounted) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> refresh() async {
    return loadVideos();
  }

  /// Surgically update a single video item without reloading the entire list
  void updateVideo({
    required String videoId,
    required String newTitle,
    required String newPath,
  }) {
    final currentList = state.value;
    if (currentList == null) return;

    final updated = currentList.map((video) {
      if (video.id == videoId) {
        return video.copyWith(
          title: newTitle,
          path: newPath,
        );
      }
      return video;
    }).toList();

    state = AsyncValue.data(updated);
  }

  /// Surgically remove a single video item without reloading the entire list
  void removeVideo(String videoId) {
    final currentList = state.value;
    if (currentList == null) return;

    final updated = currentList.where((video) => video.id != videoId).toList();
    state = AsyncValue.data(updated);
  }
}

/// Family provider for loading and mutating videos on-demand for a clicked folder
final folderVideosProvider = StateNotifierProvider.family<FolderVideosNotifier, AsyncValue<List<VideoModel>>, String>((ref, folderId) {
  return FolderVideosNotifier(folderId);
});

/// State provider to track folder ID currently undergoing rename/update for skeleton animation
final updatingFolderIdProvider = StateProvider<String?>((ref) => null);

/// State provider to track video ID currently undergoing rename/update for skeleton animation
final updatingVideoIdProvider = StateProvider<String?>((ref) => null);
