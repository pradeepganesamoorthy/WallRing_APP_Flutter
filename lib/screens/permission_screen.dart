import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'home_screen.dart';

class PermissionGateScreen extends StatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  State<PermissionGateScreen> createState() => _PermissionGateScreenState();
}

class _PermissionGateScreenState extends State<PermissionGateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  bool _checking = true;
  int _androidVersion = 0;

  List<_PermItem> _permissions = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _init();
  }

  Future<void> _init() async {
    // Detect Android version first — permissions differ per version
    final info = await DeviceInfoPlugin().androidInfo;
    _androidVersion = info.version.sdkInt;
    _buildPermissionList();
    await _checkExistingPermissions();
  }

  void _buildPermissionList() {
    // Android 14+ (SDK 34+): READ_MEDIA_VISUAL_USER_SELECTED
    // Android 13  (SDK 33):  READ_MEDIA_IMAGES + READ_MEDIA_AUDIO
    // Android 12- (SDK 32-): READ_EXTERNAL_STORAGE
    if (_androidVersion >= 34) {
      _permissions = [
        _PermItem(
          icon: Icons.photo_library_rounded,
          title: 'Photos & Media',
          desc: 'Access your photos to set as wallpaper',
          permissions: [Permission.photos, Permission.videos],
          color: const Color(0xFFFF6B35),
          granted: false,
        ),
        _PermItem(
          icon: Icons.audio_file_rounded,
          title: 'Audio Files',
          desc: 'Access music files to set as ringtone',
          permissions: [Permission.audio],
          color: const Color(0xFFFFD166),
          granted: false,
        ),
      ];
    } else if (_androidVersion >= 33) {
      _permissions = [
        _PermItem(
          icon: Icons.photo_library_rounded,
          title: 'Photos & Media',
          desc: 'Access your photos to set as wallpaper',
          permissions: [Permission.photos],
          color: const Color(0xFFFF6B35),
          granted: false,
        ),
        _PermItem(
          icon: Icons.audio_file_rounded,
          title: 'Audio Files',
          desc: 'Access music files to set as ringtone',
          permissions: [Permission.audio],
          color: const Color(0xFFFFD166),
          granted: false,
        ),
      ];
    } else {
      // Android 12 and below — single storage permission covers all
      _permissions = [
        _PermItem(
          icon: Icons.folder_rounded,
          title: 'Storage Access',
          desc: 'Access photos and audio on your device',
          permissions: [Permission.storage],
          color: const Color(0xFF06D6A0),
          granted: false,
        ),
      ];
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkExistingPermissions() async {
    if (_permissions.isEmpty) {
      setState(() => _checking = false);
      return;
    }
    bool allGranted = true;
    for (var p in _permissions) {
      bool itemGranted = true;
      for (var perm in p.permissions) {
        final status = await perm.status;
        if (!status.isGranted) itemGranted = false;
      }
      if (mounted) setState(() => p.granted = itemGranted);
      if (!itemGranted) allGranted = false;
    }
    if (allGranted && mounted) {
      _navigateHome();
    } else {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _requestAll() async {
    bool anyDenied = false;

    for (var p in _permissions) {
      bool itemGranted = true;
      for (var perm in p.permissions) {
        final status = await perm.request();
        if (!status.isGranted) itemGranted = false;
      }
      if (mounted) setState(() => p.granted = itemGranted);
      if (!itemGranted) anyDenied = true;
    }

    if (!anyDenied) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _navigateHome();
    } else {
      _showDeniedDialog();
    }
  }

  void _navigateHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Permissions Required',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'WallRing needs all permissions to work properly.\n\nPlease grant them in Settings to continue.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F1A),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B35))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B35), Color(0xFFFFD166)]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.wallpaper_rounded,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Text('WallRing',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5)),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  'Before we start,\nwe need a few permissions.',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.3),
                ),
                const SizedBox(height: 10),
                const Text(
                  'These are required for the app to work.\nWe never upload your files anywhere.',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
                const SizedBox(height: 40),
                ..._permissions.map((p) => _buildPermTile(p)),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _requestAll,
                    child: const Text(
                      'Grant Permissions & Continue',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermTile(_PermItem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: p.granted
                ? const Color(0xFF06D6A0).withOpacity(0.5)
                : Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(p.icon, color: p.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 3),
                Text(p.desc,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          Icon(
            p.granted
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: p.granted ? const Color(0xFF06D6A0) : Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _PermItem {
  final IconData icon;
  final String title;
  final String desc;
  final List<Permission> permissions; // supports multiple permissions per tile
  final Color color;
  bool granted;

  _PermItem({
    required this.icon,
    required this.title,
    required this.desc,
    required this.permissions,
    required this.color,
    required this.granted,
  });
}
