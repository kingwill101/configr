# syntax=docker/dockerfile:1
FROM fedora:40

LABEL org.opencontainers.image.description="Configr test environment: Fedora 40"

RUN dnf install -y \
    curl ca-certificates \
    systemd systemd-libs \
    shadow-utils \
    hostname \
    tzdata \
    glibc-langpack-en \
    procps-ng \
    iproute \
    git \
    python3-pip \
    nodejs npm \
    && dnf clean all

# Install Dart SDK
RUN curl -fsSL https://storage.googleapis.com/download.dartlang.org/linux/fedora/dart_stable.repo > /etc/yum.repos.d/dart_stable.repo \
    && dnf install -y dart \
    && dnf clean all

ENV HOME=/root
ENV PATH="$PATH:/usr/lib/dart/bin:$HOME/.pub-cache/bin"

WORKDIR /app
CMD ["dart", "test"]