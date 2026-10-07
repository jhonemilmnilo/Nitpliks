import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
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

  /// Check if user has granted full storage management (MANAGE_EXTERNAL_STORAGE)
  static Future<bool> hasManageStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.status;
    return status.isGranted;
  }

  /// Request All Files Access (MANAGE_EXTERNAL_STORAGE)
  static Future<bool> requestManageStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.manageExternalStorage.request();
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    return status.isGranted;
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
          // Resolve accurate physical folder name from first file path if available
          String displayName = album.name;
          try {
            final sample = await album.getAssetListRange(start: 0, end: 1);
            if (sample.isNotEmpty) {
              final f = await sample.first.file;
              if (f != null) {
                displayName = f.parent.path.split(Platform.pathSeparator).last;
              }
            }
          } catch (_) {}

          folderList.add(
            DeviceFolderModel(
              id: album.id,
              name: displayName,
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

  /// Delete all video assets in a folder using PhotoManager and remove empty directory
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
      
      // Attempt to capture directory path from first asset
      Directory? folderDir;
      if (count > 0) {
        final sample = await album.getAssetListRange(start: 0, end: 1);
        if (sample.isNotEmpty) {
          final file = await sample.first.file;
          if (file != null) {
            folderDir = file.parent;
          }
        }
      }

      bool deletedFromMediaStore = true;
      if (count > 0) {
        final List<AssetEntity> assets = await album.getAssetListRange(
          start: 0,
          end: count,
        );

        final List<String> assetIds = assets.map((a) => a.id).toList();
        final List<String> deleted = await PhotoManager.editor.deleteWithIds(assetIds);
        deletedFromMediaStore = deleted.isNotEmpty;
      }

      // If user granted MANAGE_EXTERNAL_STORAGE, also physically delete folder on disk
      if (folderDir != null && await folderDir.exists()) {
        try {
          final hasManage = await hasManageStoragePermission();
          if (hasManage) {
            // Delete folder directory recursively if empty or cleaned
            await folderDir.delete(recursive: true);
            debugPrint('🎬 [NitPliks Delete] Deleted folder on disk: ${folderDir.path}');
          }
        } catch (e) {
          debugPrint('🎬 [NitPliks Delete] Notice: Directory removal on disk skipped: $e');
        }
      }

      await PhotoManager.clearFileCache();
      return deletedFromMediaStore;
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

      debugPrint('🎬 [NitPliks Rename] Current Dir: ${currentDir.path}');
      debugPrint('🎬 [NitPliks Rename] Target Dir: $newDirPath');

      if (currentDir.path.toLowerCase() == newDirPath.toLowerCase()) {
        debugPrint('🎬 [NitPliks Rename] Same name detected');
        return RenameResult.sameName;
      }

      final newDir = Directory(newDirPath);
      if (await newDir.exists()) {
        debugPrint('🎬 [NitPliks Rename] Target dir already exists');
        return RenameResult.alreadyExists;
      }

      // Check manage storage permission first on Android
      final hasManage = await hasManageStoragePermission();
      debugPrint('🎬 [NitPliks Rename] Has MANAGE_EXTERNAL_STORAGE permission: $hasManage');
      if (!hasManage) {
        return RenameResult.permissionDenied;
      }

      // Perform directory rename on file system
      final renamedDir = await currentDir.rename(newDirPath);
      debugPrint('🎬 [NitPliks Rename] Successfully renamed directory to: ${renamedDir.path}');

      // Invalidate PhotoManager cache so media scanner picks up the changes
      await PhotoManager.clearFileCache();
      
      return RenameResult.success;
    } on FileSystemException catch (e) {
      debugPrint('🎬 [NitPliks Rename] FileSystemException: $e');
      return RenameResult.permissionDenied;
    } catch (e, stack) {
      debugPrint('🎬 [NitPliks Rename] Unknown Exception: $e\n$stack');
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
