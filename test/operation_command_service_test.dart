import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/protobuf.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/features/dashboard/data/operation_command_service.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';

typedef _PublishedMessage = ({String topic, GeneratedMessage message});

void main() {
  test('42mm exchange uses its dedicated command type', () {
    final published = <_PublishedMessage>[];

    _serviceRecordingTo(published).exchange42mm(30);

    final command = published.single.message as CommonCommand;
    expect(published.single.topic, topicCommonCommand);
    expect(command.cmdType, commonCommandExchange42mm);
    expect(command.param, 30);
  });

  test('operation methods publish the exact protocol fields', () {
    final published = <_PublishedMessage>[];

    _serviceRecordingTo(published)
      ..exchange17mm(20)
      ..exchange42mm(30)
      ..remoteHeal()
      ..remoteAmmo()
      ..startExchange(4)
      ..confirmAssembly()
      ..cancelAssembly();

    expect(_commonAt(published, 0), (
      type: commonCommandExchange17mm,
      param: 20,
    ));
    expect(_commonAt(published, 1), (
      type: commonCommandExchange42mm,
      param: 30,
    ));
    expect(_commonAt(published, 2), (type: commonCommandRemoteHeal, param: 0));
    expect(_commonAt(published, 3), (
      type: commonCommandRemoteAmmo,
      param: remoteAmmoExchangeRounds,
    ));
    expect(_assemblyAt(published, 4), (
      operation: assemblyOperationStartExchange,
      difficulty: 4,
    ));
    expect(_assemblyAt(published, 5), (
      operation: assemblyOperationConfirm,
      difficulty: 0,
    ));
    expect(_assemblyAt(published, 6), (
      operation: assemblyOperationCancel,
      difficulty: 0,
    ));
  });
}

OperationCommandService _serviceRecordingTo(List<_PublishedMessage> target) {
  return OperationCommandService(
    publish: (topic, message) {
      target.add((topic: topic, message: message));
    },
  );
}

({int type, int param}) _commonAt(
  List<_PublishedMessage> published,
  int index,
) {
  final command = published[index].message as CommonCommand;
  expect(published[index].topic, topicCommonCommand);
  return (type: command.cmdType, param: command.param);
}

({int operation, int difficulty}) _assemblyAt(
  List<_PublishedMessage> published,
  int index,
) {
  final command = published[index].message as AssemblyCommand;
  expect(published[index].topic, topicAssemblyCommand);
  return (operation: command.operation, difficulty: command.difficulty);
}
