/// topic 注册表和记录配置的单元测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/constants/topic_registry.dart';
import 'package:robomaster_custom_client_1/features/settings/logic/record_config_provider.dart';

void main() {
  _topicRegistryTests();
  _recordConfigTests();
}

void _topicRegistryTests() {
  group('TopicRegistry', () {
    test('covers all 36 protocol topics', () {
      expect(TopicRegistry.all.length, 36);
    });

    test('byName lookup is consistent with all', () {
      expect(TopicRegistry.byName.length, TopicRegistry.all.length);
      for (final info in TopicRegistry.all) {
        expect(TopicRegistry.byName[info.topic], same(info));
      }
    });

    test('recordable == server→client topics only', () {
      expect(
        TopicRegistry.recordable.every(
          (t) => t.direction == TopicDirection.serverToClient,
        ),
        isTrue,
      );
      expect(
        TopicRegistry.recordable.any((t) => t.scope == TopicScope.command),
        isFalse,
      );
    });

    test('recordableByScope splits team-shared and robot-private', () {
      final shared = TopicRegistry.recordableByScope[TopicScope.teamShared]!;
      final private = TopicRegistry.recordableByScope[TopicScope.robotPrivate]!;
      expect(shared, isNotEmpty);
      expect(private, isNotEmpty);
      expect(
        shared.length + private.length,
        TopicRegistry.recordable.length,
      );
    });

    test('CustomByteBlock is robot-private recordable telemetry', () {
      final info = TopicRegistry.byName['CustomByteBlock'];
      expect(info, isNotNull);
      expect(info!.direction, TopicDirection.serverToClient);
      expect(info.scope, TopicScope.robotPrivate);
      expect(info.isRecordable, isTrue);
    });

    test('RobotPosition is robot-private (云台手 only)', () {
      expect(
        TopicRegistry.byName['RobotPosition']!.scope,
        TopicScope.robotPrivate,
      );
    });
  });
}

void _recordConfigTests() {
  group('RecordConfig allEnabled', () {
    test('enables exactly the recordable set', () {
      final config = RecordConfig.allEnabled();
      expect(config.enabledTopics, TopicRegistry.recordableTopicNames);
    });
  });

  group('RecordConfig toggles', () {
    test('withTopic toggles a single topic immutably', () {
      final base = RecordConfig.allEnabled();
      final off = base.withTopic('GameStatus', enabled: false);
      expect(off.isEnabled('GameStatus'), isFalse);
      expect(base.isEnabled('GameStatus'), isTrue);

      final on = off.withTopic('GameStatus', enabled: true);
      expect(on.isEnabled('GameStatus'), isTrue);
    });

    test('withAll(false) disables everything', () {
      expect(
        RecordConfig.allEnabled().withAll(enabled: false).enabledTopics,
        isEmpty,
      );
    });
  });

  group('RecordConfig serialization', () {
    test('toJson/fromJson round-trips the enabled set', () {
      final config = RecordConfig.allEnabled()
          .withTopic('GameStatus', enabled: false)
          .withTopic('Buff', enabled: false);
      final restored = RecordConfig.fromJson(config.toJson());
      expect(restored.enabledTopics, config.enabledTopics);
    });

    test('fromJson drops unknown topics and falls back when empty', () {
      final restored = RecordConfig.fromJson({
        'enabled_topics': ['GameStatus', 'NotARealTopic', 'KeyboardMouseControl'],
      });
      expect(restored.isEnabled('GameStatus'), isTrue);
      expect(restored.isEnabled('NotARealTopic'), isFalse);
      expect(restored.isEnabled('KeyboardMouseControl'), isFalse);

      final fallback = RecordConfig.fromJson({'enabled_topics': <String>[]});
      expect(fallback.enabledTopics, TopicRegistry.recordableTopicNames);
    });

    test('toJson carries the schema version', () {
      expect(
        RecordConfig.allEnabled().toJson()['schema_version'],
        recordConfigSchemaVersion,
      );
    });
  });
}
