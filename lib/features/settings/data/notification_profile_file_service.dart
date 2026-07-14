/// 通知规则档案的本地 JSON 文件导入导出服务。
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../domain/notification_rule_profile.dart';

const XTypeGroup _notificationProfileType = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
);

/// 使用平台文件选择器导入和导出通知规则档案。
class NotificationProfileFileService {
  /// 导出 [profile]；用户取消时返回 null。
  Future<String?> exportProfile(NotificationRuleProfile profile) async {
    final location = await getSaveLocation(
      suggestedName: _suggestedFileName(profile),
      acceptedTypeGroups: const [_notificationProfileType],
    );
    if (location == null) return null;
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(profile.toJson());
    await File(location.path).writeAsString(encoded);
    return location.path;
  }

  /// 导入一个档案；用户取消时返回 null。
  Future<NotificationRuleProfile?> importProfile() async {
    final file = await openFile(
      acceptedTypeGroups: const [_notificationProfileType],
    );
    if (file == null) return null;
    final encoded = await File(file.path).readAsString();
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Notification profile must be a JSON object');
    }
    return NotificationRuleProfile.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  String _suggestedFileName(NotificationRuleProfile profile) {
    final safeName = profile.name
        .replaceAll(RegExp(r'[^A-Za-z0-9\u4e00-\u9fa5_-]+'), '_')
        .replaceAll(RegExp('_+'), '_');
    return 'notification_rules_$safeName.json';
  }
}
