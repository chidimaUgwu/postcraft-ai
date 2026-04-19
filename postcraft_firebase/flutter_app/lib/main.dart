// lib/main.dart

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/providers.dart';
import 'screens/splash_screen.dart';
import 'services/app_lock_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before running the app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const PostCraftApp());
}

class PostCraftApp extends StatelessWidget {
  const PostCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => AiProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, s, __) => MaterialApp(
          title: 'PostCraft AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: s.themeMode,
          // AppLockGate wraps every route so the biometric overlay fires on
          // resume when App Lock is enabled.
          builder: (ctx, child) =>
              AppLockGate(child: child ?? const SizedBox.shrink()),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Re-prompts biometric / device-credential auth when the app comes back to
/// the foreground (e.g. after sharing to WhatsApp) so no one who picks up
/// the phone can peek at the app without authenticating.
///
/// Short background trips (under 8 seconds — picking a file, granting a
/// permission) are ignored so the UX stays smooth.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authInFlight = false;
  DateTime? _backgroundedAt;

  static const _grace = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sp = context.read<SettingsProvider>();
    if (!sp.appLockEnabled) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      if (since != null && DateTime.now().difference(since) > _grace) {
        _requestUnlock();
      }
      _backgroundedAt = null;
    }
  }

  Future<void> _requestUnlock() async {
    if (_authInFlight || _locked) return;
    _authInFlight = true;
    setState(() => _locked = true);
    final result =
        await AppLockService.authenticate(reason: 'Unlock PostCraft AI');
    _authInFlight = false;
    if (!mounted) return;
    if (result.ok) {
      setState(() => _locked = false);
    } else {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      context.read<SettingsProvider>().reset();
      setState(() => _locked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      if (_locked)
        Positioned.fill(
          child: Container(
            color: Colors.black87,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.white70, size: 56),
                const SizedBox(height: 14),
                const Text('App Locked',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock'),
                  onPressed: _requestUnlock,
                ),
              ],
            ),
          ),
        ),
    ]);
  }
}
