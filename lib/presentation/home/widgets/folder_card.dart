import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/app/theme/palette_provider.dart';
import 'package:video_player/domain/models/media_models.dart';
import 'package:video_player/presentation/home/providers/media_provider.dart';
import 'folder_action_bottom_sheet.dart';

class FolderCard extends ConsumerWidget {
  final DeviceFolderModel folder;
  final VoidCallback onTap;

  const FolderCard({
    super.key,
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final updatingFolderId = ref.watch(updatingFolderIdProvider);
    final isUpdating = updatingFolderId == folder.id;

    if (isUpdating) {
      return _FolderCardSkeleton(palette: palette);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          // Ultra compact padding for high list density
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Compact Folder Icon Container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.folder,
                  color: palette.primaryLight,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),

              // Folder Name & Video Count & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${folder.videoCount} ${folder.videoCount == 1 ? 'video' : 'videos'}',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        if (folder.formattedDate.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: palette.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            folder.formattedDate,
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // 3-dots Contextual Action Menu Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final action = await FolderActionBottomSheet.show(context, folder);
                    if (!context.mounted || action == null) return;

                    switch (action) {
                      case FolderMenuAction.rename:
                        FolderActionBottomSheet.showRenameDialog(context, ref, folder);
                        break;
                      case FolderMenuAction.delete:
                        FolderActionBottomSheet.showDeleteDialog(context, ref, folder);
                        break;
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      LucideIcons.moreVertical,
                      color: palette.textMuted,
                      size: 18,
                    ),
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

class _FolderCardSkeleton extends StatefulWidget {
  final dynamic palette;

  const _FolderCardSkeleton({required this.palette});

  @override
  State<_FolderCardSkeleton> createState() => _FolderCardSkeletonState();
}

class _FolderCardSkeletonState extends State<_FolderCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    _opacityAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        final shimmerColor = palette.border.withValues(alpha: _opacityAnim.value);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Skeleton Icon Box
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),

              // Skeleton Lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title placeholder
                    Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subtitle placeholder
                    Container(
                      width: 75,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shimmerColor.withValues(alpha: _opacityAnim.value * 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),

              // 3-dots placeholder
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: shimmerColor.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
