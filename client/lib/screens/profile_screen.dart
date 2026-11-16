import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/v2_kit.dart';

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

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

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
    _toast(ok ? 'Profile updated' : (auth.error ?? 'Could not update profile'));
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
    _toast(
      ok ? 'Password changed' : (auth.error ?? 'Could not change password'),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;
    final colors = context.colors;
    final initial = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          v2Centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: colors.isDark
                          ? const [Color(0xFF1B2A2C), Color(0xFF251318)]
                          : const [Color(0xFFF8F2E9), Color(0xFFEFE0DD)],
                    ),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFB3263B), Color(0xFF761527)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Student',
                              style: TextStyle(
                                color: colors.textMain,
                                fontFamily: 'serif',
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                            if (user?.createdAt != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Joined ${formatDate(user!.createdAt!)}',
                                style: TextStyle(
                                  color: colors.textDim,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      V2Badge(
                        user?.course ?? 'Student',
                        color: colors.primary,
                        dense: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _profileKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(title: 'Account details'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fullName,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _studentNo,
                          decoration: const InputDecoration(
                            labelText: 'Student number',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _course,
                          decoration: const InputDecoration(
                            labelText: 'Course',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _yearLevel,
                          decoration: const InputDecoration(
                            labelText: 'Year level',
                          ),
                        ),
                        const SizedBox(height: 14),
                        PillButton(
                          label: auth.busy ? 'Saving…' : 'Save profile',
                          icon: Icons.save_outlined,
                          tone: colors.primary,
                          expand: true,
                          onPressed: auth.busy ? null : _saveProfile,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _passwordKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading(
                          title: 'Change password',
                          subtitle: 'Use at least 8 characters you have not used before.',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _currentPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Current password',
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _newPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password (min 8)',
                          ),
                          validator: (v) {
                            if (v == null || v.length < 8) {
                              return 'At least 8 characters';
                            }
                            if (v == _currentPassword.text) {
                              return 'Choose a different password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _confirmPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                          ),
                          validator: (v) => v != _newPassword.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        PillButton(
                          label: auth.busy ? 'Updating…' : 'Change password',
                          icon: Icons.lock_outline,
                          expand: true,
                          onPressed: auth.busy ? null : _changePassword,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
