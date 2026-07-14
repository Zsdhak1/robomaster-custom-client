import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows 原生窗口操作的 MethodChannel 封装。
class DesktopWindowController {
  DesktopWindowController._();

  static const MethodChannel _channel = MethodChannel('wod_client/window');

  /// 当前平台是否使用 Flutter 应用内标题栏。
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// 开始拖动原生窗口。
  static Future<void> startDrag() => _invokeVoid('startDrag');

  /// 最小化原生窗口。
  static Future<void> minimize() => _invokeVoid('minimize');

  /// 切换最大化/还原，并返回切换后的最大化状态。
  static Future<bool> toggleMaximize() async {
    try {
      return await _channel.invokeMethod<bool>('toggleMaximize') ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  /// 查询当前窗口是否最大化。
  static Future<bool> isMaximized() async {
    try {
      return await _channel.invokeMethod<bool>('isMaximized') ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  /// 关闭原生窗口。
  static Future<void> close() => _invokeVoid('close');

  static Future<void> _invokeVoid(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (_) {
      return;
    } on MissingPluginException catch (_) {
      return;
    }
  }
}
