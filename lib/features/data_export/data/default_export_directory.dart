/// Resolves the per-platform default export directory.
///
/// Used when the user has not explicitly picked an export directory, so that
/// automatic recording and saving works out of the box.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Sub-folder created under the platform base directory for saved records.
const String _appFolderName = 'RoboMasterMonitor';

/// Records sub-folder under [_appFolderName].
const String _recordsFolderName = 'records';

/// Resolves the default export directory for the current platform, creating it
/// if needed, and returns its absolute path.
///
/// Layout per platform:
/// - Android: `<app external files>/RoboMasterMonitor/records`
///   (app-private external storage, no runtime permission required).
/// - Windows / Linux / macOS: `<Documents>/RoboMasterMonitor/records`.
///
/// Falls back to the application documents directory if the preferred base is
/// unavailable.
Future<String> resolveDefaultExportDirectory() async {
  final base = await _resolveBaseDirectory();
  final dir = Directory(
    p.join(base.path, _appFolderName, _recordsFolderName),
  );
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}

Future<Directory> _resolveBaseDirectory() async {
  if (Platform.isAndroid) {
    // App-private external storage: visible via file managers, survives app
    // updates, and needs no storage permission.
    final external = await getExternalStorageDirectory();
    if (external != null) return external;
  }
  return getApplicationDocumentsDirectory();
}
