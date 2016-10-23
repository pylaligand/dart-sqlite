Contributing
============================================

## Building

*Prerequisites*

- Dart SDK
- sqlite3-dev package
- g++ toolchain

This package uses `make` as its build tool. Note that several build rules
require the DART_SDK environment variable to be set.

Build the library:
```
make
```

Run the tests:
```
make test
```

Run the examples:
```
make examples
```

View all the available commands:
```
make help
```


## Making changes

We use the normal GitHub Pull Request process:

1. fork the repository;
2. make changes in your fork;
3. format your changed files with `make format`;
4. send a Pull Request;
5. profit.


## Creating a new release (team only)

1. create [a PR](https://github.com/pylaligand/dart-sqlite/pull/50) bumping the
   library version number to `X.Y.Z`;
2. on GitHub, create a new release called `vX.Y.Z`;
3. Travis will build the new tag: wait until the build shared libraries are
   attached to the release;
4. download the tag in your local client with `git fetch` and check it out with
   `git checkout vX.Y.Z`
5. download the shared libraries with
`dart tool/download_shared_libraries.dart`
6. try a publication dry run with `pub publish -n`
7. go for it: `pub publish`
