// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#library("sqlite");

#import("dart-ext:dart_sqlite");

/// A connection to a SQLite database. 
/// Each database must be [close()]d after use.
class Database {
  var _db;
  /// The location on disk of the database file.
  final String path;

  /// Opens the specified database file, creating it if it doesn't exist.
  Database(path) : this.path = path {
    _db = _new(path);
  }

  /// Creates a new in-memory database, whose contents will not be persisted.
  Database.inMemory() : this(":memory:");

  /// Returns the version number of the SQLite library.
  static get version() => _version();

  String toString() => "<Sqlite: ${path}>";

  /// Closes the database.
  /// This should be called exactly once for each instance created.
  /// After calling this method, all attempts to operate on the database
  /// will throw [SqliteException].
  void close() {
    _checkOpen();
    _close(_db);
    _db = null;
  }

  /// Executes [callback] in a transaction, and returns the callback's return value.
  /// If the callbacks throws an exception, the transaction will be rolled back
  /// and the exception propagated, otherwise the transaction will be committed.
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

  /// Creates a new reusable prepared statement.
  /// [sql] may contain '?' as a placeholder for values. These values can be
  /// specified when the statement is executed.
  /// Each prepared statement should be closed after use.
  Statement prepare(String sql) {
    _checkOpen();
    return new Statement._internal(_db, sql);
  }

  /// Executes a single SQL statement.
  /// See [Statement#execute].
  int execute(String statement, [params=const [], bool callback(Row)]) {
    _checkOpen();
    statement = prepare(statement);
    try {
      return statement.execute(params, callback);
    } finally {
      statement.close();
    }
  }

  /// Executes a single SQL statement, and returns the first row.
  /// Any additional results will be discarded. If there are no results, returns null.
  Row first(String statement, [params = const []]) {
    _checkOpen();
    var result = null;
    execute(statement, params, (row) {
      result = row;
      return true;
    });
    return result;
  }

  _checkOpen() {
    if (_db == null) throw new SqliteException._internal("Database is closed");
  }
}

/// A reusable prepared SQL statement.
/// The statement may contain placeholders for values, these values are specified
/// with each call to [execute()].
/// Each prepared statement should be closed after use.
class Statement {
  var _statement;
  /// The SQL used to create this statement.
  final String sql;

  Statement._internal(db, sql) : this.sql = sql {
    _statement = _prepare(db, sql, this);
  }

  _checkOpen() {
    if (_statement == null) throw new SqliteException._internal("Statement is closed");
  }

  /// Closes this statement, and releases associated resources.
  /// This should be called exactly once for each instance created.
  /// After calling this method, attempting to execute the statement will throw [SqliteException]. 
  void close() {
    _checkOpen();
    _closeStatement(_statement);
    _statement = null;
  }

  /// Executes this statement.
  /// If this statement contains placeholders, their values must be specified in [params].
  /// If [callback] is given, it will be invoked for each [Row] that this statement produces.
  /// [callback] may return [:true:] to stop fetching rows.
  /// Returns the number of rows fetched (for statements which produce rows), 
  /// or the number of rows affected (for statements which alter data).
  int execute([params = const [], bool callback(Row)]) {
    _checkOpen();
    _reset(_statement);
    if (params.length > 0) _bind(_statement, params);
    var result;
    int count = 0;
    var info = null;
    while ((result = _step(_statement)) is! int) {
      count++;
      if (info == null) info = new _ResultInfo(_column_info(_statement));
      if (callback != null && callback(new Row._internal(count - 1, info, result))) break;
    }
    // If update affected no rows, count == result == 0
    return (result == 0) ? count : result;
  }
}

/// Exception indicating a SQLite-related problem.
class SqliteException implements Exception {
  final String message;
  SqliteException._internal(String this.message);
  toString() => "SqliteException: $message";
}

/// Exception indicating that a SQL statement failed to compile.
class SqliteSyntaxException extends SqliteException {
  /// The SQL that was rejected by the SQLite library.
  final String query;
  SqliteSyntaxException._internal(String message, String this.query) : super._internal(message);
  toString() => "SqliteSyntaxException: $message. Query: [${query}]";
}

class _ResultInfo {
  List columns;
  Map columnToIndex;

  _ResultInfo(this.columns) {
    columnToIndex = {};
    for (int i = 0; i < columns.length; i++) {
      columnToIndex[columns[i]] = i;
    }
  }
}

/// A row of data returned from a executing a [Statement].
/// Entries can be accessed in several ways:
///   * row[0]       // by column number
///   * row.title    // by name
///   * row['title'] // by name
/// Column names are not guaranteed unless a SQL AS clause is used.
class Row {
  final List<String> _resultInfo;
  final List _data;
  Map _columnToIndex;
  /// This row's offset into the result set. The first row has index 0.
  final int index;

  Row._internal(this.index, this._resultInfo, this._data);

  /// Returns the value from the specified column.
  /// [i] may be a column name or index.
  operator [](i) {
    if (i is int) {
      return _data[i];
    } else {
      index = _resultInfo.columnToIndex[i];
      if (index == null) throw new SqliteException._internal("No such column $i");
      return _data[index];
    }
  }

  /// Returns the values in this row as a [List].
  List<Object> asList() => new List<Object>.from(_data);

  /// Returns the values in this row as a [Map] keyed by column name.
  /// The Map iterates in column order.
  Map<String, Object> asMap() {
    var result = new LinkedHashMap<String, Object>();
    for (int i = 0; i < _data.length; i++) {
      result[_resultInfo.columns[i]] = _data[i];
    }
    return result;
  }

  toString() => _data.toString();

  noSuchMethod(String method, List args) {
    if (args.length == 0 && method.startsWith("get:")) {
      String property = method.substring(4);
      index = _resultInfo.columnToIndex[i];
      if (index != null) return _data[index];
    }
    return super.noSuchMethod(method, args);
  }
}

_sqliteException(message) => new SqliteException._internal(message);
_sqliteSyntaxException(message, sql) => new SqliteSyntaxException._internal(message, sql);

_prepare(db, query, statementObject) native 'PrepareStatement';
_reset(statement) native 'Reset';
_bind(statement, params) native 'Bind';
_column_info(statement) native 'ColumnInfo';
_step(statement) native 'Step';
_closeStatement(statement) native 'CloseStatement';
_new(path) native 'New';
_close(handle) native 'Close';
_version() native 'Version';

