import 'package:grinder/grinder.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

final scriptPath = path.canonicalize('bin/speakeasy.dart');
final snapshotPath = path.canonicalize('build/speakeasy.dart.snapshot');
final deployPath = path.canonicalize('c:/Programs/infovizion_serv12/bin');
main() async {
  log('Removing build dir...');
  if (new Directory('build').existsSync()) {
    await new Directory('build').delete(recursive: true);
  }
  await new Directory('build').create();
  await runAsync('dart', arguments: ['--snapshot=$snapshotPath', scriptPath]);
  copyFile(new File(Platform.resolvedExecutable), buildDir);
}

