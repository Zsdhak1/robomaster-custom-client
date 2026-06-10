// This is a generated file - do not edit.
//
// Generated from robomaster_custom_client.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use keyboardMouseControlDescriptor instead')
const KeyboardMouseControl$json = {
  '1': 'KeyboardMouseControl',
  '2': [
    {'1': 'mouse_x', '3': 1, '4': 1, '5': 5, '10': 'mouseX'},
    {'1': 'mouse_y', '3': 2, '4': 1, '5': 5, '10': 'mouseY'},
    {'1': 'mouse_z', '3': 3, '4': 1, '5': 5, '10': 'mouseZ'},
    {'1': 'left_button_down', '3': 4, '4': 1, '5': 8, '10': 'leftButtonDown'},
    {'1': 'right_button_down', '3': 5, '4': 1, '5': 8, '10': 'rightButtonDown'},
    {'1': 'keyboard_value', '3': 6, '4': 1, '5': 13, '10': 'keyboardValue'},
    {'1': 'mid_button_down', '3': 7, '4': 1, '5': 8, '10': 'midButtonDown'},
  ],
};

/// Descriptor for `KeyboardMouseControl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keyboardMouseControlDescriptor = $convert.base64Decode(
    'ChRLZXlib2FyZE1vdXNlQ29udHJvbBIXCgdtb3VzZV94GAEgASgFUgZtb3VzZVgSFwoHbW91c2'
    'VfeRgCIAEoBVIGbW91c2VZEhcKB21vdXNlX3oYAyABKAVSBm1vdXNlWhIoChBsZWZ0X2J1dHRv'
    'bl9kb3duGAQgASgIUg5sZWZ0QnV0dG9uRG93bhIqChFyaWdodF9idXR0b25fZG93bhgFIAEoCF'
    'IPcmlnaHRCdXR0b25Eb3duEiUKDmtleWJvYXJkX3ZhbHVlGAYgASgNUg1rZXlib2FyZFZhbHVl'
    'EiYKD21pZF9idXR0b25fZG93bhgHIAEoCFINbWlkQnV0dG9uRG93bg==');

@$core.Deprecated('Use customControlDescriptor instead')
const CustomControl$json = {
  '1': 'CustomControl',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `CustomControl`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List customControlDescriptor =
    $convert.base64Decode('Cg1DdXN0b21Db250cm9sEhIKBGRhdGEYASABKAxSBGRhdGE=');

@$core.Deprecated('Use gameStatusDescriptor instead')
const GameStatus$json = {
  '1': 'GameStatus',
  '2': [
    {'1': 'current_round', '3': 1, '4': 1, '5': 13, '10': 'currentRound'},
    {'1': 'total_rounds', '3': 2, '4': 1, '5': 13, '10': 'totalRounds'},
    {'1': 'red_score', '3': 3, '4': 1, '5': 13, '10': 'redScore'},
    {'1': 'blue_score', '3': 4, '4': 1, '5': 13, '10': 'blueScore'},
    {'1': 'current_stage', '3': 5, '4': 1, '5': 13, '10': 'currentStage'},
    {
      '1': 'stage_countdown_sec',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'stageCountdownSec'
    },
    {'1': 'stage_elapsed_sec', '3': 7, '4': 1, '5': 5, '10': 'stageElapsedSec'},
    {'1': 'is_paused', '3': 8, '4': 1, '5': 8, '10': 'isPaused'},
  ],
};

/// Descriptor for `GameStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gameStatusDescriptor = $convert.base64Decode(
    'CgpHYW1lU3RhdHVzEiMKDWN1cnJlbnRfcm91bmQYASABKA1SDGN1cnJlbnRSb3VuZBIhCgx0b3'
    'RhbF9yb3VuZHMYAiABKA1SC3RvdGFsUm91bmRzEhsKCXJlZF9zY29yZRgDIAEoDVIIcmVkU2Nv'
    'cmUSHQoKYmx1ZV9zY29yZRgEIAEoDVIJYmx1ZVNjb3JlEiMKDWN1cnJlbnRfc3RhZ2UYBSABKA'
    '1SDGN1cnJlbnRTdGFnZRIuChNzdGFnZV9jb3VudGRvd25fc2VjGAYgASgFUhFzdGFnZUNvdW50'
    'ZG93blNlYxIqChFzdGFnZV9lbGFwc2VkX3NlYxgHIAEoBVIPc3RhZ2VFbGFwc2VkU2VjEhsKCW'
    'lzX3BhdXNlZBgIIAEoCFIIaXNQYXVzZWQ=');

@$core.Deprecated('Use globalUnitStatusDescriptor instead')
const GlobalUnitStatus$json = {
  '1': 'GlobalUnitStatus',
  '2': [
    {'1': 'base_health', '3': 1, '4': 1, '5': 13, '10': 'baseHealth'},
    {'1': 'base_status', '3': 2, '4': 1, '5': 13, '10': 'baseStatus'},
    {'1': 'base_shield', '3': 3, '4': 1, '5': 13, '10': 'baseShield'},
    {'1': 'outpost_health', '3': 4, '4': 1, '5': 13, '10': 'outpostHealth'},
    {'1': 'outpost_status', '3': 5, '4': 1, '5': 13, '10': 'outpostStatus'},
    {
      '1': 'enemy_base_health',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'enemyBaseHealth'
    },
    {
      '1': 'enemy_base_status',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'enemyBaseStatus'
    },
    {
      '1': 'enemy_base_shield',
      '3': 8,
      '4': 1,
      '5': 13,
      '10': 'enemyBaseShield'
    },
    {
      '1': 'enemy_outpost_health',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'enemyOutpostHealth'
    },
    {
      '1': 'enemy_outpost_status',
      '3': 10,
      '4': 1,
      '5': 13,
      '10': 'enemyOutpostStatus'
    },
    {'1': 'robot_health', '3': 11, '4': 3, '5': 13, '10': 'robotHealth'},
    {'1': 'robot_bullets', '3': 12, '4': 3, '5': 5, '10': 'robotBullets'},
    {
      '1': 'total_damage_ally',
      '3': 13,
      '4': 1,
      '5': 13,
      '10': 'totalDamageAlly'
    },
    {
      '1': 'total_damage_enemy',
      '3': 14,
      '4': 1,
      '5': 13,
      '10': 'totalDamageEnemy'
    },
  ],
};

