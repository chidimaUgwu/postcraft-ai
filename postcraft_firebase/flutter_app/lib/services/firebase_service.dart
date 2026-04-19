// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import 'local_storage_service.dart';
import 'openai_service.dart' show GeminiService;

class FirebaseService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  // ── Convenience getters ───────────────────────────────────────────────────
  static User? get currentUser => _auth.currentUser;
  static String get uid => _auth.currentUser!.uid;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─────────────────────────────────────────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────────────────────────────────────────

  static Future<UserCredential> register(
      String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(name);

    // Create user document + default settings in Firestore
    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(cred.user!.uid), {
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_firestore.collection('settings').doc(cred.user!.uid), {
      'openaiApiKey': '',
      'defaultPlatform': 'whatsapp',
      'tonePreference': 'professional',
    });
    await batch.commit();

    return cred;
  }

  static Future<UserCredential> login(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  static Future<void> logout() => _auth.signOut();

  static Future<void> updateProfile(String name) async {
    await _auth.currentUser!.updateDisplayName(name);
    await _firestore.collection('users').doc(uid).update({'name': name});
  }

  /// Send a Firebase password-reset email to the given address. Returns
  /// true on success; on failure throws a FirebaseAuthException the caller
  /// can translate into a user-friendly message.
  static Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Send a verification link to the signed-in user\'s current email.
  /// Firebase requires the account email to be verified before many
  /// sensitive actions (like changing email via verifyBeforeUpdateEmail).
  static Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user.');
    await user.reload();
    if (user.emailVerified) return; // already verified — nothing to do
    await user.sendEmailVerification();
  }

  /// Refresh the signed-in user\'s data from Firebase (useful after they
  /// click an email verification link on another device).
  static Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  /// Change the signed-in user\'s password. Requires their current password
  /// for re-auth (Firebase rule for sensitive ops).
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No signed-in user.');
    }
    final cred = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  /// Change the signed-in user\'s email. Requires current password for re-auth.
  /// Firebase will send a verification email to the NEW address; the change
  /// only takes effect once the user clicks the link.
  static Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No signed-in user.');
    }
    final cred = EmailAuthProvider.credential(
        email: user.email!, password: currentPassword);
    await user.reauthenticateWithCredential(cred);
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POSTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Create a new post document and return its generated ID
  static Future<String> createPost(Map<String, dynamic> data) async {
    final ref = await _firestore.collection('posts').add({
      ...data,
      'userId': uid,
      'imagePaths': [], // Changed from imageUrls
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Real-time stream of all posts for the current user
  static Stream<List<PostModel>> postsStream({String? status}) {
    Query query =
        _firestore.collection('posts').where('userId', isEqualTo: uid);
    if (status != null) query = query.where('status', isEqualTo: status);
    query = query.orderBy('updatedAt', descending: true);

    return query.snapshots().map(
          (snap) => snap.docs.map((d) => PostModel.fromDoc(d)).toList(),
        );
  }

  /// Fetch a single post
  static Future<PostModel?> getPost(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    return doc.exists ? PostModel.fromDoc(doc) : null;
  }

  /// Update any fields on a post
  static Future<void> updatePost(String postId, Map<String, dynamic> fields) =>
      _firestore.collection('posts').doc(postId).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Update just the status (draft / saved / favorite)
  static Future<void> updateStatus(String postId, String status) =>
      updatePost(postId, {'status': status});

  /// Delete post + local images + Firestore data (no Cloud Function needed)
  static Future<void> deletePost(String postId) async {
    // Delete local images first
    await LocalStorageService.deletePostImages(uid, postId);

    // Delete caption versions from Firestore
    final versions = await _firestore
        .collection('caption_versions')
        .where('userId', isEqualTo: uid)
        .where('postId', isEqualTo: postId)
        .get();

    final batch = _firestore.batch();
    for (final doc in versions.docs) {
      batch.delete(doc.reference);
    }

    // Delete the post document
    batch.delete(_firestore.collection('posts').doc(postId));
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMAGES — Local Storage (No Firebase Storage)
  // ─────────────────────────────────────────────────────────────────────────

  /// Save images locally and update Firestore with paths
  static Future<List<String>> saveImages(
      String postId, List<XFile> images) async {
    final imagePaths =
        await LocalStorageService.saveXFiles(images, uid, postId);

    await _firestore.collection('posts').doc(postId).update({
      'imagePaths': FieldValue.arrayUnion(imagePaths),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return imagePaths;
  }

  /// Add more images to existing post
  static Future<List<String>> addImages(
      String postId, List<XFile> images) async {
    final imagePaths =
        await LocalStorageService.saveXFiles(images, uid, postId);

    await _firestore.collection('posts').doc(postId).update({
      'imagePaths': FieldValue.arrayUnion(imagePaths),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return imagePaths;
  }

  /// Remove an image from a post
  static Future<void> removeImage(String postId, String imagePath) async {
    // Delete the local file
    await LocalStorageService.deleteImage(imagePath);

    // Remove from Firestore array
    final postRef = _firestore.collection('posts').doc(postId);
    await postRef.update({
      'imagePaths': FieldValue.arrayRemove([imagePath]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI GENERATION — calls OpenAI directly (no Cloud Function needed)
  // ─────────────────────────────────────────────────────────────────────────

  /// Calls OpenAI API directly and saves the caption to Firestore.
  static Future<Map<String, dynamic>> generateCaption({
    required String postId,
    required String platform,
    required Map<String, dynamic> propertyData,
  }) async {
    // 1. Get the user's Gemini API key from Firestore settings
    final settings = await getSettings();
    final openaiKey = settings['openaiApiKey'] as String? ?? '';
    if (openaiKey.isEmpty) {
      throw Exception('No Gemini API key configured. Add one in Settings.');
    }

    // 2. Call Gemini API directly with contact info and tone
    final user = _auth.currentUser;
    final captionText = await GeminiService.generateCaption(
      apiKey: openaiKey,
      platform: platform,
      propertyData: propertyData,
      tone: settings['tonePreference'] as String? ?? 'professional',
      currency: settings['currency'] as String? ?? 'NGN',
      language: settings['language'] as String? ?? 'en',
      country: settings['country'] as String? ?? 'Nigeria',
      contactInfo: {
        'userName': user?.displayName ?? '',
        'userEmail': user?.email ?? '',
        'phoneNumber': settings['phoneNumber'] ?? '',
        'whatsappNumber': settings['whatsappNumber'] ?? '',
        'website': settings['website'] ?? '',
        'businessName': settings['businessName'] ?? '',
        'businessLocation': settings['businessLocation'] ?? '',
      },
    );

    // 3. Get next generation number for this post + platform
    final versionsQuery = await _firestore
        .collection('caption_versions')
        .where('userId', isEqualTo: uid)
        .where('postId', isEqualTo: postId)
        .where('platform', isEqualTo: platform)
        .orderBy('generationNum', descending: true)
        .limit(1)
        .get();

    final nextGen = versionsQuery.docs.isEmpty
        ? 1
        : ((versionsQuery.docs.first.data()['generationNum'] ?? 0) as int) + 1;

    // 4. Mark previous versions as not selected
    final allSelected = await _firestore
        .collection('caption_versions')
        .where('userId', isEqualTo: uid)
        .where('postId', isEqualTo: postId)
        .where('platform', isEqualTo: platform)
        .where('isSelected', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (final doc in allSelected.docs) {
      batch.update(doc.reference, {'isSelected': false});
    }

    // 5. Save new version
    final newVersionRef = _firestore.collection('caption_versions').doc();
    batch.set(newVersionRef, {
      'id': newVersionRef.id,
      'postId': postId,
      'userId': uid,
      'platform': platform,
      'captionText': captionText,
      'isSelected': true,
      'generationNum': nextGen,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return {
      'success': true,
      'captionId': newVersionRef.id,
      'captionText': captionText,
      'generationNum': nextGen,
      'platform': platform,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAPTION VERSIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Real-time stream of all caption versions for a post + platform
  static Stream<List<CaptionVersionModel>> captionVersionsStream(
      String postId, String platform) {
    return _firestore
        .collection('caption_versions')
        .where('userId', isEqualTo: uid)
        .where('postId', isEqualTo: postId)
        .where('platform', isEqualTo: platform)
        .orderBy('generationNum', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => CaptionVersionModel.fromDoc(d)).toList());
  }

  /// Select a specific caption version (deselects others for same platform)
  static Future<void> selectCaptionVersion(
      String postId, String platform, String captionId) async {
    final batch = _firestore.batch();

    // Deselect all for this post+platform
    final versions = await _firestore
        .collection('caption_versions')
        .where('userId', isEqualTo: uid)
        .where('postId', isEqualTo: postId)
        .where('platform', isEqualTo: platform)
        .get();
    for (final doc in versions.docs) {
      batch.update(doc.reference, {'isSelected': doc.id == captionId});
    }
    await batch.commit();
  }

  /// Edit a caption's text
  static Future<void> updateCaptionText(String captionId, String newText) =>
      _firestore.collection('caption_versions').doc(captionId).update({
        'captionText': newText,
      });

  // ─────────────────────────────────────────────────────────────────────────
  // SETTINGS
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSettings() async {
    final doc = await _firestore.collection('settings').doc(uid).get();
    return doc.exists ? (doc.data() ?? {}) : {};
  }

  static Future<void> updateSettings(Map<String, dynamic> data) => _firestore
      .collection('settings')
      .doc(uid)
      .set(data, SetOptions(merge: true));

  // ─────────────────────────────────────────────────────────────────────────
  // ACCOUNT — re-auth + full delete
  // ─────────────────────────────────────────────────────────────────────────

  /// Re-authenticate the current user with their password. Firebase requires
  /// recent auth for destructive operations like account deletion.
  static Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No signed-in user.');
    }
    final cred =
        EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(cred);
  }

  /// Delete every post (including local images), caption versions, settings,
  /// user doc, and finally the Firebase Auth account itself. Irreversible.
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No signed-in user.');
    final userId = user.uid;

    // 1. All posts for this user → collect IDs for local image cleanup.
    final postsSnap = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .get();
    final postIds = postsSnap.docs.map((d) => d.id).toList();

    // 2. Delete each post\'s local images.
    for (final postId in postIds) {
      await LocalStorageService.deletePostImages(userId, postId);
    }

    // 3. Batch-delete all posts + all caption versions + user docs.
    final captionsSnap = await _firestore
        .collection('caption_versions')
        .where('userId', isEqualTo: userId)
        .get();

    // Firestore batches are capped at 500 writes — chunk if needed.
    final allDocs = [
      ...postsSnap.docs.map((d) => d.reference),
      ...captionsSnap.docs.map((d) => d.reference),
      _firestore.collection('settings').doc(userId),
      _firestore.collection('users').doc(userId),
    ];
    for (var i = 0; i < allDocs.length; i += 400) {
      final batch = _firestore.batch();
      final chunk = allDocs.sublist(
          i, i + 400 > allDocs.length ? allDocs.length : i + 400);
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    // 4. Finally, delete the Auth account. This signs the user out.
    await user.delete();
  }
}

// // lib/services/firebase_service.dart
// // Single class that wraps ALL Firebase interactions.
// // Screens and providers never call Firebase directly — they call this.
//
// import 'dart:io';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_functions/cloud_functions.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_storage/firebase_storage.dart';
// import 'local_storage_service.dart';
// import '../models/models.dart';
//
// class FirebaseService {
//   static final _auth = FirebaseAuth.instance;
//   static final _firestore = FirebaseFirestore.instance;
//   static final _storage = FirebaseStorage.instance;
//   static final _functions = FirebaseFunctions.instance;
//
//   // ── Convenience getters ───────────────────────────────────────────────────
//   static User? get currentUser => _auth.currentUser;
//   static String get uid => _auth.currentUser!.uid;
//   static Stream<User?> get authStateChanges => _auth.authStateChanges();
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // AUTH
//   // ─────────────────────────────────────────────────────────────────────────
//
//   static Future<UserCredential> register(
//       String name, String email, String password) async {
//     final cred = await _auth.createUserWithEmailAndPassword(
//         email: email, password: password);
//     await cred.user!.updateDisplayName(name);
//
//     // Create user document + default settings in Firestore
//     final batch = _firestore.batch();
//     batch.set(_firestore.collection('users').doc(cred.user!.uid), {
//       'name': name,
//       'email': email,
//       'createdAt': FieldValue.serverTimestamp(),
//     });
//     batch.set(_firestore.collection('settings').doc(cred.user!.uid), {
//       'openaiApiKey': '',
//       'defaultPlatform': 'whatsapp',
//       'tonePreference': 'professional',
//     });
//     await batch.commit();
//
//     return cred;
//   }
//
//   static Future<UserCredential> login(String email, String password) =>
//       _auth.signInWithEmailAndPassword(email: email, password: password);
//
//   static Future<void> logout() => _auth.signOut();
//
//   static Future<void> updateProfile(String name) async {
//     await _auth.currentUser!.updateDisplayName(name);
//     await _firestore.collection('users').doc(uid).update({'name': name});
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // POSTS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Create a new post document and return its generated ID
//   static Future<String> createPost(Map<String, dynamic> data) async {
//     final ref = await _firestore.collection('posts').add({
//       ...data,
//       'userId': uid,
//       'imageUrls': [],
//       'status': 'draft',
//       'createdAt': FieldValue.serverTimestamp(),
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//     return ref.id;
//   }
//
//   /// Real-time stream of all posts for the current user
//   static Stream<List<PostModel>> postsStream({String? status}) {
//     Query query =
//         _firestore.collection('posts').where('userId', isEqualTo: uid);
//     if (status != null) query = query.where('status', isEqualTo: status);
//     query = query.orderBy('updatedAt', descending: true);
//
//     return query.snapshots().map(
//           (snap) => snap.docs.map((d) => PostModel.fromDoc(d)).toList(),
//         );
//   }
//
//   /// Fetch a single post
//   static Future<PostModel?> getPost(String postId) async {
//     final doc = await _firestore.collection('posts').doc(postId).get();
//     return doc.exists ? PostModel.fromDoc(doc) : null;
//   }
//
//   /// Update any fields on a post
//   static Future<void> updatePost(String postId, Map<String, dynamic> fields) =>
//       _firestore.collection('posts').doc(postId).update({
//         ...fields,
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//
//   /// Update just the status (draft / saved / favorite)
//   static Future<void> updateStatus(String postId, String status) =>
//       updatePost(postId, {'status': status});
//
//   /// Delete post + all sub-collections via Cloud Function
//   static Future<void> deletePost(String postId) async {
//     final callable = _functions.httpsCallable('deletePost');
//     await callable.call({'postId': postId});
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // IMAGES — Firebase Storage
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Upload multiple images and return their download URLs
//   static Future<List<String>> uploadImages(
//       String postId, List<File> files) async {
//     final urls = <String>[];
//
//     for (int i = 0; i < files.length; i++) {
//       final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
//       final ref = _storage.ref('posts/$uid/$postId/$fileName');
//
//       final task = await ref.putFile(
//         files[i],
//         SettableMetadata(contentType: 'image/jpeg'),
//       );
//       final url = await task.ref.getDownloadURL();
//       urls.add(url);
//     }
//
//     // Update the post's imageUrls array in Firestore
//     await _firestore.collection('posts').doc(postId).update({
//       'imageUrls': FieldValue.arrayUnion(urls),
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//
//     return urls;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // AI GENERATION — calls Firebase Cloud Function
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Calls the generateCaption Cloud Function.
//   /// Returns a map with captionText, captionId, generationNum.
//   /// Old versions are NEVER deleted — only isSelected is toggled.
//   static Future<Map<String, dynamic>> generateCaption({
//     required String postId,
//     required String platform,
//     required Map<String, dynamic> propertyData,
//   }) async {
//     final callable = _functions.httpsCallable(
//       'generateCaption',
//       options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
//     );
//     final result = await callable.call({
//       'postId': postId,
//       'platform': platform,
//       'propertyData': propertyData,
//     });
//     return Map<String, dynamic>.from(result.data);
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // CAPTION VERSIONS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Real-time stream of all caption versions for a post + platform
//   static Stream<List<CaptionVersionModel>> captionVersionsStream(
//       String postId, String platform) {
//     return _firestore
//         .collection('caption_versions')
//         .where('postId', isEqualTo: postId)
//         .where('platform', isEqualTo: platform)
//         .orderBy('generationNum', descending: true)
//         .snapshots()
//         .map((snap) =>
//             snap.docs.map((d) => CaptionVersionModel.fromDoc(d)).toList());
//   }
//
//   /// Select a specific caption version (deselects others for same platform)
//   static Future<void> selectCaptionVersion(
//       String postId, String platform, String captionId) async {
//     final batch = _firestore.batch();
//
//     // Deselect all for this post+platform
//     final versions = await _firestore
//         .collection('caption_versions')
//         .where('postId', isEqualTo: postId)
//         .where('platform', isEqualTo: platform)
//         .get();
//     for (final doc in versions.docs) {
//       batch.update(doc.reference, {'isSelected': doc.id == captionId});
//     }
//     await batch.commit();
//   }
//
//   /// Edit a caption's text locally and persist to Firestore
//   static Future<void> updateCaptionText(String captionId, String newText) =>
//       _firestore.collection('caption_versions').doc(captionId).update({
//         'captionText': newText,
//       });
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // SETTINGS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   static Future<Map<String, dynamic>> getSettings() async {
//     final doc = await _firestore.collection('settings').doc(uid).get();
//     return doc.exists ? (doc.data() ?? {}) : {};
//   }
//
//   static Future<void> updateSettings(Map<String, dynamic> data) => _firestore
//       .collection('settings')
//       .doc(uid)
//       .set(data, SetOptions(merge: true));
// }
