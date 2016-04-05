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

Dart_NativeFunction ResolveName(Dart_Handle name, int argc, bool* auto_setup_scope);

static Dart_PersistentHandle library;
static Dart_PersistentHandle ptr_class_p;

typedef struct {
  sqlite3* db;
  sqlite3_stmt* stmt;
  Dart_WeakPersistentHandle finalizer;
} statement_peer;

DART_EXPORT Dart_Handle dart_sqlite_Init(Dart_Handle parent_library) {
  if (Dart_IsError(parent_library)) { return parent_library; }

  Dart_Handle result_code = Dart_SetNativeResolver(parent_library, ResolveName, NULL);
  if (Dart_IsError(result_code)) return result_code;

  library = Dart_NewPersistentHandle(parent_library);

  Dart_Handle class_name = Dart_NewStringFromCString("_RawPtrImpl");
  Dart_Handle ptr_class = Dart_CreateNativeWrapperClass(parent_library,
          class_name, 1);
  ptr_class_p = Dart_NewPersistentHandle(ptr_class);

  return parent_library;
}

void Throw(const char* message) {
  Dart_Handle messageHandle = Dart_NewStringFromCString(message);
  Dart_Handle exceptionClass = Dart_GetClass(library, Dart_NewStringFromCString("SqliteException"));
  Dart_ThrowException(Dart_New(exceptionClass, Dart_NewStringFromCString("_internal"), 1, &messageHandle));
}

void CheckSqlError(sqlite3* db, int result) {
  if (result) Throw(sqlite3_errmsg(db));
}

Dart_Handle CheckDartError(Dart_Handle result) {
  if (Dart_IsError(result)) Throw(Dart_GetError(result));
  return result;
}

sqlite3* get_db(Dart_Handle db_handle) {
  intptr_t db_addr;
  Dart_GetNativeInstanceField(db_handle, 0, &db_addr);
  return (sqlite3*) db_addr;
}

statement_peer* get_statement(Dart_Handle statement_handle) {
  intptr_t statement_addr;
  Dart_GetNativeInstanceField(statement_handle, 0, &statement_addr);
  return (statement_peer*) statement_addr;
}

DART_FUNCTION(New) {
  DART_ARGS_1(path);

  sqlite3* db;
  const char* cpath;
  Dart_Handle result;

  CheckDartError(Dart_StringToCString(path, &cpath));
  CheckSqlError(db, sqlite3_open(cpath, &db));
  sqlite3_busy_timeout(db, 100);
  CheckDartError(result = Dart_Allocate(Dart_HandleFromPersistent(ptr_class_p)));
  Dart_SetNativeInstanceField(result, 0, (intptr_t) db);
  DART_RETURN(result);
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

  DART_RETURN(Dart_NewStringFromCString(sqlite3_version));
}

void finalize_statement(void* isolate_callback_data, Dart_WeakPersistentHandle handle, void* peer) {
  static bool warned = false;
  statement_peer* statement = (statement_peer*) peer;
  sqlite3_finalize(statement->stmt);
  if (!warned) {
    fprintf(stderr, "Warning: sqlite.Statement was not closed before garbage collection.\n");
    warned = true;
  }
  sqlite3_free(statement);
}

DART_FUNCTION(PrepareStatement) {
  DART_ARGS_3(db_handle, sql_handle, statement_object);

  sqlite3* db = get_db(db_handle);
  const char* sql;
  sqlite3_stmt* stmt;
  Dart_Handle result;

  CheckDartError(Dart_StringToCString(sql_handle, &sql));
  if (sqlite3_prepare_v2(db, sql, strlen(sql), &stmt, NULL)) {
    Dart_Handle params[2];
    params[0] = Dart_NewStringFromCString(sqlite3_errmsg(db));
    params[1] = sql_handle;
    Dart_Handle syntaxExceptionClass = CheckDartError(Dart_GetClass(library, Dart_NewStringFromCString("SqliteSyntaxException")));
    Dart_ThrowException(Dart_New(syntaxExceptionClass, Dart_NewStringFromCString("_internal"), 2, params));
  }
  statement_peer* peer = (statement_peer*) sqlite3_malloc(sizeof(statement_peer));
  peer->db = db;
  peer->stmt = stmt;

  CheckDartError(result = Dart_Allocate(Dart_HandleFromPersistent(ptr_class_p)));
  Dart_SetNativeInstanceField(result, 0, (intptr_t) peer);
  peer->finalizer = Dart_NewWeakPersistentHandle(result, peer, 0, finalize_statement);
  DART_RETURN(result);
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
    } else if (Dart_IsTypedData(value)) {
      Dart_TypedData_Type type;
      unsigned char* data;
      intptr_t length;
      CheckDartError(Dart_TypedDataAcquireData(value, &type, (void**) &data, &length));
      unsigned char* result = (unsigned char*) sqlite3_malloc(length);
      if (length < count) {
        CheckDartError(Dart_TypedDataReleaseData(value));
        Throw("Dart buffer was too small");
        return;
      }
      if (type != Dart_TypedData_kUint8) {
        CheckDartError(Dart_TypedDataReleaseData(value));
        Throw("Dart buffer was not a Uint8Array");
        return;
      }
      memcpy(result, data, count);
      CheckDartError(Dart_TypedDataReleaseData(value));
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
      return Dart_NewStringFromCString((const char*) sqlite3_column_text(statement->stmt, col));
    case SQLITE_BLOB:
      count = sqlite3_column_bytes(statement->stmt, col);
      result = CheckDartError(Dart_NewTypedData(Dart_TypedData_kUint8, count));
      binary_data = (const unsigned char*) sqlite3_column_blob(statement->stmt, col);
      Dart_TypedData_Type type;
      unsigned char* data;
      intptr_t length;
      CheckDartError(Dart_TypedDataAcquireData(result, &type, (void**) &data, &length));
      if (length < count) {
        CheckDartError(Dart_TypedDataReleaseData(result));
        Throw("Dart buffer was too small");
        return Dart_Null();
      }
      memcpy(data, binary_data, count);
      CheckDartError(Dart_TypedDataReleaseData(result));
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
    Dart_ListSetAt(result, i, Dart_NewStringFromCString(sqlite3_column_name(statement->stmt, i)));
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
        fprintf(stderr, "Got sqlite_busy\n");
        continue; // TODO: have to roll back transaction?
      case SQLITE_LOCKED:
        fprintf(stderr, "Got sqlite_locked\n");
        continue; // TODO: have to roll back transaction?
      case SQLITE_DONE:
        // Note: sqlite3_changes will stil return a non-0 value for statements
        // which don't affect rows (e.g. SELECT). It simply returns the number
        // of changes by the last row-altering statement.
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
  Dart_DeleteWeakPersistentHandle(Dart_CurrentIsolate(), statement->finalizer);
  sqlite3_free(statement);
  DART_RETURN(Dart_Null());
}

#define EXPORT(func, args) if (!strcmp(#func, cname) && argc == args) { return func; }
Dart_NativeFunction ResolveName(Dart_Handle name, int argc, bool* auto_setup_scope) {
  assert(Dart_IsString(name));
  const char* cname;
  Dart_Handle check_error = Dart_StringToCString(name, &cname);
  if (Dart_IsError(check_error)) Dart_PropagateError(check_error);
  *auto_setup_scope = false;

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
