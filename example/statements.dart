// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

import 'dart:async';

import 'package:sqlite/sqlite.dart';

_runSimpleQuery(Database db) async {
  Row row =
      await db.query('SELECT ?+16, UPPER(?)', params: [2000, 'Ligue 1']).first;
  final int year = row[0];
  final String league = row[1];
  print('-- $league $year --');
}

_createAndInsertEntries(Database db) async {
  await db.execute('CREATE TABLE rankings (team text, points int)');
  await db.execute('INSERT INTO rankings VALUES ("Nice", 38)');
  await db.execute('INSERT INTO rankings VALUES ("Monaco", 41)');
  final count =
      (await db.query("SELECT COUNT(*) AS count FROM rankings").first).count;
  print('$count teams competing');
}

_useStatements(Database db) async {
  await db.execute('INSERT INTO rankings VALUES ("PSG", 78)');
  await db.execute('INSERT INTO rankings VALUES ("Lyon", 39)');
  final teams = db.query("SELECT * FROM rankings");
  final count = await teams.length;
  print('$count teams competing now');
}

_inspectResults(Database db) async {
  final subscription = db
      .query('SELECT * FROM rankings ORDER BY points DESC')
      .listen((Row row) => print('${row.team.padRight(10)} ${row.points}'));
  await subscription.asFuture();
  print('Who\'s the best now?');
}

Future main(List<String> args) async {
  final db = new Database.inMemory();
  await _runSimpleQuery(db);
  await _createAndInsertEntries(db);
  await _useStatements(db);
  await _inspectResults(db);
}