/// Descriptor for `GlobalUnitStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List globalUnitStatusDescriptor = $convert.base64Decode(
    'ChBHbG9iYWxVbml0U3RhdHVzEh8KC2Jhc2VfaGVhbHRoGAEgASgNUgpiYXNlSGVhbHRoEh8KC2'
    'Jhc2Vfc3RhdHVzGAIgASgNUgpiYXNlU3RhdHVzEh8KC2Jhc2Vfc2hpZWxkGAMgASgNUgpiYXNl'
    'U2hpZWxkEiUKDm91dHBvc3RfaGVhbHRoGAQgASgNUg1vdXRwb3N0SGVhbHRoEiUKDm91dHBvc3'
    'Rfc3RhdHVzGAUgASgNUg1vdXRwb3N0U3RhdHVzEioKEWVuZW15X2Jhc2VfaGVhbHRoGAYgASgN'
    'Ug9lbmVteUJhc2VIZWFsdGgSKgoRZW5lbXlfYmFzZV9zdGF0dXMYByABKA1SD2VuZW15QmFzZV'
    'N0YXR1cxIqChFlbmVteV9iYXNlX3NoaWVsZBgIIAEoDVIPZW5lbXlCYXNlU2hpZWxkEjAKFGVu'
    'ZW15X291dHBvc3RfaGVhbHRoGAkgASgNUhJlbmVteU91dHBvc3RIZWFsdGgSMAoUZW5lbXlfb3'
    'V0cG9zdF9zdGF0dXMYCiABKA1SEmVuZW15T3V0cG9zdFN0YXR1cxIhCgxyb2JvdF9oZWFsdGgY'
    'CyADKA1SC3JvYm90SGVhbHRoEiMKDXJvYm90X2J1bGxldHMYDCADKAVSDHJvYm90QnVsbGV0cx'
    'IqChF0b3RhbF9kYW1hZ2VfYWxseRgNIAEoDVIPdG90YWxEYW1hZ2VBbGx5EiwKEnRvdGFsX2Rh'
    'bWFnZV9lbmVteRgOIAEoDVIQdG90YWxEYW1hZ2VFbmVteQ==');

@$core.Deprecated('Use globalLogisticsStatusDescriptor instead')
const GlobalLogisticsStatus$json = {
  '1': 'GlobalLogisticsStatus',
  '2': [
    {
      '1': 'remaining_economy',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'remainingEconomy'
    },
    {
      '1': 'total_economy_obtained',
      '3': 2,
      '4': 1,
      '5': 4,
      '10': 'totalEconomyObtained'
    },
    {'1': 'tech_level', '3': 3, '4': 1, '5': 13, '10': 'techLevel'},
    {'1': 'encryption_level', '3': 4, '4': 1, '5': 13, '10': 'encryptionLevel'},
  ],
};

/// Descriptor for `GlobalLogisticsStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List globalLogisticsStatusDescriptor = $convert.base64Decode(
    'ChVHbG9iYWxMb2dpc3RpY3NTdGF0dXMSKwoRcmVtYWluaW5nX2Vjb25vbXkYASABKA1SEHJlbW'
    'FpbmluZ0Vjb25vbXkSNAoWdG90YWxfZWNvbm9teV9vYnRhaW5lZBgCIAEoBFIUdG90YWxFY29u'
    'b215T2J0YWluZWQSHQoKdGVjaF9sZXZlbBgDIAEoDVIJdGVjaExldmVsEikKEGVuY3J5cHRpb2'
    '5fbGV2ZWwYBCABKA1SD2VuY3J5cHRpb25MZXZlbA==');

@$core.Deprecated('Use globalSpecialMechanismDescriptor instead')
const GlobalSpecialMechanism$json = {
  '1': 'GlobalSpecialMechanism',
  '2': [
    {'1': 'mechanism_id', '3': 1, '4': 3, '5': 13, '10': 'mechanismId'},
    {
      '1': 'mechanism_time_sec',
      '3': 2,
      '4': 3,
      '5': 5,
      '10': 'mechanismTimeSec'
    },
  ],
};

/// Descriptor for `GlobalSpecialMechanism`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List globalSpecialMechanismDescriptor =
    $convert.base64Decode(
        'ChZHbG9iYWxTcGVjaWFsTWVjaGFuaXNtEiEKDG1lY2hhbmlzbV9pZBgBIAMoDVILbWVjaGFuaX'
        'NtSWQSLAoSbWVjaGFuaXNtX3RpbWVfc2VjGAIgAygFUhBtZWNoYW5pc21UaW1lU2Vj');

@$core.Deprecated('Use eventDescriptor instead')
const Event$json = {
  '1': 'Event',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 5, '10': 'eventId'},
    {'1': 'param', '3': 2, '4': 1, '5': 9, '10': 'param'},
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBIZCghldmVudF9pZBgBIAEoBVIHZXZlbnRJZBIUCgVwYXJhbRgCIAEoCVIFcGFyYW'
    '0=');

@$core.Deprecated('Use robotInjuryStatDescriptor instead')
const RobotInjuryStat$json = {
  '1': 'RobotInjuryStat',
  '2': [
    {'1': 'total_damage', '3': 1, '4': 1, '5': 13, '10': 'totalDamage'},
    {'1': 'collision_damage', '3': 2, '4': 1, '5': 13, '10': 'collisionDamage'},
    {
      '1': 'small_projectile_damage',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'smallProjectileDamage'
    },
    {
      '1': 'large_projectile_damage',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'largeProjectileDamage'
    },
    {
      '1': 'dart_splash_damage',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'dartSplashDamage'
    },
    {
      '1': 'module_offline_damage',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'moduleOfflineDamage'
    },
    {'1': 'offline_damage', '3': 7, '4': 1, '5': 13, '10': 'offlineDamage'},
    {'1': 'penalty_damage', '3': 8, '4': 1, '5': 13, '10': 'penaltyDamage'},
    {
      '1': 'server_kill_damage',
      '3': 9,
      '4': 1,
      '5': 13,
      '10': 'serverKillDamage'
    },
    {'1': 'killer_id', '3': 10, '4': 1, '5': 13, '10': 'killerId'},
  ],
};

