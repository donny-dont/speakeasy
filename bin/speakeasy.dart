// Copyright (c) 2015, the Speakeasy Project Authors.
// Please see the AUTHORS file for details. All rights reserved.
// Use of this source code is governed by a zlib license that can be found in
// the LICENSE file.

library speakeasy.bin.speakeasy;

//---------------------------------------------------------------------
// Standard libraries
//---------------------------------------------------------------------

import 'dart:async';
import 'dart:io';

//---------------------------------------------------------------------
// Imports
//---------------------------------------------------------------------

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:pub_server/shelf_pubserver.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:speakeasy/configuration.dart';
import 'package:speakeasy/repository.dart';

//---------------------------------------------------------------------
// Library contents
//---------------------------------------------------------------------

const String _configOption = 'config';

Future<Null> main(List<String> args) async {
  setupLogger();

  // Parse the arguments
  var parser = new ArgParser()
      ..addOption(_configOption, defaultsTo: 'config.yml');

  var parsed = parser.parse(args);

  var configPath = parsed[_configOption];

  // Attempt to read the file
  var config = await readConfiguration(configPath);

  // See if the config file is present
  if (config.isEmpty) {
    print('File not present');

    config = await writeDefaultConfiguration(configPath);
  }

  // Create the file repository based on the value of storage
  var fileRepository = new FileRepository(config['storage']);

  // Create the proxies
  //
  // \TODO More than one :)
  var httpClient = new http.Client();
  var pubRepository = new HttpProxyRepository(httpClient, Uri.parse(config['proxies']['dartlang']['url']));

  var cowRepository = new CopyAndWriteRepository(fileRepository, pubRepository);

  // Just start up the server for now
  var server = new ShelfPubServer(cowRepository);
  var internetAddressTypeStr = config['internetAddressType'];
  var internetAddressType = InternetAddressType.ANY;
  if (internetAddressTypeStr == 'IP_V4') {
    internetAddressType = InternetAddressType.IP_V4;
  } else if (internetAddressTypeStr == 'IP_V6') {
    internetAddressType = InternetAddressType.IP_V6;
  }
  // Get the address based on the IP address
  var interfaces = await NetworkInterface.list(type: internetAddressType);
  var address = interfaces[0].addresses.first.address;

  int port = config['port'] ?? 8080;

  shelf_io.serve(server.requestHandler, address, port);

  printClientUsage(address, port, false);
}

void setupLogger() {
  Logger.root.onRecord.listen((LogRecord record) {
    var head = '${record.time} ${record.level} ${record.loggerName}';
    var tail = record.stackTrace != null ? '\n${record.stackTrace}' : '';
    print('$head ${record.message} $tail');
  });
}

void printClientUsage(String address, int port, bool isSecure) {
  var scheme = isSecure ? 'https' : 'http';
  var hostedUrl = '$scheme://$address:$port';

  print('################################################################################');
  print('The pub command uses environment variables to specify the registry to use.');
  print('If you want to setup pub to work with this registry run the following commands:\n');
  print('POSIX OS');
  print('\$ export PUB_HOSTED_URL=$hostedUrl\n');
  print('WINDOWS');
  print('\$ SET PUB_HOSTED_URL=$hostedUrl\n');
  print('To prevent pub publish from unintentially publishing to the pub.dartlang.org');
  print('registry include the following in the package pubspec.yml\n');
  print('publish_to: $hostedUrl');
  print('################################################################################');
}
