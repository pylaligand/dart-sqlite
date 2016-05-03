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
  final count =
      (db.first("SELECT COUNT(*) AS count FROM rankings")).asMap()['count'];
  print('$count teams competing');
}

_useStatements(Database db) async {
  db.execute('INSERT INTO rankings VALUES ("PSG", 78)');
  db.execute('INSERT INTO rankings VALUES ("Lyon", 39)');

  num count = 0;
  db.execute("SELECT * FROM rankings", callback: (Row row) {
    count++;
  });
  print('$count teams competing now');
}

_inspectResults(Database db) async {
  db.execute('SELECT * FROM rankings ORDER BY points DESC',
      callback: (Row row) {
    var r = row.asMap();
    print('${r["team"].padRight(10)} ${r["points"]}');
    return true;
  });
  print('Who\'s the best now?');
}

main(List<String> args) {
  final db = new Database.inMemory();
  _runSimpleQuery(db);
  _createAndInsertEntries(db);
  _useStatements(db);
  _inspectResults(db);
}
