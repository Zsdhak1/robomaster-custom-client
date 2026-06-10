/// Decodes [Event] protobuf messages into human-readable descriptions.
///
/// Event semantics follow protocol V1.3.1 §2.2.7. Each event_id (1-15)
/// carries a `param` string whose meaning varies by id.
library;

import 'package:flutter/material.dart';

import '../../../generated/robomaster_custom_client.pb.dart';

/// Visual category of a decoded event, used for icon/color.
enum EventCategory {
  /// Combat/kill related (red).
  combat,

  /// Structure (base/outpost) related (orange).
  structure,

  /// Energy rune related (purple).
  rune,

  /// Air support related (blue).
  airSupport,

  /// Dart related (teal).
  dart,

  /// Assembly/engineering related (brown).
  assembly,

  /// Generic notification (grey).
  generic,
}

/// A decoded, display-ready representation of an [Event].
class DecodedEvent {
  /// Creates a [DecodedEvent].
  const DecodedEvent({
    required this.title,
    required this.detail,
    required this.category,
  });

  /// Short event title (e.g. "击杀").
  final String title;

  /// Detailed description with resolved parameters.
  final String detail;

  /// Visual category.
  final EventCategory category;

  /// Icon for this category.
  IconData get icon => switch (category) {
        EventCategory.combat => Icons.gps_fixed,
        EventCategory.structure => Icons.shield,
        EventCategory.rune => Icons.bolt,
        EventCategory.airSupport => Icons.flight,
        EventCategory.dart => Icons.rocket_launch,
        EventCategory.assembly => Icons.build,
        EventCategory.generic => Icons.info_outline,
      };

  /// Color for this category.
  Color get color => switch (category) {
        EventCategory.combat => Colors.red,
        EventCategory.structure => Colors.orange,
        EventCategory.rune => Colors.purple,
        EventCategory.airSupport => Colors.blue,
        EventCategory.dart => Colors.teal,
        EventCategory.assembly => Colors.brown,
        EventCategory.generic => Colors.grey,
      };
}

/// Maps a robot id (per protocol §附录: 1-9 红, 11-19 蓝) to a name.
String _robotName(String idStr) {
  final id = int.tryParse(idStr.trim());
  if (id == null) return idStr;
  return switch (id) {
    1 => '红方英雄',
    2 => '红方工程',
    3 || 4 || 5 => '红方步兵$id',
    6 => '红方空中',
    7 => '红方哨兵',
    8 => '红方基地',
    9 => '红方前哨站',
    11 => '蓝方英雄',
    12 => '蓝方工程',
    13 || 14 || 15 => '蓝方步兵${id - 10}',
    16 => '蓝方空中',
    17 => '蓝方哨兵',
    18 => '蓝方基地',
    19 => '蓝方前哨站',
    101 => '红方英雄', // 部分实现用 1xx 表示红方
    111 => '蓝方英雄',
    _ => 'ID $id',
  };
}

/// Splits a comma-separated param string, trimming whitespace.
List<String> _parts(String param) =>
    param.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

