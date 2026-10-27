import 'dart:io';

/// 邮件文件夹里的一个导出文件，扫描时看到的样子。
class ExportFileInfo {
  const ExportFileInfo({
    required this.name,
    required this.size,
    required this.modifiedAt,
  });

  /// 文件名，不带路径。
  final String name;

  final int size;

  /// 修改时间（UTC）。
  final DateTime modifiedAt;
}

/// 邮件文件夹不存在或者没有权限。
class ExportFolderUnavailable implements Exception {
  const ExportFolderUnavailable();
}

/// 导出文件读不出来：被删了、被占用，或者 OneDrive 按需下载失败。
class ExportFileUnreadable implements Exception {
  const ExportFileUnreadable();
}

/// 放导出文件的文件夹（spec 0002"模块清单"）。Windows 上是 OneDrive 同步
/// 过来的文件夹。
abstract interface class ExportSource {
  /// 文件夹里所有 `mail-*.json`。文件夹不可用时抛出 [ExportFolderUnavailable]。
  Future<List<ExportFileInfo>> list();

  /// 读出一个文件的全部字节。读不出来时抛出 [ExportFileUnreadable]。
  Future<List<int>> read(String name);

  /// 删除一个文件；文件已经不在了也算成功。删不掉时抛出 [ExportFileUnreadable]。
  Future<void> delete(String name);
}

/// 导出文件的文件名：`mail-` 开头、`.json` 结尾，不分大小写。
bool isExportFileName(String name) {
  final lower = name.toLowerCase();
  return lower.startsWith('mail-') && lower.endsWith('.json');
}

/// 本机文件夹里的导出文件，基于 `dart:io`。
class DirectoryExportSource implements ExportSource {
  DirectoryExportSource(this.path);

  final String path;

  File _file(String name) => File('$path${Platform.pathSeparator}$name');

  @override
  Future<List<ExportFileInfo>> list() async {
    final files = <ExportFileInfo>[];
    try {
      await for (final entity in Directory(path).list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!isExportFileName(name)) continue;
        final FileStat stat;
        try {
          stat = await entity.stat();
        } on FileSystemException {
          continue;
        }
        // 列出以后、stat 之前被删掉的文件。
        if (stat.type == FileSystemEntityType.notFound) continue;
        files.add(
          ExportFileInfo(
            name: name,
            size: stat.size,
            modifiedAt: stat.modified.toUtc(),
          ),
        );
      }
    } on FileSystemException {
      throw const ExportFolderUnavailable();
    }
    return files;
  }

  @override
  Future<List<int>> read(String name) async {
    try {
      return await _file(name).readAsBytes();
    } on FileSystemException {
      throw const ExportFileUnreadable();
    }
  }

  @override
  Future<void> delete(String name) async {
    try {
      await _file(name).delete();
    } on PathNotFoundException {
      // 已经不在了。
    } on FileSystemException {
      throw const ExportFileUnreadable();
    }
  }
}
