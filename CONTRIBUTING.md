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
3. send a Pull Request;
4. profit.
