import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import 'dashboard_screen.dart';
import 'focus_screen.dart';
import 'grades_screen.dart';
import 'more_screen.dart';
import 'schedule_screen.dart';
import 'works_screen.dart';

/// Signed-in shell. Uses a NavigationRail on wide screens (web / desktop) and a
/// bottom NavigationBar on narrow screens (mobile).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'Schedule', 'School Works', 'Grades', 'Focus', 'More'];
  static const _labels = ['Home', 'Schedule', 'Works', 'Grades', 'Focus', 'More'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.calendar_month_outlined,
    Icons.assignment_outlined,
    Icons.grading_outlined,
    Icons.timer_outlined,
    Icons.more_horiz,
  ];

  static const _screens = [
    DashboardScreen(),
    ScheduleScreen(),
    WorksScreen(),
    GradesScreen(),
    FocusScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (auth.user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text(auth.user!.fullName)),
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthState>().logout(),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < _titles.length; i++)
                      NavigationRailDestination(
                        icon: Icon(_icons[i]),
                        label: Text(_labels[i]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: IndexedStack(index: _index, children: _screens)),
              ],
            )
          : IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _titles.length; i++)
                  NavigationDestination(icon: Icon(_icons[i]), label: _labels[i]),
              ],
            ),
    );
  }
}
