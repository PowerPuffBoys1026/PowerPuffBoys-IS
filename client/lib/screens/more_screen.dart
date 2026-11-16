import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/animated_glass_background.dart';
import 'attendance_screen.dart';
import 'notes_screen.dart';
import 'profile_screen.dart';
import 'recycle_bin_screen.dart';
import 'settings_screen.dart';
import 'subjects_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final user = auth.user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                (user?.fullName.isNotEmpty ?? false)
                    ? user!.fullName[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(user?.fullName ?? 'Signed in'),
            subtitle: Text(user?.email ?? ''),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _push(context, const ProfileScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _Tile(
          icon: Icons.fact_check_outlined,
          title: 'Attendance',
          subtitle: 'Mark and review class attendance',
          onTap: () => _push(
            context,
            const _GlassPage(title: 'Attendance', child: AttendanceScreen()),
          ),
        ),
        _Tile(
          icon: Icons.book_outlined,
          title: 'Subjects',
          subtitle: 'Instructors, units, and colors',
          onTap: () => _push(
            context,
            const _GlassPage(title: 'Subjects', child: SubjectsScreen()),
          ),
        ),
        _Tile(
          icon: Icons.note_alt_outlined,
          title: 'Notes',
          subtitle: 'Searchable notes with attachments',
          onTap: () => _push(
            context,
            const AnimatedGlassBackground(child: NotesScreen()),
          ),
        ),
        _Tile(
          icon: Icons.delete_outline,
          title: 'Recycle bin',
          subtitle: 'Restore or permanently remove deleted items',
          onTap: () => _push(context, const RecycleBinScreen()),
        ),
        _Tile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Server address and connection',
          onTap: () => _push(context, const SettingsScreen()),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Sign out'),
            onTap: () => context.read<AuthState>().logout(),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _GlassPage extends StatelessWidget {
  const _GlassPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(title)),
        body: child,
      ),
    );
  }
}
