import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:just_audio/just_audio.dart';

class RingtoneScreen extends StatefulWidget {
  const RingtoneScreen({super.key});

  @override
  State<RingtoneScreen> createState() => _RingtoneScreenState();
}

class _RingtoneScreenState extends State<RingtoneScreen> {
  List<AssetEntity> _audios = [];
  bool _loading = true;
  AssetEntity? _playing;
  AssetEntity? _selected;
  final AudioPlayer _player = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Method channel to call native Android code for setting ringtone
  static const _channel =
      MethodChannel('com.example.wallpaper_ringtone_app/ringtone');

  @override
  void initState() {
    super.initState();
    _loadAudio();
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playing = null);
      }
    });
  }

  Future<void> _loadAudio() async {
    final albums =
        await PhotoManager.getAssetPathList(type: RequestType.audio);
    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final assets = await albums[0].getAssetListRange(start: 0, end: 300);
    setState(() {
      _audios = assets;
      _loading = false;
    });
  }

  Future<void> _playPause(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return;

    if (_playing == asset) {
      await _player.pause();
      setState(() => _playing = null);
    } else {
      await _player.stop();
      await _player.setFilePath(file.path);
      await _player.play();
      setState(() => _playing = asset);
    }
  }

  Future<void> _showSetDialog(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RingtoneSetSheet(
        fileName: asset.title ?? 'Unknown',
        filePath: file.path,
        onSet: (type) async {
          Navigator.pop(context);
          await _setRingtone(file, type, asset.title ?? 'Ringtone');
        },
      ),
    );
  }

  Future<void> _setRingtone(File file, String type, String title) async {
    try {
      _showLoadingDialog();
      // We use a method channel to call native Android RingtoneManager
      final result = await _channel.invokeMethod('setRingtone', {
        'path': file.path,
        'type': type, // 'ringtone' or 'notification'
        'title': title,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result == true
                ? '✅ ${type == 'ringtone' ? 'Phone ringtone' : 'Message tone'} set!'
                : '❌ Failed — grant "Modify System Settings" permission'),
            backgroundColor:
                result == true ? const Color(0xFF06D6A0) : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error: ${e.message}\n\nGo to Settings > Apps > WallRing > Modify System Settings and enable it.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: Color(0xFF1A1A2E),
        content: SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFD166)),
              SizedBox(height: 16),
              Text('Setting tone...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD166)));
    }

    if (_audios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text('No audio files found',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Row(
            children: [
              Text(
                '${_audios.length} Audio Files',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Text(
                'Tap to preview • Hold to set',
                style: TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        // Mini player (shown when playing)
        if (_playing != null)
          _MiniPlayer(
            title: _playing!.title ?? 'Unknown',
            position: _position,
            duration: _duration,
            onStop: () {
              _player.stop();
              setState(() => _playing = null);
            },
            formatDuration: _formatDuration,
          ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _audios.length,
            itemBuilder: (_, i) {
              final audio = _audios[i];
              final isPlaying = _playing == audio;
              return _AudioTile(
                audio: audio,
                isPlaying: isPlaying,
                onTap: () => _playPause(audio),
                onLongPress: () => _showSetDialog(audio),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Mini Player ────────────────────────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  final String title;
  final Duration position;
  final Duration duration;
  final VoidCallback onStop;
  final String Function(Duration) formatDuration;

  const _MiniPlayer({
    required this.title,
    required this.position,
    required this.duration,
    required this.onStop,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A0E), Color(0xFF1A2A2E)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note_rounded,
                    color: Color(0xFFFFD166), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${formatDuration(position)} / ${formatDuration(duration)}',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onStop,
                child: const Icon(Icons.stop_circle_rounded,
                    color: Color(0xFFFFD166), size: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xFFFFD166)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Audio Tile ─────────────────────────────────────────────────────────────────

class _AudioTile extends StatelessWidget {
  final AssetEntity audio;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AudioTile({
    required this.audio,
    required this.isPlaying,
    required this.onTap,
    required this.onLongPress,
  });

  String _formatDuration(int? ms) {
    if (ms == null) return '--:--';
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPlaying
              ? const Color(0xFFFFD166).withOpacity(0.1)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFFFFD166).withOpacity(0.5)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isPlaying
                    ? const Color(0xFFFFD166).withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: isPlaying
                    ? const Color(0xFFFFD166)
                    : Colors.white54,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title ?? 'Unknown',
                    style: TextStyle(
                      color: isPlaying
                          ? const Color(0xFFFFD166)
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatDuration(audio.duration),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert_rounded,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Ringtone Set Bottom Sheet ──────────────────────────────────────────────────

class _RingtoneSetSheet extends StatelessWidget {
  final String fileName;
  final String filePath;
  final Function(String) onSet;

  const _RingtoneSetSheet({
    required this.fileName,
    required this.filePath,
    required this.onSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.music_note_rounded,
              color: Color(0xFFFFD166), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Set as...',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            fileName,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),

          // Phone Ringtone
          _SetOptionTile(
            icon: Icons.phone_rounded,
            title: 'Phone Ringtone',
            desc: 'Replaces your current call ringtone',
            color: const Color(0xFFFF6B35),
            onTap: () => onSet('ringtone'),
          ),
          const SizedBox(height: 12),

          // Message Tone
          _SetOptionTile(
            icon: Icons.message_rounded,
            title: 'Message Tone',
            desc: 'Replaces your notification / SMS tone',
            color: const Color(0xFF06D6A0),
            onTap: () => onSet('notification'),
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }
}

class _SetOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _SetOptionTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}
