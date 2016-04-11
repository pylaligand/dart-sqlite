// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const _FLAG_PACKAGE_ROOT = 'package-root';
const _RELEASES_URL =
    'https://api.github.com/repos/pylaligand/dart-sqlite/releases';

Future main(List<String> args) async {
  final parser = new ArgParser()
    ..addOption(_FLAG_PACKAGE_ROOT, help: 'Root of the package [required]');
  final params = parser.parse(args);

  if (!params.options.contains(_FLAG_PACKAGE_ROOT)) {
    print(parser.usage);
    exit(314);
  }
  final packageRoot = params[_FLAG_PACKAGE_ROOT];

  if (!Platform.isLinux && !Platform.isMacOS) {
    print('This library is only supported on Linux and Mac OS!');
    exit(314);
  }

  final lockFile = path.join(packageRoot, 'pubspec.lock');
  final deps = loadYaml(new File(lockFile).readAsStringSync());
  final version = deps['packages']['sqlite']['version'];
  print('Setting up version $version');

  final releasesBody = await http.read(_RELEASES_URL).catchError((e, _) {
    print('Unable to list releases: $e');
    exit(314);
  });
  final releases = JSON.decode(releasesBody);

  final Map<String, dynamic> release = releases.firstWhere(
      (release) => release['tag_name'] == 'v$version',
      orElse: () => null);
  if (release == null) {
    print('Unknown release: $version');
    exit(314);
  }

  final assetName =
      Platform.isLinux ? 'libdart_sqlite.so' : 'libdart_sqlite.dylib';
  final libUrl =
      release['assets'].firstWhere((asset) => asset['name'] == assetName)[
          'browser_download_url'];
  final libFile = path.join(packageRoot, 'packages', 'sqlite', assetName);
  await http.readBytes(libUrl).catchError((e, _) {
    print('Could not download library file: $e');
    exit(314);
  }).then((bytes) => new File(libFile).writeAsBytesSync(bytes));
  print('Library setup complete');
}