/// Descriptor for `RobotInjuryStat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotInjuryStatDescriptor = $convert.base64Decode(
    'Cg9Sb2JvdEluanVyeVN0YXQSIQoMdG90YWxfZGFtYWdlGAEgASgNUgt0b3RhbERhbWFnZRIpCh'
    'Bjb2xsaXNpb25fZGFtYWdlGAIgASgNUg9jb2xsaXNpb25EYW1hZ2USNgoXc21hbGxfcHJvamVj'
    'dGlsZV9kYW1hZ2UYAyABKA1SFXNtYWxsUHJvamVjdGlsZURhbWFnZRI2ChdsYXJnZV9wcm9qZW'
    'N0aWxlX2RhbWFnZRgEIAEoDVIVbGFyZ2VQcm9qZWN0aWxlRGFtYWdlEiwKEmRhcnRfc3BsYXNo'
    'X2RhbWFnZRgFIAEoDVIQZGFydFNwbGFzaERhbWFnZRIyChVtb2R1bGVfb2ZmbGluZV9kYW1hZ2'
    'UYBiABKA1SE21vZHVsZU9mZmxpbmVEYW1hZ2USJQoOb2ZmbGluZV9kYW1hZ2UYByABKA1SDW9m'
    'ZmxpbmVEYW1hZ2USJQoOcGVuYWx0eV9kYW1hZ2UYCCABKA1SDXBlbmFsdHlEYW1hZ2USLAoSc2'
    'VydmVyX2tpbGxfZGFtYWdlGAkgASgNUhBzZXJ2ZXJLaWxsRGFtYWdlEhsKCWtpbGxlcl9pZBgK'
    'IAEoDVIIa2lsbGVySWQ=');

@$core.Deprecated('Use robotRespawnStatusDescriptor instead')
const RobotRespawnStatus$json = {
  '1': 'RobotRespawnStatus',
  '2': [
    {
      '1': 'is_pending_respawn',
      '3': 1,
      '4': 1,
      '5': 8,
      '10': 'isPendingRespawn'
    },
    {
      '1': 'total_respawn_progress',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'totalRespawnProgress'
    },
    {
      '1': 'current_respawn_progress',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'currentRespawnProgress'
    },
    {'1': 'can_free_respawn', '3': 4, '4': 1, '5': 8, '10': 'canFreeRespawn'},
    {
      '1': 'gold_cost_for_respawn',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'goldCostForRespawn'
    },
    {
      '1': 'can_pay_for_respawn',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'canPayForRespawn'
    },
  ],
};

/// Descriptor for `RobotRespawnStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotRespawnStatusDescriptor = $convert.base64Decode(
    'ChJSb2JvdFJlc3Bhd25TdGF0dXMSLAoSaXNfcGVuZGluZ19yZXNwYXduGAEgASgIUhBpc1Blbm'
    'RpbmdSZXNwYXduEjQKFnRvdGFsX3Jlc3Bhd25fcHJvZ3Jlc3MYAiABKA1SFHRvdGFsUmVzcGF3'
    'blByb2dyZXNzEjgKGGN1cnJlbnRfcmVzcGF3bl9wcm9ncmVzcxgDIAEoDVIWY3VycmVudFJlc3'
    'Bhd25Qcm9ncmVzcxIoChBjYW5fZnJlZV9yZXNwYXduGAQgASgIUg5jYW5GcmVlUmVzcGF3bhIx'
    'ChVnb2xkX2Nvc3RfZm9yX3Jlc3Bhd24YBSABKA1SEmdvbGRDb3N0Rm9yUmVzcGF3bhItChNjYW'
    '5fcGF5X2Zvcl9yZXNwYXduGAYgASgIUhBjYW5QYXlGb3JSZXNwYXdu');

@$core.Deprecated('Use robotStaticStatusDescriptor instead')
const RobotStaticStatus$json = {
  '1': 'RobotStaticStatus',
  '2': [
    {'1': 'connection_state', '3': 1, '4': 1, '5': 13, '10': 'connectionState'},
    {'1': 'field_state', '3': 2, '4': 1, '5': 13, '10': 'fieldState'},
    {'1': 'alive_state', '3': 3, '4': 1, '5': 13, '10': 'aliveState'},
    {'1': 'robot_id', '3': 4, '4': 1, '5': 13, '10': 'robotId'},
    {'1': 'robot_type', '3': 5, '4': 1, '5': 13, '10': 'robotType'},
    {
      '1': 'performance_system_shooter',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'performanceSystemShooter'
    },
    {
      '1': 'performance_system_chassis',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'performanceSystemChassis'
    },
    {'1': 'level', '3': 8, '4': 1, '5': 13, '10': 'level'},
    {'1': 'max_health', '3': 9, '4': 1, '5': 13, '10': 'maxHealth'},
    {'1': 'max_heat', '3': 10, '4': 1, '5': 13, '10': 'maxHeat'},
    {
      '1': 'heat_cooldown_rate',
      '3': 11,
      '4': 1,
      '5': 2,
      '10': 'heatCooldownRate'
    },
    {'1': 'max_power', '3': 12, '4': 1, '5': 13, '10': 'maxPower'},
    {
      '1': 'max_buffer_energy',
      '3': 13,
      '4': 1,
      '5': 13,
      '10': 'maxBufferEnergy'
    },
    {
      '1': 'max_chassis_energy',
      '3': 14,
      '4': 1,
      '5': 13,
      '10': 'maxChassisEnergy'
    },
  ],
};

/// Descriptor for `RobotStaticStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotStaticStatusDescriptor = $convert.base64Decode(
    'ChFSb2JvdFN0YXRpY1N0YXR1cxIpChBjb25uZWN0aW9uX3N0YXRlGAEgASgNUg9jb25uZWN0aW'
    '9uU3RhdGUSHwoLZmllbGRfc3RhdGUYAiABKA1SCmZpZWxkU3RhdGUSHwoLYWxpdmVfc3RhdGUY'
    'AyABKA1SCmFsaXZlU3RhdGUSGQoIcm9ib3RfaWQYBCABKA1SB3JvYm90SWQSHQoKcm9ib3RfdH'
    'lwZRgFIAEoDVIJcm9ib3RUeXBlEjwKGnBlcmZvcm1hbmNlX3N5c3RlbV9zaG9vdGVyGAYgASgN'
    'UhhwZXJmb3JtYW5jZVN5c3RlbVNob290ZXISPAoacGVyZm9ybWFuY2Vfc3lzdGVtX2NoYXNzaX'
    'MYByABKA1SGHBlcmZvcm1hbmNlU3lzdGVtQ2hhc3NpcxIUCgVsZXZlbBgIIAEoDVIFbGV2ZWwS'
    'HQoKbWF4X2hlYWx0aBgJIAEoDVIJbWF4SGVhbHRoEhkKCG1heF9oZWF0GAogASgNUgdtYXhIZW'
    'F0EiwKEmhlYXRfY29vbGRvd25fcmF0ZRgLIAEoAlIQaGVhdENvb2xkb3duUmF0ZRIbCgltYXhf'
    'cG93ZXIYDCABKA1SCG1heFBvd2VyEioKEW1heF9idWZmZXJfZW5lcmd5GA0gASgNUg9tYXhCdW'
    'ZmZXJFbmVyZ3kSLAoSbWF4X2NoYXNzaXNfZW5lcmd5GA4gASgNUhBtYXhDaGFzc2lzRW5lcmd5');

