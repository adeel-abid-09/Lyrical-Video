import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../services/ffmpeg_export_service.dart';
import '../state/editor_state_notifier.dart';
import '../theme/app_theme.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _isExporting = true;
  String? _exportedPath;
  String? _errorMessage;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startExport();
  }

  Future<void> _startExport() async {
    final project = ref.read(editorProjectProvider);

    try {
      final path = await FFmpegExportService.exportProject(
        project,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportedPath = path;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Video'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: _isExporting
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.primaryAccent,
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Rendering Lyrical Video...',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Applying text animations, audio, and video layers',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                )
              : _errorMessage != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        const Text(
                          'Export Error',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isExporting = true;
                              _errorMessage = null;
                            });
                            _startExport();
                          },
                          child: const Text('Try Again'),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, size: 64, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Export Complete!',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your video has been saved to your gallery.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 32),

                        // Share Button
                        if (_exportedPath != null)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryAccent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.share_rounded, color: Colors.white),
                              label: const Text('Share Video', style: TextStyle(color: Colors.white, fontSize: 16)),
                              onPressed: () {
                                Share.shareXFiles([XFile(_exportedPath!)], text: 'Check out my new Lyrical Video!');
                              },
                            ),
                          ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back to Editor', style: TextStyle(color: Colors.white70)),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
