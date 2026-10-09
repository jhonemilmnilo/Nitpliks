import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:media_kit/media_kit.dart';
import '../../../app/theme/palette_provider.dart';

class SubtitleDrawer extends ConsumerStatefulWidget {
  final Tracks tracks;
  final Track selectedTrack;
  final ValueChanged<SubtitleTrack> onTrackSelected;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOnlineDownload;

  const SubtitleDrawer({
    super.key,
    required this.tracks,
    required this.selectedTrack,
    required this.onTrackSelected,
    this.onOpenFile,
    this.onOnlineDownload,
  });

  static Future<void> show(
    BuildContext context, {
    required Tracks tracks,
    required Track selectedTrack,
    required ValueChanged<SubtitleTrack> onTrackSelected,
    VoidCallback? onOpenFile,
    VoidCallback? onOnlineDownload,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Subtitle Drawer',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: SubtitleDrawer(
            tracks: tracks,
            selectedTrack: selectedTrack,
            onTrackSelected: onTrackSelected,
            onOpenFile: onOpenFile,
            onOnlineDownload: onOnlineDownload,
          ),
        );
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(
          position: anim.drive(slide),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<SubtitleDrawer> createState() => _SubtitleDrawerState();
}

class _SubtitleDrawerState extends ConsumerState<SubtitleDrawer> {
  late SubtitleTrack _activeSubtitle;

  @override
  void initState() {
    super.initState();
    _activeSubtitle = widget.selectedTrack.subtitle;
  }

  void _selectTrack(SubtitleTrack track) {
    setState(() {
      _activeSubtitle = track;
    });
    widget.onTrackSelected(track);
  }

  String _formatTrackTitle(SubtitleTrack track, int index) {
    if (track == SubtitleTrack.no()) {
      return 'None';
    }
    if (track == SubtitleTrack.auto()) {
      return 'Auto-detect';
    }

    final title = track.title;
    final language = track.language;

    if (title != null && title.trim().isNotEmpty) {
      if (language != null && language.trim().isNotEmpty) {
        return '$title ($language)';
      }
      return title;
    }

    if (language != null && language.trim().isNotEmpty) {
      return 'Track $index ($language)';
    }

    return 'Track $index (${track.id})';
  }

  String get _currentSubtitleDisplay {
    if (_activeSubtitle == SubtitleTrack.no()) {
      return 'None';
    }
    if (_activeSubtitle == SubtitleTrack.auto()) {
      return 'Auto-detect';
    }
    final title = _activeSubtitle.title;
    final lang = _activeSubtitle.language;
    if (title != null && title.trim().isNotEmpty) {
      return lang != null ? '$title ($lang)' : title;
    }
    if (lang != null && lang.trim().isNotEmpty) {
      return lang;
    }
    return _activeSubtitle.id;
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final mediaQuery = MediaQuery.of(context);
    final drawerWidth = (mediaQuery.size.width * 0.40).clamp(280.0, 360.0);
    final subtitleTracks = widget.tracks.subtitle;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        height: mediaQuery.size.height,
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: palette.isDark ? 0.96 : 0.98),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          border: Border(
            left: BorderSide(color: palette.border, width: 1),
          ),
          boxShadow: palette.isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    offset: const Offset(-5, 0),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Minimalist Clean Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtitle',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        IconButton(
                          icon: Icon(LucideIcons.x, color: palette.textMuted, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  Divider(color: palette.border.withValues(alpha: 0.5), height: 1),

                  // Compact Text-Only Options List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      children: [
                        // 1. CURRENT SUBTITLE STATUS SECTION
                        Text(
                          'Current Subtitle',
                          style: TextStyle(
                            color: palette.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Single unified None or Active Subtitle button
                        _buildRowAction(
                          label: _currentSubtitleDisplay,
                          isSelected: true,
                          palette: palette,
                          onTap: () {
                            // Tapping toggles off if active, or keeps off
                            if (_activeSubtitle != SubtitleTrack.no()) {
                              _selectTrack(SubtitleTrack.no());
                            }
                          },
                        ),

                        if (subtitleTracks.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Divider(color: palette.border.withValues(alpha: 0.5), height: 1),
                          const SizedBox(height: 8),
                          ...subtitleTracks.asMap().entries.map((entry) {
                            final index = entry.key + 1;
                            final track = entry.value;
                            final isSelected = _activeSubtitle.id == track.id;

                            // Skip if it duplicates None
                            if (track == SubtitleTrack.no()) return const SizedBox.shrink();

                            return _buildRowAction(
                              label: _formatTrackTitle(track, index),
                              isSelected: isSelected,
                              palette: palette,
                              onTap: () => _selectTrack(track),
                            );
                          }),
                        ],

                        const SizedBox(height: 8),
                        Divider(color: palette.border.withValues(alpha: 0.5), height: 1),
                        const SizedBox(height: 10),

                        // 3. ACTION BUTTONS: Open file, Online download, AI generate
                        _buildRowAction(
                          label: 'Open file',
                          icon: LucideIcons.folderOpen,
                          palette: palette,
                          onTap: () {
                            Navigator.of(context).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              widget.onOpenFile?.call();
                            });
                          },
                        ),

                        _buildRowAction(
                          label: 'Online download',
                          icon: LucideIcons.downloadCloud,
                          palette: palette,
                          onTap: () {
                            Navigator.of(context).pop();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              widget.onOnlineDownload?.call();
                            });
                          },
                        ),
                      ],
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

  Widget _buildRowAction({
    required String label,
    IconData? icon,
    bool isSelected = false,
    String? badge,
    required dynamic palette,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: palette.textSecondary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? palette.primary : palette.textPrimary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (isSelected)
              Icon(
                LucideIcons.check,
                color: palette.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}
