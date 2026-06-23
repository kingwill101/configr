# syntax=docker/dockerfile:1
FROM alpine:3.20

LABEL org.opencontainers.image.description="Configr test environment: Alpine Linux (musl)"

RUN apk add --no-cache \
    curl ca-certificates \
    shadow \
    hostname \
    tzdata \
    musl-locales \
    procps \
    iproute2 \
    crond \
    git \
    python3 py3-pip \
    nodejs npm

# Install Dart SDK (Alpine uses musl, use the Dart SDK tarball)
RUN curl -fsSL https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -o /tmp/dart.zip \
    && unzip /tmp/dart.zip -d /usr/lib \
    && rm /tmp/dart.zip \
    && ln -s /usr/lib/dart-sdk/bin/dart /usr/local/bin/dart

ENV HOME=/root
ENV PATH="$PATH:/usr/lib/dart-sdk/bin:$HOME/.pub-cache/bin"

WORKDIR /app

# Default: run tests (overridden by docker-compose or CI)
CMD ["dart", "test"]