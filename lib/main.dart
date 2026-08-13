import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/web_mobile_frame.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  runApp(
    const ProviderScope(
      child: LyricalVideoApp(),
    ),
  );
}

class LyricalVideoApp extends ConsumerStatefulWidget {
  const LyricalVideoApp({super.key});

  @override
  ConsumerState<LyricalVideoApp> createState() => _LyricalVideoAppState();
}

class _LyricalVideoAppState extends ConsumerState<LyricalVideoApp> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Lyrical Video Maker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => WebMobileFrame(child: child ?? const SizedBox()),
      home: const SplashScreen(),
    );
  }
}
