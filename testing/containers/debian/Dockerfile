# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

LABEL org.opencontainers.image.description="Configr test environment: Debian Bookworm"

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
    cron \
    git \
    python3-pip \
    nodejs npm \
    sudo \
    nano \
    zip unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Dart SDK
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/dart.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" > /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update && apt-get install -y dart \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/usr/lib/dart/bin:$HOME/.pub-cache/bin"

# Allow root to use sudo without password (for configr's NonInteractiveSudoEscalation)
RUN echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Generate en_US.UTF-8 locale
RUN locale-gen en_US.UTF-8

WORKDIR /app

# Default: run tests (overridden by docker-compose or CI)
CMD ["dart", "test"]
