# syntax=docker/dockerfile:1
FROM ubuntu:24.04

LABEL org.opencontainers.image.description="Configr test environment: Ubuntu 24.04"

# Prevent tzdata interactive prompt
ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg apt-transport-https \
    systemd systemd-sysv \
    passwd adduser \
    hostname \
    tzdata \
    locales \
    procps \
    iproute2 \
    apt-utils \
    snapd \
    flatpak \
    git \
    python3-pip \
    nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Install Dart SDK
RUN curl -fsSL https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list \
    && curl -fsSL https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_linux_signing_key.asc | gpg --dearmor -o /usr/share/keyrings/dart.gpg \
    && sed -i 's|https://storage.googleapis.com|signed-by=/usr/share/keyrings/dart.gpg https://storage.googleapis.com|g' /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update && apt-get install -y dart \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/usr/lib/dart/bin:$HOME/.pub-cache/bin"

# Generate en_US.UTF-8 locale
RUN locale-gen en_US.UTF-8

WORKDIR /app

# Default: run tests (overridden by docker-compose or CI)
CMD ["dart", "test"]