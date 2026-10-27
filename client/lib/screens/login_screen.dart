import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // Pre-filled with the seed demo account for quick demos.
  final _email = TextEditingController(text: 'demo@classmate.app');
  final _password = TextEditingController(text: 'demo12345');
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<AuthState>().login(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                              const Color(0xFF22D3EE).withValues(alpha: 0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                              blurRadius: 40,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.school_outlined, size: 38, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'ClassMate',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Attendance • Schedule • School Works',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Sign in',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.92),
                                      ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(labelText: 'Email'),
                                  validator: (v) =>
                                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                if (auth.error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(auth.error!, style: TextStyle(color: Colors.redAccent.shade100)),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed: auth.busy ? null : _submit,
                                  child: auth.busy
                                      ? const SizedBox(
                                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('Sign in'),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: auth.busy
                                      ? null
                                      : () {
                                          context.read<AuthState>().clearError();
                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                          );
                                        },
                                  child: const Text('Create an account'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
