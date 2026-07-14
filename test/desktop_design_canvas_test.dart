import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/responsive/desktop_design_canvas.dart';

const canvasKey = ValueKey<String>('design-canvas-child');

void main() {
  testWidgets('Windows canvas expands to a larger 16:9 window', (tester) async {
    await _withPlatform(TargetPlatform.windows, () async {
      await _pumpCanvas(tester, const Size(2048, 1152));
      expect(
        tester.getRect(find.byKey(canvasKey)),
        const Rect.fromLTWH(0, 0, 2048, 1152),
      );
    });
  });

  testWidgets('Linux canvas contains itself in a narrow window', (tester) async {
    await _withPlatform(TargetPlatform.linux, () async {
      await _pumpCanvas(tester, const Size(800, 800));
      final rect = tester.getRect(find.byKey(canvasKey));
      expect(rect.left, closeTo(0, 0.01));
      expect(rect.top, closeTo(133.33, 0.01));
      expect(rect.width, closeTo(800, 0.01));
      expect(rect.height, closeTo(533.33, 0.01));
    });
  });

  testWidgets('Windows canvas fills a 3:2 window without letterboxing', (
    tester,
  ) async {
    await _withPlatform(TargetPlatform.windows, () async {
      await _pumpCanvas(tester, const Size(1200, 800));
      expect(
        tester.getRect(find.byKey(canvasKey)),
        const Rect.fromLTWH(0, 0, 1200, 800),
      );
    });
  });

  testWidgets('Windows canvas fills a slightly wider maximized work area', (
    tester,
  ) async {
    await _withPlatform(TargetPlatform.windows, () async {
      await _pumpCanvas(tester, const Size(2048, 1128));
      expect(
        tester.getRect(find.byKey(canvasKey)),
        const Rect.fromLTWH(0, 0, 2048, 1128),
      );
    });
  });

  testWidgets('Android bypasses the fixed desktop canvas', (tester) async {
    await _withPlatform(TargetPlatform.android, () async {
      await _pumpCanvas(tester, const Size(800, 800));
      expect(
        tester.getRect(find.byKey(canvasKey)),
        const Rect.fromLTWH(0, 0, 800, 800),
      );
    });
  });
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

Future<void> _pumpCanvas(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const MaterialApp(
      home: DesktopDesignCanvas(
        child: ColoredBox(key: canvasKey, color: Colors.red),
      ),
    ),
  );
}
