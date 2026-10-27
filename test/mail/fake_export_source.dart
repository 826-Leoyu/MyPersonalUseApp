import 'package:my_personal_use_app/mail/export_source.dart';

/// 内存里的邮件文件夹，给界面测试用：界面测试在假时间里跑，真实的文件读写
/// 不可靠。导入规则本身用真实的临时目录测（`mail_folder_test.dart`）。
class FakeExportFolders {
  /// 文件夹路径 → 文件名 → 内容。不在这里的路径算不存在。
  final folders = <String, Map<String, ({List<int> bytes, DateTime at})>>{};

  /// 在 [folder] 里写一个文件（文件夹不存在时新建）。
  void write(String folder, String name, List<int> bytes, DateTime at) =>
      (folders[folder] ??= {})[name] = (bytes: bytes, at: at.toUtc());

  ExportSource open(String folder) => _FakeExportSource(this, folder);
}

class _FakeExportSource implements ExportSource {
  _FakeExportSource(this._folders, this._path);

  final FakeExportFolders _folders;
  final String _path;

  Map<String, ({List<int> bytes, DateTime at})> get _files =>
      _folders.folders[_path] ?? (throw const ExportFolderUnavailable());

  @override
  Future<List<ExportFileInfo>> list() async => [
    for (final MapEntry(key: name, value: file) in _files.entries)
      if (isExportFileName(name))
        ExportFileInfo(
          name: name,
          size: file.bytes.length,
          modifiedAt: file.at,
        ),
  ];

  @override
  Future<List<int>> read(String name) async =>
      _files[name]?.bytes ?? (throw const ExportFileUnreadable());

  @override
  Future<void> delete(String name) async => _files.remove(name);
}
