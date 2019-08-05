// Copyright 2016 Google Inc.
// Licensed under the Apache License, Version 2.0 (the "License")
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

import 'dart:mirrors';

import 'exceptions.dart';
import 'row.dart';

class RowMetadata {
  RowMetadata(this.columns) {
    for (int i = 0; i < columns.length; i++) {
      columnToIndex[columns[i]] = i;
    }
  }

  final List<String> columns;
  final Map<String, int> columnToIndex = {};
}

class RowImpl implements Row {
  RowImpl(this.index, this._metadata, this._data);

  final RowMetadata _metadata;
  final List _data;

  @override
  final int index;

  @override
  dynamic operator [](dynamic i) {
    if (i is int) {
      return _data[i];
    } else if (i is String){
      var index = _metadata.columnToIndex[i];
      if (index == null) {
        throw SqliteException("No such column $i");
      }
      return _data[index];
    } else {
      throw SqliteException("Invalid column identifier: $i");
    }
  }

  @override
  List toList() => List.from(_data);

  @override
  Map<String, dynamic> toMap() {
    var result = Map<String, dynamic>();
    for (int i = 0; i < _data.length; i++) {
      result[_metadata.columns[i]] = _data[i];
    }
    return result;
  }

  @override
  String toString() => _data.toString();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter) {
      final property = MirrorSystem.getName(invocation.memberName);
      final index = _metadata.columnToIndex[property];
      if (index != null) {
        return _data[index];
      }
    }
    return super.noSuchMethod(invocation);
  }
}
