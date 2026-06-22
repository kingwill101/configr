build: clean
    dart compile exe bin/configr.dart -o configr

cmd  DIR *args:build
    cd examples/{{DIR}} && ../../bin/main.exe {{ args }}

run_cmd  DIR *args:
    cd examples/{{DIR}} &&  dart run ../../bin/main.dart {{ args }}

clean:


install:
    dart pub global activate --source path .

uninstall:
    dart pub global deactivate configr

docker-test:
    docker build -f examples/dotfiles-bootstrap/Dockerfile -t configr-test-dotfiles .
    docker run --rm configr-test-dotfiles
