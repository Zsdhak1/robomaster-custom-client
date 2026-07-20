import 'package:protobuf/protobuf.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../generated/robomaster_custom_client.pb.dart';

/// 将操作指令发布到指定 MQTT Topic 的回调。
typedef OperationMessagePublisher =
    void Function(String topic, GeneratedMessage message);

/// 构建并发布操作面板使用的协议消息。
class OperationCommandService {
  /// 创建使用 [publish] 发送消息的操作指令服务。
  const OperationCommandService({required OperationMessagePublisher publish})
    : this._(publish);

  const OperationCommandService._(this._publish);

  final OperationMessagePublisher _publish;

  /// 请求兑换指定数量的 17mm 弹丸。
  void exchange17mm(int rounds) => _common(commonCommandExchange17mm, rounds);

  /// 请求兑换指定数量的 42mm 弹丸。
  void exchange42mm(int rounds) => _common(commonCommandExchange42mm, rounds);

  /// 请求远程兑换血量。
  void remoteHeal() => _common(commonCommandRemoteHeal, 0);

  /// 请求远程兑换固定数量的弹丸。
  void remoteAmmo() =>
      _common(commonCommandRemoteAmmo, remoteAmmoExchangeRounds);

  /// 请求以 [difficulty] 难度开始工程兑换流程。
  void startExchange(int difficulty) {
    _assembly(assemblyOperationStartExchange, difficulty);
  }

  /// 请求确认当前工程装配步骤。
  void confirmAssembly() => _assembly(assemblyOperationConfirm, 0);

  /// 请求取消当前工程装配流程。
  void cancelAssembly() => _assembly(assemblyOperationCancel, 0);

  void _common(int type, int param) {
    _publish(topicCommonCommand, CommonCommand(cmdType: type, param: param));
  }

  void _assembly(int operation, int difficulty) {
    _publish(
      topicAssemblyCommand,
      AssemblyCommand(operation: operation, difficulty: difficulty),
    );
  }
}
