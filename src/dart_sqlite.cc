// Copyright 2012 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

#include <string.h>
#include <stdio.h>

#include "dart_api.h"
#include "sqlite3.h"

#define DART_ARG(name, i) Dart_Handle name = Dart_GetNativeArgument(arguments, i);
#define DART_ARGS_0() Dart_EnterScope(); /*{printf("Entering %s\n", __FUNCTION__);}*/
#define DART_ARGS_1(arg0) DART_ARGS_0() DART_ARG(arg0, 0)
#define DART_ARGS_2(arg0, arg1) DART_ARGS_1(arg0); DART_ARG(arg1, 1)
#define DART_ARGS_3(arg0, arg1, arg2) DART_ARGS_2(arg0, arg1); DART_ARG(arg2, 2)
#define DART_ARGS_4(arg0, arg1, arg2, arg3) DART_ARGS_3(arg0, arg1, arg2); DART_ARG(arg3, 3)

#define DART_FUNCTION(name) static void name(Dart_NativeArguments arguments)
#define DART_RETURN(expr) {Dart_SetReturnValue(arguments, expr); Dart_ExitScope(); return;}

Dart_NativeFunction ResolveName(Dart_Handle name, int argc);

static Dart_Handle library;

typedef struct {
  sqlite3* db;
  sqlite3_stmt* stmt;
  Dart_Handle finalizer;
} statement_peer;

DART_EXPORT Dart_Handle dart_sqlite_Init(Dart_Handle parent_library) {
  if (Dart_IsError(parent_library)) { return parent_library; }

  Dart_Handle result_code = Dart_SetNativeResolver(parent_library, ResolveName);
  if (Dart_IsError(result_code)) return result_code;

  library = Dart_NewPersistentHandle(parent_library);
  return parent_library;
}

void Throw(const char* message) {
  Dart_Handle messageHandle = Dart_NewString(message);
  Dart_ThrowException(Dart_Invoke(library, Dart_NewString("_sqliteException"), 1, &messageHandle));
}

void CheckSqlError(sqlite3* db, int result) {
  if (result) Throw(sqlite3_errmsg(db));
}

Dart_Handle CheckDartError(Dart_Handle result) {
  if (Dart_IsError(result)) Throw(Dart_GetError(result));
  return result;
}

sqlite3* get_db(Dart_Handle db_handle) {
  int64_t db_addr;
  Dart_IntegerToInt64(db_handle, &db_addr);
  return (sqlite3*) db_addr;
}

statement_peer* get_statement(Dart_Handle statement_handle) {
  int64_t statement_addr;
  Dart_IntegerToInt64(statement_handle, &statement_addr);
  return (statement_peer*) statement_addr;
}

DART_FUNCTION(New) {
  DART_ARGS_1(path);

  sqlite3* db;
  const char* cpath;
  CheckDartError(Dart_StringToCString(path, &cpath));
  CheckSqlError(db, sqlite3_open(cpath, &db));
  sqlite3_busy_timeout(db, 100);
  DART_RETURN(Dart_NewInteger((int64_t) db));
}

DART_FUNCTION(Close) {
  DART_ARGS_1(db_handle);

  sqlite3* db = get_db(db_handle);
  sqlite3_stmt* statement = NULL;
  int count = 0;
  while ((statement = sqlite3_next_stmt(db, statement))) {
    sqlite3_finalize(statement);
    count++;
  }
  if (count) fprintf(stderr, "Warning: sqlite.Database.close(): %d statements still open.\n", count);
  CheckSqlError(db, sqlite3_close(db));
  DART_RETURN(Dart_Null());
}

DART_FUNCTION(Version) {
  DART_ARGS_0();

  DART_RETURN(Dart_NewString(sqlite3_version));
}

void finalize_statement(Dart_Handle handle, void* ctx) {
  static bool warned = false;
  statement_peer* statement = (statement_peer*) ctx;
  if (statement->stmt) {
    sqlite3_finalize(statement->stmt);
    statement->stmt = NULL;
    if (!warned) {
      fprintf(stderr, "Warning: sqlite.Statement was not closed before garbage collection.\n");
      warned = true;
    }
  }
  sqlite3_free(statement);
}

DART_FUNCTION(PrepareStatement) {
  DART_ARGS_3(db_handle, sql_handle, statement_object);

  sqlite3* db = get_db(db_handle);
  const char* sql;
  sqlite3_stmt* stmt;
  CheckDartError(Dart_StringToCString(sql_handle, &sql));
  if (sqlite3_prepare_v2(db, sql, strlen(sql), &stmt, NULL)) {
    Dart_Handle params[2];
    params[0] = Dart_NewString(sqlite3_errmsg(db));
    params[1] = sql_handle;
    Dart_ThrowException(Dart_Invoke(library, Dart_NewString("_sqliteSyntaxException"), 2, params));
  }
  statement_peer* peer = (statement_peer*) sqlite3_malloc(sizeof(statement_peer));
  peer->db = db;
  peer->stmt = stmt;
  peer->finalizer = CheckDartError(Dart_NewWeakPersistentHandle(statement_object, peer, finalize_statement));
  DART_RETURN(Dart_NewInteger((int64_t) peer));
}

DART_FUNCTION(Reset) {
  DART_ARGS_1(statement_handle);

  statement_peer* statement = get_statement(statement_handle);
  CheckSqlError(statement->db, sqlite3_clear_bindings(statement->stmt));
  CheckSqlError(statement->db, sqlite3_reset(statement->stmt));
  DART_RETURN(Dart_Null());
}

