import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/window/desktop_window_frame.dart';

const windowChannel = MethodChannel('wod_client/window');
const windowChildKey = ValueKey<String>('window-child');

void main() {
  testWidgets('Windows uses the application title bar controls', (tester) async {
    await _withPlatform(TargetPlatform.windows, () async {
      _mockWindowChannel(tester);
      await _pumpFrame(tester);

      expect(find.byType(Stack), findsWidgets);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(find.byIcon(Icons.crop_square), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byKey(windowChildKey), findsOneWidget);
    });
  });

  testWidgets('Android bypasses desktop window controls', (tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      await _pumpFrame(tester);

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byKey(windowChildKey), findsOneWidget);
    });
  });
}

void _mockWindowChannel(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    windowChannel,
    (call) async => call.method == 'isMaximized' ? false : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      null,
    ),
  );
}

Future<void> _pumpFrame(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: DesktopWindowFrame(
        child: ColoredBox(key: windowChildKey, color: Colors.red),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
