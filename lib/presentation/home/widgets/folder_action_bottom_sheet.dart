import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/app/theme/palette_provider.dart';
import 'package:video_player/data/services/device_media_service.dart';
import 'package:video_player/domain/models/media_models.dart';
import 'package:video_player/presentation/home/providers/media_provider.dart';

enum FolderMenuAction {
  rename,
  delete,
}

class FolderActionBottomSheet extends ConsumerWidget {
  final DeviceFolderModel folder;

  const FolderActionBottomSheet({
    super.key,
    required this.folder,
  });

  static Future<FolderMenuAction?> show(BuildContext context, DeviceFolderModel folder) {
    return showModalBottomSheet<FolderMenuAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FolderActionBottomSheet(folder: folder),
    );
  }

  static void showRenameDialog(BuildContext context, WidgetRef ref, DeviceFolderModel folder) {
    final palette = ref.read(paletteProvider);
    final controller = TextEditingController(text: folder.name);
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: palette.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Rename Folder',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isSubmitting,
                    style: TextStyle(color: palette.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter new folder name',
                      hintStyle: TextStyle(color: palette.textMuted),
                      errorText: errorMessage,
                      errorStyle: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: palette.primary),
                      ),
                    ),
                    onSubmitted: (_) async {
                      if (isSubmitting) return;
                      await _performRename(
                        dialogCtx: dialogCtx,
                        parentContext: context,
                        ref: ref,
                        folder: folder,
                        newName: controller.text,
                        getIsSubmitting: () => isSubmitting,
                        setIsSubmitting: (val) => setDialogState(() => isSubmitting = val),
                        setErrorMessage: (msg) => setDialogState(() => errorMessage = msg),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          await _performRename(
                            dialogCtx: dialogCtx,
                            parentContext: context,
                            ref: ref,
                            folder: folder,
                            newName: controller.text,
                            getIsSubmitting: () => isSubmitting,
                            setIsSubmitting: (val) => setDialogState(() => isSubmitting = val),
                            setErrorMessage: (msg) => setDialogState(() => errorMessage = msg),
                          );
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Rename'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<void> _performRename({
    required BuildContext dialogCtx,
    required BuildContext parentContext,
    required WidgetRef ref,
    required DeviceFolderModel folder,
    required String newName,
    required bool Function() getIsSubmitting,
    required void Function(bool) setIsSubmitting,
    required void Function(String?) setErrorMessage,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      setErrorMessage('Folder name cannot be empty');
      return;
    }

    if (trimmed == folder.name) {
      Navigator.pop(dialogCtx);
      return;
    }

    setIsSubmitting(true);
    setErrorMessage(null);

    final result = await DeviceMediaService.renameFolder(folder.id, trimmed);

    if (!dialogCtx.mounted) return;

    if (result == RenameResult.success) {
      // Invalidate and re-fetch folders so UI immediately reflects the new name
      ref.invalidate(deviceFoldersProvider);
      
      Navigator.pop(dialogCtx);
      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Renamed folder to "$trimmed"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (result == RenameResult.permissionDenied) {
      setIsSubmitting(false);
      Navigator.pop(dialogCtx);
      if (parentContext.mounted) {
        _showStoragePermissionDialog(parentContext, ref);
      }
    } else {
      String msg;
      switch (result) {
        case RenameResult.invalidCharacters:
          msg = 'Name cannot contain \\ / : * ? " < > |';
          break;
        case RenameResult.alreadyExists:
          msg = 'A folder with that name already exists';
          break;
        case RenameResult.emptyFolder:
          msg = 'Folder is empty or not found';
          break;
        default:
          msg = 'Could not rename folder on this device';
      }
      setIsSubmitting(false);
      setErrorMessage(msg);
    }
  }

  static void _showStoragePermissionDialog(BuildContext context, WidgetRef ref) {
    final palette = ref.read(paletteProvider);

    showDialog(
      context: context,
      builder: (pCtx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.shieldAlert, color: palette.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Permission Required',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Android Scoped Storage requires "All Files Access" to rename folders directly on your device storage.\n\nWould you like to grant this permission in System Settings?',
          style: TextStyle(color: palette.textSecondary, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(pCtx),
            child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(pCtx);
              await DeviceMediaService.requestManageStoragePermission();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  static void showDeleteDialog(BuildContext context, WidgetRef ref, DeviceFolderModel folder) {
    final palette = ref.read(paletteProvider);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Delete Folder?',
              style: TextStyle(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${folder.name}" and all its ${folder.videoCount} videos from device storage? This cannot be undone.',
          style: TextStyle(color: palette.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: palette.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await DeviceMediaService.deleteFolderVideos(folder.id);
              if (success) {
                ref.invalidate(deviceFoldersProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Deleted "${folder.name}"')),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not delete videos from device')),
                  );
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Folder Header Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.folder,
                      color: palette.primaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${folder.videoCount} ${folder.videoCount == 1 ? 'video' : 'videos'}',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action 1: Edit / Rename Folder
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.edit2, color: palette.textPrimary, size: 20),
                title: Text(
                  'Rename Folder',
                  style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context, FolderMenuAction.rename);
                },
              ),

              // Action 2: Delete Folder
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                title: const Text(
                  'Delete Folder',
                  style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context, FolderMenuAction.delete);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
