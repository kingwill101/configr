build: clean
    dart compile exe bin/main.dart -o bin/main.exe

cmd  DIR *args:build
    cd examples/{{DIR}} && ../../bin/main.exe {{ args }}

run_cmd  DIR *args:
    cd examples/{{DIR}} &&  dart run ../../bin/main.dart {{ args }}

clean:


install:
    dart pub global activate --source path .

uninstall:
    dart pub global deactivate configr
