import 'dart:async';

import '../planner/planner_exceptions.dart';
import 'import_status.dart';
import 'mail_service.dart';

/// 什么时候扫描邮件文件夹（spec 0002"导入规则·什么时候扫描"）：开始时一次，
/// 之后每 5 分钟一次，再加上 [scanNow]（[立即导入]、选好文件夹以后）。
///
/// 一次扫描以后还有刚看到、要等下一次扫描才读的文件时，30 秒后再看一次，
/// 不用等 5 分钟。
class MailScanSchedule {
  MailScanSchedule(this._service);

  static const interval = Duration(minutes: 5);
  static const recheckAfter = Duration(seconds: 30);

  final MailService _service;
  Timer? _periodic;
  Timer? _recheck;
  bool _disposed = false;

  void start() {
    _periodic = Timer.periodic(interval, (_) => scanNow());
    unawaited(scanNow());
  }

  /// 马上扫描一次。读写数据库失败时什么都不做，下一次再扫。
  Future<void> scanNow() => _scan(recheck: true);

  Future<void> _scan({required bool recheck}) async {
    _recheck?.cancel();
    try {
      await _service.scanFolder();
      if (!recheck || _disposed) return;
      final status = await _service.importStatus();
      if (_disposed || !status.notices.contains(const FilesSyncing())) return;
      _recheck = Timer(recheckAfter, () => _scan(recheck: false));
    } on StorageFailure {
      // 下一次再扫。
    }
  }

  void dispose() {
    _disposed = true;
    _periodic?.cancel();
    _recheck?.cancel();
  }
}
