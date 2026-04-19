// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

/// App-wide user preferences. Loaded from Firestore after login,
/// saved back whenever the user edits them in Settings. Drives theme,
/// default currency, language, base country — all threaded into the
/// AI prompt so captions match the user\'s region.
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _currency = 'NGN';
  String _language = 'en';
  String _country = 'Nigeria';
  bool _appLockEnabled = false;
  bool _guideSeen = false;

  ThemeMode get themeMode => _themeMode;
  String get currency => _currency;
  String get language => _language;
  String get country => _country;
  bool get appLockEnabled => _appLockEnabled;
  bool get guideSeen => _guideSeen;

  /// Hydrate from Firestore (called after login / on app start).
  Future<void> load() async {
    try {
      final s = await FirebaseService.getSettings();
      final mode = s['themeMode'] as String? ?? 'system';
      _themeMode = mode == 'dark'
          ? ThemeMode.dark
          : mode == 'light'
              ? ThemeMode.light
              : ThemeMode.system;
      _currency = s['currency'] as String? ?? 'NGN';
      _language = s['language'] as String? ?? 'en';
      _country = s['country'] as String? ?? 'Nigeria';
      _appLockEnabled = s['appLockEnabled'] as bool? ?? false;
      _guideSeen = s['guideSeen'] as bool? ?? false;
      notifyListeners();
    } catch (_) {
      // Not logged in yet / no settings doc — keep defaults.
    }
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLockEnabled = value;
    notifyListeners();
    await FirebaseService.updateSettings({'appLockEnabled': value});
  }

  Future<void> markGuideSeen() async {
    _guideSeen = true;
    notifyListeners();
    await FirebaseService.updateSettings({'guideSeen': true});
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await FirebaseService.updateSettings({
      'themeMode': mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system',
    });
  }

  Future<void> setCurrency(String code) async {
    _currency = code;
    notifyListeners();
    await FirebaseService.updateSettings({'currency': code});
  }

  Future<void> setLanguage(String code) async {
    _language = code;
    notifyListeners();
    await FirebaseService.updateSettings({'language': code});
  }

  Future<void> setCountry(String country) async {
    _country = country;
    notifyListeners();
    await FirebaseService.updateSettings({'country': country});
  }

  void reset() {
    _themeMode = ThemeMode.system;
    _currency = 'NGN';
    _language = 'en';
    _country = 'Nigeria';
    _appLockEnabled = false;
    _guideSeen = false;
    notifyListeners();
  }
}

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuth => _user != null;

  AuthProvider() {
    FirebaseService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> register(String name, String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await FirebaseService.register(name, email, password);
      _loading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _authMessage(e.code, e.message);
      _loading = false;
      notifyListeners();
      return false;
    } on FirebaseException catch (e) {
      _error = _authMessage(e.code, e.message);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _friendlyError(e.toString());
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await FirebaseService.login(email, password);
      _loading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _authMessage(e.code, e.message);
      _loading = false;
      notifyListeners();
      return false;
    } on FirebaseException catch (e) {
      _error = _authMessage(e.code, e.message);
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = _friendlyError(e.toString());
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() => FirebaseService.logout();

  String _friendlyError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('api-key-not-valid') ||
        lower.contains('api key not valid')) {
      return 'Firebase is not configured correctly. Please check your API key.';
    }
    if (lower.contains('network') || lower.contains('socketexception')) {
      return 'No internet connection. Check your network.';
    }
    return 'Something went wrong. Please try again.';
  }

  String _authMessage(String code, [String? message]) {
    // Normalize code: Firebase sometimes appends extra text with dots
    final normalizedCode =
        code.split('.').first.toLowerCase().replaceAll(' ', '-');
    switch (normalizedCode) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console.';
      case 'configuration-not-found':
      case 'api-key-not-valid':
        return 'Firebase is not configured correctly. Please check your API key.';
      default:
        return message ?? 'Authentication failed. Please try again.';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/providers/posts_provider.dart

// lib/providers/posts_provider.dart (updated section only)

class PostsProvider extends ChangeNotifier {
  List<PostModel> _posts = [];
  bool _loading = false;
  String? _error;
  StreamSubscription? _sub;

  List<PostModel> get posts => _posts;
  bool get loading => _loading;
  String? get error => _error;

  List<PostModel> byStatus(String s) =>
      _posts.where((p) => p.status == s).toList();
  List<PostModel> search(String q) => _posts
      .where((p) => p.title.toLowerCase().contains(q.toLowerCase()))
      .toList();

  /// Start listening to Firestore in real-time
  void startListening() {
    _sub?.cancel();
    _loading = true;
    notifyListeners();
    _sub = FirebaseService.postsStream().listen(
      (posts) {
        _posts = posts;
        _loading = false;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _loading = false;
        notifyListeners();
      },
    );
  }

  void stopListening() => _sub?.cancel();

  /// Create post + save images
  Future<PostModel?> createPost(
      Map<String, dynamic> data, List<XFile> images) async {
    _error = null;
    try {
      final postId = await FirebaseService.createPost(data);
      if (images.isNotEmpty) {
        // Save images locally instead of uploading to Firebase Storage
        await FirebaseService.saveImages(postId, images);
      }
      // Fetch the freshly created post
      return await FirebaseService.getPost(postId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> updatePost(String postId, Map<String, dynamic> fields) async {
    try {
      await FirebaseService.updatePost(postId, fields);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateStatus(String postId, String status) async {
    try {
      await FirebaseService.updateStatus(postId, status);
      final idx = _posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        _posts[idx].status = status;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await FirebaseService.deletePost(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// class PostsProvider extends ChangeNotifier
// {
//   List<PostModel> _posts = [];
//   bool    _loading = false;
//   String? _error;
//   StreamSubscription? _sub;
//
//   List<PostModel> get posts   => _posts;
//   bool            get loading => _loading;
//   String?         get error   => _error;
//
//   List<PostModel> byStatus(String s) => _posts.where((p) => p.status == s).toList();
//   List<PostModel> search(String q)   => _posts.where((p) => p.title.toLowerCase().contains(q.toLowerCase())).toList();
//
//   /// Start listening to Firestore in real-time
//   void startListening() {
//     _sub?.cancel();
//     _loading = true; notifyListeners();
//     _sub = FirebaseService.postsStream().listen(
//       (posts) { _posts = posts; _loading = false; notifyListeners(); },
//       onError: (e) { _error = e.toString(); _loading = false; notifyListeners(); },
//     );
//   }
//
//   void stopListening() => _sub?.cancel();
//
//   /// Create post + upload images, returns the new PostModel
//   Future<PostModel?> createPost(Map<String, dynamic> data, List<File> images) async {
//     _error = null;
//     try {
//       final postId = await FirebaseService.createPost(data);
//       if (images.isNotEmpty) {
//         await FirebaseService.uploadImages(postId, images);
//       }
//       // Fetch the freshly created post
//       return await FirebaseService.getPost(postId);
//     } catch (e) {
//       _error = e.toString();
//       notifyListeners();
//       return null;
//     }
//   }
//
//   Future<void> updateStatus(String postId, String status) async {
//     try {
//       await FirebaseService.updateStatus(postId, status);
//       final idx = _posts.indexWhere((p) => p.id == postId);
//       if (idx != -1) { _posts[idx].status = status; notifyListeners(); }
//     } catch (e) { _error = e.toString(); notifyListeners(); }
//   }
//
//   Future<bool> deletePost(String postId) async {
//     try {
//       await FirebaseService.deletePost(postId);
//       return true;
//     } catch (e) {
//       _error = e.toString(); notifyListeners();
//       return false;
//     }
//   }
//
//   @override
//   void dispose() { _sub?.cancel(); super.dispose(); }
// }

// ─────────────────────────────────────────────────────────────────────────────
// lib/providers/ai_provider.dart
class AiProvider extends ChangeNotifier {
  final Map<String, List<CaptionVersionModel>> _versions = {};
  final Map<String, StreamSubscription> _subs = {};
  bool _generating = false;
  String? _error;

  bool get generating => _generating;
  String? get error => _error;

  List<CaptionVersionModel> versionsFor(String platform) =>
      _versions[platform] ?? [];

  CaptionVersionModel? selectedFor(String platform) {
    final list = _versions[platform] ?? [];
    try {
      return list.firstWhere((v) => v.isSelected);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  /// Start listening to caption versions for a post + platform in real-time
  void listenToPlatform(String postId, String platform) {
    _subs[platform]?.cancel();
    _subs[platform] =
        FirebaseService.captionVersionsStream(postId, platform).listen(
      (versions) {
        _versions[platform] = versions;
        notifyListeners();
      },
    );
  }

  void stopListening(String platform) {
    _subs[platform]?.cancel();
  }

  void stopAll() {
    for (final s in _subs.values) {
      s.cancel();
    }
    _subs.clear();
  }

  /// Generate a new caption — NEVER deletes old versions
  Future<bool> generate({
    required String postId,
    required String platform,
    required Map<String, dynamic> propertyData,
  }) async {
    _generating = true;
    _error = null;
    notifyListeners();
    try {
      await FirebaseService.generateCaption(
        postId: postId,
        platform: platform,
        propertyData: propertyData,
      );
      // Firestore stream will auto-update _versions[platform]
      _generating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      _generating = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> selectVersion(
      String postId, String platform, String captionId) async {
    // Optimistic local update
    final list = _versions[platform] ?? [];
    for (final v in list) {
      v.isSelected = v.id == captionId;
    }
    notifyListeners();
    // Persist to Firestore
    await FirebaseService.selectCaptionVersion(postId, platform, captionId);
  }

  Future<void> editCaption(
      String captionId, String platform, String newText) async {
    final list = _versions[platform] ?? [];
    final idx = list.indexWhere((v) => v.id == captionId);
    if (idx != -1) {
      list[idx].captionText = newText;
      notifyListeners();
    }
    await FirebaseService.updateCaptionText(captionId, newText);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }
}
