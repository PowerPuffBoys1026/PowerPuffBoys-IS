import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/grades_state.dart';
import '../state/theme_state.dart';
import '../theme.dart';
import '../widgets/v2_kit.dart';
import 'attendance_screen.dart';
import 'dashboard_screen.dart';
import 'focus_screen.dart';
import 'grades_screen.dart';
import 'notes_screen.dart';
import 'profile_screen.dart';
import 'recycle_bin_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';
import 'works_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = [
    "Today's Overview",
    'Academic Timetable',
    'Attendance & Cut Calculator',
    'Tasks & School Works',
    'Study Focus Zone',
    'Courses & GPA Solver',
    'Study Flashnotes',
    'Recycle Bin',
  ];

  static const _nav = [
    (Icons.today_outlined, 'Today'),
    (Icons.calendar_month_outlined, 'Timetable'),
    (Icons.fact_check_outlined, 'Attendance'),
    (Icons.assignment_outlined, 'Tasks'),
    (Icons.center_focus_strong_outlined, 'Focus Zone'),
    (Icons.grading_outlined, 'Courses & GPA'),
    (Icons.note_alt_outlined, 'Flashnotes'),
    (Icons.delete_outline, 'Recycle Bin'),
  ];

  void _select(int index) => setState(() => _index = index);

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 768;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Sidebar(
                    index: _index,
                    titles: _titles,
                    nav: _nav,
                    onSelect: _select,
                    onProfile: () => _push(const ProfileScreen()),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _Header(
                          title: _titles[_index],
                          wide: true,
                          onGrades: () => _select(5),
                          onNotes: () => _select(6),
                        ),
                        Expanded(child: _buildViews()),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  const _Header(wide: false),
                  Expanded(child: _buildViews()),
                  _BottomNav(
                    index: _index,
                    onSelect: _select,
                    onMore: _openMore,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildViews() {
    return IndexedStack(
      index: _index,
      children: [
        DashboardScreen(onNavigate: _select),
        const ScheduleScreen(),
        const AttendanceScreen(),
        const WorksScreen(),
        const FocusScreen(),
        const GradesScreen(),
        const NotesScreen(),
        const RecycleBinScreen(),
      ],
    );
  }

  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        return Container(
          margin: const EdgeInsets.only(top: 70),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          decoration: BoxDecoration(
            color: colors.bgSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'All sections',
                      style: TextStyle(
                        color: colors.textMain,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconAction(
                      icon: Icons.close,
                      compact: true,
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 4.2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    for (var i = 0; i < _titles.length; i++)
                      _MoreItem(
                        icon: _nav[i].$1,
                        label: _nav[i].$2,
                        selected: _index == i,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _select(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MoreItem(
                        icon: Icons.person_outline,
                        label: 'Profile',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _push(const ProfileScreen());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MoreItem(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _push(const SettingsScreen());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ProfileStrip(
                  onProfile: () {
                    Navigator.pop(sheetContext);
                    _push(const ProfileScreen());
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Consumer<ThemeState>(
                      builder: (context, theme, _) => Expanded(
                        child: PillButton(
                          label: theme.isDark ? 'Light mode' : 'Dark mode',
                          icon: theme.isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          expand: true,
                          onPressed: theme.toggle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PillButton(
                        label: 'Sign out',
                        icon: Icons.logout,
                        tone: context.colors.rose,
                        expand: true,
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          context.read<AuthState>().logout();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.titles,
    required this.nav,
    required this.onSelect,
    required this.onProfile,
  });

  final int index;
  final List<String> titles;
  final List<(IconData, String)> nav;
  final ValueChanged<int> onSelect;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pending = context
        .watch<AppState>()
        .works
        .where((w) => w.status != 'done')
        .length;
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 22),
            child: BrandMark(size: 40, radius: 7, showText: true),
          ),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 18),
          Text(
            'ACADEMICS',
            style: TextStyle(
              color: colors.textDim,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: nav.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final active = i == index;
                return Material(
                  color: active ? colors.primarySoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: active ? colors.primary : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        gradient: active
                            ? LinearGradient(
                                colors: [
                                  colors.primarySoft,
                                  Colors.transparent,
                                ],
                                stops: const [0, 0.95],
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            nav[i].$1,
                            size: 19,
                            color: active ? colors.primary : colors.textMuted,
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              nav[i].$2,
                              style: TextStyle(
                                color: active
                                    ? colors.textMain
                                    : colors.textMuted,
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (i == 3 && pending > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$pending',
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
                );
              },
            ),
          ),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: 12),
          _ProfileStrip(onProfile: onProfile),
        ],
      ),
    );
  }
}

class _ProfileStrip extends StatelessWidget {
  const _ProfileStrip({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final user = context.watch<AuthState>().user;
    final initial = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName[0].toUpperCase()
        : '?';
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onProfile,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB3263B), Color(0xFF761527)],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Student',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMain,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      user?.course ?? 'Student Account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textDim, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    this.title = 'ClassMate',
    required this.wide,
    this.onGrades,
    this.onNotes,
  });

  final String title;
  final bool wide;
  final VoidCallback? onGrades;
  final VoidCallback? onNotes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = context.watch<ThemeState>();
    final gpa = context.watch<GradesState>().summary?.cumulativeGpa;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 30 : 14,
        vertical: wide ? 12 : 9,
      ),
      decoration: BoxDecoration(
        color: colors.glass,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (wide)
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'serif',
                  color: colors.textMain,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            )
          else ...[
            const BrandMark(size: 34, radius: 9),
            const SizedBox(width: 9),
            Text(
              'ClassMate',
              style: TextStyle(
                color: colors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
          ],
          if (wide) ...[
            PillButton(
              label: gpa == null ? 'GPA —' : 'GPA ${gpa.toStringAsFixed(2)}',
              icon: Icons.school_outlined,
              onPressed: onGrades,
            ),
            const SizedBox(width: 8),
            PillButton(
              label: 'Flashnotes',
              icon: Icons.note_alt_outlined,
              onPressed: onNotes,
            ),
            const SizedBox(width: 10),
          ],
          IconAction(
            icon: theme.isDark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            tooltip: theme.isDark
                ? 'Switch to light theme'
                : 'Switch to dark theme',
            onPressed: theme.toggle,
            compact: !wide,
          ),
          const SizedBox(width: 8),
          if (wide)
            Consumer<AuthState>(
              builder: (context, auth, _) {
                final initial = (auth.user?.fullName.isNotEmpty ?? false)
                    ? auth.user!.fullName[0].toUpperCase()
                    : '?';
                return PopupMenuButton<String>(
                  tooltip: 'Account',
                  onSelected: (value) {
                    if (value == 'profile') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      );
                    } else if (value == 'settings') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    } else if (value == 'signout') {
                      context.read<AuthState>().logout();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'profile', child: Text('Profile')),
                    PopupMenuItem(value: 'settings', child: Text('Settings')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'signout', child: Text('Sign out')),
                  ],
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB3263B), Color(0xFF761527)],
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            )
          else ...[
            Consumer<AuthState>(
              builder: (context, auth, _) {
                final initial = (auth.user?.fullName.isNotEmpty ?? false)
                    ? auth.user!.fullName[0].toUpperCase()
                    : '?';
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB3263B), Color(0xFF761527)],
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onSelect,
    required this.onMore,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onMore;

  static const _primary = <(IconData, String, int)>[
    (Icons.today_outlined, 'Today', 0),
    (Icons.calendar_month_outlined, 'Plan', 1),
    (Icons.assignment_outlined, 'Tasks', 3),
    (Icons.center_focus_strong_outlined, 'Focus', 4),
    (Icons.note_alt_outlined, 'Notes', 6),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final moreSelected = !_primary.any((item) => item.$3 == index);
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        5,
        8,
        5 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          for (final item in _primary)
            Expanded(
              child: _NavItem(
                icon: item.$1,
                label: item.$2,
                active: index == item.$3,
                onTap: () => onSelect(item.$3),
              ),
            ),
          Expanded(
            child: _NavItem(
              icon: Icons.grid_view_outlined,
              label: 'More',
              active: moreSelected,
              onTap: onMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: active ? colors.primarySoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? colors.primary : colors.textDim,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? colors.primary : colors.textDim,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.primarySoft : colors.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? colors.borderGlow : colors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? colors.primary : colors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? colors.primary : colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
