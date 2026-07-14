/// 仪表盘预计击杀弹丸数使用的本地配置。
library;

import 'dart:math' as math;

/// 击杀估算配置的 JSON Schema 版本。
const int killEstimateSchemaVersion = 1;

/// 默认命中率。
const double defaultHitRate = 0.6;

/// 默认 17mm 弹丸单发伤害。
const double defaultSmallProjectileDamage = 10;

/// 默认 42mm 弹丸单发伤害。
const double defaultLargeProjectileDamage = 100;

/// 可配置的机器人角色。
enum KillEstimateRobotRole { hero, engineer, infantry3, infantry4, sentry }

/// [KillEstimateRobotRole] 的显示信息。
extension KillEstimateRobotRoleLabel on KillEstimateRobotRole {
  /// 设置页使用的中文名称。
  String get label => switch (this) {
    KillEstimateRobotRole.hero => '英雄',
    KillEstimateRobotRole.engineer => '工程',
    KillEstimateRobotRole.infantry3 => '步兵3',
    KillEstimateRobotRole.infantry4 => '步兵4',
    KillEstimateRobotRole.sentry => '哨兵',
  };

  /// 默认血量上限。
  int get defaultMaxHealth => switch (this) {
    KillEstimateRobotRole.hero => 500,
    KillEstimateRobotRole.engineer => 300,
    KillEstimateRobotRole.infantry3 => 300,
    KillEstimateRobotRole.infantry4 => 300,
    KillEstimateRobotRole.sentry => 600,
  };
}

/// 用户可调的击杀估算参数。
class KillEstimateConfig {
  /// 创建一份击杀估算配置。
  const KillEstimateConfig({
    this.hitRate = defaultHitRate,
    this.smallProjectileDamage = defaultSmallProjectileDamage,
    this.largeProjectileDamage = defaultLargeProjectileDamage,
    this.maxHealthByRole = const {
      KillEstimateRobotRole.hero: 500,
      KillEstimateRobotRole.engineer: 300,
      KillEstimateRobotRole.infantry3: 300,
      KillEstimateRobotRole.infantry4: 300,
      KillEstimateRobotRole.sentry: 600,
    },
  });

  /// 从 JSON 恢复配置；非法字段回退为默认值。
  factory KillEstimateConfig.fromJson(Map<String, dynamic> json) {
    const defaults = KillEstimateConfig();
    final healthJson = json['max_health_by_role'];
    final healthMap = healthJson is Map<String, dynamic>
        ? healthJson
        : const <String, dynamic>{};
    return KillEstimateConfig(
      hitRate: _positiveDouble(
        json['hit_rate'],
        defaults.hitRate,
      ).clamp(0.01, 1.0),
      smallProjectileDamage: _positiveDouble(
        json['small_projectile_damage'],
        defaults.smallProjectileDamage,
      ),
      largeProjectileDamage: _positiveDouble(
        json['large_projectile_damage'],
        defaults.largeProjectileDamage,
      ),
      maxHealthByRole: {
        for (final role in KillEstimateRobotRole.values)
          role: _positiveInt(healthMap[role.name], defaults.maxHealth(role)),
      },
    );
  }

  /// 预计命中率，范围为 0.01–1.0。
  final double hitRate;

  /// 17mm 弹丸单发伤害。
  final double smallProjectileDamage;

  /// 42mm 弹丸单发伤害。
  final double largeProjectileDamage;

  /// 各机器人角色的血量上限。
  final Map<KillEstimateRobotRole, int> maxHealthByRole;

  /// 返回 [role] 的血量上限。
  int maxHealth(KillEstimateRobotRole role) =>
      maxHealthByRole[role] ?? role.defaultMaxHealth;

  /// 计算击杀 [currentHealth] 预计需要发射的弹丸数。
  int? expectedProjectiles({
    required int currentHealth,
    required bool useLargeProjectile,
  }) {
    if (currentHealth <= 0) return 0;
    final damage = useLargeProjectile
        ? largeProjectileDamage
        : smallProjectileDamage;
    final expectedDamage = damage * hitRate;
    if (expectedDamage <= 0) return null;
    return math.max(1, (currentHealth / expectedDamage).ceil());
  }

  /// 创建更新部分字段后的不可变副本。
  KillEstimateConfig copyWith({
    double? hitRate,
    double? smallProjectileDamage,
    double? largeProjectileDamage,
    Map<KillEstimateRobotRole, int>? maxHealthByRole,
  }) {
    return KillEstimateConfig(
      hitRate: (hitRate ?? this.hitRate).clamp(0.01, 1.0),
      smallProjectileDamage: _positiveDouble(
        smallProjectileDamage,
        this.smallProjectileDamage,
      ),
      largeProjectileDamage: _positiveDouble(
        largeProjectileDamage,
        this.largeProjectileDamage,
      ),
      maxHealthByRole: Map.unmodifiable(
        maxHealthByRole ?? this.maxHealthByRole,
      ),
    );
  }

  /// 转换为可持久化的 JSON。
  Map<String, dynamic> toJson() => {
    'schema_version': killEstimateSchemaVersion,
    'hit_rate': hitRate,
    'small_projectile_damage': smallProjectileDamage,
    'large_projectile_damage': largeProjectileDamage,
    'max_health_by_role': {
      for (final entry in maxHealthByRole.entries) entry.key.name: entry.value,
    },
  };
}

double _positiveDouble(Object? value, double fallback) {
  final parsed = value is num ? value.toDouble() : null;
  return parsed != null && parsed > 0 ? parsed : fallback;
}

int _positiveInt(Object? value, int fallback) {
  final parsed = value is num ? value.toInt() : null;
  return parsed != null && parsed > 0 ? parsed : fallback;
}
