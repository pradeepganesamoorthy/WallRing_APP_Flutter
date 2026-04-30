import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  final WallpaperManagerFlutter _wallpaperManager = WallpaperManagerFlutter();

  List<AssetEntity> _photos = [];
  AssetEntity? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() => _loading = false);
      return;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final assets = await albums[0].getAssetListRange(start: 0, end: 500);

    if (!mounted) return;
    setState(() {
      _photos = assets;
      _loading = false;
    });
  }

  void _onSelectPhoto(AssetEntity asset) {
    setState(() => _selected = asset);
    _showPreviewBottomSheet(asset);
  }

  Future<void> _showPreviewBottomSheet(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null || !mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WallpaperPreviewSheet(
        imageFile: file,
        onSetWallpaper: (croppedFile, location) async {
          Navigator.pop(context);
          await _setWallpaper(croppedFile, location);
        },
      ),
    );
  }

  Future<void> _setWallpaper(File imageFile, int location) async {
    try {
      _showLoadingDialog();

      final result = await _wallpaperManager.setWallpaper(
        imageFile,
        location,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Wallpaper set successfully'
                : 'Failed to set wallpaper',
          ),
          backgroundColor:
              result ? const Color(0xFF06D6A0) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
              CircularProgressIndicator(color: Color(0xFFFF6B35)),
              SizedBox(height: 16),
              Text(
                'Setting wallpaper...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }

    if (_photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text(
              'No photos found',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
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
                '${_photos.length} Photos',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Text(
                'Long press to select',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _photos.length,
            itemBuilder: (_, index) {
              final asset = _photos[index];
              return _PhotoTile(
                asset: asset,
                isSelected: _selected == asset,
                onTap: () => _onSelectPhoto(asset),
                onLongPress: () => _onSelectPhoto(asset),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PhotoTile({
    required this.asset,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
    );

    if (!mounted) return;
    setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: widget.isSelected
              ? Border.all(color: const Color(0xFFFF6B35), width: 3)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _thumb != null
              ? Image.memory(
                  _thumb!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : Container(
                  color: const Color(0xFF1A1A2E),
                ),
        ),
      ),
    );
  }
}

class _WallpaperPreviewSheet extends StatefulWidget {
  final File imageFile;
  final Function(File, int) onSetWallpaper;

  const _WallpaperPreviewSheet({
    required this.imageFile,
    required this.onSetWallpaper,
  });

  @override
  State<_WallpaperPreviewSheet> createState() => _WallpaperPreviewSheetState();
}

class _WallpaperPreviewSheetState extends State<_WallpaperPreviewSheet> {
  File? _croppedFile;
  int _wallpaperLocation = WallpaperManagerFlutter.bothScreens;

  File get _displayFile => _croppedFile ?? widget.imageFile;

  Future<void> _cropImage() async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: widget.imageFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Wallpaper',
          toolbarColor: const Color(0xFF1A1A2E),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFFF6B35),
          backgroundColor: const Color(0xFF0F0F1A),
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
      ],
    );

    if (cropped != null) {
      setState(() => _croppedFile = File(cropped.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          const Text(
            'Preview & Set Wallpaper',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _displayFile,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD166),
                side: const BorderSide(
                  color: Color(0xFFFFD166),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 46),
              ),
              icon: const Icon(Icons.crop_rounded, size: 18),
              label: const Text(
                'Crop Image',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _cropImage,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set as:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LocationChip(
                      label: 'Home Screen',
                      icon: Icons.home_rounded,
                      selected: _wallpaperLocation ==
                          WallpaperManagerFlutter.homeScreen,
                      onTap: () => setState(
                        () => _wallpaperLocation =
                            WallpaperManagerFlutter.homeScreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LocationChip(
                      label: 'Lock Screen',
                      icon: Icons.lock_rounded,
                      selected: _wallpaperLocation ==
                          WallpaperManagerFlutter.lockScreen,
                      onTap: () => setState(
                        () => _wallpaperLocation =
                            WallpaperManagerFlutter.lockScreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LocationChip(
                      label: 'Both',
                      icon: Icons.phonelink_rounded,
                      selected: _wallpaperLocation ==
                          WallpaperManagerFlutter.bothScreens,
                      onTap: () => setState(
                        () => _wallpaperLocation =
                            WallpaperManagerFlutter.bothScreens,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Apply Wallpaper',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () =>
                    widget.onSetWallpaper(_displayFile, _wallpaperLocation),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LocationChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
                : const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFFFF6B35) : Colors.white12,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFFFF6B35)
                    : Colors.white38,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFFF6B35)
                      : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}