import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/app/theme/palette_provider.dart';
import 'package:video_player/data/services/device_media_service.dart';
import 'package:video_player/domain/models/media_models.dart';
import 'package:video_player/presentation/home/providers/media_provider.dart';

enum VideoMenuAction {
  rename,
  delete,
}

class VideoActionBottomSheet extends ConsumerWidget {
  final VideoModel video;
  final String folderId;

  const VideoActionBottomSheet({
    super.key,
    required this.video,
    required this.folderId,
  });

  static Future<VideoMenuAction?> show(BuildContext context, VideoModel video, String folderId) {
    return showModalBottomSheet<VideoMenuAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VideoActionBottomSheet(video: video, folderId: folderId),
    );
  }

  /// Compact Minimalist Rename Modal with Underline Only Border
  static void showRenameDialog(BuildContext context, WidgetRef ref, VideoModel video, String folderId) {
    final palette = ref.read(paletteProvider);
    final controller = TextEditingController(text: video.title);
    bool isSubmitting = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (builderCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: palette.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              title: Text(
                'Rename Video',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    cursorColor: palette.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintText: 'Enter new video name',
                      hintStyle: TextStyle(color: palette.textMuted, fontSize: 13),
                      errorText: errorMessage,
                      errorStyle: const TextStyle(fontSize: 11, color: Colors.redAccent),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: palette.border, width: 1.2),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: palette.border, width: 1.2),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: palette.primary, width: 2),
                      ),
                      errorBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) async {
                      if (isSubmitting) return;
                      await _performRename(
                        dialogCtx: dialogCtx,
                        parentContext: context,
                        ref: ref,
                        video: video,
                        folderId: folderId,
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
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: palette.textMuted, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          await _performRename(
                            dialogCtx: dialogCtx,
                            parentContext: context,
                            ref: ref,
                            video: video,
                            folderId: folderId,
                            newName: controller.text,
                            getIsSubmitting: () => isSubmitting,
                            setIsSubmitting: (val) => setDialogState(() => isSubmitting = val),
                            setErrorMessage: (msg) => setDialogState(() => errorMessage = msg),
                          );
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Rename', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
    required VideoModel video,
    required String folderId,
    required String newName,
    required bool Function() getIsSubmitting,
    required void Function(bool) setIsSubmitting,
    required void Function(String?) setErrorMessage,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      setErrorMessage('Video name cannot be empty');
      return;
    }

    if (trimmed == video.title) {
      Navigator.pop(dialogCtx);
      return;
    }

    // Dismiss dialog immediately and trigger pulsing skeleton on that video row
    Navigator.pop(dialogCtx);
    ref.read(updatingVideoIdProvider.notifier).state = video.id;

    final output = await DeviceMediaService.renameVideo(video.path, trimmed);

    if (output.isSuccess) {
      final newPath = output.targetPath ?? video.path;
      // In-memory targeted update: only this item is updated, zero full-list reload
      ref.read(folderVideosProvider(folderId).notifier).updateVideo(
        videoId: video.id,
        newTitle: trimmed,
        newPath: newPath,
      );

      ref.read(updatingVideoIdProvider.notifier).state = null;

      if (parentContext.mounted) {
        _showTopToast(
          context: parentContext,
          ref: ref,
          message: 'Renamed video to "$trimmed"',
          isError: false,
        );
      }
    } else {
      ref.read(updatingVideoIdProvider.notifier).state = null;

      String msg;
      switch (output.result) {
        case RenameResult.invalidCharacters:
          msg = 'Name cannot contain \\ / : * ? " < > |';
          break;
        case RenameResult.alreadyExists:
          msg = 'A video with that name already exists';
          break;
        case RenameResult.permissionDenied:
          msg = 'Storage permission denied by Android';
          break;
        default:
          msg = 'Could not rename video on this device';
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

  /// Compact Delete Confirmation Dialog
  static void showDeleteDialog(BuildContext context, WidgetRef ref, VideoModel video, String folderId) {
    final palette = ref.read(paletteProvider);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Delete Video?',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Permanently delete "${video.title}" from your device storage? This cannot be undone.',
          style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: TextStyle(color: palette.textMuted, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              ref.read(updatingVideoIdProvider.notifier).state = video.id;

              final success = await DeviceMediaService.deleteSingleVideo(video.id, video.path);

              if (success) {
                // In-memory targeted removal: only this item is removed, zero full-list reload
                ref.read(folderVideosProvider(folderId).notifier).removeVideo(video.id);
                // Invalidate folder summary count in background
                ref.invalidate(deviceFoldersProvider);
                ref.read(updatingVideoIdProvider.notifier).state = null;

                if (context.mounted) {
                  _showTopToast(
                    context: context,
                    ref: ref,
                    message: 'Deleted "${video.title}"',
                    isError: false,
                  );
                }
              } else {
                ref.read(updatingVideoIdProvider.notifier).state = null;
                if (context.mounted) {
                  _showTopToast(
                    context: context,
                    ref: ref,
                    message: 'Could not delete video from device',
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

              // Video Header Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.video,
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
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${video.formattedSize} • ${video.formattedDuration}',
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

              // Action 1: Rename Video
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(LucideIcons.edit2, color: palette.textPrimary, size: 20),
                title: Text(
                  'Rename Video',
                  style: TextStyle(color: palette.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context, VideoMenuAction.rename);
                },
              ),

              // Action 2: Delete Video
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 20),
                title: const Text(
                  'Delete Video',
                  style: TextStyle(color: Colors.redAccent, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context, VideoMenuAction.delete);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

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
}

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
