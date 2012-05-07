@ECHO OFF
set DART_SDK=D:\dart-sdk\
set SQLITE=.

IF "%1"=="doc" GOTO DOC
IF "%1"=="test" GOTO TEST

:BUILD
cl /DDART_SHARED_LIB /D_USRDLL /D_WINDLL /I%SQLITE% /I%DART_SDK%\include src\dart_sqlite.cc %SQLITE%\sqlite3.c dart.lib /link /DLL /OUT:lib/dart_sqlite.dll
GOTO END

:DOC
%DART_SDK%\bin\dart %DART_SDK%\lib\dartdoc\dartdoc.dart --mode=static lib\sqlite.dart
GOTO END

:TEST
%DART_SDK%\bin\dart test\test.dart
GOTO END

:END
