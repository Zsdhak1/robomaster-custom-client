/// Riverpod provider for the JSON data importer.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../data/json_importer.dart';

/// Provides a configured [JsonImporter] instance.
///
/// The importer shares the same topic-to-Protobuf mapping as [ProtobufParser]
/// so exported files round-trip back to the same message types.
final jsonImporterProvider = Provider<JsonImporter>(
  (ref) => JsonImporter(messageFactories: ProtobufParser.messageFactories),
);
