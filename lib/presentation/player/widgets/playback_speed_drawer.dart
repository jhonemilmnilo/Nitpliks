import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../app/theme/palette_provider.dart';
import '../providers/playback_speed_provider.dart';

class PlaybackSpeedDrawer extends ConsumerStatefulWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  const PlaybackSpeedDrawer({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
  });

  static const List<double> presetSpeeds = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  static Future<void> show(
    BuildContext context, {
    required double currentSpeed,
    required ValueChanged<double> onSpeedSelected,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Speed Drawer',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: PlaybackSpeedDrawer(
            currentSpeed: currentSpeed,
            onSpeedSelected: onSpeedSelected,
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
  ConsumerState<PlaybackSpeedDrawer> createState() => _PlaybackSpeedDrawerState();
}

class _PlaybackSpeedDrawerState extends ConsumerState<PlaybackSpeedDrawer> {
  late double _activeSpeed;

  @override
  void initState() {
    super.initState();
    _activeSpeed = widget.currentSpeed;
  }

  void _applySpeed(double speed) {
    // Round to 2 decimals for clean values
    final rounded = (speed * 20).round() / 20;
    setState(() {
      _activeSpeed = rounded;
    });
    ref.read(playbackSpeedProvider.notifier).setSpeed(rounded);
    widget.onSpeedSelected(rounded);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final size = MediaQuery.of(context).size;
    final drawerWidth = (size.width * 0.42).clamp(280.0, 360.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
          border: Border(left: BorderSide(color: palette.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 28,
              offset: const Offset(-8, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.gauge, color: palette.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Playback Speed',
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, color: palette.textMuted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.white12),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  children: [
                    // LIVE SPEED BADGE DISPLAY
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _activeSpeed == 1.0 ? '1.0x (Normal)' : '${_activeSpeed.toStringAsFixed(2)}x',
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SMOOTH SLIDER ADJUSTMENT CONTROL
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fine-Tune Speed',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _applySpeed(1.0),
                          child: Text(
                            'Reset to 1.0x',
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: palette.primary,
                        inactiveTrackColor: Colors.white12,
                        thumbColor: palette.primary,
                        overlayColor: palette.primary.withValues(alpha: 0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      ),
                      child: Slider(
                        value: _activeSpeed.clamp(0.25, 2.0),
                        min: 0.25,
                        max: 2.0,
                        divisions: 35, // 0.05 step intervals
                        onChanged: (val) {
                          _applySpeed(val);
                        },
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0.25x', style: TextStyle(color: palette.textMuted, fontSize: 10)),
                          Text('1.0x', style: TextStyle(color: palette.textMuted, fontSize: 10)),
                          Text('2.0x', style: TextStyle(color: palette.textMuted, fontSize: 10)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // PRESET QUICK SELECT BUTTONS
                    Text(
                      'Quick Presets',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PlaybackSpeedDrawer.presetSpeeds.map((preset) {
                        final isSelected = (_activeSpeed - preset).abs() < 0.01;

                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _applySpeed(preset),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.primary
                                  : palette.surfaceLight.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? palette.primary : palette.border,
                              ),
                            ),
                            child: Text(
                              preset == 1.0 ? '1.0x' : '${preset}x',
                              style: TextStyle(
                                color: isSelected ? Colors.white : palette.textPrimary,
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
