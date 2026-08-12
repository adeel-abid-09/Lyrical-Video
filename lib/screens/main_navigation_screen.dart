import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_project_model.dart';
import '../services/project_storage_service.dart';
import '../state/editor_state_notifier.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'aspect_ratio_screen.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;
  List<EditorProjectModel> _recentProjects = [];

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final projects = await ProjectStorageService.loadSavedProjects();
    if (mounted) {
      setState(() {
        _recentProjects = projects;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final List<Widget> pages = [
      _buildHomeTab(context, isDark),
      _buildProjectsTab(context, isDark),
      const SizedBox.shrink(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Lyrical Video Maker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primaryAccent,
        unselectedItemColor: isDark ? Colors.white54 : Colors.black54,
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        onTap: (index) {
          if (index == 2) {
            ref.read(editorProjectProvider.notifier).resetProject();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AspectRatioScreen()),
            ).then((_) => _loadProjects());
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library_rounded), label: 'Projects'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: AppTheme.primaryAccent,
              radius: 20,
              child: Icon(Icons.add_rounded, color: Colors.white),
            ),
            label: 'Create',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero Creation Banner
        GestureDetector(
          onTap: () {
            ref.read(editorProjectProvider.notifier).resetProject();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AspectRatioScreen()),
            ).then((_) => _loadProjects());
          },
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryAccent.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 140,
                    color: Colors.white.withOpacity(0.15),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Create New Project',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Import video, photos & sync animated lyrics',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'RECENT PROJECTS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),

        if (_recentProjects.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 8),
                  Text('No Saved Projects Yet', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Tap + Create to start a new video project', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ..._recentProjects.map((p) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryAccent,
                  child: Icon(Icons.movie_rounded, color: Colors.white),
                ),
                title: Text(p.title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: Text('${p.duration.toInt()}s • ${p.aspectRatio.label}', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    await ProjectStorageService.deleteProject(p.id);
                    _loadProjects();
                  },
                ),
                onTap: () {
                  ref.read(editorProjectProvider.notifier).loadProject(p);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditorScreen()),
                  ).then((_) => _loadProjects());
                },
              ),
            );
          }),
      ],
    );
  }

  Widget _buildProjectsTab(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_recentProjects.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.folder_open_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(height: 12),
                  Text('No Saved Projects', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Tap + Create to start a new video project', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
                ],
              ),
            ),
          )
        else
          ..._recentProjects.map((p) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryAccent,
                  child: Icon(Icons.movie_rounded, color: Colors.white),
                ),
                title: Text(p.title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: Text('${p.duration.toInt()}s • ${p.aspectRatio.label}', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () async {
                    await ProjectStorageService.deleteProject(p.id);
                    _loadProjects();
                  },
                ),
                onTap: () {
                  ref.read(editorProjectProvider.notifier).loadProject(p);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditorScreen()),
                  ).then((_) => _loadProjects());
                },
              ),
            );
          }),
      ],
    );
  }
}
