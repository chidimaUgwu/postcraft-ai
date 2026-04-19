// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
            'DefaultFirebaseOptions not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCyqybO3fkE9CJyd9C8alF-xxUqVTHraOI',
    appId: '1:563487825141:web:87a4bf648fd86a9a1979bc',
    messagingSenderId: '563487825141',
    projectId: 'postcraft-ai-c3180',
    authDomain: 'postcraft-ai-c3180.firebaseapp.com',
    storageBucket: 'postcraft-ai-c3180.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCWC9zpKeWNssS7-O0jKXYK4gQ-VCUk9yI',
    appId: '1:563487825141:android:192a7a8b2c1f16331979bc',
    messagingSenderId: '563487825141',
    projectId: 'postcraft-ai-c3180',
    storageBucket: 'postcraft-ai-c3180.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCyqybO3fkE9CJyd9C8alF-xxUqVTHraOI',
    appId: '1:563487825141:web:87a4bf648fd86a9a1979bc',
    messagingSenderId: '563487825141',
    projectId: 'postcraft-ai-c3180',
    storageBucket: 'postcraft-ai-c3180.firebasestorage.app',
    iosBundleId: 'com.postcraft.ai',
  );
}
