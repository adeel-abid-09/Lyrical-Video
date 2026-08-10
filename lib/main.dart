import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'services/project_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state/editor_state_notifier.dart';
import 'screens/editor_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  final prefs = await SharedPreferences.getInstance();
  final activeId = prefs.getString('active_session_id');
  String? initialRoute = 'splash';
  
  if (activeId != null && activeId.isNotEmpty) {
    initialRoute = 'editor';
  }

  runApp(
    ProviderScope(
      overrides: [
        initialRouteProvider.overrideWithValue(initialRoute),
      ],
      child: const LyricalVideoApp(),
    ),
  );
}

final initialRouteProvider = Provider<String>((ref) => 'splash');

class LyricalVideoApp extends ConsumerStatefulWidget {
  const LyricalVideoApp({super.key});

  @override
  ConsumerState<LyricalVideoApp> createState() => _LyricalVideoAppState();
}

class _LyricalVideoAppState extends ConsumerState<LyricalVideoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Auto-save current editor state if we are in an active project
      final project = ref.read(editorProjectProvider);
      // We assume if title is changed or duration changed or layers exist, it's worth saving
      if (project.mediaLayers.isNotEmpty || project.textLayers.isNotEmpty) {
        ProjectStorageService.saveProject(project).then((_) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('active_session_id', project.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final initialRoute = ref.watch(initialRouteProvider);

    return MaterialApp(
      title: 'Lyrical Video Maker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: initialRoute == 'splash'
          ? const SplashScreen()
          : FutureBuilder(
              future: _loadActiveProject(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF14141E),
                    body: Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent)),
                  );
                }
                return const EditorScreen();
              },
            ),
    );
  }

  Future<void> _loadActiveProject() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString('active_session_id');
    if (activeId != null && activeId.isNotEmpty) {
      final projects = await ProjectStorageService.loadSavedProjects();
      final recoveredProject = projects.where((p) => p.id == activeId).firstOrNull;
      if (recoveredProject != null) {
        ref.read(editorProjectProvider.notifier).loadProject(recoveredProject);
        await prefs.remove('active_session_id');
      }
    }
  }
}
