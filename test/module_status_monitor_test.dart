import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/module_status_monitor.dart';

void main() {
  test('reports an explicitly offline module in the first snapshot', () {
    final controller = ModuleStatusMonitorController();

    final transitions = controller.observe(
      const ModuleStatusReading({
        RobotModuleType.videoTransmission: ModuleAvailability.offline,
      }),
    );

    expect(transitions.single.becameOffline, isTrue);
    expect(controller.state.hasOffline, isTrue);
  });

  test('missing fields retain the last valid state', () {
    final controller = ModuleStatusMonitorController()
      ..observe(
        const ModuleStatusReading({
          RobotModuleType.armor: ModuleAvailability.offline,
        }),
      )
      ..observe(const ModuleStatusReading({}));

    expect(
      controller.state.statuses[RobotModuleType.armor],
      ModuleAvailability.offline,
    );
  });

  test('does not report an explicitly online module in the first snapshot', () {
    final controller = ModuleStatusMonitorController();

    final transitions = controller.observe(
      const ModuleStatusReading({
        RobotModuleType.armor: ModuleAvailability.online,
      }),
    );

    expect(transitions, isEmpty);
  });

  test(
    'does not duplicate an offline transition for protocol values zero and two',
    () {
      final controller = ModuleStatusMonitorController();
      final transitions =
          (controller..observe(
                ModuleStatusReading.fromProtocolValues({
                  RobotModuleType.armor: 0,
                }),
              ))
              .observe(
                ModuleStatusReading.fromProtocolValues({
                  RobotModuleType.armor: 2,
                }),
              );

      expect(transitions, isEmpty);
    },
  );

  test('reports recovery when an offline module becomes online', () {
    final controller = ModuleStatusMonitorController();
    final transitions =
        (controller..observe(
              const ModuleStatusReading({
                RobotModuleType.armor: ModuleAvailability.offline,
              }),
            ))
            .observe(
              const ModuleStatusReading({
                RobotModuleType.armor: ModuleAvailability.online,
              }),
            );

    expect(transitions.single.becameOnline, isTrue);
  });

  test('reset clears explicitly observed statuses', () {
    final controller = ModuleStatusMonitorController()
      ..observe(
        const ModuleStatusReading({
          RobotModuleType.armor: ModuleAvailability.offline,
        }),
      )
      ..reset();

    expect(controller.state.statuses, isEmpty);
  });
}
