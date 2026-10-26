import 'package:flutter/material.dart';

import '../board/board_page.dart';
import 'daily_maintenance.dart';
import 'planner_theme.dart';

/// App 的根组件。需要放在 `ProviderScope` 里面。
class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dailynote',
      debugShowCheckedModeBanner: false,
      theme: PlannerTheme.light(),
      darkTheme: PlannerTheme.dark(),
      themeMode: ThemeMode.system,
      home: const DailyMaintenance(child: BoardPage()),
    );
  }
}