@$core.Deprecated('Use robotDynamicStatusDescriptor instead')
const RobotDynamicStatus$json = {
  '1': 'RobotDynamicStatus',
  '2': [
    {'1': 'current_health', '3': 1, '4': 1, '5': 13, '10': 'currentHealth'},
    {'1': 'current_heat', '3': 2, '4': 1, '5': 2, '10': 'currentHeat'},
    {
      '1': 'last_projectile_fire_rate',
      '3': 3,
      '4': 1,
      '5': 2,
      '10': 'lastProjectileFireRate'
    },
    {
      '1': 'current_chassis_energy',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'currentChassisEnergy'
    },
    {
      '1': 'current_buffer_energy',
      '3': 5,
      '4': 1,
      '5': 13,
      '10': 'currentBufferEnergy'
    },
    {
      '1': 'current_experience',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'currentExperience'
    },
    {
      '1': 'experience_for_upgrade',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'experienceForUpgrade'
    },
    {
      '1': 'total_projectiles_fired',
      '3': 8,
      '4': 1,
      '5': 13,
      '10': 'totalProjectilesFired'
    },
    {'1': 'remaining_ammo', '3': 9, '4': 1, '5': 13, '10': 'remainingAmmo'},
    {'1': 'is_out_of_combat', '3': 10, '4': 1, '5': 8, '10': 'isOutOfCombat'},
    {
      '1': 'out_of_combat_countdown',
      '3': 11,
      '4': 1,
      '5': 13,
      '10': 'outOfCombatCountdown'
    },
    {'1': 'can_remote_heal', '3': 12, '4': 1, '5': 8, '10': 'canRemoteHeal'},
    {'1': 'can_remote_ammo', '3': 13, '4': 1, '5': 8, '10': 'canRemoteAmmo'},
  ],
};

/// Descriptor for `RobotDynamicStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotDynamicStatusDescriptor = $convert.base64Decode(
    'ChJSb2JvdER5bmFtaWNTdGF0dXMSJQoOY3VycmVudF9oZWFsdGgYASABKA1SDWN1cnJlbnRIZW'
    'FsdGgSIQoMY3VycmVudF9oZWF0GAIgASgCUgtjdXJyZW50SGVhdBI5ChlsYXN0X3Byb2plY3Rp'
    'bGVfZmlyZV9yYXRlGAMgASgCUhZsYXN0UHJvamVjdGlsZUZpcmVSYXRlEjQKFmN1cnJlbnRfY2'
    'hhc3Npc19lbmVyZ3kYBCABKA1SFGN1cnJlbnRDaGFzc2lzRW5lcmd5EjIKFWN1cnJlbnRfYnVm'
    'ZmVyX2VuZXJneRgFIAEoDVITY3VycmVudEJ1ZmZlckVuZXJneRItChJjdXJyZW50X2V4cGVyaW'
    'VuY2UYBiABKA1SEWN1cnJlbnRFeHBlcmllbmNlEjQKFmV4cGVyaWVuY2VfZm9yX3VwZ3JhZGUY'
    'ByABKA1SFGV4cGVyaWVuY2VGb3JVcGdyYWRlEjYKF3RvdGFsX3Byb2plY3RpbGVzX2ZpcmVkGA'
    'ggASgNUhV0b3RhbFByb2plY3RpbGVzRmlyZWQSJQoOcmVtYWluaW5nX2FtbW8YCSABKA1SDXJl'
    'bWFpbmluZ0FtbW8SJwoQaXNfb3V0X29mX2NvbWJhdBgKIAEoCFINaXNPdXRPZkNvbWJhdBI1Ch'
    'dvdXRfb2ZfY29tYmF0X2NvdW50ZG93bhgLIAEoDVIUb3V0T2ZDb21iYXRDb3VudGRvd24SJgoP'
    'Y2FuX3JlbW90ZV9oZWFsGAwgASgIUg1jYW5SZW1vdGVIZWFsEiYKD2Nhbl9yZW1vdGVfYW1tbx'
    'gNIAEoCFINY2FuUmVtb3RlQW1tbw==');

@$core.Deprecated('Use robotModuleStatusDescriptor instead')
const RobotModuleStatus$json = {
  '1': 'RobotModuleStatus',
  '2': [
    {'1': 'power_manager', '3': 1, '4': 1, '5': 13, '10': 'powerManager'},
    {'1': 'rfid', '3': 2, '4': 1, '5': 13, '10': 'rfid'},
    {'1': 'light_strip', '3': 3, '4': 1, '5': 13, '10': 'lightStrip'},
    {'1': 'small_shooter', '3': 4, '4': 1, '5': 13, '10': 'smallShooter'},
    {'1': 'big_shooter', '3': 5, '4': 1, '5': 13, '10': 'bigShooter'},
    {'1': 'uwb', '3': 6, '4': 1, '5': 13, '10': 'uwb'},
    {'1': 'armor', '3': 7, '4': 1, '5': 13, '10': 'armor'},
    {
      '1': 'video_transmission',
      '3': 8,
      '4': 1,
      '5': 13,
      '10': 'videoTransmission'
    },
    {'1': 'capacitor', '3': 9, '4': 1, '5': 13, '10': 'capacitor'},
    {'1': 'main_controller', '3': 10, '4': 1, '5': 13, '10': 'mainController'},
    {
      '1': 'laser_detection_module',
      '3': 11,
      '4': 1,
      '5': 13,
      '10': 'laserDetectionModule'
    },
  ],
};

/// Descriptor for `RobotModuleStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotModuleStatusDescriptor = $convert.base64Decode(
    'ChFSb2JvdE1vZHVsZVN0YXR1cxIjCg1wb3dlcl9tYW5hZ2VyGAEgASgNUgxwb3dlck1hbmFnZX'
    'ISEgoEcmZpZBgCIAEoDVIEcmZpZBIfCgtsaWdodF9zdHJpcBgDIAEoDVIKbGlnaHRTdHJpcBIj'
    'Cg1zbWFsbF9zaG9vdGVyGAQgASgNUgxzbWFsbFNob290ZXISHwoLYmlnX3Nob290ZXIYBSABKA'
    '1SCmJpZ1Nob290ZXISEAoDdXdiGAYgASgNUgN1d2ISFAoFYXJtb3IYByABKA1SBWFybW9yEi0K'
    'EnZpZGVvX3RyYW5zbWlzc2lvbhgIIAEoDVIRdmlkZW9UcmFuc21pc3Npb24SHAoJY2FwYWNpdG'
    '9yGAkgASgNUgljYXBhY2l0b3ISJwoPbWFpbl9jb250cm9sbGVyGAogASgNUg5tYWluQ29udHJv'
    'bGxlchI0ChZsYXNlcl9kZXRlY3Rpb25fbW9kdWxlGAsgASgNUhRsYXNlckRldGVjdGlvbk1vZH'
    'VsZQ==');

