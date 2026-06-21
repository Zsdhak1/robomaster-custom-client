/// Widget/unit tests for the custom video UI layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_providers.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/custom_video_screen.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/widgets/crosshair_painter.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/widgets/custom_video_debug_panel.dart';

/// A non-running stats snapshot the debug panel can render against.
CustomVideoStats _stoppedStats() => const CustomVideoStats(
      running: false,
      chunksReceived: 0,
      bytesReceived: 0,
      gateOpen: false,
      framesForwarded: 0,
      bytesForwarded: 0,
      decoderClients: 0,
      streamUrl: null,
      tsWrap: false,
      gateBufferBytes: 0,
      pendingFrames: 0,
      millisSinceLastChunk: null,
    );

/// A running stats snapshot with throughput, exercising every debug row.
CustomVideoStats _runningStats() => const CustomVideoStats(
      running: true,
      chunksReceived: 500,
      bytesReceived: 75000,
      gateOpen: true,
      framesForwarded: 120,
      bytesForwarded: 60000,
      decoderClients: 1,
      streamUrl: 'tcp://127.0.0.1:54321',
      tsWrap: true,
      gateBufferBytes: 0,
      pendingFrames: 0,
      millisSinceLastChunk: 20,
    ).withRates(
      chunksPerSec: 50,
      bytesInPerSec: 7500,
      framesPerSec: 30,
      bytesOutPerSec: 6000,
    );


void main() {
  group('CrosshairPainter', () {
    test('default constructor uses null aimCenter and line width 1', () {
      const painter = CrosshairPainter();
      expect(painter.aimCenter, isNull);
      expect(painter.lineWidth, 1);
    });

    test('shouldRepaint returns true when parameters change', () {
      const a = CrosshairPainter();
      const b = CrosshairPainter(aimCenter: Offset(50, 50));
      expect(b.shouldRepaint(a), isTrue);

      const c = CrosshairPainter(aimCenter: Offset(100, 200));
      expect(c.shouldRepaint(a), isTrue);

      const d = CrosshairPainter(lineWidth: 2);
      expect(d.shouldRepaint(a), isTrue);
    });

    test('shouldRepaint returns false for identical parameters', () {
      const a = CrosshairPainter(aimCenter: Offset(120, 80), lineWidth: 2);
      const b = CrosshairPainter(aimCenter: Offset(120, 80), lineWidth: 2);
      expect(b.shouldRepaint(a), isFalse);
    });

    test('shouldRepaint returns true when aimCenter changes from null', () {
      const a = CrosshairPainter();
      const b = CrosshairPainter(aimCenter: Offset(200, 150));
      expect(b.shouldRepaint(a), isTrue);
    });

    testWidgets('crosshair paints without error in a widget', (tester) async {
      const painter = CrosshairPainter();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: Size(200, 200),
              painter: painter,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('CustomVideoScreen', () {
    testWidgets('renders app bar and custom video panel', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override the periodic stats stream with a finite one so the
            // widget test doesn't leak a never-ending Stream.periodic timer.
            customVideoStatsProvider.overrideWith(
              (ref) => const Stream<CustomVideoStats>.empty(),
            ),
          ],
          child: const MaterialApp(
            home: CustomVideoScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('自定义图传 · CustomByteBlock'), findsOneWidget);
      expect(find.byType(CustomVideoScreen), findsOneWidget);
    });
  });

  group('CustomVideoDebugContent', () {
    testWidgets('renders pipeline sections even when not running',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customVideoStatsProvider.overrideWith(
              (ref) => Stream<CustomVideoStats>.value(_stoppedStats()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: CustomVideoDebugContent()),
            ),
          ),
        ),
      );
      await tester.pump();

      // The embeddable content always renders its sections; the running/idle
      // gating now lives in the shared VideoSidePanel wrapper.
      expect(find.text('流水线状态'), findsOneWidget);
      expect(find.text('MQTT 接收 (CustomByteBlock)'), findsOneWidget);
    });

    testWidgets('renders all diagnostic sections when running', (tester) async {
      // Tall viewport so the lazy ListView builds every section (the decoder
      // log sits below the fold at the default test surface height).
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customVideoStatsProvider.overrideWith(
              (ref) => Stream<CustomVideoStats>.value(_runningStats()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: CustomVideoDebugContent()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Each pipeline stage section header is present.
      expect(find.text('流水线状态'), findsOneWidget);
      expect(find.text('MQTT 接收 (CustomByteBlock)'), findsOneWidget);
      expect(find.text('TCP 桥转发'), findsOneWidget);
      expect(find.textContaining('解码器'), findsWidgets);
      expect(find.text('解码器日志'), findsOneWidget);

      // Throughput and bridge values surface.
      expect(find.text('tcp://127.0.0.1:54321'), findsOneWidget);
      expect(find.text('MPEG-TS'), findsOneWidget);
    });
  });
}
