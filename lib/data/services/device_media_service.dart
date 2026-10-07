import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../domain/models/media_models.dart';

class DeviceMediaResult {
  final List<DeviceFolderModel> folders;
  final bool hasPermission;

  const DeviceMediaResult({
    required this.folders,
    required this.hasPermission,
  });
}

class DeviceMediaService {
  /// Request storage/media permissions using PhotoManager
  static Future<bool> requestPermission() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  /// Check current permission state
  static Future<bool> hasPermission() async {
    final PermissionState state = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.video,
          mediaLocation: false,
        ),
      ),
    );
    return state.isAuth || state.hasAccess;
  }

  /// Fast scan: fetches only folder headers and counts without touching video files
  static Future<DeviceMediaResult> fetchFolders() async {
    final permitted = await requestPermission();
    if (!permitted) {
      return const DeviceMediaResult(
        folders: [],
        hasPermission: false,
      );
    }

    try {
      // Query video albums (folders)
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: false,
      );

      final List<DeviceFolderModel> folderList = [];

      for (final album in albums) {
        // Skip virtual "Recent/All" album to avoid duplicate folder entries
        if (album.isAll) {
          continue;
        }

        final int count = await album.assetCountAsync;
        if (count > 0) {
          folderList.add(
            DeviceFolderModel(
              id: album.id,
              name: album.name,
              videoCount: count,
              lastModified: album.lastModified,
            ),
          );
        }
      }

      // Sort folders by video count (most populated first)
      folderList.sort((a, b) => b.videoCount.compareTo(a.videoCount));

      return DeviceMediaResult(
        folders: folderList,
        hasPermission: true,
      );
    } catch (e, stack) {
      debugPrint('Error fetching folders: $e\n$stack');
      return const DeviceMediaResult(
        folders: [],
        hasPermission: true,
      );
    }
  }

  /// On-Demand Fetch: Only invoked when a user taps into a specific folder!
  static Future<List<VideoModel>> fetchVideosInFolder(String folderId) async {
    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: false,
      );

      final album = albums.firstWhere(
        (a) => a.id == folderId,
        orElse: () => albums.first,
      );

      final int count = await album.assetCountAsync;
      if (count == 0) return [];

      final List<AssetEntity> assets = await album.getAssetListRange(
        start: 0,
        end: count,
      );

      final List<VideoModel> videos = [];

      for (final asset in assets) {
        final file = await asset.file;
        final path = file?.path ?? '';

        videos.add(
          VideoModel(
            id: asset.id,
            title: asset.title ?? 'Untitled Video',
            path: path,
            duration: Duration(seconds: asset.duration),
            sizeInBytes: file != null ? await file.length() : 0,
            parentFolder: album.name,
            modifiedDate: asset.createDateTime,
          ),
        );
      }

      // Sort videos by newest first
      videos.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
      return videos;
    } catch (e, stack) {
      debugPrint('Error loading videos for folder $folderId: $e\n$stack');
      return [];
    }
  }

  /// Delete all video assets in a folder using PhotoManager
  static Future<bool> deleteFolderVideos(String folderId) async {
    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: false,
      );

      final album = albums.firstWhere(
        (a) => a.id == folderId,
        orElse: () => albums.first,
      );

      final int count = await album.assetCountAsync;
      if (count == 0) return true;

      final List<AssetEntity> assets = await album.getAssetListRange(
        start: 0,
        end: count,
      );

      final List<String> assetIds = assets.map((a) => a.id).toList();
      final List<String> deleted = await PhotoManager.editor.deleteWithIds(assetIds);
      return deleted.isNotEmpty;
    } catch (e, stack) {
      debugPrint('Error deleting folder $folderId: $e\n$stack');
      return false;
    }
  }

  /// Result of rename operation
  static Future<RenameResult> renameFolder(String folderId, String newName) async {
    // 1. Sanitize input name
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return RenameResult.invalidName;
    }
    
    // Check for illegal file/folder characters in Android/Linux/Windows
    final illegalChars = RegExp(r'[\\/:*?"<>|]');
    if (illegalChars.hasMatch(trimmed)) {
      return RenameResult.invalidCharacters;
    }

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: false,
      );

      final album = albums.firstWhere(
        (a) => a.id == folderId,
        orElse: () => albums.first,
      );

      final List<AssetEntity> assets = await album.getAssetListRange(start: 0, end: 1);
      if (assets.isEmpty) {
        return RenameResult.emptyFolder;
      }

      final file = await assets.first.file;
      if (file == null) {
        return RenameResult.fileNotFound;
      }

      final currentDir = file.parent;
      final parentDir = currentDir.parent;
      final newDirPath = '${parentDir.path}${Platform.pathSeparator}$trimmed';

      if (currentDir.path.toLowerCase() == newDirPath.toLowerCase()) {
        return RenameResult.sameName;
      }

      final newDir = Directory(newDirPath);
      if (await newDir.exists()) {
        return RenameResult.alreadyExists;
      }

      // Perform directory rename on file system
      await currentDir.rename(newDirPath);

      // Invalidate PhotoManager cache so media scanner picks up the changes
      await PhotoManager.clearFileCache();
      
      return RenameResult.success;
    } on FileSystemException catch (e) {
      debugPrint('FileSystemException renaming folder: $e');
      return RenameResult.permissionDenied;
    } catch (e, stack) {
      debugPrint('Error renaming folder: $e\n$stack');
      return RenameResult.unknownError;
    }
  }
}

enum RenameResult {
  success,
  invalidName,
  invalidCharacters,
  sameName,
  alreadyExists,
  emptyFolder,
  fileNotFound,
  permissionDenied,
  unknownError,
}
