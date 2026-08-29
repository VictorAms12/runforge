import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'features/checklist/presentation/checklist_screen.dart';
import 'features/goals/presentation/goals_screen.dart';
import 'features/history/presentation/history_screen.dart';
import 'features/home/presentation/home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    GoalsScreen(),
    ChecklistScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: 280.ms,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.025, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Início'),
          NavigationDestination(icon: Icon(Icons.flag_rounded), label: 'Metas'),
          NavigationDestination(icon: Icon(Icons.checklist_rounded), label: 'Checklist'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Histórico'),
        ],
      ),
    );
  }
}
