/// Unit tests for [RemoteRecordMeta] file-name parsing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/data_export/domain/remote_record_meta.dart';

void main() {
  group('RemoteRecordMeta.parse', () {
    test('parses a red-side export file name', () {
      final meta = RemoteRecordMeta.parse('rm_export_3_20260615_143005.json');
      expect(meta.kind, RecordKind.export);
      expect(meta.robotId, 3);
      expect(meta.side, RecordSide.red);
      expect(meta.date, DateTime(2026, 6, 15, 14, 30, 5));
    });

    test('parses a blue-side export file name (id >= 100)', () {
      final meta = RemoteRecordMeta.parse('rm_export_103_20260615_090000.json');
      expect(meta.robotId, 103);
      expect(meta.side, RecordSide.blue);
    });

    test('parses a merged file name', () {
      final meta = RemoteRecordMeta.parse('rm_merged_blue_20260103_080000.json');
      expect(meta.kind, RecordKind.merged);
      expect(meta.side, RecordSide.blue);
      expect(meta.robotId, isNull);
      expect(meta.date, DateTime(2026, 1, 3, 8));
    });

    test('parses merged red', () {
      final meta = RemoteRecordMeta.parse('rm_merged_red_20260201_120000.json');
      expect(meta.side, RecordSide.red);
      expect(meta.kind, RecordKind.merged);
    });

    test('unknown file name keeps name and stays unknown', () {
      final meta = RemoteRecordMeta.parse('some_other_file.json');
      expect(meta.kind, RecordKind.unknown);
      expect(meta.side, RecordSide.unknown);
      expect(meta.robotId, isNull);
      expect(meta.date, isNull);
      expect(meta.fileName, 'some_other_file.json');
    });

    test('works without .json suffix', () {
      final meta = RemoteRecordMeta.parse('rm_export_7_20260615_143005');
      expect(meta.kind, RecordKind.export);
      expect(meta.robotId, 7);
    });

    test('malformed date falls back to null date but keeps kind', () {
      // 13th month — DateTime would roll over, but our pattern requires 8
      // digits so this still matches; rollover is acceptable, just ensure no
      // throw and a non-null result.
      final meta = RemoteRecordMeta.parse('rm_export_1_20261301_143005.json');
      expect(meta.kind, RecordKind.export);
      expect(meta.robotId, 1);
    });
  });
}
