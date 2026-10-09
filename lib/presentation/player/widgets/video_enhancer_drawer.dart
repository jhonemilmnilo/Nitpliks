import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/palette_provider.dart';
import '../providers/video_enhancer_provider.dart';

class VideoEnhancerDrawer extends ConsumerStatefulWidget {
  final VideoEnhanceMode currentMode;
  final ValueChanged<VideoEnhanceMode> onModeSelected;

  const VideoEnhancerDrawer({
    super.key,
    required this.currentMode,
    required this.onModeSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required VideoEnhanceMode currentMode,
    required ValueChanged<VideoEnhanceMode> onModeSelected,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Visual Enhancer',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: VideoEnhancerDrawer(
            currentMode: currentMode,
            onModeSelected: onModeSelected,
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
  ConsumerState<VideoEnhancerDrawer> createState() => _VideoEnhancerDrawerState();
}

class _VideoEnhancerDrawerState extends ConsumerState<VideoEnhancerDrawer> {
  late VideoEnhanceMode _activeMode;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.currentMode;
  }

  void _applyMode(VideoEnhanceMode mode) {
    setState(() {
      _activeMode = mode;
    });
    ref.read(videoEnhanceProvider.notifier).setMode(mode);
    widget.onModeSelected(mode);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final mediaQuery = MediaQuery.of(context);
    final drawerWidth = (mediaQuery.size.width * 0.40).clamp(280.0, 360.0);

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: palette.isDark ? 0.6 : 0.2),
              blurRadius: 30,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Clean Minimalist Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Visual Enhancer',
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

                  // Compact Presets List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      children: VideoEnhanceMode.values.map((mode) {
                        final isSelected = _activeMode == mode;

                        return InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _applyMode(mode),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mode.label,
                                        style: TextStyle(
                                          color: isSelected ? palette.primary : palette.textPrimary,
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        mode.description,
                                        style: TextStyle(
                                          color: palette.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                      }).toList(),
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
