import 'package:flutter/material.dart';

import '../screens/profile_tab.dart';
import 'questions_tab.dart';
import 'teacher_tests_tab.dart';

/// Teacher (and admin) app: Tests, Questions, Me.
class TeacherHome extends StatefulWidget {
  const TeacherHome({super.key});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  int _index = 0;
  final Set<int> _visited = {0};

  @override
  Widget build(BuildContext context) {
    const tabs = <Widget>[TeacherTestsTab(), QuestionsTab(), ProfileTab()];
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < tabs.length; i++) _visited.contains(i) ? tabs[i] : const SizedBox.shrink()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Tests'),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: 'Questions'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}
