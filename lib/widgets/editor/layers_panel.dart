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
                                    // Visibility Toggle
                                    IconButton(
                                      icon: Icon(
                                        textLayer.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                        color: textLayer.isVisible ? Colors.white70 : Colors.white24,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      tooltip: textLayer.isVisible ? 'Hide Layer' : 'Show Layer',
                                      onPressed: () => notifier.toggleVisibilityTextLayer(textLayer.id),
                                    ),
                                    // Lock Toggle
                                    IconButton(
                                      icon: Icon(
                                        textLayer.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                        color: textLayer.isLocked ? Colors.amberAccent : Colors.white38,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      tooltip: textLayer.isLocked ? 'Unlock Layer' : 'Lock Layer',
                                      onPressed: () => notifier.toggleLockTextLayer(textLayer.id),
                                    ),
                                    // Delete
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      tooltip: 'Delete',
                                      onPressed: () => notifier.deleteTextLayer(textLayer.id),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.drag_handle_rounded, color: Colors.white38, size: 20),
                                  ],
                                ),
                                onTap: () {
                                  if (!textLayer.isLocked) {
                                    notifier.selectLayer(textLayer.id);
                                    Navigator.pop(context);
                                  }
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
                            
                            IconData layerIcon;
                            Color iconColor;
                            String layerCategory;

                            if (mediaLayer.type == MediaType.audio) {
                              layerIcon = Icons.audiotrack_rounded;
                              iconColor = Colors.greenAccent;
                              layerCategory = 'Audio';
                            } else if (mediaLayer.isOverlay) {
                              layerIcon = mediaLayer.type == MediaType.video ? Icons.picture_in_picture_rounded : Icons.layers_rounded;
                              iconColor = const Color(0xFFE040FB);
                              layerCategory = mediaLayer.type == MediaType.video ? 'Overlay Video' : 'Overlay Image';
                            } else {
                              layerIcon = mediaLayer.type == MediaType.video ? Icons.video_collection_rounded : Icons.image_rounded;
                              iconColor = mediaLayer.type == MediaType.video ? Colors.blueAccent : Colors.amberAccent;
                              layerCategory = mediaLayer.type == MediaType.video ? 'Main Video' : 'Main Image';
                            }

                            final hasAudio = mediaLayer.type == MediaType.video || mediaLayer.type == MediaType.audio;

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
                                  layerIcon,
                                  color: iconColor,
                                ),
                                title: Text(
                                  mediaLayer.path.split('/').last.split('\\').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                ),
                                subtitle: Text(
                                  '$layerCategory • ${mediaLayer.startTime.toStringAsFixed(1)}s - ${(mediaLayer.startTime + mediaLayer.mediaDuration).toStringAsFixed(1)}s',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Visibility Toggle
                                    IconButton(
                                      icon: Icon(
                                        mediaLayer.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                        color: mediaLayer.isVisible ? Colors.white70 : Colors.white24,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      tooltip: mediaLayer.isVisible ? 'Hide Layer' : 'Show Layer',
                                      onPressed: () => notifier.toggleVisibilityMediaLayer(mediaLayer.id),
                                    ),
                                    // Mute Toggle (for video/audio)
                                    if (hasAudio)
                                      IconButton(
                                        icon: Icon(
                                          mediaLayer.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                          color: mediaLayer.isMuted ? Colors.redAccent : Colors.white70,
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                        tooltip: mediaLayer.isMuted ? 'Unmute' : 'Mute',
                                        onPressed: () => notifier.toggleMuteMediaLayer(mediaLayer.id),
                                      ),
                                    // Lock Toggle
                                    IconButton(
                                      icon: Icon(
                                        mediaLayer.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                                        color: mediaLayer.isLocked ? Colors.amberAccent : Colors.white38,
                                        size: 18,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      tooltip: mediaLayer.isLocked ? 'Unlock Layer' : 'Lock Layer',
                                      onPressed: () => notifier.toggleLockMediaLayer(mediaLayer.id),
                                    ),
                                    // Delete
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                                      tooltip: 'Delete',
                                      onPressed: () => notifier.deleteMediaLayer(mediaLayer.id),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(Icons.drag_handle_rounded, color: Colors.white38, size: 20),
                                  ],
                                ),
                                onTap: () {
                                  if (!mediaLayer.isLocked) {
                                    notifier.selectLayer(mediaLayer.id);
                                    Navigator.pop(context);
                                  }
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
