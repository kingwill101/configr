# syntax=docker/dockerfile:1
FROM alpine:3.20

LABEL org.opencontainers.image.description="Configr test environment: Alpine Linux (musl)"

# Install glibc compatibility layer for Dart SDK
RUN apk add --no-cache gcompat libstdc++

RUN apk add --no-cache \
    curl ca-certificates \
    shadow \
    tzdata \
    musl-locales \
    procps \
    iproute2 \
    dcron \
    bash \
    git \
    python3 py3-pip \
    nodejs npm \
    sudo \
    unzip

# Install Dart SDK (Alpine uses musl, use the Dart SDK tarball)
RUN curl -fsSL https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -o /tmp/dart.zip \
    && unzip /tmp/dart.zip -d /usr/lib \
    && rm /tmp/dart.zip \
    && ln -s /usr/lib/dart-sdk/bin/dart /usr/local/bin/dart

ENV HOME=/root
ENV PATH="$PATH:/usr/lib/dart-sdk/bin:$HOME/.pub-cache/bin"

# Allow root to use sudo without password (for configr's NonInteractiveSudoEscalation)
RUN echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

WORKDIR /app

# Default: run tests (overridden by docker-compose or CI)
CMD ["dart", "test"]