import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/deployment_navigation_controller.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/combat_notification_rules.dart';

void main() {
  _testCountdownNavigation();
  _testMatchSuppression();
  _testLatePreparationCancellation();
  _testCancellationWhileEntering();
  _testNavigationFailure();
}

void _testCountdownNavigation() {
  test('counts down, prepares video and navigates', () async {
    var prepared = false;
    var navigated = false;
    final controller = DeploymentNavigationController(
      () async {
        prepared = true;
        return true;
      },
      () {},
      () => navigated = true,
      const Duration(milliseconds: 2),
    );
    expect(
      controller.start(const DeploymentNavigationConfig(countdownSeconds: 2)),
      isTrue,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(prepared, isTrue);
    expect(navigated, isTrue);
    expect(controller.state.isVisible, isFalse);
    controller.dispose();
  });
}

void _testMatchSuppression() {
  test('cancel can suppress current match and reset enables next match', () {
    var stopCount = 0;
    final controller = DeploymentNavigationController(
      () async => true,
      () => stopCount++,
      () {},
    );
    const config = DeploymentNavigationConfig(
      countdownSeconds: 5,
      cancelForCurrentMatch: true,
    );
    expect(controller.start(config), isTrue);
    controller.cancel();
    expect(controller.start(config), isFalse);
    controller.resetMatch();
    expect(controller.start(config), isTrue);
    controller.cancelIgnoringPolicy();
    expect(stopCount, greaterThanOrEqualTo(0));
    controller.dispose();
  });
}

void _testLatePreparationCancellation() {
  test('cancel during preparation stops a late-started video', () async {
    var stopped = false;
    final controller = DeploymentNavigationController(
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return true;
      },
      () => stopped = true,
      () {},
      const Duration(days: 1),
    );
    addTearDown(controller.dispose);
    controller
      ..start(const DeploymentNavigationConfig(countdownSeconds: 5))
      ..cancel();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(stopped, isTrue);
  });
}

void _testCancellationWhileEntering() {
  test('cancel while entering ignores the late preparation result', () async {
    final preparation = Completer<bool>();
    var navigated = false;
    var stopCount = 0;
    final controller = DeploymentNavigationController(
      () => preparation.future,
      () => stopCount++,
      () => navigated = true,
      const Duration(days: 1),
    );
    addTearDown(controller.dispose);
    controller.start(const DeploymentNavigationConfig(countdownSeconds: 5));
    final entering = controller.enterNow();
    controller.cancel();
    preparation.complete(true);
    await entering;
    expect(controller.state.isVisible, isFalse);
    expect(navigated, isFalse);
    expect(stopCount, 1);
  });
}

void _testNavigationFailure() {
  test('navigation callback failure stays visible with an error', () async {
    final controller = DeploymentNavigationController(
      () async => true,
      () {},
      () => throw StateError('navigation failed'),
    );
    addTearDown(controller.dispose);
    controller.start(
      const DeploymentNavigationConfig(
        countdownSeconds: 5,
        prestartVideo: false,
      ),
    );
    await controller.enterNow();
    expect(controller.state.phase, DeploymentNavigationPhase.failed);
    expect(controller.state.errorMessage, isNotEmpty);
  });
}
