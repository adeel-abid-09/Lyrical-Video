import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/editor_state_notifier.dart';
import '../theme/app_theme.dart';
import 'export_screen.dart';

class ExportSettingsScreen extends ConsumerStatefulWidget {
  const ExportSettingsScreen({super.key});

  @override
  ConsumerState<ExportSettingsScreen> createState() => _ExportSettingsScreenState();
}

class _ExportSettingsScreenState extends ConsumerState<ExportSettingsScreen> {
  String _selectedResolution = '1080p';
  int _selectedFps = 30;
  String _selectedQuality = 'High';

  final List<String> _resolutions = ['720p', '1080p', '2K/4K'];
  final List<int> _fpsOptions = [24, 30, 60];
  final List<String> _qualityOptions = ['Lower', 'High', 'Higher'];

  double _calculateEstimatedSizeMb(double durationSeconds) {
    double baseBitrateMbps = 6.0; // Default 1080p 30fps
    if (_selectedResolution == '720p') baseBitrateMbps = 3.5;
    if (_selectedResolution == '2K/4K') baseBitrateMbps = 15.0;

    if (_selectedFps == 60) baseBitrateMbps *= 1.4;
    if (_selectedFps == 24) baseBitrateMbps *= 0.85;

    if (_selectedQuality == 'Lower') baseBitrateMbps *= 0.7;
    if (_selectedQuality == 'Higher') baseBitrateMbps *= 1.3;

    final totalBits = baseBitrateMbps * 1000000 * durationSeconds;
    final megabytes = totalBits / (8 * 1024 * 1024);
    return megabytes.clamp(1.5, 999.0);
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorProjectProvider);
    final duration = project.duration > 0 ? project.duration : 15.0;
    final estimatedMb = _calculateEstimatedSizeMb(duration).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFF111116),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111116),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Export Settings',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // RESOLUTION CARD
                  _buildSectionHeader('RESOLUTION', Icons.hd_rounded),
                  const SizedBox(height: 10),
                  _buildOptionSelector(
                    options: _resolutions,
                    selectedValue: _selectedResolution,
                    onSelected: (val) => setState(() => _selectedResolution = val),
                    subtitles: const {
                      '720p': 'HD (Standard)',
                      '1080p': 'Full HD (Recommended)',
                      '2K/4K': 'Ultra HD (Highest Quality)',
                    },
                  ),

                  const SizedBox(height: 24),

                  // FRAME RATE (FPS) CARD
                  _buildSectionHeader('FRAME RATE (FPS)', Icons.speed_rounded),
                  const SizedBox(height: 10),
                  _buildOptionSelector(
                    options: _fpsOptions.map((f) => '${f} FPS').toList(),
                    selectedValue: '${_selectedFps} FPS',
                    onSelected: (val) {
                      final parsed = int.tryParse(val.replaceAll(' FPS', '')) ?? 30;
                      setState(() => _selectedFps = parsed);
                    },
                    subtitles: const {
                      '24 FPS': 'Cinematic Film',
                      '30 FPS': 'Standard Smooth',
                      '60 FPS': 'Ultra Smooth',
                    },
                  ),

                  const SizedBox(height: 24),

                  // CODEC & QUALITY
                  _buildSectionHeader('QUALITY / BITRATE', Icons.tune_rounded),
                  const SizedBox(height: 10),
                  _buildOptionSelector(
                    options: _qualityOptions,
                    selectedValue: _selectedQuality,
                    onSelected: (val) => setState(() => _selectedQuality = val),
                    subtitles: const {
                      'Lower': 'Smaller file size',
                      'High': 'Balanced quality (Default)',
                      'Higher': 'Maximum detail',
                    },
                  ),

                  const SizedBox(height: 28),

                  // ESTIMATED FILE SIZE CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.sd_storage_rounded, color: AppTheme.primaryAccent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimated File Size',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '~$estimatedMb MB',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${project.aspectRatio.label} • ${duration.toStringAsFixed(0)}s',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // BOTTOM EXPORT BUTTON
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryAccent,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportScreen(
                          resolution: _selectedResolution,
                          fps: _selectedFps,
                          quality: _selectedQuality,
                        ),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Export Video',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryAccent, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.primaryAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionSelector({
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    required Map<String, String> subtitles,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: options.map((option) {
          final isSelected = selectedValue == option;
          final isLast = option == options.last;
          return Column(
            children: [
              InkWell(
                onTap: () => onSelected(option),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          if (subtitles.containsKey(option)) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitles[option]!,
                              style: TextStyle(
                                color: isSelected ? AppTheme.primaryAccent : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Radio<String>(
                        value: option,
                        groupValue: selectedValue,
                        activeColor: AppTheme.primaryAccent,
                        onChanged: (val) {
                          if (val != null) onSelected(val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white10),
            ],
          );
        }).toList(),
      ),
    );
  }
}
