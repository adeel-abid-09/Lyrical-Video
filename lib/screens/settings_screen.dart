import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/groq_auto_lyrics_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await GroqAutoLyricsService.getApiKey();
    _apiKeyController.text = key;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Theme Section
          const Text('APPEARANCE', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
              title: const Text('Dark Mode'),
              subtitle: Text(isDark ? 'Sleek dark theme active' : 'Light theme active'),
              value: isDark,
              onChanged: (_) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
          ),
          const SizedBox(height: 24),

          // Groq AI API Key Section
          const Text('AI AUTO-LYRICS SETTINGS', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryAccent),
                      SizedBox(width: 8),
                      Text('Groq API Key', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Used for AI-powered song transcription and lyrics translation.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'API Key (gsk_...)',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
                      onPressed: () async {
                        await GroqAutoLyricsService.saveApiKey(_apiKeyController.text);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Groq API Key saved successfully!')),
                          );
                        }
                      },
                      child: const Text('Save API Key', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          const Text('ABOUT APP', style: TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Lyrical Video Maker'),
              subtitle: Text('Version 1.0.0 (Client Side Engine)'),
            ),
          ),
        ],
      ),
    );
  }
}
