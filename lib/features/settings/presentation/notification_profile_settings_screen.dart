/// 通知规则档案二级设置页面。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_messenger.dart';
import '../data/notification_profile_file_service.dart';
import '../logic/notification_profile_provider.dart';
import 'notification_settings_strings.dart';
import 'notification_settings_subpages.dart';
import 'widgets/notification_profile_section.dart';

/// 管理规则档案选择、复制、导入、导出、重置和删除。
class NotificationProfileSettingsScreen extends ConsumerStatefulWidget {
  /// 创建规则档案页面。
  const NotificationProfileSettingsScreen({super.key, this.embedded = false});

  /// 是否嵌入设置详情区。
  final bool embedded;

  @override
  ConsumerState<NotificationProfileSettingsScreen> createState() =>
      _NotificationProfileSettingsScreenState();
}

class _NotificationProfileSettingsScreenState
    extends ConsumerState<NotificationProfileSettingsScreen> {
  final NotificationProfileFileService _fileService =
      NotificationProfileFileService();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProfileProvider);
    return NotificationSettingsSubpage(
      title: notificationProfilePageTitle,
      embedded: widget.embedded,
      children: [
        NotificationProfileSection(
          state: state,
          onSelected: _activate,
          onDuplicate: _duplicate,
          onImport: _import,
          onExport: _export,
          onReset: _reset,
          onDelete: _confirmDelete,
        ),
      ],
    );
  }

  NotificationProfileNotifier get _notifier =>
      ref.read(notificationProfileProvider.notifier);

  void _activate(String? profileId) {
    if (profileId != null) _runOperation(_notifier.activate(profileId));
  }

  void _duplicate() {
    _runOperation(
      _notifier.duplicateActive().then<void>((_) {}),
      successMessage: notificationProfileCopied,
    );
  }

  Future<void> _import() async {
    try {
      final profile = await _fileService.importProfile();
      if (profile == null) return;
      await _notifier.addImported(profile);
      if (mounted) context.showSuccessSnack(notificationProfileImported);
    } on Object catch (error) {
      if (mounted) {
        context.showErrorSnack('$notificationProfileImportFailed: $error');
      }
    }
  }

  Future<void> _export() async {
    try {
      final path = await _fileService.exportProfile(
        ref.read(notificationProfileProvider).activeProfile,
      );
      if (path != null && mounted) {
        context.showSuccessSnack('$notificationProfileExported: $path');
      }
    } on Object catch (error) {
      if (mounted) {
        context.showErrorSnack('$notificationProfileExportFailed: $error');
      }
    }
  }

  void _reset() {
    _runOperation(
      _notifier.resetActive(),
      successMessage: notificationProfileResetDone,
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: _deleteDialog,
    );
    if (confirmed != true) return;
    final profileId = ref.read(notificationProfileProvider).activeProfileId;
    await _handleOperation(
      _notifier.remove(profileId),
      successMessage: notificationProfileDeleted,
    );
  }

  Widget _deleteDialog(BuildContext dialogContext) {
    return AlertDialog(
      title: const Text(notificationProfileDeleteTitle),
      content: const Text(notificationProfileDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(notificationCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(notificationDelete),
        ),
      ],
    );
  }

  void _runOperation(Future<void> operation, {String? successMessage}) {
    unawaited(_handleOperation(operation, successMessage: successMessage));
  }

  Future<void> _handleOperation(
    Future<void> operation, {
    String? successMessage,
  }) async {
    try {
      await operation;
      if (successMessage != null && mounted) {
        context.showSuccessSnack(successMessage);
      }
    } on Object catch (error) {
      if (mounted) {
        context.showErrorSnack('$notificationProfileSaveFailed: $error');
      }
    }
  }
}
