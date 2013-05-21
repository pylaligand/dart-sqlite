import 'dart:io' as io;
import 'dart:math';
import '../lib/sqlite.dart' as sqlite;
import 'package:unittest/unittest.dart';

testFirst(db) {
  var row = db.first("SELECT ?+2, UPPER(?)", [3, "hello"]);
  expect(5, equals(row[0]));
  expect("HELLO", equals(row[1]));
}

testRow(db) {
  var row = db.first("SELECT 42 AS foo");
  expect(0, equals(row.index));

  expect(42, equals(row[0]));
  expect(42, equals(row['foo']));
  expect(42, equals(row.foo));

  expect([42], equals(row.asList()));
  expect({"foo": 42}, equals(row.asMap()));
}

testBulk(db) {
  createBlogTable(db);
  var insert = db.prepare("INSERT INTO posts (title, body) VALUES (?,?)");
  try {
    expect(1, equals(insert.execute(["hi", "hello world"])));
    expect(1, equals(insert.execute(["bye", "goodbye cruel world"])));
  } finally {
    insert.close();
  }
  var rows = [];
  expect(2, equals(db.execute("SELECT * FROM posts", [], (row) { rows.add(row); })));
  expect(2, equals(rows.length));
  expect("hi", equals(rows[0].title));
  expect("bye", equals(rows[1].title));
  expect(0, equals(rows[0].index));
  expect(1, equals(rows[1].index));
  rows = [];
  expect(1, equals(db.execute("SELECT * FROM posts", [], (row) {
    rows.add(row);
    return true;
  })));
  expect(1, equals(rows.length));
  expect("hi", equals(rows[0].title));
}

testTransactionSuccess(db) {
  createBlogTable(db);
  expect(42, equals(db.transaction(() {
    db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
    return 42;
        })));
  expect(1, equals(db.execute("SELECT * FROM posts")));
}

testTransactionFailure(db) {
  createBlogTable(db);
  try {
    db.transaction(() {
      db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
      throw new UnsupportedOperationException("whee");
    });
    fail("Exception should have been propagated");
  } catch (UnsupportedOperationException expected) {}
  expect.equals(0, db.execute("SELECT * FROM posts"));
}

testSyntaxError(db) {
  expect(() => db.execute("random non sql"),
         throwsA(new isInstanceOf<sqlite.SqliteSyntaxException>()));
}

testColumnError(db) {
  expect(() => db.first("select 2+2")['qwerty'],
         throwsA(new isInstanceOf<sqlite.SqliteException>()));
}

main() {
  [testFirst, testRow, testBulk, testSyntaxError, testColumnError].forEach((test) {
    connectionOnDisk(test);
    connectionInMemory(test);
  });
  print("All tests pass!");
}

createBlogTable(db) {
  db.execute("CREATE TABLE posts (title text, body text)");
}

deleteWhenDone(callback(filename)) {
  var nonce = new Random().nextInt(100000000);
  var filename = "dart-sqlite-test-${nonce}";
  try {
    callback(filename);
  } finally {
    var f = new io.File(filename);
    if (f.existsSync()) f.deleteSync();
  }
}

connectionOnDisk(callback(connection)) {
  deleteWhenDone((filename) {
    var c = new sqlite.Database(filename);
    try {
      callback(c);
    } finally {
      c.close();
    }
  });
}

connectionInMemory(callback(connection)) {
  var c = new sqlite.Database.inMemory();
  try {
    callback(c);
  } finally {
    c.close();
  }
}
