import 'package:flutter/material.dart';

import '../screens/profile_tab.dart';
import 'dashboard_tab.dart';
import 'practice_tab.dart';
import 'ranks_tab.dart';
import 'tests_tab.dart';

/// Student app: Home, Tests, Practice, Ranks, Me.
class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  int _index = 0;
  final Set<int> _visited = {0}; // tabs are built the first time they are opened

  void _go(int index) => setState(() {
        _index = index;
        _visited.add(index);
      });

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      DashboardTab(onOpenTests: () => _go(1), onOpenRanks: () => _go(3)),
      const TestsTab(),
      const PracticeTab(),
      const RanksTab(),
      const ProfileTab(),
    ];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < tabs.length; i++) _visited.contains(i) ? tabs[i] : const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Tests'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Ranks'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
