/// 更新检查器使用的语义化版本比较工具。
library;

import 'package:flutter/foundation.dart';

/// 使用宽松的语义化版本规则比较两个版本字符串。
///
/// 前导 `v`/`V` 和 `+` 后的构建元数据会被忽略。版本号按 `.` 拆分，只比较前三个
/// 数字段（major、minor、patch）；缺失段默认为 `0`。
///
/// 返回:
/// - 负数： [a] 早于 [b]
/// - 0：两者等价
/// - 正数： [a] 新于 [b]
@visibleForTesting
int compareVersions(String a, String b) {
  int parseSegment(String s) {
    final digits = RegExp(r'^\d+').stringMatch(s);
    return int.tryParse(digits ?? '') ?? 0;
  }

  List<int> normalize(String raw) {
    var s = raw.trim();
    if (s.startsWith(RegExp(r'^[vV]'))) {
      s = s.substring(1);
    }
    final plus = s.indexOf('+');
    if (plus != -1) s = s.substring(0, plus);
    final parts = s.split('.').map(parseSegment).toList();
    while (parts.length < 3) {
    parts.add(0);
  }
    return parts.sublist(0, 3);
  }

  final pa = normalize(a);
  final pb = normalize(b);
  for (var i = 0; i < 3; i++) {
    final va = pa[i];
    final vb = pb[i];
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

/// 当 [latest] 新于 [current] 时返回 `true`。
bool isNewerVersion(String current, String latest) {
  return compareVersions(current, latest) < 0;
}
