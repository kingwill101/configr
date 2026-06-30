FROM dart:3.12.2 AS build

WORKDIR /app
COPY . .
RUN dart pub get
RUN dart compile exe bin/configr.dart -o /usr/local/bin/configr

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    sudo \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bin/configr /usr/local/bin/configr
COPY examples/dotfiles-bootstrap /examples/dotfiles-bootstrap

WORKDIR /examples/dotfiles-bootstrap
CMD ["./test.sh"]
