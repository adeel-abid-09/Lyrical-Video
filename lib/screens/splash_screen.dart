import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/project_storage_service.dart';
import '../state/editor_state_notifier.dart';
import 'main_navigation_screen.dart';
import 'editor_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final String? restoreSessionId;
  const SplashScreen({super.key, this.restoreSessionId});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _animController.forward();
    _startTimer();
  }

  Future<void> _startTimer() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );

    // If there is a session to restore, load it and push EditorScreen on top
    if (widget.restoreSessionId != null && widget.restoreSessionId!.isNotEmpty) {
      final projects = await ProjectStorageService.loadSavedProjects();
      final recoveredProject = projects.where((p) => p.id == widget.restoreSessionId).firstOrNull;
      if (recoveredProject != null) {
        if (!mounted) return;
        ref.read(editorProjectProvider.notifier).loadProject(recoveredProject);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditorScreen()),
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('editor_restore_session_id');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Custom 3D Play Icon with Dual Ring Arcs
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Ring Arc
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryAccent.withOpacity(0.8),
                              width: 8,
                            ),
                          ),
                        ),
                        // Inner Play Icon
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 64,
                          color: AppTheme.primaryAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // App Title
                  const Text(
                    'Lyrical Video Maker',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create Beautiful Animated Lyrics',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
