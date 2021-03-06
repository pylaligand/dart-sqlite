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

const _FLAG_GITHUB_USERNAME = 'username';
const _FLAG_GITHUB_TOKEN = 'token';
const _RELEASES_URL =
    'https://api.github.com/repos/pylaligand/dart-sqlite/releases';

Future main(List<String> args) async {
  final parser = new ArgParser()
    ..addOption(_FLAG_GITHUB_USERNAME, help: 'Github username')
    ..addOption(_FLAG_GITHUB_TOKEN, help: 'Github personal access token');
  final params = parser.parse(args);

  if (!params.options.contains(_FLAG_GITHUB_USERNAME) ||
      !params.options.contains(_FLAG_GITHUB_TOKEN)) {
    print(parser.usage);
    exit(314);
  }
  final username = params[_FLAG_GITHUB_USERNAME];
  final token = params[_FLAG_GITHUB_TOKEN];

  final deps = loadYaml(new File('pubspec.yaml').readAsStringSync());
  final version = deps['version'];
  print('Setting up version $version');

  final authHeaders = {};
  if (username != null && token != null) {
    final authToken = BASE64.encode(UTF8.encode('$username:$token'));
    authHeaders['Authorization'] = 'Basic $authToken';
  }
  final releasesBody =
      await http.read(_RELEASES_URL, headers: authHeaders).catchError((e, _) {
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

  final assetNames = ['libdart_sqlite.so', 'libdart_sqlite.dylib'];
  await Future.forEach(assetNames, (assetName) async {
    final libUrl =
        release['assets'].firstWhere((asset) => asset['name'] == assetName)[
            'browser_download_url'];
    final libFile = path.join('lib', 'src', assetName);
    await http.readBytes(libUrl).catchError((e, _) {
      print('Could not download library file: $e');
      exit(314);
    }).then((bytes) => new File(libFile).writeAsBytesSync(bytes));
    print('Installed $assetName');
  });
  print('Library setup complete');
}
