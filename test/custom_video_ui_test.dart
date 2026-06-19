/// Widget/unit tests for the custom video UI layer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_providers.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/custom_video_screen.dart';
import 'package:robomaster_custom_client_1/features/custom_video/presentation/widgets/crosshair_painter.dart';

void main() {
  group('CrosshairPainter', () {
    test('default constructor uses zero offset and line width 1', () {
      const painter = CrosshairPainter();
      expect(painter.offsetX, 0);
      expect(painter.offsetY, 0);
      expect(painter.lineWidth, 1);
    });

    test('shouldRepaint returns true when parameters change', () {
      const a = CrosshairPainter();
      const b = CrosshairPainter(offsetX: 5);
      expect(b.shouldRepaint(a), isTrue);

      const c = CrosshairPainter(offsetY: 3);
      expect(c.shouldRepaint(a), isTrue);

      const d = CrosshairPainter(lineWidth: 2);
      expect(d.shouldRepaint(a), isTrue);
    });

    test('shouldRepaint returns false for identical parameters', () {
      const a = CrosshairPainter(offsetX: 10, offsetY: -5, lineWidth: 2);
      const b = CrosshairPainter(offsetX: 10, offsetY: -5, lineWidth: 2);
      expect(b.shouldRepaint(a), isFalse);
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
}
