import 'dart:io';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';

class InAppAudioPicker extends StatefulWidget {
  final Function(String path) onAudioPicked;

  const InAppAudioPicker({Key? key, required this.onAudioPicked}) : super(key: key);

  @override
  _InAppAudioPickerState createState() => _InAppAudioPickerState();
}

class _InAppAudioPickerState extends State<InAppAudioPicker> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  bool _hasPermission = false;
  bool _isLoading = true;
  List<SongModel> _songs = [];

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    bool hasPermission = false;
    if (Platform.isAndroid) {
      if (await Permission.audio.isGranted || await Permission.storage.isGranted) {
        hasPermission = true;
      } else {
        final statusStorage = await Permission.storage.request();
        final statusAudio = await Permission.audio.request();
        hasPermission = statusStorage.isGranted || statusAudio.isGranted;
      }
    } else {
      hasPermission = await _audioQuery.checkAndRequest(retryRequest: true);
    }
    
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
      });
    }

    if (hasPermission) {
      _loadAudioFiles();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAudioFiles() async {
    try {
      final songs = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      if (mounted) {
        setState(() {
          _songs = songs.where((s) => s.isMusic == true && s.data.isNotEmpty).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Audio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
    }
    
    if (!_hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Storage permission is required to access audio files',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return const Center(
        child: Text(
          'No audio files found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      itemCount: _songs.length,
      padding: const EdgeInsets.only(bottom: 20),
      itemBuilder: (context, index) {
        final song = _songs[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.white10,
            child: Icon(Icons.music_note, color: AppTheme.primaryAccent),
          ),
          title: Text(
            song.title,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song.artist ?? 'Unknown Artist',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            widget.onAudioPicked(song.data);
          },
        );
      },
    );
  }
}
