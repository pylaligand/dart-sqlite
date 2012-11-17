import 'dart:io' as io;
import 'dart:math' as Math;
import '../lib/sqlite.dart' as sqlite;

testFirst(db) {
  var row = db.first("SELECT ?+2, UPPER(?)", [3, "hello"]);
  Expect.equals(5, row[0]);
  Expect.equals("HELLO", row[1]);
}

testRow(db) {
  var row = db.first("SELECT 42 AS foo");
  Expect.equals(0, row.index);

  Expect.equals(42, row[0]);
  Expect.equals(42, row['foo']);
  Expect.equals(42, row.foo);

  Expect.listEquals([42], row.asList());
  Expect.mapEquals({"foo": 42}, row.asMap());
}

testBulk(db) {
  createBlogTable(db);
  var insert = db.prepare("INSERT INTO posts (title, body) VALUES (?,?)");
  try {
    Expect.equals(1, insert.execute(["hi", "hello world"]));
    Expect.equals(1, insert.execute(["bye", "goodbye cruel world"]));
  } finally {
    insert.close();
  }
  var rows = [];
  Expect.equals(2, db.execute("SELECT * FROM posts", callback: (row) { rows.add(row); }));
  Expect.equals(2, rows.length);
  Expect.equals("hi", rows[0].title);
  Expect.equals("bye", rows[1].title);
  Expect.equals(0, rows[0].index);
  Expect.equals(1, rows[1].index);
  rows = [];
  Expect.equals(1, db.execute("SELECT * FROM posts", callback: (row) {
    rows.add(row);
    return true;
  }));
  Expect.equals(1, rows.length);
  Expect.equals("hi", rows[0].title);
}

testTransactionSuccess(db) {
  createBlogTable(db);
  Expect.equals(42, db.transaction(() {
    db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
    return 42;
  }));
  Expect.equals(1, db.execute("SELECT * FROM posts"));
}

testTransactionFailure(db) {
  createBlogTable(db);
  try {
    db.transaction(() {
      db.execute("INSERT INTO posts (title, body) VALUES (?,?)");
      throw new UnsupportedError("whee");
    });
    
    Expect.fail("Exception should have been propagated");
  } on UnsupportedError catch (expected) {}
  Expect.equals(0, db.execute("SELECT * FROM posts"));
}

testSyntaxError(db) {
  Expect.throws(() => db.execute("random non sql"), (x) => x is sqlite.SqliteSyntaxException);
}

testColumnError(db) {
  Expect.throws(() => db.first("select 2+2")['qwerty'], (x) => x is sqlite.SqliteException);
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
  var rnd = new Math.Random();
  var nonce = (rnd.nextDouble() * 100000000).toInt();
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
