import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/aspect_ratio_model.dart';
import '../state/editor_state_notifier.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import 'editor_screen.dart';

class AspectRatioScreen extends ConsumerStatefulWidget {
  const AspectRatioScreen({super.key});

  @override
  ConsumerState<AspectRatioScreen> createState() => _AspectRatioScreenState();
}

class _AspectRatioScreenState extends ConsumerState<AspectRatioScreen> {
  ProjectAspectRatio _selectedRatio = ProjectAspectRatio.default9x16;
  final TextEditingController _widthController = TextEditingController(text: '1080');
  final TextEditingController _heightController = TextEditingController(text: '1920');

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _proceedToEditor() {
    ProjectAspectRatio finalRatio = _selectedRatio;
    if (_selectedRatio.type == AspectRatioType.custom) {
      final w = double.tryParse(_widthController.text.trim()) ?? 1080.0;
      final h = double.tryParse(_heightController.text.trim()) ?? 1920.0;
      finalRatio = ProjectAspectRatio.createCustom(w, h);
    }

    ref.read(editorProjectProvider.notifier).setAspectRatio(finalRatio);

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Aspect Ratio'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Choose your target video dimension',
              style: TextStyle(fontSize: 16, color: subtextColor),
            ),
            const SizedBox(height: 24),

            // Grid of Aspect Ratio Cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  ...ProjectAspectRatio.allPresets.map((ratioItem) {
                    final isSelected = _selectedRatio.type == ratioItem.type;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRatio = ratioItem;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryAccent.withOpacity(0.15)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryAccent : (isDark ? Colors.white10 : Colors.black12),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              ratioItem.icon,
                              size: 36,
                              color: isSelected ? AppTheme.primaryAccent : subtextColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ratioItem.label,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppTheme.primaryAccent : textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ratioItem.sublabel,
                              style: TextStyle(fontSize: 12, color: subtextColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Custom Ratio Card
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRatio = ProjectAspectRatio.createCustom(1080, 1920);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedRatio.type == AspectRatioType.custom
                            ? AppTheme.primaryAccent.withOpacity(0.15)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedRatio.type == AspectRatioType.custom
                              ? AppTheme.primaryAccent
                              : (isDark ? Colors.white10 : Colors.black12),
                          width: _selectedRatio.type == AspectRatioType.custom ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.dashboard_customize_rounded,
                            size: 36,
                            color: AppTheme.primaryAccent,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Custom',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 2),
                          Text('Width x Height', style: TextStyle(fontSize: 12, color: subtextColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Custom Size Inputs
            if (_selectedRatio.type == AspectRatioType.custom) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _widthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Width (px)',
                        filled: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('x', style: TextStyle(fontSize: 20, color: subtextColor)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Height (px)',
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Proceed Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _proceedToEditor,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Start Editing',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
