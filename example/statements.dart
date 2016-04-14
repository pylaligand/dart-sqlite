// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

import 'package:sqlite/sqlite.dart';

_runSimpleQuery(Database db) {
  Row row = db.first('SELECT ?+16, UPPER(?)', params: [2000, 'Ligue 1']);
  final int year = row[0];
  final String league = row[1];
  print('-- $league $year --');
}

_createAndInsertEntries(Database db) {
  db.execute('CREATE TABLE rankings (team text, points int)');
  db.execute('INSERT INTO rankings VALUES ("Nice", 38)');
  db.execute('INSERT INTO rankings VALUES ("Monaco", 41)');
  final count = db.first("SELECT COUNT(*) AS count FROM rankings").count;
  print('$count teams competing');
}

_useStatements(Database db) {
  final statement = db.prepare('INSERT INTO rankings VALUES (?, ?)');
  try {
    statement.execute(params: ['PSG', 78]);
    statement.execute(params: ['Lyon', 39]);
  } finally {
    statement.close();
  }
  final count = db.first("SELECT COUNT(*) AS count FROM rankings").count;
  print('$count teams competing now');
}

_inspectResults(Database db) {
  final count = db.execute('SELECT * FROM rankings ORDER BY points DESC',
      callback: (Row row) {
    print('${row.team.padRight(10)} ${row.points}');
  });
  print('Who\'s the best of these $count?');
}

void main(List<String> args) {
  final db = new Database.inMemory();
  _runSimpleQuery(db);
  _createAndInsertEntries(db);
  _useStatements(db);
  _inspectResults(db);
}