DART_FUNCTION(Bind) {
  DART_ARGS_2(statement_handle, args);

  statement_peer* statement = get_statement(statement_handle);
  if (!Dart_IsList(args)) {
    Throw("args must be a List");
  }
  intptr_t count;
  Dart_ListLength(args, &count);
  if (sqlite3_bind_parameter_count(statement->stmt) != count) {
    Throw("Number of arguments doesn't match number of placeholders");
  }
  for (int i = 0; i < count; i++) {
    Dart_Handle value = Dart_ListGetAt(args, i);
    if (Dart_IsInteger(value)) {
      int64_t result;
      Dart_IntegerToInt64(value, &result);
      CheckSqlError(statement->db, sqlite3_bind_int64(statement->stmt, i + 1, result));
    } else if (Dart_IsDouble(value)) {
      double result;
      Dart_DoubleValue(value, &result);
      CheckSqlError(statement->db, sqlite3_bind_double(statement->stmt, i + 1, result));
    } else if (Dart_IsNull(value)) {
      CheckSqlError(statement->db, sqlite3_bind_null(statement->stmt, i + 1));
    } else if (Dart_IsString(value)) {
      const char* result;
      CheckDartError(Dart_StringToCString(value, &result));
      CheckSqlError(statement->db, sqlite3_bind_text(statement->stmt, i + 1, result, strlen(result), SQLITE_TRANSIENT));
    } else if (Dart_IsByteArray(value)) {
      intptr_t count;
      CheckDartError(Dart_ListLength(value, &count));
      unsigned char* result = (unsigned char*) sqlite3_malloc(count);
      for (int j = 0; j < count; j++) {
        Dart_ByteArrayGetUint8At(value, i + 1, &result[j]);
      }
      CheckSqlError(statement->db, sqlite3_bind_blob(statement->stmt, i + 1, result, count, sqlite3_free));
    } else {
      Throw("Invalid parameter type");
    }
  }
  DART_RETURN(Dart_Null());
}

Dart_Handle get_column_value(statement_peer* statement, int col) {
  int count;
  const unsigned char* binary_data;
  Dart_Handle result;
  switch (sqlite3_column_type(statement->stmt, col)) {
    case SQLITE_INTEGER:
      return Dart_NewInteger(sqlite3_column_int64(statement->stmt, col));
    case SQLITE_FLOAT:
      return Dart_NewDouble(sqlite3_column_double(statement->stmt, col));
    case SQLITE_TEXT:
      return Dart_NewString((const char*) sqlite3_column_text(statement->stmt, col));
    case SQLITE_BLOB:
      count = sqlite3_column_bytes(statement->stmt, col);
      result = CheckDartError(Dart_NewByteArray(count));
      binary_data = (const unsigned char*) sqlite3_column_blob(statement->stmt, col);
      // this is stupid
      for (int i = 0; i < count; i++) {
        Dart_ByteArraySetUint8At(result, i, binary_data[i]);
      }
      return result;
    case SQLITE_NULL:
      return Dart_Null();
    default:
      Throw("Unknown result type");
      return Dart_Null();
  }
}

Dart_Handle get_last_row(statement_peer* statement) {
  int count = sqlite3_column_count(statement->stmt);
  Dart_Handle list = CheckDartError(Dart_NewList(count));
  for (int i = 0; i < count; i++) {
    Dart_ListSetAt(list, i, get_column_value(statement, i));
  }
  return list;
}

DART_FUNCTION(ColumnInfo) {
  DART_ARGS_1(statement_handle);

  statement_peer* statement = get_statement(statement_handle);
  int count = sqlite3_column_count(statement->stmt);
  Dart_Handle result = Dart_NewList(count);
  for (int i = 0; i < count; i++) {
    Dart_ListSetAt(result, i, Dart_NewString(sqlite3_column_name(statement->stmt, i)));
  }
  DART_RETURN(result);
}
 
DART_FUNCTION(Step) {
  DART_ARGS_1(statement_handle);

  statement_peer* statement = get_statement(statement_handle);
  while (true) {
    int status = sqlite3_step(statement->stmt);
    switch (status) {
      case SQLITE_BUSY:
        continue; // TODO: have to roll back transaction?
      case SQLITE_DONE:
        DART_RETURN(Dart_NewInteger(sqlite3_changes(statement->db)));
      case SQLITE_ROW:
        DART_RETURN(get_last_row(statement));
      default:
        CheckSqlError(statement->db, status);
        Throw("Unreachable");
    }
  }
}

DART_FUNCTION(CloseStatement) {
  DART_ARGS_1(statement_handle);

  statement_peer* statement = get_statement(statement_handle);
  CheckSqlError(statement->db, sqlite3_finalize(statement->stmt));
  Dart_DeletePersistentHandle(statement->finalizer);
  sqlite3_free(statement);
  DART_RETURN(Dart_Null());
}

#define EXPORT(func, args) if (!strcmp(#func, cname) && argc == args) { return func; }
Dart_NativeFunction ResolveName(Dart_Handle name, int argc) {
  assert(Dart_IsString8(name));
  const char* cname;
  Dart_Handle check_error = Dart_StringToCString(name, &cname);
  if (Dart_IsError(check_error)) Dart_PropagateError(check_error);

  EXPORT(New, 1);
  EXPORT(Close, 1);
  EXPORT(Version, 0);
  EXPORT(PrepareStatement, 3);
  EXPORT(Reset, 1);
  EXPORT(Bind, 2);
  EXPORT(Step, 1);
  EXPORT(ColumnInfo, 1);
  EXPORT(CloseStatement, 1);
  return NULL;
}