@$core.Deprecated('Use robotPositionDescriptor instead')
const RobotPosition$json = {
  '1': 'RobotPosition',
  '2': [
    {'1': 'x', '3': 1, '4': 1, '5': 2, '10': 'x'},
    {'1': 'y', '3': 2, '4': 1, '5': 2, '10': 'y'},
    {'1': 'z', '3': 3, '4': 1, '5': 2, '10': 'z'},
    {'1': 'yaw', '3': 4, '4': 1, '5': 2, '10': 'yaw'},
    {'1': 'robot_id', '3': 5, '4': 1, '5': 13, '10': 'robotId'},
  ],
};

/// Descriptor for `RobotPosition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotPositionDescriptor = $convert.base64Decode(
    'Cg1Sb2JvdFBvc2l0aW9uEgwKAXgYASABKAJSAXgSDAoBeRgCIAEoAlIBeRIMCgF6GAMgASgCUg'
    'F6EhAKA3lhdxgEIAEoAlIDeWF3EhkKCHJvYm90X2lkGAUgASgNUgdyb2JvdElk');

@$core.Deprecated('Use buffDescriptor instead')
const Buff$json = {
  '1': 'Buff',
  '2': [
    {'1': 'robot_id', '3': 1, '4': 1, '5': 13, '10': 'robotId'},
    {'1': 'buff_type', '3': 2, '4': 1, '5': 13, '10': 'buffType'},
    {'1': 'buff_level', '3': 3, '4': 1, '5': 5, '10': 'buffLevel'},
    {'1': 'buff_max_time', '3': 4, '4': 1, '5': 13, '10': 'buffMaxTime'},
    {'1': 'buff_left_time', '3': 5, '4': 1, '5': 13, '10': 'buffLeftTime'},
  ],
};

/// Descriptor for `Buff`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List buffDescriptor = $convert.base64Decode(
    'CgRCdWZmEhkKCHJvYm90X2lkGAEgASgNUgdyb2JvdElkEhsKCWJ1ZmZfdHlwZRgCIAEoDVIIYn'
    'VmZlR5cGUSHQoKYnVmZl9sZXZlbBgDIAEoBVIJYnVmZkxldmVsEiIKDWJ1ZmZfbWF4X3RpbWUY'
    'BCABKA1SC2J1ZmZNYXhUaW1lEiQKDmJ1ZmZfbGVmdF90aW1lGAUgASgNUgxidWZmTGVmdFRpbW'
    'U=');

@$core.Deprecated('Use penaltyInfoDescriptor instead')
const PenaltyInfo$json = {
  '1': 'PenaltyInfo',
  '2': [
    {'1': 'penalty_type', '3': 1, '4': 1, '5': 13, '10': 'penaltyType'},
    {
      '1': 'penalty_effect_sec',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'penaltyEffectSec'
    },
    {
      '1': 'total_penalty_num',
      '3': 3,
      '4': 1,
      '5': 13,
      '10': 'totalPenaltyNum'
    },
  ],
};

/// Descriptor for `PenaltyInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List penaltyInfoDescriptor = $convert.base64Decode(
    'CgtQZW5hbHR5SW5mbxIhCgxwZW5hbHR5X3R5cGUYASABKA1SC3BlbmFsdHlUeXBlEiwKEnBlbm'
    'FsdHlfZWZmZWN0X3NlYxgCIAEoDVIQcGVuYWx0eUVmZmVjdFNlYxIqChF0b3RhbF9wZW5hbHR5'
    'X251bRgDIAEoDVIPdG90YWxQZW5hbHR5TnVt');

@$core.Deprecated('Use robotPathPlanInfoDescriptor instead')
const RobotPathPlanInfo$json = {
  '1': 'RobotPathPlanInfo',
  '2': [
    {'1': 'intention', '3': 1, '4': 1, '5': 13, '10': 'intention'},
    {'1': 'start_pos_x', '3': 2, '4': 1, '5': 13, '10': 'startPosX'},
    {'1': 'start_pos_y', '3': 3, '4': 1, '5': 13, '10': 'startPosY'},
    {
      '1': 'offset_x',
      '3': 4,
      '4': 3,
      '5': 5,
      '8': {'2': true},
      '10': 'offsetX',
    },
    {
      '1': 'offset_y',
      '3': 5,
      '4': 3,
      '5': 5,
      '8': {'2': true},
      '10': 'offsetY',
    },
    {'1': 'sender_id', '3': 6, '4': 1, '5': 13, '10': 'senderId'},
  ],
};

/// Descriptor for `RobotPathPlanInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotPathPlanInfoDescriptor = $convert.base64Decode(
    'ChFSb2JvdFBhdGhQbGFuSW5mbxIcCglpbnRlbnRpb24YASABKA1SCWludGVudGlvbhIeCgtzdG'
    'FydF9wb3NfeBgCIAEoDVIJc3RhcnRQb3NYEh4KC3N0YXJ0X3Bvc195GAMgASgNUglzdGFydFBv'
    'c1kSHQoIb2Zmc2V0X3gYBCADKAVCAhABUgdvZmZzZXRYEh0KCG9mZnNldF95GAUgAygFQgIQAV'
    'IHb2Zmc2V0WRIbCglzZW5kZXJfaWQYBiABKA1SCHNlbmRlcklk');

@$core.Deprecated('Use mapClickInfoDescriptor instead')
const MapClickInfo$json = {
  '1': 'MapClickInfo',
  '2': [
    {'1': 'is_send_all', '3': 1, '4': 1, '5': 13, '10': 'isSendAll'},
    {'1': 'robot_id', '3': 2, '4': 1, '5': 12, '10': 'robotId'},
    {'1': 'mode', '3': 3, '4': 1, '5': 13, '10': 'mode'},
    {'1': 'enemy_id', '3': 4, '4': 1, '5': 13, '10': 'enemyId'},
    {'1': 'ascii', '3': 5, '4': 1, '5': 13, '10': 'ascii'},
    {'1': 'type', '3': 6, '4': 1, '5': 13, '10': 'type'},
    {'1': 'map_x', '3': 7, '4': 1, '5': 2, '10': 'mapX'},
    {'1': 'map_y', '3': 8, '4': 1, '5': 2, '10': 'mapY'},
  ],
};

