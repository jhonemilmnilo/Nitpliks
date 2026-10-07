import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme/app_theme.dart';
import 'presentation/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: NitPliksApp(),
    ),
  );
}

class NitPliksApp extends StatelessWidget {
  const NitPliksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NitPliks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
