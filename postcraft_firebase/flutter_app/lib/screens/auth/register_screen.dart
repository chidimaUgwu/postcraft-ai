// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  bool _loading = false, _obscure = true;

  @override
  void initState() {
    super.initState();
    // Drive the live strength checklist as the user types.
    _passCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  static bool _hasMinLength(String v) => v.length >= 8;
  static bool _hasUpper(String v) => RegExp(r'[A-Z]').hasMatch(v);
  static bool _hasLower(String v) => RegExp(r'[a-z]').hasMatch(v);
  static bool _hasDigit(String v) => RegExp(r'\d').hasMatch(v);
  static bool _hasSpecial(String v) =>
      RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\];/\\`~]').hasMatch(v);

  /// Returns the first rule that isn\'t met, or null if the password is strong.
  String? _passwordIssue(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (!_hasMinLength(v)) return 'At least 8 characters';
    if (!_hasUpper(v)) return 'Add at least one uppercase letter';
    if (!_hasLower(v)) return 'Add at least one lowercase letter';
    if (!_hasDigit(v)) return 'Add at least one number';
    if (!_hasSpecial(v)) return 'Add at least one special character (!@#\$…)';
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await context.read<AuthProvider>().register(
        _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      // Force the user through Login after signing up — do NOT jump straight
      // to Home. This guarantees credentials are memorised and verifies the
      // password works before granting access.
      await FirebaseService.logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Account created! Please log in to continue.'),
        backgroundColor: AppTheme.secondary,
        duration: Duration(seconds: 3),
      ));
      Navigator.pop(context, _emailCtrl.text.trim());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(context.read<AuthProvider>().error ?? 'Registration failed'),
        backgroundColor: AppTheme.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Join PostCraft AI',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                      const SizedBox(height: 6),
                      const Text('Create your free account',
                          style: TextStyle(color: AppTheme.textMid)),
                      const SizedBox(height: 30),
                      AppTextField(
                          controller: _nameCtrl,
                          label: 'Full name',
                          hint: 'John Doe',
                          validator: (v) => (v == null || v.length < 2)
                              ? 'Enter your full name'
                              : null),
                      const SizedBox(height: 16),
                      AppTextField(
                          controller: _emailCtrl,
                          label: 'Email address',
                          hint: 'you@example.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null),
                      const SizedBox(height: 16),
                      AppTextField(
                          controller: _passCtrl,
                          label: 'Password',
                          hint: '••••••••',
                          obscureText: _obscure,
                          validator: _passwordIssue,
                          suffix: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppTheme.textMid),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure))),
                      const SizedBox(height: 10),
                      _PasswordRules(password: _passCtrl.text),
                      const SizedBox(height: 16),
                      AppTextField(
                          controller: _pass2Ctrl,
                          label: 'Confirm password',
                          hint: '••••••••',
                          obscureText: _obscure,
                          validator: (v) => v != _passCtrl.text
                              ? 'Passwords do not match'
                              : null),
                      const SizedBox(height: 28),
                      _loading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _register,
                              child: const Text('Create Account')),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account? ',
                                style: TextStyle(color: AppTheme.textMid)),
                            GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text('Sign In',
                                    style: TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w600))),
                          ]),
                    ])),
          ),
        ),
      );
}

/// Live checklist that ticks each rule as the user types. Only the failing
/// ones are shown in red; met rules go green so the user sees progress.
class _PasswordRules extends StatelessWidget {
  final String password;
  const _PasswordRules({required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = <({String label, bool ok})>[
      (label: 'At least 8 characters',
          ok: _RegisterScreenState._hasMinLength(password)),
      (label: 'One uppercase letter',
          ok: _RegisterScreenState._hasUpper(password)),
      (label: 'One lowercase letter',
          ok: _RegisterScreenState._hasLower(password)),
      (label: 'One number', ok: _RegisterScreenState._hasDigit(password)),
      (label: 'One special character (!@#\$…)',
          ok: _RegisterScreenState._hasSpecial(password)),
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
