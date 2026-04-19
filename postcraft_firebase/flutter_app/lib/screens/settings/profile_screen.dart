// lib/screens/settings/profile_screen.dart
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common_widgets.dart';

/// Profile screen — edit display name, change email address (verification
/// required), change password (current password required for re-auth).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _savingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await FirebaseService.updateProfile(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Name updated'),
        backgroundColor: AppTheme.secondary,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not update name: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
    if (mounted) setState(() => _savingName = false);
  }

  Future<void> _openChangePassword() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(),
          fullscreenDialog: true),
    );
  }

  Future<void> _openChangeEmail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const ChangeEmailScreen(),
          fullscreenDialog: true),
    );
  }

  /// Send a verification link to the user\'s CURRENT email address. This
  /// must happen before Firebase will accept a change-email request.
  Future<void> _sendVerification() async {
    try {
      await FirebaseService.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Verification link sent to ${FirebaseAuth.instance.currentUser?.email ?? 'your email'}. Check inbox + spam.'),
        backgroundColor: AppTheme.secondary,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not send verification: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  /// Pull fresh user data from Firebase (use after clicking the verification
  /// link on another device to flip the "verified" chip).
  Future<void> _refreshUser() async {
    await FirebaseService.reloadCurrentUser();
    if (!mounted) return;
    setState(() {}); // trigger rebuild to reflect the refreshed emailVerified flag
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initial = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName![0].toUpperCase()
        : (user?.email?[0].toUpperCase() ?? 'U');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), leading: const BackButton()),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + identity card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.accent,
                    child: Text(initial,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.ink))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'No name set',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                      const SizedBox(height: 4),
                      Text(user?.email ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      if (user?.emailVerified == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('✓ Email verified',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Email not verified',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Display name ──────────────────────────────────
            const SectionLabel('Display Name'),
            AppTextField(
              controller: _nameCtrl,
              label: 'Name',
              hint: 'Your full name',
            ),
            const SizedBox(height: 10),
            _savingName
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveName,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save name'),
                    ),
                  ),

            const SizedBox(height: 28),

            // ── Email ─────────────────────────────────────────
            const SectionLabel('Email',
                subtitle:
                    'Verify your current email first — Firebase requires this before it will let you change to a new email.'),

            // Verification banner (only when not verified).
            if (user?.emailVerified != true) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.18),
                  border: Border.all(color: AppTheme.secondary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.secondary, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Your email is not verified yet.',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                        'Verify it so you can change email, reset your password reliably, and keep your account secure.',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textMid)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sendVerification,
                          icon: const Icon(Icons.mark_email_read, size: 18),
                          label: const Text('Send verify link'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 42),
                            backgroundColor: AppTheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _refreshUser,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('I verified'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          minimumSize: const Size(0, 42),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openChangeEmail,
                icon: const Icon(Icons.alternate_email, size: 18),
                label: const Text('Change email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Password ──────────────────────────────────────
            const SectionLabel('Password',
                subtitle:
                    'Requires your current password. Use a strong new password.'),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openChangePassword,
                icon: const Icon(Icons.lock_reset, size: 18),
                label: const Text('Change password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared strong-password helpers
// ─────────────────────────────────────────────────────────────────────────

bool _hasMinLength(String v) => v.length >= 8;
bool _hasUpper(String v) => RegExp(r'[A-Z]').hasMatch(v);
bool _hasLower(String v) => RegExp(r'[a-z]').hasMatch(v);
bool _hasDigit(String v) => RegExp(r'\d').hasMatch(v);
bool _hasSpecial(String v) =>
    RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\];/\\`~]').hasMatch(v);

String? _passwordIssue(String? v) {
  if (v == null || v.isEmpty) return 'New password is required';
  if (!_hasMinLength(v)) return 'At least 8 characters';
  if (!_hasUpper(v)) return 'Add an uppercase letter';
  if (!_hasLower(v)) return 'Add a lowercase letter';
  if (!_hasDigit(v)) return 'Add a number';
  if (!_hasSpecial(v)) return 'Add a special character';
  return null;
}

String _authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'wrong-password':
    case 'invalid-credential':
      return 'Current password is incorrect.';
    case 'weak-password':
      return 'New password is too weak.';
    case 'email-already-in-use':
      return 'That email is already registered.';
    case 'invalid-email':
      return 'That email is not valid.';
    case 'requires-recent-login':
      return 'Please sign out and back in, then try again.';
    default:
      return e.message ?? 'Authentication error (${e.code}).';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Change Password — full-screen route (cleaner lifecycle than AlertDialog)
// ─────────────────────────────────────────────────────────────────────────

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Drive the password-rules checklist live as the user types.
    _nextCtrl.addListener(_onNextChanged);
  }

  void _onNextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nextCtrl.removeListener(_onNextChanged);
    _currentCtrl.dispose();
    _nextCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await FirebaseService.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _nextCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🔐 Password changed'),
        backgroundColor: AppTheme.secondary,
      ));
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_authErrorMessage(e)),
        backgroundColor: AppTheme.error,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not change password: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        leading: const CloseButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_reset,
                  size: 56, color: AppTheme.primary),
              const SizedBox(height: 8),
              const Text(
                  'Enter your current password, then pick a strong new one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMid)),
              const SizedBox(height: 24),

              AppTextField(
                controller: _currentCtrl,
                label: 'Current password',
                hint: '••••••••',
                obscureText: _obscureCurrent,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
                suffix: IconButton(
                  icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppTheme.textMid),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _nextCtrl,
                label: 'New password',
                hint: '••••••••',
                obscureText: _obscureNew,
                validator: _passwordIssue,
                suffix: IconButton(
                  icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textMid),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              const SizedBox(height: 10),
              _PasswordRules(password: _nextCtrl.text),
              const SizedBox(height: 16),

              AppTextField(
                controller: _confirmCtrl,
                label: 'Confirm new password',
                hint: '••••••••',
                obscureText: _obscureNew,
                validator: (v) =>
                    v != _nextCtrl.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 24),

              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('Update password'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordRules extends StatefulWidget {
  final String password;
  const _PasswordRules({required this.password});
  @override
  State<_PasswordRules> createState() => _PasswordRulesState();
}

class _PasswordRulesState extends State<_PasswordRules> {
  // Rebuild whenever the parent rebuilds with a new password string — the
  // parent does that via setState on every keystroke of the new-password
  // field (see below, we wire a listener there).
  @override
  Widget build(BuildContext context) {
    final p = widget.password;
    final rules = <({String label, bool ok})>[
      (label: 'At least 8 characters', ok: _hasMinLength(p)),
      (label: 'One uppercase letter', ok: _hasUpper(p)),
      (label: 'One lowercase letter', ok: _hasLower(p)),
      (label: 'One number', ok: _hasDigit(p)),
      (label: 'One special character (!@#\$…)', ok: _hasSpecial(p)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rules
          .map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Icon(r.ok ? Icons.check_circle : Icons.circle_outlined,
                      size: 14,
                      color: r.ok ? AppTheme.secondary : AppTheme.textLight),
                  const SizedBox(width: 6),
                  Text(r.label,
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              r.ok ? AppTheme.secondary : AppTheme.textMid)),
                ]),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Change Email — full-screen route
// ─────────────────────────────────────────────────────────────────────────

class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});
  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final newEmail = _emailCtrl.text.trim();
    try {
      await FirebaseService.changeEmail(
        currentPassword: _passCtrl.text,
        newEmail: newEmail,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '📧 Verification sent to $newEmail. Click the link to confirm the change.'),
        backgroundColor: AppTheme.secondary,
        duration: const Duration(seconds: 5),
      ));
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_authErrorMessage(e)),
        backgroundColor: AppTheme.error,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not change email: $e'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change email'),
        leading: const CloseButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.alternate_email,
                  size: 56, color: AppTheme.primary),
              const SizedBox(height: 8),
              Text('Currently: $currentEmail',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMid)),
              const SizedBox(height: 24),

              AppTextField(
                controller: _emailCtrl,
                label: 'New email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _passCtrl,
                label: 'Current password',
                hint: '••••••••',
                obscureText: _obscure,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
                suffix: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.textMid),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: const [
                  Icon(Icons.info_outline,
                      size: 18, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Firebase will send a verification link to the new address. The change only takes effect once you click the link.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textDark))),
                ]),
              ),
              const SizedBox(height: 24),

              if (_busy)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.send),
                  label: const Text('Send verification link'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