/// Descriptor for `MapClickInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mapClickInfoDescriptor = $convert.base64Decode(
    'CgxNYXBDbGlja0luZm8SHgoLaXNfc2VuZF9hbGwYASABKA1SCWlzU2VuZEFsbBIZCghyb2JvdF'
    '9pZBgCIAEoDFIHcm9ib3RJZBISCgRtb2RlGAMgASgNUgRtb2RlEhkKCGVuZW15X2lkGAQgASgN'
    'UgdlbmVteUlkEhQKBWFzY2lpGAUgASgNUgVhc2NpaRISCgR0eXBlGAYgASgNUgR0eXBlEhMKBW'
    '1hcF94GAcgASgCUgRtYXBYEhMKBW1hcF95GAggASgCUgRtYXBZ');

@$core.Deprecated('Use mapClickCmdDescriptor instead')
const MapClickCmd$json = {
  '1': 'MapClickCmd',
  '2': [
    {'1': 'is_send_all', '3': 1, '4': 1, '5': 13, '10': 'isSendAll'},
    {'1': 'robot_id', '3': 2, '4': 1, '5': 12, '10': 'robotId'},
    {'1': 'mode', '3': 3, '4': 1, '5': 13, '10': 'mode'},
    {'1': 'enemy_id', '3': 4, '4': 1, '5': 13, '10': 'enemyId'},
    {'1': 'ascii', '3': 5, '4': 1, '5': 13, '10': 'ascii'},
    {'1': 'type', '3': 6, '4': 1, '5': 13, '10': 'type'},
    {'1': 'map_x', '3': 7, '4': 1, '5': 2, '10': 'mapX'},
    {'1': 'map_y', '3': 8, '4': 1, '5': 2, '10': 'mapY'},
  ],
};

/// Descriptor for `MapClickCmd`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mapClickCmdDescriptor = $convert.base64Decode(
    'CgtNYXBDbGlja0NtZBIeCgtpc19zZW5kX2FsbBgBIAEoDVIJaXNTZW5kQWxsEhkKCHJvYm90X2'
    'lkGAIgASgMUgdyb2JvdElkEhIKBG1vZGUYAyABKA1SBG1vZGUSGQoIZW5lbXlfaWQYBCABKA1S'
    'B2VuZW15SWQSFAoFYXNjaWkYBSABKA1SBWFzY2lpEhIKBHR5cGUYBiABKA1SBHR5cGUSEwoFbW'
    'FwX3gYByABKAJSBG1hcFgSEwoFbWFwX3kYCCABKAJSBG1hcFk=');

@$core.Deprecated('Use radarSingleRobotInfoDescriptor instead')
const RadarSingleRobotInfo$json = {
  '1': 'RadarSingleRobotInfo',
  '2': [
    {'1': 'target_pos_x', '3': 1, '4': 1, '5': 13, '10': 'targetPosX'},
    {'1': 'target_pos_y', '3': 2, '4': 1, '5': 13, '10': 'targetPosY'},
    {'1': 'is_high_light', '3': 3, '4': 1, '5': 13, '10': 'isHighLight'},
  ],
};

/// Descriptor for `RadarSingleRobotInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List radarSingleRobotInfoDescriptor = $convert.base64Decode(
    'ChRSYWRhclNpbmdsZVJvYm90SW5mbxIgCgx0YXJnZXRfcG9zX3gYASABKA1SCnRhcmdldFBvc1'
    'gSIAoMdGFyZ2V0X3Bvc195GAIgASgNUgp0YXJnZXRQb3NZEiIKDWlzX2hpZ2hfbGlnaHQYAyAB'
    'KA1SC2lzSGlnaExpZ2h0');

@$core.Deprecated('Use radarInfoToClientDescriptor instead')
const RadarInfoToClient$json = {
  '1': 'RadarInfoToClient',
  '2': [
    {
      '1': 'radar_info',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.robomaster.RadarSingleRobotInfo',
      '10': 'radarInfo'
    },
  ],
};

/// Descriptor for `RadarInfoToClient`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List radarInfoToClientDescriptor = $convert.base64Decode(
    'ChFSYWRhckluZm9Ub0NsaWVudBI/CgpyYWRhcl9pbmZvGAEgAygLMiAucm9ib21hc3Rlci5SYW'
    'RhclNpbmdsZVJvYm90SW5mb1IJcmFkYXJJbmZv');

@$core.Deprecated('Use customByteBlockDescriptor instead')
const CustomByteBlock$json = {
  '1': 'CustomByteBlock',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `CustomByteBlock`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List customByteBlockDescriptor = $convert
    .base64Decode('Cg9DdXN0b21CeXRlQmxvY2sSEgoEZGF0YRgBIAEoDFIEZGF0YQ==');

@$core.Deprecated('Use assemblyCommandDescriptor instead')
const AssemblyCommand$json = {
  '1': 'AssemblyCommand',
  '2': [
    {'1': 'operation', '3': 1, '4': 1, '5': 13, '10': 'operation'},
    {'1': 'difficulty', '3': 2, '4': 1, '5': 13, '10': 'difficulty'},
  ],
};

/// Descriptor for `AssemblyCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List assemblyCommandDescriptor = $convert.base64Decode(
    'Cg9Bc3NlbWJseUNvbW1hbmQSHAoJb3BlcmF0aW9uGAEgASgNUglvcGVyYXRpb24SHgoKZGlmZm'
    'ljdWx0eRgCIAEoDVIKZGlmZmljdWx0eQ==');

@$core.Deprecated('Use techCoreMotionStateSyncDescriptor instead')
const TechCoreMotionStateSync$json = {
  '1': 'TechCoreMotionStateSync',
  '2': [
    {
      '1': 'maximum_difficulty_level',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'maximumDifficultyLevel'
    },
    {'1': 'basic_state', '3': 2, '4': 1, '5': 13, '10': 'basicState'},
    {'1': 'putin_state', '3': 3, '4': 1, '5': 13, '10': 'putinState'},
    {'1': 'move_state', '3': 4, '4': 1, '5': 13, '10': 'moveState'},
    {'1': 'rotate_state', '3': 5, '4': 1, '5': 13, '10': 'rotateState'},
    {
      '1': 'enemy_core_status',
      '3': 6,
      '4': 1,
      '5': 13,
      '10': 'enemyCoreStatus'
    },
    {'1': 'remain_time_all', '3': 7, '4': 1, '5': 13, '10': 'remainTimeAll'},
    {'1': 'remain_time_step', '3': 8, '4': 1, '5': 13, '10': 'remainTimeStep'},
  ],
};

