import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/user.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'grades_dialog.dart';
import 'notes_dialog.dart';
import 'schedule_screen.dart';
import 'study_ui.dart';
import 'subjects_screen.dart';
import 'works_screen.dart';

/// Signed-in shell. Uses a modern student sidebar on wide screens (web / desktop) and a
/// sleek bottom NavigationBar on narrow screens (mobile).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = [
    'Today',
    'Timetable',
    'Attendance',
    'Tasks',
    'Focus Zone',
    'Courses',
  ];

  static const _icons = [
    Icons.space_dashboard_rounded,
    Icons.calendar_today_rounded,
    Icons.verified_user_rounded,
    Icons.check_circle_outline_rounded,
    Icons.headphones_rounded,
    Icons.school_rounded,
  ];

  List<Widget> get _screens => [
    DashboardScreen(onNavigate: _select),
    const ScheduleScreen(),
    const AttendanceScreen(),
    const WorksScreen(),
    const StudyScreen(),
    const SubjectsScreen(),
  ];

  void _select(int index) => setState(() => _index = index);

  Future<void> _editProfile(BuildContext context) async {
    final auth = context.read<AuthState>();
    final user = auth.user;
    if (user == null) return;
    final result = await showDialog<_ProfileResult>(
      context: context,
      builder: (_) => _ProfileDialog(user: user),
    );
    if (result == null || !context.mounted) return;
    try {
      await auth.updateProfile(
        fullName: result.fullName,
        studentNo: result.studentNo,
        course: result.course,
      );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _openNotes(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const NotesDialog(),
    );
  }

  void _openGrades(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const GradesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final auth = context.watch<AuthState>();
    final app = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (wide)
              _ModernSidebar(
                index: _index,
                titles: _titles,
                icons: _icons,
                user: auth.user,
                onSelect: _select,
                onProfile: () => _editProfile(context),
                onNotes: () => _openNotes(context),
                onGrades: () => _openGrades(context),
                onLogout: () => context.read<AuthState>().logout(),
              ),
            Expanded(
              child: Column(
                children: [
                  _ModernHeader(
                    title: _titles[_index],
                    user: auth.user,
                    wide: wide,
                    onProfile: () => _editProfile(context),
                    onNotes: () => _openNotes(context),
                    onGrades: () => _openGrades(context),
                    onLogout: () => context.read<AuthState>().logout(),
                  ),
                  if (app.error != null) _SyncWarning(onRetry: app.refreshAll),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.012, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: _screens[_index],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _titles[i],
                  ),
              ],
            ),
    );
  }
}

class _SyncWarning extends StatelessWidget {
  const _SyncWarning({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF3B2510) : const Color(0xFFFFF4DE),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: Color(0xFFD97706),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Operating in offline/cached mode. Tap refresh to sync with server.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Retry sync',
            visualDensity: VisualDensity.compact,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ModernSidebar extends StatelessWidget {
  const _ModernSidebar({
    required this.index,
    required this.titles,
    required this.icons,
    required this.user,
    required this.onSelect,
    required this.onProfile,
    required this.onNotes,
    required this.onGrades,
    required this.onLogout,
  });

  final int index;
  final List<String> titles;
  final List<IconData> icons;
  final User? user;
  final ValueChanged<int> onSelect;
  final VoidCallback onProfile;
  final VoidCallback onNotes;
  final VoidCallback onGrades;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? PortalColors.lineDark : PortalColors.lineLight;

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: isDark ? PortalColors.surfaceDark : Colors.white,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo & Branding
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 18, 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: PortalColors.primary.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    'C',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Avenir Next',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ClassMate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'STUDENT SUITE 2.0',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark
                              ? PortalColors.mutedDark
                              : PortalColors.mutedLight,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Navigation Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (var i = 0; i < titles.length; i++)
                  _SidebarNavItem(
                    title: titles[i],
                    icon: icons[i],
                    selected: index == i,
                    badgeCount: i == 3
                        ? app.works.where((w) => w.status != 'done').length
                        : null,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Tools
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'STUDENT TOOLS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: isDark ? PortalColors.mutedDark : PortalColors.mutedLight,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _QuickToolItem(
                  icon: Icons.calculate_outlined,
                  title: 'GPA & Target Solver',
                  color: PortalColors.primary,
                  onTap: onGrades,
                ),
                _QuickToolItem(
                  icon: Icons.note_alt_outlined,
                  title: 'Study Flashnotes',
                  color: PortalColors.amber,
                  onTap: onNotes,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Theme Switcher & Profile Footer
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  onPressed: app.toggleTheme,
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? Colors.amber : PortalColors.primary,
                  ),
                ),
                Expanded(
                  child: Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? PortalColors.mutedDark : PortalColors.mutedLight,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, size: 18),
                ),
              ],
            ),
          ),

          // Profile tile
          Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: onProfile,
              dense: true,
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: PortalColors.primary.withAlpha(30),
                foregroundColor: PortalColors.primary,
                child: Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              title: Text(
                user?.fullName ?? 'Student',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                user?.course ?? 'View Profile',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
    required this.title,
    required this.icon,
    required this.selected,
    this.badgeCount,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final int? badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? const Color(0xFF232E47) : PortalColors.primaryWash)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? PortalColors.primary
                      : (isDark ? PortalColors.mutedDark : PortalColors.mutedLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? PortalColors.primary
                          : (isDark ? PortalColors.inkDark : PortalColors.inkLight),
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: PortalColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickToolItem extends StatelessWidget {
  const _QuickToolItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: PortalColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernHeader extends StatelessWidget {
  const _ModernHeader({
    required this.title,
    required this.user,
    required this.wide,
    required this.onProfile,
    required this.onNotes,
    required this.onGrades,
    required this.onLogout,
  });

  final String title;
  final User? user;
  final bool wide;
  final VoidCallback onProfile;
  final VoidCallback onNotes;
  final VoidCallback onGrades;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? PortalColors.lineDark : PortalColors.lineLight;
    final summary = app.gradeSummary;

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 16),
      decoration: BoxDecoration(
        color: isDark ? PortalColors.surfaceDark : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (!wide) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'C',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // GPA Quick Pill
          if (summary?.cumulativeGpa != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: onGrades,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: PortalColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PortalColors.primary.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'GPA ${summary!.cumulativeGpa!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: PortalColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Quick Flashnotes Pill
          IconButton(
            tooltip: 'Study Flashnotes',
            onPressed: onNotes,
            icon: const Icon(Icons.note_alt_outlined),
          ),

          // Theme Toggle
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: app.toggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: isDark ? Colors.amber : null,
            ),
          ),

          // Profile
          IconButton(
            tooltip: 'Edit Profile',
            onPressed: onProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),

          if (!wide)
            IconButton(
              tooltip: 'Sign out',
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
    );
  }
}

class _ProfileResult {
  const _ProfileResult({required this.fullName, this.studentNo, this.course});

  final String fullName;
  final String? studentNo;
  final String? course;
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.user});

  final User user;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _studentNo;
  late final TextEditingController _course;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: widget.user.fullName);
    _studentNo = TextEditingController(text: widget.user.studentNo ?? '');
    _course = TextEditingController(text: widget.user.course ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _studentNo.dispose();
    _course.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ProfileResult(
        fullName: _fullName.text.trim(),
        studentNo: _studentNo.text.trim(),
        course: _course.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: widget.user.email,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullName,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _studentNo,
              decoration: const InputDecoration(labelText: 'Student number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _course,
              decoration: const InputDecoration(labelText: 'Course / Major'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save Changes')),
      ],
    );
  }
}
