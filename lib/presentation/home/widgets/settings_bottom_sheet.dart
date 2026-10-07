import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:video_player/app/theme/app_palettes.dart';
import 'package:video_player/app/theme/palette_provider.dart';

class SettingsBottomSheet extends ConsumerStatefulWidget {
  const SettingsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SettingsBottomSheet(),
    );
  }

  @override
  ConsumerState<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends ConsumerState<SettingsBottomSheet> {
  bool _showDarkMode = true;

  @override
  void initState() {
    super.initState();
    // Default the tab based on currently active palette mode
    final current = ref.read(paletteProvider);
    _showDarkMode = current.isDark;
  }

  @override
  Widget build(BuildContext context) {
    final currentPalette = ref.watch(paletteProvider);
    final displayedPalettes = _showDarkMode ? AppPalettes.darkPalettes : AppPalettes.lightPalettes;

    return Container(
      decoration: BoxDecoration(
        color: currentPalette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: currentPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
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
                    color: currentPalette.textMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: currentPalette.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      LucideIcons.palette,
                      color: currentPalette.primaryLight,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance & Theme',
                        style: TextStyle(
                          color: currentPalette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select mode and dynamic color palette',
                        style: TextStyle(
                          color: currentPalette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Dark / Light Mode Segmented Toggle Switch
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: currentPalette.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: currentPalette.border),
                ),
                child: Row(
                  children: [
                    // Dark Mode Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showDarkMode = true;
                          });
                          if (!currentPalette.isDark) {
                            ref.read(paletteProvider.notifier).setPalette(AppPalettes.cyberIndigo);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _showDarkMode ? currentPalette.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _showDarkMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.moon,
                                size: 16,
                                color: _showDarkMode ? currentPalette.primary : currentPalette.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dark Mode',
                                style: TextStyle(
                                  color: _showDarkMode ? currentPalette.textPrimary : currentPalette.textMuted,
                                  fontSize: 13,
                                  fontWeight: _showDarkMode ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Light Mode Tab
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showDarkMode = false;
                          });
                          if (currentPalette.isDark) {
                            ref.read(paletteProvider.notifier).setPalette(AppPalettes.cleanFrost);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_showDarkMode ? currentPalette.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_showDarkMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.sun,
                                size: 16,
                                color: !_showDarkMode ? currentPalette.primary : currentPalette.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Light Mode',
                                style: TextStyle(
                                  color: !_showDarkMode ? currentPalette.textPrimary : currentPalette.textMuted,
                                  fontSize: 13,
                                  fontWeight: !_showDarkMode ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Color Palette Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedPalettes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.3,
                ),
                itemBuilder: (context, index) {
                  final palette = displayedPalettes[index];
                  final isSelected = palette.id == currentPalette.id;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        ref.read(paletteProvider.notifier).setPalette(palette);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? palette.primary.withValues(alpha: 0.15)
                              : currentPalette.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? palette.primary : currentPalette.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Dual gradient preview dot
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [palette.primary, palette.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.primary.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      LucideIcons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),

                            // Palette Name
                            Expanded(
                              child: Text(
                                palette.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? currentPalette.textPrimary
                                      : currentPalette.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
