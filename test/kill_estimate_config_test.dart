import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/kill_estimate_config.dart';

void main() {
  group('KillEstimateConfig', () {
    test('round-trips JSON fields', () {
      const config = KillEstimateConfig(
        hitRate: 0.5,
        smallProjectileDamage: 12,
        largeProjectileDamage: 120,
      );

      final restored = KillEstimateConfig.fromJson(config.toJson());

      expect(restored.hitRate, 0.5);
      expect(restored.smallProjectileDamage, 12);
      expect(restored.largeProjectileDamage, 120);
      expect(restored.maxHealth(KillEstimateRobotRole.sentry), 600);
    });

    test('calculates expected fired projectile count using hit rate', () {
      const config = KillEstimateConfig(hitRate: 0.5);

      expect(
        config.expectedProjectiles(
          currentHealth: 101,
          useLargeProjectile: false,
        ),
        21,
      );
      expect(
        config.expectedProjectiles(
          currentHealth: 500,
          useLargeProjectile: true,
        ),
        10,
      );
      expect(
        config.expectedProjectiles(currentHealth: 0, useLargeProjectile: true),
        0,
      );
    });

    test('invalid JSON values fall back to defaults', () {
      final config = KillEstimateConfig.fromJson({
        'hit_rate': 0,
        'small_projectile_damage': -1,
        'max_health_by_role': {'hero': 0},
      });

      expect(config.hitRate, defaultHitRate);
      expect(config.smallProjectileDamage, defaultSmallProjectileDamage);
      expect(config.maxHealth(KillEstimateRobotRole.hero), 500);
    });
  });
}
