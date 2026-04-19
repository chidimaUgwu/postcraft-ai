// lib/screens/splash_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/app_lock_service.dart';
import '../utils/app_theme.dart';
import 'auth/login_screen.dart';
import 'guide/guide_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;

    // Not logged in → straight to login.
    if (user == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Hydrate preferences so theme + app-lock flag are ready before we
    // decide what to show.
    final sp = context.read<SettingsProvider>();
    await sp.load();
    if (!mounted) return;

    // App Lock gate — if enabled, require biometric/PIN before proceeding.
    if (sp.appLockEnabled) {
      final result =
          await AppLockService.authenticate(reason: 'Unlock PostCraft AI');
      if (!mounted) return;
      if (!result.ok) {
        // Failed or cancelled — push to login so they can sign out and in again.
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (result.error != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.error!),
            backgroundColor: AppTheme.error,
          ));
        }
        return;
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );

    // First-time users see the walkthrough automatically, after home loads.
    if (!sp.guideSeen) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const GuideScreen(firstRun: true),
              fullscreenDialog: true),
        );
        if (mounted) await sp.markGuideSeen();
      });
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.primary,
    body: FadeTransition(
      opacity: _fade,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 96, height: 96,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 54)),
        const SizedBox(height: 20),
        const Text('PostCraft AI', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Powered by Firebase & AI', style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 60),
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
      ])),
    ),
  );
}
