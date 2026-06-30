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

bootstrap-test:
    docker build -f examples/dotfiles-bootstrap/Dockerfile -t configr-test-dotfiles .
    docker run --rm configr-test-dotfiles

# Run all unit tests (excludes container-backed tests that need docker-in-docker)
test:
    dart test --exclude-tags container --exclude-tags integration
testt *args:
    mkdir -p .dart_test_tmp
    TMPDIR="$PWD/.dart_test_tmp" dart test {{ args }}
# Build all docker test containers from the testing/docker-compose.yml matrix
docker-build:
    docker compose -f testing/docker-compose.yml build

# Run the full integration test matrix across all supported distros
docker-test-all:
    docker compose -f testing/docker-compose.yml --profile all up --abort-on-container-exit

# Run integration tests on a specific distro: just docker-test ubuntu|debian|fedora|arch|alpine
docker-test distro="ubuntu":
    @docker compose -f testing/docker-compose.yml run --rm {{distro}}-test

# Run unit tests + all distro integration tests
ci:
    dart test --exclude-tags container --exclude-tags integration
    echo "---"
    docker compose -f testing/docker-compose.yml --profile all up --abort-on-container-exit
