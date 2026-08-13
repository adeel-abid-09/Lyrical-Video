import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/web_mobile_frame.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  final prefs = await SharedPreferences.getInstance();
  final restoreId = prefs.getString('editor_restore_session_id');

  runApp(
    ProviderScope(
      child: LyricalVideoApp(restoreSessionId: restoreId),
    ),
  );
}

class LyricalVideoApp extends ConsumerStatefulWidget {
  final String? restoreSessionId;
  const LyricalVideoApp({super.key, this.restoreSessionId});

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
      home: SplashScreen(restoreSessionId: widget.restoreSessionId),
    );
  }
}
