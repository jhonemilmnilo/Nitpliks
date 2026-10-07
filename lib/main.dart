import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app/theme/palette_provider.dart';
import 'presentation/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(
    const ProviderScope(
      child: NitPliksApp(),
    ),
  );
}

class NitPliksApp extends ConsumerWidget {
  const NitPliksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePalette = ref.watch(paletteProvider);

    return MaterialApp(
      title: 'NitPliks',
      debugShowCheckedModeBanner: false,
      theme: activePalette.themeData,
      home: const HomeScreen(),
    );
  }
}
