// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#library("sqlite");

#import("dart-ext:dart_sqlite");

class Connection {
  var _db;
  final String path;

  Connection(path) : this.path = path {
    _db = _new(path);
  }

  static get version() => _version();

  String toString() => "<Sqlite: ${path} (${version})>";

  void close() {
    _checkOpen();
    _close(_db);
    _db = null;
  }

  transaction(callback()) {
    _checkOpen();
    execute("BEGIN");
    try {
      var result = callback();
      execute("COMMIT");
      return result;
    } catch (x) {
      execute("ROLLBACK");
      throw x;
    }
  }

  Statement prepare(String statement) {
    return new Statement._internal(_db, statement);
  }

  int execute(String statement, [params=const [], bool callback(Row)]) {
    statement = prepare(statement);
    try {
      return statement.execute(params, callback);
    } finally {
      statement.close();
    }
  }

  Row first(String statement, [params = const []]) {
    var result = null;
    execute(statement, params, (row) {
      result = row;
      return true;
    });
    return result;
  }

  _checkOpen() {
    if (_db == null) throw new SqliteException("Database is closed");
  }
}

class Statement {
  var _statement;
  final String sql;

  Statement._internal(db, sql) : this.sql = sql {
    _statement = _prepare(db, sql, this);
  }

  void close() => _closeStatement(_statement);

  int execute([params = const [], bool callback(Row)]) {
    _reset(_statement);
    if (params.length > 0) _bind(_statement, params);
    var result;
    int count = 0;
    var info = null;
    while ((result = _step(_statement)) is! int) {
      count++;
      if (info == null) info = _column_info(_statement);
      if (callback != null && callback(new Row._internal(count - 1, info, result))) break;
    }
    // If update affected no rows, count == result == 0
    return (result == 0) ? count : result;
  }
}

class SqliteException implements Exception {
  final String message;
  SqliteException(String this.message);
  toString() => "SqliteException: $message";
}

class SqliteSyntaxException extends SqliteException {
  final String query;
  SqliteSyntaxException(String message, String this.query) : super(message);
  toString() => "SqliteSyntaxException: $message. Query: [${query}]";
}

class Row {
  final List<String> _columns;
  final List _data;
  final int index;
  Map _columnToIndex;

  Row._internal(this.index, this._columns, this._data) {
    _columnToIndex = {};
    for (int i = 0; i < _columns.length; i++) {
      _columnToIndex[i] = i;
      _columnToIndex[_columns[i]] = i;
    }
  }

  operator [](i) {
    if (_columnToIndex.containsKey(i)) {
      return _data[_columnToIndex[i]];
    } else {
      throw new SqliteException("No such column $i");
    }
  }

  List<Object> asList() => new List<Object>.from(_data);
  Map<String, Object> asMap() {
    var result = new Map<String, Object>();
    for (int i = 0; i < _columns.length; i++) {
      result[_columns[i]] = _data[i];
    }
    return result;
  }

  toString() => _data.toString();

  noSuchMethod(String method, List args) {
    if (args.length == 0 && method.startsWith("get:")) {
      String property = method.substring(4);
      if (_columnToIndex.containsKey(property)) return _data[_columnToIndex[property]];
    }
    return super.noSuchMethod(method, args);
  }
}

_sqliteException(message) => new SqliteException(message);
_sqliteSyntaxException(message, sql) => new SqliteSyntaxException(message, sql);

_prepare(db, query, statementObject) native 'PrepareStatement';
_reset(statement) native 'Reset';
_bind(statement, params) native 'Bind';
_column_info(statement) native 'ColumnInfo';
_step(statement) native 'Step';
_closeStatement(statement) native 'CloseStatement';
_new(path) native 'New';
_close(handle) native 'Close';
_version() native 'Version';

