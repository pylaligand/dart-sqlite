// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const String _FLAG_GITHUB_USERNAME = 'username';
const String _FLAG_GITHUB_TOKEN = 'token';
const String _RELEASES_URL =
    'https://api.github.com/repos/pylaligand/dart-sqlite/releases';

Future<void> main(List<String> args) async {
  final ArgParser parser = new ArgParser()
    ..addOption(_FLAG_GITHUB_USERNAME, help: 'Github username')
    ..addOption(_FLAG_GITHUB_TOKEN, help: 'Github personal access token');
  final ArgResults params = parser.parse(args);

  if (!params.options.contains(_FLAG_GITHUB_USERNAME) ||
      !params.options.contains(_FLAG_GITHUB_TOKEN)) {
    print(parser.usage);
    exit(314);
  }
  final String username = params[_FLAG_GITHUB_USERNAME];
  final String token = params[_FLAG_GITHUB_TOKEN];

  final Map<String, dynamic> dependencies =
      loadYaml(new File('pubspec.yaml').readAsStringSync());
  final int version = dependencies['version'];
  print('Setting up version $version');

  final Map<String, String> authHeaders = <String, String>{};
  if (username != null && token != null) {
    final String authToken = base64.encode(utf8.encode('$username:$token'));
    authHeaders['Authorization'] = 'Basic $authToken';
  }
  final String releasesBody = await http
      .read(_RELEASES_URL, headers: authHeaders)
      .catchError((dynamic e) {
    print('Unable to list releases: $e');
    exit(314);
  });

  final List<Map<String, dynamic>> releases = json.decode(releasesBody);
  final Map<String, dynamic> release = releases.firstWhere(
    (Map<String, dynamic> release) => release['tag_name'] == 'v$version',
    orElse: () => null,
  );
  if (release == null) {
    print('Unknown release: $version');
    exit(314);
  }

  final List<String> assetNames = <String>[
    'libdart_sqlite.so',
    'libdart_sqlite.dylib'
  ];
  await Future.forEach(assetNames, (String assetName) async {
    final Map<String, dynamic> asset = release['assets']
        .firstWhere((Map<String, dynamic> asset) => asset['name'] == assetName);
    final String libUrl = asset['browser_download_url'];
    final String libFile = path.join('lib', 'src', assetName);
    await http.readBytes(libUrl).catchError((dynamic e) {
      print('Could not download library file: $e');
      exit(314);
    }).then((Uint8List bytes) => new File(libFile).writeAsBytesSync(bytes));
    print('Installed $assetName');
  });
  print('Library setup complete');
}