/// Decodes an [Event] into a [DecodedEvent] per protocol V1.3.1 §2.2.7.
DecodedEvent decodeEvent(int eventId, String param) {
  final p = _parts(param);

  switch (eventId) {
    case 1: // 击杀：参数1被击杀者，参数2击杀者
      final victim = p.isNotEmpty ? _robotName(p[0]) : '?';
      final killer = p.length > 1 ? _robotName(p[1]) : '?';
      return DecodedEvent(
        title: '击杀事件',
        detail: '$killer 击毁了 $victim',
        category: EventCategory.combat,
      );
    case 2: // 前哨站被摧毁：参数为目标id (11红/111蓝)
      final target = p.isNotEmpty ? _robotName(p[0]) : '?';
      return DecodedEvent(
        title: '前哨站被摧毁',
        detail: '$target 前哨站被摧毁',
        category: EventCategory.structure,
      );
    case 3: // 大能量机关激活灯臂数、平均环数
      final arms = p.isNotEmpty ? p[0] : '?';
      final rings = p.length > 1 ? p[1] : '?';
      return DecodedEvent(
        title: '大能量机关激活',
        detail: '激活 $arms 个灯臂，平均环数 $rings',
        category: EventCategory.rune,
      );
    case 4: // 能量机关进入已激活：1小 2大
      final type = p.isNotEmpty
          ? (p[0] == '1' ? '小能量机关' : '大能量机关')
          : '能量机关';
      return DecodedEvent(
        title: '能量机关激活',
        detail: '$type 进入已激活状态',
        category: EventCategory.rune,
      );
    case 5: // 己方英雄狙击伤害累计
      return DecodedEvent(
        title: '己方狙击伤害',
        detail: '己方英雄累计造成狙击伤害 ${p.isNotEmpty ? p[0] : '?'}',
        category: EventCategory.combat,
      );
    case 6: // 对方英雄狙击伤害累计
      return DecodedEvent(
        title: '对方狙击伤害',
        detail: '对方英雄累计造成狙击伤害 ${p.isNotEmpty ? p[0] : '?'}',
        category: EventCategory.combat,
      );
    case 7: // 对方呼叫空中支援
      return const DecodedEvent(
        title: '对方空中支援',
        detail: '对方呼叫了空中支援',
        category: EventCategory.airSupport,
      );
    case 8: // 对方空中支援被反制：剩余可反制次数
      return DecodedEvent(
        title: '空中支援被反制',
        detail: '对方空中支援被反制，剩余可反制次数 ${p.isNotEmpty ? p[0] : '?'}',
        category: EventCategory.airSupport,
      );
    case 9: // 飞镖命中：命中方(1红2蓝)，命中目标(1-5)
      final side = p.isNotEmpty ? (p[0] == '1' ? '红方' : '蓝方') : '?';
      final hit = p.length > 1 ? _dartTarget(p[1]) : '?';
      return DecodedEvent(
        title: '飞镖命中',
        detail: '$side 飞镖命中 $hit',
        category: EventCategory.dart,
      );
    case 10: // 对方飞镖闸门开启
      return const DecodedEvent(
        title: '对方飞镖闸门开启',
        detail: '对方飞镖闸门已开启',
        category: EventCategory.dart,
      );
    case 11: // 基地遭到攻击
      return const DecodedEvent(
        title: '基地遭到攻击',
        detail: '己方基地遭到攻击',
        category: EventCategory.structure,
      );
    case 12: // 对方前哨站停转
      return const DecodedEvent(
        title: '对方前哨站停转',
        detail: '对方前哨站中部装甲已停转',
        category: EventCategory.structure,
      );
    case 13: // 对方基地护甲展开
      return const DecodedEvent(
        title: '对方基地护甲展开',
        detail: '对方基地护甲已展开',
        category: EventCategory.structure,
      );
    case 14: // 对方请求四级装配，进入强制退出缓冲期
      return const DecodedEvent(
        title: '四级装配请求',
        detail: '对方请求四级装配，进入强制退出缓冲期',
        category: EventCategory.assembly,
      );
    case 15: // 装配结果事件
      return DecodedEvent(
        title: '装配结果',
        detail: _assemblyResult(p.isNotEmpty ? p[0] : ''),
        category: EventCategory.assembly,
      );
    default:
      return DecodedEvent(
        title: '事件 #$eventId',
        detail: param.isEmpty ? '(无参数)' : param,
        category: EventCategory.generic,
      );
  }
}

/// Resolves the dart-hit target code (event 9 param 2).
String _dartTarget(String code) => switch (code) {
      '1' => '前哨站',
      '2' => '基地固定目标',
      '3' => '基地随机固定目标',
      '4' => '基地随机移动目标',
      '5' => '基地末端移动目标',
      _ => '目标 $code',
    };

/// Resolves the assembly result code (event 15 param).
String _assemblyResult(String code) => switch (code) {
      '0' => '装配成功',
      '1' => '能量单元被拔出',
      '2' => '装配超时',
      '3' => '离开装配区过久',
      '4' => '工程战亡',
      '5' => '四级难度未满足协作时限',
      '6' => '主动退出',
      '7' => '完成装配但结算时未检测到能量单元',
      '8' => '缓冲期到期，装配流程强制结束',
      _ => '结果码 $code',
    };

