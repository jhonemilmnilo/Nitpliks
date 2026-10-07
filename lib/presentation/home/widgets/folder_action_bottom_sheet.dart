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

    // Dismiss dialog immediately and activate skeleton loader on the folder row
    Navigator.pop(dialogCtx);
    ref.read(updatingFolderIdProvider.notifier).state = folder.id;

    final result = await DeviceMediaService.renameFolder(folder.id, trimmed);

    // Stop skeleton loader and refresh
    ref.read(updatingFolderIdProvider.notifier).state = null;

    if (result == RenameResult.success) {
      ref.invalidate(deviceFoldersProvider);
      if (parentContext.mounted) {
        _showTopToast(
          context: parentContext,
          ref: ref,
          message: 'Renamed folder to "$trimmed"',
          isError: false,
        );
      }
    } else if (result == RenameResult.permissionDenied) {
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
      if (parentContext.mounted) {
        _showTopToast(
          context: parentContext,
          ref: ref,
          message: msg,
          isError: true,
        );
      }
    }
  }

  /// Modern floating Top Toast overlay
  static void _showTopToast({
    required BuildContext context,
    required WidgetRef ref,
    required String message,
    bool isError = false,
  }) {
    final overlay = Overlay.of(context);
    final palette = ref.read(paletteProvider);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopToastWidget(
        message: message,
        palette: palette,
        isError: isError,
        onDismiss: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
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
              ref.read(updatingFolderIdProvider.notifier).state = folder.id;

              final success = await DeviceMediaService.deleteFolderVideos(folder.id);
              ref.read(updatingFolderIdProvider.notifier).state = null;

              if (success) {
                ref.invalidate(deviceFoldersProvider);
                if (context.mounted) {
                  _showTopToast(
                    context: context,
                    ref: ref,
                    message: 'Deleted "${folder.name}"',
                    isError: false,
                  );
                }
              } else {
                if (context.mounted) {
                  _showTopToast(
                    context: context,
                    ref: ref,
                    message: 'Could not delete videos from device',
                    isError: true,
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

/// Floating Top Toast Notification with slide and fade animation
class _TopToastWidget extends StatefulWidget {
  final String message;
  final dynamic palette;
  final bool isError;
  final VoidCallback onDismiss;

  const _TopToastWidget({
    required this.message,
    required this.palette,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Auto-dismiss after 2.8 seconds
    Future.delayed(const Duration(milliseconds: 2800), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final palette = widget.palette;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isError ? Colors.redAccent.withValues(alpha: 0.5) : palette.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isError ? LucideIcons.alertCircle : LucideIcons.checkCircle2,
                    color: widget.isError ? Colors.redAccent : palette.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
