import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/editor_project_model.dart';
import '../models/media_layer_model.dart';
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

  void _handleCreateNewProject(BuildContext context) {
    ref.read(editorProjectProvider.notifier).resetProject();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AspectRatioScreen()),
    ).then((_) => _loadProjects());
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

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT PROJECTS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (_recentProjects.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() => _currentIndex = 1);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryAccent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppTheme.primaryAccent,
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
        else ...[
          ..._recentProjects.take(4).map((p) => _buildProjectCard(context, p, isDark)),
          if (_recentProjects.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryAccent,
                    side: BorderSide(color: AppTheme.primaryAccent.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() => _currentIndex = 1);
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text('View all ${_recentProjects.length} projects'),
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _searchQuery = '';

  Widget _buildProjectsTab(BuildContext context, bool isDark) {
    final filtered = _recentProjects.where((p) {
      if (_searchQuery.trim().isEmpty) return true;
      return p.title.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadProjects,
      color: AppTheme.primaryAccent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ALL PROJECTS (${_recentProjects.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              if (_recentProjects.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _handleCreateNewProject(context),
                  icon: const Icon(Icons.add_rounded, size: 18, color: AppTheme.primaryAccent),
                  label: const Text('New', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Box if multiple projects exist
          if (_recentProjects.length >= 3) ...[
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                ),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search projects by name...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

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
          else if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 8),
                    Text('No matching projects found', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((p) => _buildProjectCard(context, p, isDark)),
        ],
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, EditorProjectModel p, bool isDark) {
    final hasVideo = p.mediaLayers.any((m) => m.type == MediaType.video);
    final textCount = p.textLayers.length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.read(editorProjectProvider.notifier).loadProject(p, resetPlayhead: true);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditorScreen()),
          ).then((_) => _loadProjects());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Project Icon / Thumbnail Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3F3D56)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    hasVideo ? Icons.movie_filter_rounded : Icons.music_note_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Title and Meta Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildMetaBadge(
                          icon: Icons.timer_outlined,
                          label: '${p.duration.toInt()}s',
                          isDark: isDark,
                        ),
                        _buildMetaBadge(
                          icon: Icons.aspect_ratio_rounded,
                          label: p.aspectRatio.label,
                          isDark: isDark,
                        ),
                        if (textCount > 0)
                          _buildMetaBadge(
                            icon: Icons.text_fields_rounded,
                            label: '$textCount lyrics',
                            isDark: isDark,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete action button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                tooltip: 'Delete Project',
                onPressed: () => _confirmDeleteProject(context, p, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaBadge({required IconData icon, required String label, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteProject(BuildContext context, EditorProjectModel project, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete Project?',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${project.title}"? This action cannot be undone.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProjectStorageService.deleteProject(project.id);
      _loadProjects();
    }
  }
}
