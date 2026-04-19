// lib/screens/create/image_selection_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/video_player_tile.dart';
import 'property_details_screen.dart';

class ImageSelectionScreen extends StatefulWidget {
  const ImageSelectionScreen({super.key});
  @override
  State<ImageSelectionScreen> createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  final List<XFile> _images = [];
  final Map<String, Uint8List> _imageBytes = {}; // For web preview
  final _picker = ImagePicker();

  static const int _maxMedia = 5;

  int get _slotsLeft => _maxMedia - _images.length;

  void _showLimitSnack() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('You can only attach up to 5 photos/videos in total.'),
      backgroundColor: AppTheme.error,
    ));
  }

  Future<void> _pick(ImageSource src) async {
    if (_slotsLeft <= 0) {
      _showLimitSnack();
      return;
    }
    if (src == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      // Cap additions to the remaining slots.
      final toAdd = picked.take(_slotsLeft).toList();
      for (final xfile in toAdd) {
        _images.add(xfile);
        if (kIsWeb) {
          _imageBytes[xfile.path] = await xfile.readAsBytes();
        }
      }
      if (picked.length > toAdd.length && mounted) _showLimitSnack();
      setState(() {});
    } else {
      final picked = await _picker.pickImage(source: src, imageQuality: 85);
      if (picked != null) {
        _images.add(picked);
        if (kIsWeb) {
          _imageBytes[picked.path] = await picked.readAsBytes();
        }
        setState(() {});
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_slotsLeft <= 0) {
      _showLimitSnack();
      return;
    }
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      _images.add(picked);
      setState(() {});
    }
  }

  bool _isVideo(XFile file) {
    final lower = file.path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
  }

  /// Open a full-screen video preview so the user can rewatch before
  /// proceeding to the next step.
  void _previewVideo(String path) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Video Preview'),
        ),
        body: Center(
          child: VideoPlayerTile(
              path: path, width: double.infinity, height: 300),
        ),
      ),
    ));
  }

  Widget _buildImagePreview(XFile xfile) {
    if (kIsWeb) {
      final bytes = _imageBytes[xfile.path];
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      }
      return const Center(child: CircularProgressIndicator());
    } else {
      return Image.file(File(xfile.path), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Center(child: Icon(Icons.broken_image)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Property Images'), leading: const BackButton()),
        body: Column(children: [
          const StepIndicator(current: 1),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Property Photos',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark)),
              const SizedBox(height: 6),
              const Text(
                  'Great photos attract more interest — add at least one.',
                  style: TextStyle(color: AppTheme.textMid)),
              const SizedBox(height: 24),
              Row(children: [
                if (!kIsWeb)
                  Expanded(
                      child: _SrcBtn(
                          icon: Icons.camera_alt,
                          label: 'Camera',
                          onTap: () => _pick(ImageSource.camera))),
                if (!kIsWeb) const SizedBox(width: 12),
                Expanded(
                    child: _SrcBtn(
                        icon: Icons.photo_library,
                        label: 'Gallery',
                        onTap: () => _pick(ImageSource.gallery))),
                const SizedBox(width: 12),
                Expanded(
                    child: _SrcBtn(
                        icon: Icons.videocam,
                        label: 'Video',
                        onTap: _pickVideo)),
              ]),
              const SizedBox(height: 24),
              if (_images.isEmpty)
                Container(
                    height: 200,
                    decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(12),
                        color: AppTheme.background),
                    child: const Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Icon(Icons.add_photo_alternate,
                              size: 48, color: AppTheme.textLight),
                          SizedBox(height: 8),
                          Text('No images added yet',
                              style: TextStyle(color: AppTheme.textMid)),
                        ])))
              else ...[
                Row(children: [
                  const Text('Selected Media',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Text(
                      '${_images.length}/$_maxMedia file${_images.length != 1 ? "s" : ""}',
                      style: const TextStyle(
                          color: AppTheme.textMid, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8),
                  itemCount: _images.length,
                  itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _isVideo(_images[i])
                            ? GestureDetector(
                                onTap: kIsWeb
                                    ? null
                                    : () => _previewVideo(_images[i].path),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Container(color: Colors.black87),
                                    const Center(
                                        child: Icon(Icons.play_circle_fill,
                                            color: Colors.white,
                                            size: 42)),
                                  ],
                                ),
                              )
                            : _buildImagePreview(_images[i])),
                    if (i == 0)
                      Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('Cover',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)))),
                    Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                            onTap: () => setState(() {
                                  _imageBytes.remove(_images[i].path);
                                  _images.removeAt(i);
                                }),
                            child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14)))),
                  ]),
                ),
              ],
            ]),
          )),
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: ElevatedButton(
                onPressed: _images.isNotEmpty
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PropertyDetailsScreen(
                                images: _images,
                                imageBytes: _imageBytes)))
                    : null,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _images.isNotEmpty
                        ? AppTheme.primary
                        : AppTheme.border),
                child: Text(_images.isNotEmpty
                    ? 'Next: Property Details →'
                    : 'Add at least one photo or video'),
              )),
        ]),
      );
}

class _SrcBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SrcBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary),
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.primary.withOpacity(0.05)),
        child: Column(children: [
          Icon(icon, color: AppTheme.primary, size: 30),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.primary, fontWeight: FontWeight.w600))
        ]),
      ));
}
