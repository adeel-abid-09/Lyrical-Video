import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/media_layer_model.dart';
import '../../state/editor_state_notifier.dart';
import '../../theme/app_theme.dart';

class LayersPanelWidget extends ConsumerWidget {
  const LayersPanelWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorProjectProvider);
    final notifier = ref.read(editorProjectProvider.notifier);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Layers Manager',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: project.textLayers.isEmpty && project.mediaLayers.isEmpty
                ? const Center(
                    child: Text(
                      'No layers added yet',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView(
                    children: [
                      if (project.textLayers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('TEXT & LYRICS', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          onReorder: (oldIndex, newIndex) {
                            notifier.reorderTextLayers(oldIndex, newIndex);
                          },
                          children: project.textLayers.map((textLayer) {
                            final isSelected = project.selectedLayerId == textLayer.id;
                            return Container(
                              key: ValueKey(textLayer.id),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryAccent.withOpacity(0.2) : const Color(0xFF28283C),
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(color: AppTheme.primaryAccent) : null,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  textLayer.isAutoLyric ? Icons.auto_awesome_rounded : Icons.text_fields_rounded,
                                  color: textLayer.isAutoLyric ? Colors.purpleAccent : AppTheme.primaryAccent,
                                ),
                                title: Text(
                                  textLayer.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${textLayer.startTime.toStringAsFixed(1)}s - ${textLayer.endTime.toStringAsFixed(1)}s',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        textLayer.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                        color: textLayer.isVisible ? Colors.white70 : Colors.white24,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        notifier.updateTextLayer(
                                          textLayer.copyWith(isVisible: !textLayer.isVisible),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                      onPressed: () => notifier.deleteTextLayer(textLayer.id),
                                    ),
                                    const Icon(Icons.drag_handle_rounded, color: Colors.white38),
                                  ],
                                ),
                                onTap: () {
                                  notifier.selectLayer(textLayer.id);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (project.mediaLayers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                          child: Text('MEDIA (PIP / AUDIO)', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        ReorderableListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          onReorder: (oldIndex, newIndex) {
                            notifier.reorderMediaLayers(oldIndex, newIndex);
                          },
                          children: project.mediaLayers.map((mediaLayer) {
                            final isSelected = project.selectedLayerId == mediaLayer.id;
                            final isAudio = mediaLayer.type == MediaType.audio;
                            return Container(
                              key: ValueKey(mediaLayer.id),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blueAccent.withOpacity(0.2) : const Color(0xFF28283C),
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(color: Colors.blueAccent) : null,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  isAudio ? Icons.audiotrack_rounded : Icons.video_collection_rounded,
                                  color: isAudio ? Colors.greenAccent : Colors.blueAccent,
                                ),
                                title: Text(
                                  mediaLayer.path.split('/').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${mediaLayer.startTime.toStringAsFixed(1)}s',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        mediaLayer.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                        color: mediaLayer.isMuted ? Colors.redAccent : Colors.white70,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        notifier.toggleMuteMediaLayer(mediaLayer.id);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                      onPressed: () => notifier.deleteMediaLayer(mediaLayer.id),
                                    ),
                                    const Icon(Icons.drag_handle_rounded, color: Colors.white38),
                                  ],
                                ),
                                onTap: () {
                                  notifier.selectLayer(mediaLayer.id);
                                  Navigator.pop(context);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
