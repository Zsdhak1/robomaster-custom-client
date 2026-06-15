/// Semver-style version comparison used by the update checker.
library;

import 'package:flutter/foundation.dart';

/// Compares two version strings using a relaxed semver rule.
///
/// Leading `v`/`V` and build metadata after `+` are ignored. Versions are
/// split by `.` and the first three numeric segments (major, minor, patch)
/// are compared. Missing segments default to `0`.
///
/// Returns:
/// - a negative integer if [a] is older than [b]
/// - zero if they are equivalent
/// - a positive integer if [a] is newer than [b]
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

/// Returns `true` when [latest] is newer than [current].
bool isNewerVersion(String current, String latest) {
  return compareVersions(current, latest) < 0;
}