/// Descriptor for `TechCoreMotionStateSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List techCoreMotionStateSyncDescriptor = $convert.base64Decode(
    'ChdUZWNoQ29yZU1vdGlvblN0YXRlU3luYxI4ChhtYXhpbXVtX2RpZmZpY3VsdHlfbGV2ZWwYAS'
    'ABKA1SFm1heGltdW1EaWZmaWN1bHR5TGV2ZWwSHwoLYmFzaWNfc3RhdGUYAiABKA1SCmJhc2lj'
    'U3RhdGUSHwoLcHV0aW5fc3RhdGUYAyABKA1SCnB1dGluU3RhdGUSHQoKbW92ZV9zdGF0ZRgEIA'
    'EoDVIJbW92ZVN0YXRlEiEKDHJvdGF0ZV9zdGF0ZRgFIAEoDVILcm90YXRlU3RhdGUSKgoRZW5l'
    'bXlfY29yZV9zdGF0dXMYBiABKA1SD2VuZW15Q29yZVN0YXR1cxImCg9yZW1haW5fdGltZV9hbG'
    'wYByABKA1SDXJlbWFpblRpbWVBbGwSKAoQcmVtYWluX3RpbWVfc3RlcBgIIAEoDVIOcmVtYWlu'
    'VGltZVN0ZXA=');

@$core.Deprecated('Use robotPerformanceSelectionCommandDescriptor instead')
const RobotPerformanceSelectionCommand$json = {
  '1': 'RobotPerformanceSelectionCommand',
  '2': [
    {'1': 'shooter', '3': 1, '4': 1, '5': 13, '10': 'shooter'},
    {'1': 'chassis', '3': 2, '4': 1, '5': 13, '10': 'chassis'},
    {'1': 'sentry_control', '3': 3, '4': 1, '5': 13, '10': 'sentryControl'},
  ],
};

/// Descriptor for `RobotPerformanceSelectionCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotPerformanceSelectionCommandDescriptor =
    $convert.base64Decode(
        'CiBSb2JvdFBlcmZvcm1hbmNlU2VsZWN0aW9uQ29tbWFuZBIYCgdzaG9vdGVyGAEgASgNUgdzaG'
        '9vdGVyEhgKB2NoYXNzaXMYAiABKA1SB2NoYXNzaXMSJQoOc2VudHJ5X2NvbnRyb2wYAyABKA1S'
        'DXNlbnRyeUNvbnRyb2w=');

@$core.Deprecated('Use robotPerformanceSelectionSyncDescriptor instead')
const RobotPerformanceSelectionSync$json = {
  '1': 'RobotPerformanceSelectionSync',
  '2': [
    {'1': 'shooter', '3': 1, '4': 1, '5': 13, '10': 'shooter'},
    {'1': 'chassis', '3': 2, '4': 1, '5': 13, '10': 'chassis'},
    {'1': 'sentry_control', '3': 3, '4': 1, '5': 13, '10': 'sentryControl'},
  ],
};

/// Descriptor for `RobotPerformanceSelectionSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List robotPerformanceSelectionSyncDescriptor =
    $convert.base64Decode(
        'Ch1Sb2JvdFBlcmZvcm1hbmNlU2VsZWN0aW9uU3luYxIYCgdzaG9vdGVyGAEgASgNUgdzaG9vdG'
        'VyEhgKB2NoYXNzaXMYAiABKA1SB2NoYXNzaXMSJQoOc2VudHJ5X2NvbnRyb2wYAyABKA1SDXNl'
        'bnRyeUNvbnRyb2w=');

@$core.Deprecated('Use commonCommandDescriptor instead')
const CommonCommand$json = {
  '1': 'CommonCommand',
  '2': [
    {'1': 'cmd_type', '3': 1, '4': 1, '5': 13, '10': 'cmdType'},
    {'1': 'param', '3': 2, '4': 1, '5': 13, '10': 'param'},
  ],
};

/// Descriptor for `CommonCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commonCommandDescriptor = $convert.base64Decode(
    'Cg1Db21tb25Db21tYW5kEhkKCGNtZF90eXBlGAEgASgNUgdjbWRUeXBlEhQKBXBhcmFtGAIgAS'
    'gNUgVwYXJhbQ==');

@$core.Deprecated('Use heroDeployModeEventCommandDescriptor instead')
const HeroDeployModeEventCommand$json = {
  '1': 'HeroDeployModeEventCommand',
  '2': [
    {'1': 'mode', '3': 1, '4': 1, '5': 13, '10': 'mode'},
  ],
};

/// Descriptor for `HeroDeployModeEventCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heroDeployModeEventCommandDescriptor =
    $convert.base64Decode(
        'ChpIZXJvRGVwbG95TW9kZUV2ZW50Q29tbWFuZBISCgRtb2RlGAEgASgNUgRtb2Rl');

@$core.Deprecated('Use deployModeStatusSyncDescriptor instead')
const DeployModeStatusSync$json = {
  '1': 'DeployModeStatusSync',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 13, '10': 'status'},
  ],
};

/// Descriptor for `DeployModeStatusSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deployModeStatusSyncDescriptor =
    $convert.base64Decode(
        'ChREZXBsb3lNb2RlU3RhdHVzU3luYxIWCgZzdGF0dXMYASABKA1SBnN0YXR1cw==');

@$core.Deprecated('Use runeActivateCommandDescriptor instead')
const RuneActivateCommand$json = {
  '1': 'RuneActivateCommand',
  '2': [
    {'1': 'activate', '3': 1, '4': 1, '5': 13, '10': 'activate'},
  ],
};

/// Descriptor for `RuneActivateCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List runeActivateCommandDescriptor =
    $convert.base64Decode(
        'ChNSdW5lQWN0aXZhdGVDb21tYW5kEhoKCGFjdGl2YXRlGAEgASgNUghhY3RpdmF0ZQ==');

@$core.Deprecated('Use runeStatusSyncDescriptor instead')
const RuneStatusSync$json = {
  '1': 'RuneStatusSync',
  '2': [
    {'1': 'rune_status', '3': 1, '4': 1, '5': 13, '10': 'runeStatus'},
    {'1': 'activated_arms', '3': 2, '4': 1, '5': 13, '10': 'activatedArms'},
    {'1': 'average_rings', '3': 3, '4': 1, '5': 2, '10': 'averageRings'},
  ],
};

