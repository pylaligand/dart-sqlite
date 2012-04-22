#import('dart:io', prefix: 'io');
#import('../lib/sqlite.dart', prefix: 'sqlite');

testFirst(connection) {
  var row = connection.first("SELECT 2+2 AS foo");
  Expect.equals(4, row[0]);
  Expect.equals(4, row["foo"]);
  Expect.equals(4, row.foo);
}

main() {
  [testFirst].forEach((test) {
    connectionOnDisk(test);
    connectionInMemory(test);
  });
}

deleteWhenDone(callback(filename)) {
  var nonce = (Math.random() * 100000000).toInt();
  var filename = "/tmp/dart-sqlite-test-${nonce}";
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