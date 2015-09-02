
import 'dart:async';
import 'dart:io';

import 'package:yaml/yaml.dart';

/// Reads the configuration file from the [path].
///
/// If the file could not be read or then an empty map will be returned.
Future<Map> readConfiguration(String path) async {
  var file = new File(path);

  // See if the file exists
  if (!await file.exists()) {
    return {};
  }

  // Parse the file and return its contents
  var contents = await file.readAsString();
  return loadYaml(contents);
}

/// Writes the default configuration to the [path].
///
/// The default configuration will be returned by the function.
Future<Map> writeDefaultConfiguration(String path) async {
  // Get the contents of the resource
  var resource = new Resource('package:speakeasy/src/configuration/default.yml');
  var contents = await resource.readAsString();

  // Write the contents to the path
  var file = new File(path);
  await file.writeAsString(contents);

  // Parse the file and return it
  return loadYaml(contents);
}
