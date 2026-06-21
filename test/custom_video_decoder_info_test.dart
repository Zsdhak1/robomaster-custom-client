/// Unit tests for [CustomVideoDecoderInfoNotifier].
///
/// The debug panel relies on this notifier to accumulate decoder diagnostics
/// (resolution, codec, errors) and a bounded rolling log; these tests pin that
/// behaviour so the panel always reflects accurate state.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/custom_video/logic/custom_video_decoder_info.dart';

void main() {
  group('CustomVideoDecoderInfoNotifier', () {
    test('starts empty', () {
      final n = CustomVideoDecoderInfoNotifier();
      expect(n.state.backend, isNull);
      expect(n.state.playing, isFalse);
      expect(n.state.hasResolution, isFalse);
      expect(n.state.logs, isEmpty);
    });

    test('beginSession records backend, attempt and clears prior error', () {
      final n = CustomVideoDecoderInfoNotifier()
        ..setError('boom')
        ..beginSession('fvp', attempt: 2);
      expect(n.state.backend, 'fvp');
      expect(n.state.attempt, 2);
      expect(n.state.lastError, isNull);
      // One log for the error, one for the session open.
      expect(n.state.logs.length, 2);
      expect(n.state.logs.last.message, contains('fvp'));
    });

    test('setResolution ignores zero/null and logs once per change', () {
      final n = CustomVideoDecoderInfoNotifier()
        ..setResolution(0, 0)
        ..setResolution(null, 720);
      expect(n.state.hasResolution, isFalse);
      expect(n.state.logs, isEmpty);

      n.setResolution(1280, 720);
      expect(n.state.hasResolution, isTrue);
      expect(n.state.width, 1280);
      expect(n.state.height, 720);
      expect(n.state.logs.length, 1);

      // Same resolution again does not add a duplicate log.
      n.setResolution(1280, 720);
      expect(n.state.logs.length, 1);
    });

    test('setCodec stores codec details', () {
      final n = CustomVideoDecoderInfoNotifier()
        ..setCodec(
          codec: 'h264',
          pixelFormat: 'yuv420p',
          fps: 59.94,
          bitRate: 2400,
          profile: 66,
        );
      expect(n.state.codec, 'h264');
      expect(n.state.pixelFormat, 'yuv420p');
      expect(n.state.decoderFps, closeTo(59.94, 0.001));
      expect(n.state.bitRate, 2400);
      expect(n.state.profile, 66);
    });

    test('setError stops playback and records the message', () {
      final n = CustomVideoDecoderInfoNotifier()
        ..setPlaying(playing: true)
        ..setError('decode failed');
      expect(n.state.playing, isFalse);
      expect(n.state.lastError, 'decode failed');
      expect(n.state.logs.last.level, DecoderLogLevel.error);
    });

    test('setPlaying only logs on a real transition', () {
      final n = CustomVideoDecoderInfoNotifier()
        ..setPlaying(playing: false); // no-op (already false)
      expect(n.state.logs, isEmpty);

      n.setPlaying(playing: true);
      expect(n.state.playing, isTrue);
      expect(n.state.logs.length, 1);

      n.setPlaying(playing: true); // duplicate, no new log
      expect(n.state.logs.length, 1);
    });

    test('log buffer is bounded to the most recent entries', () {
      final n = CustomVideoDecoderInfoNotifier();
      for (var i = 0; i < 200; i++) {
        n.log(DecoderLogLevel.info, 'line $i');
      }
      // Bounded; keeps only the tail.
      expect(n.state.logs.length, lessThanOrEqualTo(60));
      expect(n.state.logs.last.message, 'line 199');
    });

    test('reset clears everything', () {
      final n = CustomVideoDecoderInfoNotifier()
        ..beginSession('media_kit', attempt: 1)
        ..setResolution(640, 480)
        ..reset();
      expect(n.state.backend, isNull);
      expect(n.state.hasResolution, isFalse);
      expect(n.state.logs, isEmpty);
    });
  });
}
