import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/editor_project_model.dart';
import 'screens/editor_screen.dart';
import 'screens/splash_screen.dart';
import 'services/project_storage_service.dart';
import 'state/editor_state_notifier.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'widgets/web_mobile_frame.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  final prefs = await SharedPreferences.getInstance();
  final restoreId = prefs.getString('editor_restore_session_id');

  EditorProjectModel? initialProject;
  if (restoreId != null && restoreId.isNotEmpty) {
    try {
      final projects = await ProjectStorageService.loadSavedProjects();
      initialProject = projects.where((p) => p.id == restoreId).firstOrNull;
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      child: LyricalVideoApp(initialProject: initialProject),
    ),
  );
}

class LyricalVideoApp extends ConsumerStatefulWidget {
  final EditorProjectModel? initialProject;
  const LyricalVideoApp({super.key, this.initialProject});

  @override
  ConsumerState<LyricalVideoApp> createState() => _LyricalVideoAppState();
}

class _LyricalVideoAppState extends ConsumerState<LyricalVideoApp> {
  @override
  void initState() {
    super.initState();
    if (widget.initialProject != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(editorProjectProvider.notifier).loadProject(widget.initialProject!);
      });
    }
  }

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
      home: widget.initialProject != null
          ? const EditorScreen()
          : const SplashScreen(),
    );
  }
}
