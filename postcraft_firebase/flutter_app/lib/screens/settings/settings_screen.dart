// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../services/app_lock_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';
import '../guide/guide_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _businessLocationCtrl = TextEditingController();
  String _platform = 'whatsapp';
  String _tone = 'professional';
  bool _loading = true;
  bool _saving = false;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await FirebaseService.getSettings();
    if (!mounted) return;
    setState(() {
      _apiKeyCtrl.text = s['openaiApiKey'] ?? '';
      _phoneCtrl.text = s['phoneNumber'] ?? '';
      _whatsappCtrl.text = s['whatsappNumber'] ?? '';
      _websiteCtrl.text = s['website'] ?? '';
      _businessNameCtrl.text = s['businessName'] ?? '';
      _businessLocationCtrl.text = s['businessLocation'] ?? '';
      _platform = s['defaultPlatform'] ?? 'whatsapp';
      _tone = s['tonePreference'] ?? 'professional';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirebaseService.updateSettings({
        'openaiApiKey': _apiKeyCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'whatsappNumber': _whatsappCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'businessName': _businessNameCtrl.text.trim(),
        'businessLocation': _businessLocationCtrl.text.trim(),
        'defaultPlatform': _platform,
        'tonePreference': _tone,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Settings saved!'),
        backgroundColor: AppTheme.secondary,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
    setState(() => _saving = false);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<PostsProvider>().stopListening();
      context.read<SettingsProvider>().reset();
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  /// Toggle biometric/device-credential app lock. Confirms with an actual
  /// auth prompt before flipping the preference so the user never ends up
  /// locked out by a device that can\'t authenticate.
  Future<void> _toggleAppLock(bool enable) async {
    final sp = context.read<SettingsProvider>();
    if (enable) {
      final reason = await AppLockService.unavailableReason();
      if (!mounted) return;
      if (reason != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reason),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 5),
        ));
        return;
      }
      final result = await AppLockService.authenticate(
          reason: 'Confirm to enable App Lock');
      if (!mounted) return;
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.error ?? 'App Lock not enabled.'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 5),
        ));
        return;
      }
    }
    await sp.setAppLockEnabled(enable);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enable ? '🔒 App Lock enabled' : 'App Lock disabled'),
      backgroundColor: AppTheme.secondary,
    ));
  }

  /// Full account deletion: re-auth with password, wipe every post + caption
  /// + setting + user doc, then delete the Firebase Auth user. Irreversible.
  Future<void> _deleteAccount() async {
    final passCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This permanently deletes your account, every post, every caption, and every setting. This cannot be undone.\n\nEnter your password to confirm.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete forever',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );
    if (confirmed != true) {
      passCtrl.dispose();
      return;
    }
    final password = passCtrl.text;
    passCtrl.dispose();

    try {
      await FirebaseService.reauthenticate(password);
      await FirebaseService.deleteAccount();
      if (!mounted) return;
      context.read<PostsProvider>().stopListening();
      context.read<SettingsProvider>().reset();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account deleted.'),
        backgroundColor: AppTheme.secondary,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delete failed: ${e.toString().replaceAll('Exception:', '').trim()}'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  void _openGuide() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const GuideScreen()));
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _websiteCtrl.dispose();
    _businessNameCtrl.dispose();
    _businessLocationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Profile card (tap to edit) ──────────────────
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primary,
                                  AppTheme.primaryDeep
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 28,
                                backgroundColor: AppTheme.accent,
                                child: Text(
                                    user?.displayName?[0].toUpperCase() ?? 'U',
                                    style: const TextStyle(
                                        color: AppTheme.ink,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold))),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(user?.displayName ?? 'No name set',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(user?.email ?? '',
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13)),
                                  const SizedBox(height: 6),
                                  const Row(children: [
                                    Icon(Icons.edit,
                                        size: 12, color: Colors.white70),
                                    SizedBox(width: 4),
                                    Text('Tap to edit profile',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500)),
                                  ]),
                                ])),
                            const Icon(Icons.chevron_right,
                                color: Colors.white70),
                          ]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Gemini API Key ────────────────────────────────
                    const SectionLabel('Gemini API Key',
                        subtitle: 'Required for AI caption generation (FREE)'),
                    AppTextField(
                      controller: _apiKeyCtrl,
                      label: 'Your Gemini API Key',
                      hint: 'AIza…',
                      obscureText: !_showKey,
                      suffix: IconButton(
                        icon: Icon(
                            _showKey ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.textMid),
                        onPressed: () => setState(() => _showKey = !_showKey),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '🔒 Stored securely. Used to generate AI captions.\n'
                      'Get your FREE key at: aistudio.google.com/apikey',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMid),
                    ),

                    const SizedBox(height: 24),

                    // ── Default Platform ──────────────────────────────
                    const SectionLabel('Default Platform'),
                    AppDropdown<String>(
                      label: 'Default for new posts',
                      value: _platform,
                      items: const [
                        DropdownMenuItem(
                            value: 'whatsapp', child: Text('💬 WhatsApp')),
                        DropdownMenuItem(
                            value: 'instagram', child: Text('📸 Instagram')),
                        DropdownMenuItem(
                            value: 'facebook', child: Text('👍 Facebook')),
                        DropdownMenuItem(
                            value: 'twitter', child: Text('🐦 Twitter / X')),
                        DropdownMenuItem(
                            value: 'linkedin', child: Text('💼 LinkedIn')),
                      ],
                      onChanged: (v) => setState(() => _platform = v!),
                    ),

                    const SizedBox(height: 24),

                    // ── Tone ──────────────────────────────────────────
                    const SectionLabel('Caption Tone'),
                    AppDropdown<String>(
                      label: 'Preferred AI writing tone',
                      value: _tone,
                      items: const [
                        DropdownMenuItem(
                            value: 'professional', child: Text('Professional')),
                        DropdownMenuItem(
                            value: 'casual', child: Text('Casual & Friendly')),
                        DropdownMenuItem(
                            value: 'luxury', child: Text('Luxury & Premium')),
                        DropdownMenuItem(
                            value: 'urgent',
                            child: Text('Urgent & Persuasive')),
                      ],
                      onChanged: (v) => setState(() => _tone = v!),
                    ),

                    const SizedBox(height: 28),

                    // ── Contact Info for Captions ────────────────────
                    const SectionLabel('Your Contact Info',
                        subtitle: 'Included in generated captions so clients can reach you'),
                    AppTextField(
                      controller: _businessNameCtrl,
                      label: 'Business / Agency Name',
                      hint: 'e.g. Prime Realty Lagos',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      hint: 'e.g. +234 801 234 5678',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _whatsappCtrl,
                      label: 'WhatsApp Number (if different)',
                      hint: 'e.g. +234 901 234 5678',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _businessLocationCtrl,
                      label: 'Business Location / Office Address',
                      hint: 'e.g. Lekki Phase 1, Lagos',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _websiteCtrl,
                      label: 'Website or Social Media Link',
                      hint: 'e.g. www.primerealty.ng',
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'These details will appear in your generated captions automatically.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMid),
                    ),

                    const SizedBox(height: 30),

                    // ── App Preferences ───────────────────────────────
                    const SectionLabel('App Preferences',
                        subtitle:
                            'Language, currency, and country shape every caption the AI writes.'),

                    Consumer<SettingsProvider>(
                      builder: (_, sp, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Theme mode
                          const Text('Appearance',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode, size: 16),
                                  label: Text('Light')),
                              ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode, size: 16),
                                  label: Text('Dark')),
                              ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.phone_android, size: 16),
                                  label: Text('System')),
                            ],
                            selected: {sp.themeMode},
                            onSelectionChanged: (s) =>
                                sp.setThemeMode(s.first),
                          ),
                          const SizedBox(height: 18),

                          // Language
                          AppDropdown<String>(
                            label: 'Language',
                            value: sp.language,
                            items: AppLanguages.byCode.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key, child: Text(e.value)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) sp.setLanguage(v);
                            },
                          ),
                          const SizedBox(height: 12),

                          // Currency
                          AppDropdown<String>(
                            label: 'Currency',
                            value: sp.currency,
                            items: AppCurrencies.byCode.entries
                                .map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value['label']!)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) sp.setCurrency(v);
                            },
                          ),
                          const SizedBox(height: 12),

                          // Base country
                          AppDropdown<String>(
                            label: 'Base Country',
                            value: sp.country,
                            items: AppCountries.list
                                .map((c) => DropdownMenuItem(
                                    value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) sp.setCountry(v);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _saving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Settings'),
                          ),

                    const SizedBox(height: 30),

                    // ── Security ──────────────────────────────────────
                    const SectionLabel('Security',
                        subtitle:
                            'Protect the app with your phone\'s fingerprint, Face ID, or PIN.'),

                    Consumer<SettingsProvider>(
                      builder: (_, sp, __) => Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SwitchListTile.adaptive(
                          value: sp.appLockEnabled,
                          onChanged: _toggleAppLock,
                          secondary: const Icon(Icons.fingerprint,
                              color: AppTheme.primary),
                          title: const Text('App Lock',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          subtitle: const Text(
                              'Require biometric / screen-lock credential to open PostCraft',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMid)),
                          activeTrackColor: AppTheme.secondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Help ──────────────────────────────────────────
                    const SectionLabel('Help'),

                    OutlinedButton.icon(
                      onPressed: _openGuide,
                      icon: const Icon(Icons.menu_book, size: 18),
                      label: const Text('How to use PostCraft'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Account ───────────────────────────────────────
                    const SectionLabel('Account'),

                    OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: AppTheme.textMid),
                      label: const Text('Sign Out',
                          style: TextStyle(color: AppTheme.textMid)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      onPressed: _deleteAccount,
                      icon: const Icon(Icons.delete_forever,
                          color: AppTheme.error),
                      label: const Text('Delete Account',
                          style: TextStyle(color: AppTheme.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.error),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ]),
            ),
    );
  }
}

