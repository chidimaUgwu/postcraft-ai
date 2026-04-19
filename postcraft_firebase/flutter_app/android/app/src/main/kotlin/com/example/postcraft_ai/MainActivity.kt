package com.example.postcraft_ai

import io.flutter.embedding.android.FlutterFragmentActivity

// MUST be FlutterFragmentActivity (not FlutterActivity) so that `local_auth`
// can attach its biometric prompt. With plain FlutterActivity the OS auth
// dialog silently fails and App Lock can\'t be enabled.
class MainActivity : FlutterFragmentActivity()
