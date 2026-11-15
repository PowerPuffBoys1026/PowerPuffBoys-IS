import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/animated_glass_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _studentNo;
  late final TextEditingController _course;
  late final TextEditingController _yearLevel;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthState>().user;
    _fullName = TextEditingController(text: user?.fullName ?? '');
    _studentNo = TextEditingController(text: user?.studentNo ?? '');
    _course = TextEditingController(text: user?.course ?? '');
    _yearLevel = TextEditingController(text: user?.yearLevel ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _studentNo.dispose();
    _course.dispose();
    _yearLevel.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    final ok = await auth.updateProfile(
      fullName: _fullName.text.trim(),
      studentNo: _emptyToNull(_studentNo.text),
      course: _emptyToNull(_course.text),
      yearLevel: _emptyToNull(_yearLevel.text),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Profile updated' : (auth.error ?? 'Could not update profile'))),
    );
  }

  Future<void> _changePassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    final auth = context.read<AuthState>();
    final ok = await auth.changePassword(
      currentPassword: _currentPassword.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    if (ok) {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Password changed' : (auth.error ?? 'Could not change password'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;

    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        (user?.fullName.isNotEmpty ?? false) ? user!.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? '', style: Theme.of(context).textTheme.titleMedium),
                          Text(user?.email ?? '',
                              style: Theme.of(context).textTheme.bodySmall),
                          if (user?.createdAt != null)
                            Text(
                              'Joined ${user!.createdAt!.substring(0, 10)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Account details', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Form(
              key: _profileKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _studentNo,
                    decoration: const InputDecoration(labelText: 'Student number'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _course,
                    decoration: const InputDecoration(labelText: 'Course'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _yearLevel,
                    decoration: const InputDecoration(labelText: 'Year level'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: auth.busy ? null : _saveProfile,
                      child: const Text('Save profile'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Change password', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Form(
              key: _passwordKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current password'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _newPassword,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password (min 8)'),
                    validator: (v) {
                      if (v == null || v.length < 8) return 'At least 8 characters';
                      if (v == _currentPassword.text) return 'Choose a different password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm new password'),
                    validator: (v) => v != _newPassword.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: auth.busy ? null : _changePassword,
                      child: const Text('Change password'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
