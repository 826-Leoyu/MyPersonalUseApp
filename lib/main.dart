import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/planner_app.dart';
import 'app/providers.dart';
import 'storage/planner_database.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        plannerDatabaseFactoryProvider.overrideWithValue(
          // 数据库文件 planner.sqlite 放在系统的应用文档目录里。
          () => PlannerDatabase(driftDatabase(name: 'planner')),
        ),
      ],
      child: const PlannerApp(),
    ),
  );
}
