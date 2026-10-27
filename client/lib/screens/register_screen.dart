import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/animated_glass_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _studentNo = TextEditingController();
  final _course = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _studentNo.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    final ok = await auth.register(
      email: _email.text.trim(),
      password: _password.text,
      fullName: _fullName.text.trim(),
      studentNo: _studentNo.text.trim(),
      course: _course.text.trim(),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Create account'),
        ),
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
                          width: 64,
                          height: 64,
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
                                blurRadius: 36,
                                spreadRadius: -12,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_add_alt_1_outlined, size: 34, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create your account',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Set up your ClassMate profile',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                                  TextFormField(
                                    controller: _fullName,
                                    decoration: const InputDecoration(labelText: 'Full name'),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(labelText: 'Email'),
                                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _password,
                                    obscureText: true,
                                    decoration: const InputDecoration(labelText: 'Password (8+ chars)'),
                                    validator: (v) =>
                                        (v == null || v.length < 8) ? 'At least 8 characters' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _studentNo,
                                    decoration: const InputDecoration(labelText: 'Student number (optional)'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _course,
                                    decoration: const InputDecoration(labelText: 'Course (optional)'),
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
                                        : const Text('Sign up'),
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
      ),
    );
  }
}