/// Descriptor for `RuneStatusSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List runeStatusSyncDescriptor = $convert.base64Decode(
    'Cg5SdW5lU3RhdHVzU3luYxIfCgtydW5lX3N0YXR1cxgBIAEoDVIKcnVuZVN0YXR1cxIlCg5hY3'
    'RpdmF0ZWRfYXJtcxgCIAEoDVINYWN0aXZhdGVkQXJtcxIjCg1hdmVyYWdlX3JpbmdzGAMgASgC'
    'UgxhdmVyYWdlUmluZ3M=');

@$core.Deprecated('Use sentryStatusSyncDescriptor instead')
const SentryStatusSync$json = {
  '1': 'SentryStatusSync',
  '2': [
    {'1': 'posture_id', '3': 1, '4': 1, '5': 13, '10': 'postureId'},
    {'1': 'is_weakened', '3': 2, '4': 1, '5': 8, '10': 'isWeakened'},
  ],
};

/// Descriptor for `SentryStatusSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sentryStatusSyncDescriptor = $convert.base64Decode(
    'ChBTZW50cnlTdGF0dXNTeW5jEh0KCnBvc3R1cmVfaWQYASABKA1SCXBvc3R1cmVJZBIfCgtpc1'
    '93ZWFrZW5lZBgCIAEoCFIKaXNXZWFrZW5lZA==');

@$core.Deprecated('Use dartCommandDescriptor instead')
const DartCommand$json = {
  '1': 'DartCommand',
  '2': [
    {'1': 'target_id', '3': 1, '4': 1, '5': 13, '10': 'targetId'},
    {'1': 'open', '3': 2, '4': 1, '5': 8, '10': 'open'},
    {'1': 'launch_confirm', '3': 3, '4': 1, '5': 8, '10': 'launchConfirm'},
  ],
};

/// Descriptor for `DartCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dartCommandDescriptor = $convert.base64Decode(
    'CgtEYXJ0Q29tbWFuZBIbCgl0YXJnZXRfaWQYASABKA1SCHRhcmdldElkEhIKBG9wZW4YAiABKA'
    'hSBG9wZW4SJQoObGF1bmNoX2NvbmZpcm0YAyABKAhSDWxhdW5jaENvbmZpcm0=');

@$core.Deprecated('Use dartSelectTargetStatusSyncDescriptor instead')
const DartSelectTargetStatusSync$json = {
  '1': 'DartSelectTargetStatusSync',
  '2': [
    {'1': 'target_id', '3': 1, '4': 1, '5': 13, '10': 'targetId'},
    {'1': 'open', '3': 2, '4': 1, '5': 13, '10': 'open'},
  ],
};

/// Descriptor for `DartSelectTargetStatusSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dartSelectTargetStatusSyncDescriptor =
    $convert.base64Decode(
        'ChpEYXJ0U2VsZWN0VGFyZ2V0U3RhdHVzU3luYxIbCgl0YXJnZXRfaWQYASABKA1SCHRhcmdldE'
        'lkEhIKBG9wZW4YAiABKA1SBG9wZW4=');

@$core.Deprecated('Use sentryCtrlCommandDescriptor instead')
const SentryCtrlCommand$json = {
  '1': 'SentryCtrlCommand',
  '2': [
    {'1': 'command_id', '3': 1, '4': 1, '5': 13, '10': 'commandId'},
  ],
};

/// Descriptor for `SentryCtrlCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sentryCtrlCommandDescriptor = $convert.base64Decode(
    'ChFTZW50cnlDdHJsQ29tbWFuZBIdCgpjb21tYW5kX2lkGAEgASgNUgljb21tYW5kSWQ=');

@$core.Deprecated('Use sentryCtrlResultDescriptor instead')
const SentryCtrlResult$json = {
  '1': 'SentryCtrlResult',
  '2': [
    {'1': 'command_id', '3': 1, '4': 1, '5': 13, '10': 'commandId'},
    {'1': 'result_code', '3': 2, '4': 1, '5': 13, '10': 'resultCode'},
  ],
};

/// Descriptor for `SentryCtrlResult`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sentryCtrlResultDescriptor = $convert.base64Decode(
    'ChBTZW50cnlDdHJsUmVzdWx0Eh0KCmNvbW1hbmRfaWQYASABKA1SCWNvbW1hbmRJZBIfCgtyZX'
    'N1bHRfY29kZRgCIAEoDVIKcmVzdWx0Q29kZQ==');

@$core.Deprecated('Use airSupportCommandDescriptor instead')
const AirSupportCommand$json = {
  '1': 'AirSupportCommand',
  '2': [
    {'1': 'command_id', '3': 1, '4': 1, '5': 13, '10': 'commandId'},
  ],
};

/// Descriptor for `AirSupportCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List airSupportCommandDescriptor = $convert.base64Decode(
    'ChFBaXJTdXBwb3J0Q29tbWFuZBIdCgpjb21tYW5kX2lkGAEgASgNUgljb21tYW5kSWQ=');

@$core.Deprecated('Use airSupportStatusSyncDescriptor instead')
const AirSupportStatusSync$json = {
  '1': 'AirSupportStatusSync',
  '2': [
    {
      '1': 'airsupport_status',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'airsupportStatus'
    },
    {'1': 'left_time', '3': 2, '4': 1, '5': 13, '10': 'leftTime'},
    {'1': 'cost_coins', '3': 3, '4': 1, '5': 13, '10': 'costCoins'},
    {
      '1': 'is_being_targeted',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'isBeingTargeted'
    },
    {'1': 'shooter_status', '3': 5, '4': 1, '5': 13, '10': 'shooterStatus'},
  ],
};

/// Descriptor for `AirSupportStatusSync`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List airSupportStatusSyncDescriptor = $convert.base64Decode(
    'ChRBaXJTdXBwb3J0U3RhdHVzU3luYxIrChFhaXJzdXBwb3J0X3N0YXR1cxgBIAEoDVIQYWlyc3'
    'VwcG9ydFN0YXR1cxIbCglsZWZ0X3RpbWUYAiABKA1SCGxlZnRUaW1lEh0KCmNvc3RfY29pbnMY'
    'AyABKA1SCWNvc3RDb2lucxIqChFpc19iZWluZ190YXJnZXRlZBgEIAEoDVIPaXNCZWluZ1Rhcm'
    'dldGVkEiUKDnNob290ZXJfc3RhdHVzGAUgASgNUg1zaG9vdGVyU3RhdHVz');
