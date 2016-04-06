import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import '../lib/sqlite.dart' as sqlite;

createBlogTable(db) {
  db.execute("CREATE TABLE posts (title text, body text)");
}

typedef DatabaseTest(sqlite.Database db);

runWithConnectionOnDisk(DatabaseTest dbTest) {
  final fileName = path.join(
      Directory.systemTemp.createTempSync("dart-sqlite-test-").path,
      'db.sqlite');
  final db = new sqlite.Database(fileName);
  try {
    dbTest(db);
  } finally {
    db.close();
  }
}

runWithConnectionInMemory(DatabaseTest dbTest) {
  final db = new sqlite.Database.inMemory();
  try {
    dbTest(db);
  } finally {
    db.close();
  }
}

testRunner(DatabaseTest dbTest) {
  return () {
    runWithConnectionOnDisk(dbTest);
    runWithConnectionInMemory(dbTest);
  };
}

void main() {
  test('first', testRunner((db) {
    final row = db.first("SELECT ?+2, UPPER(?)", params: [3, "hello"]);
    expect(row[0], equals(5));
    expect(row[1], equals("HELLO"));
  }));

  test('row', testRunner((db) {
    final row = db.first("SELECT 42 AS foo");
    expect(row.index, equals(0));

    expect(row[0], equals(42));
    expect(row['foo'], equals(42));

    expect(row.asList(), equals(const [42]));
    expect(row.asMap(), equals(const {"foo": 42}));
  }));

  test('bulk', testRunner((db) {
    createBlogTable(db);
    var insert = db.prepare("INSERT INTO posts (title, body) VALUES (?,?)");
    try {
      expect(insert.execute(params: ["hi", "hello world"]), equals(1));
      expect(insert.execute(params: ["bye", "goodbye cruel world"]), equals(1));
    } finally {
      insert.close();
    }
    final rows = <sqlite.Row>[];
    expect(
        db.execute("SELECT * FROM posts", callback: (row) {
          rows.add(row);
        }),
        equals(2));
    expect(rows.length, equals(2));
    expect(rows[0]['title'], equals("hi"));
    expect(rows[1]['title'], equals("bye"));
    expect(rows[0].index, equals(0));
    expect(rows[1].index, equals(1));
    rows.clear();
    expect(
        db.execute("SELECT * FROM posts", callback: (row) {
          rows.add(row);
          return true;
        }),
        equals(1));
    expect(rows.length, equals(1));
    expect(rows[0]['title'], equals("hi"));
  }));

  test('transaction success', testRunner((db) {
    createBlogTable(db);
    expect(db.transaction(() {
      db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
      return 42;
    }), equals(42));
    expect(db.execute("SELECT * FROM posts"), equals(1));
  }));

  test('transaction failure', testRunner((db) {
    createBlogTable(db);
    expect(db.execute("SELECT * FROM posts"), equals(0));
    try {
      db.transaction(() {
        db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
        throw new UnsupportedError("whee");
      });
      fail("Exception should have been propagated");
    } on UnsupportedError catch (_) {}
    expect(db.execute("SELECT * FROM posts"), equals(0));
  }));

  test('syntax error', testRunner((db) {
    expect(() => db.execute("random non sql"),
        new Throws(new isInstanceOf<sqlite.SqliteSyntaxException>()));
  }));

  test('column error', testRunner((db) {
    expect(() => db.first("select 2+2")['qwerty'],
        new Throws(new isInstanceOf<sqlite.SqliteException>()));
  }));
}
