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

  IconData _getModeIcon(VideoEnhanceMode mode) {
    switch (mode) {
      case VideoEnhanceMode.off:
        return LucideIcons.power;
      case VideoEnhanceMode.cinema:
        return LucideIcons.clapperboard;
      case VideoEnhanceMode.vivid:
        return LucideIcons.palette;
      case VideoEnhanceMode.superCrisp:
        return LucideIcons.sparkles;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final mediaQuery = MediaQuery.of(context);
    final drawerWidth = (mediaQuery.size.width * 0.42).clamp(280.0, 360.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        height: mediaQuery.size.height,
        decoration: BoxDecoration(
          color: const Color(0xFF141419).withValues(alpha: 0.94),
          border: const Border(
            left: BorderSide(color: Colors.white12, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(-5, 0),
            ),
          ],
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: palette.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                LucideIcons.sparkles,
                                color: palette.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Visual Enhancer',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white10, height: 1),

                  // Presets List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      children: VideoEnhanceMode.values.map((mode) {
                        final isSelected = _activeMode == mode;
                        final icon = _getModeIcon(mode);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? palette.primary.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? palette.primary : Colors.white10,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _applyMode(mode),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? palette.primary.withValues(alpha: 0.25)
                                            : Colors.white.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 16,
                                        color: isSelected ? palette.primary : Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mode.label,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            mode.description,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
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
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ),
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
