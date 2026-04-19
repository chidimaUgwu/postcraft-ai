// lib/services/local_storage_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class LocalStorageService {
  static const String _postsFolder = 'posts';

  // Get the app's documents directory (mobile only)
  static Future<Directory> _getAppDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final postsDir = Directory(path.join(appDir.path, _postsFolder));
    if (!await postsDir.exists()) {
      await postsDir.create(recursive: true);
    }
    return postsDir;
  }

  // Save picked XFile images locally (mobile) or return paths (web)
  static Future<List<String>> saveXFiles(
      List<XFile> images, String userId, String postId) async {
    if (kIsWeb) {
      // On web, we can't save to local filesystem — just return the blob paths
      return images.map((img) => img.path).toList();
    }

    final List<String> savedPaths = [];
    final postsDir = await _getAppDirectory();
    final userDir = Directory(path.join(postsDir.path, userId));
    if (!await userDir.exists()) {
      await userDir.create();
    }

    final postDir = Directory(path.join(userDir.path, postId));
    if (!await postDir.exists()) {
      await postDir.create();
    }

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      // Preserve the original file extension so videos stay videos.
      // Fall back to .jpg if the picker gave us no extension.
      final rawExt = path.extension(image.path).toLowerCase();
      final ext = rawExt.isNotEmpty ? rawExt : '.jpg';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i$ext';
      final destPath = path.join(postDir.path, fileName);

      // Read bytes from XFile and write to destination
      final bytes = await image.readAsBytes();
      final savedFile = File(destPath);
      await savedFile.writeAsBytes(bytes);
      savedPaths.add(savedFile.path);
    }

    return savedPaths;
  }

  // Load image from local path (mobile only)
  static Future<File?> loadImage(String imagePath) async {
    if (kIsWeb) return null;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Delete all images for a post (mobile only)
  static Future<void> deletePostImages(String userId, String postId) async {
    if (kIsWeb) return;
    try {
      final postsDir = await _getAppDirectory();
      final postDir = Directory(path.join(postsDir.path, userId, postId));
      if (await postDir.exists()) {
        await postDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting images: $e');
    }
  }

  // Delete a single image (mobile only)
  static Future<void> deleteImage(String imagePath) async {
    if (kIsWeb) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
    }
  }

  // Get all images for a user's post (mobile only)
  static Future<List<File>> getPostImages(
      String userId, String postId) async {
    if (kIsWeb) return [];
    final List<File> images = [];
    try {
      final postsDir = await _getAppDirectory();
      final postDir = Directory(path.join(postsDir.path, userId, postId));
      if (await postDir.exists()) {
        final files = await postDir.list().toList();
        const mediaExts = {
          '.jpg', '.jpeg', '.png', '.webp', '.gif',
          '.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v',
        };
        for (var file in files) {
          if (file is File &&
              mediaExts.contains(path.extension(file.path).toLowerCase())) {
            images.add(file);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading images: $e');
    }
    return images;
  }

  // Clean up orphaned images (mobile only)
  static Future<void> cleanupOrphanedImages(
      String userId, Set<String> existingPostIds) async {
    if (kIsWeb) return;
    try {
      final postsDir = await _getAppDirectory();
      final userDir = Directory(path.join(postsDir.path, userId));
      if (await userDir.exists()) {
        final postDirs = await userDir.list().toList();
        for (var dir in postDirs) {
          if (dir is Directory) {
            final postId = path.basename(dir.path);
            if (!existingPostIds.contains(postId)) {
              await dir.delete(recursive: true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up images: $e');
    }
  }
}

void debugPrint(String message) {
  assert(() {
    // ignore: avoid_print
    print(message);
    return true;
  }());
}
