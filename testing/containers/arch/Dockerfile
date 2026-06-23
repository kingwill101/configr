# syntax=docker/dockerfile:1
FROM archlinux:latest

LABEL org.opencontainers.image.description="Configr test environment: Arch Linux"

RUN pacman -Syu --noconfirm \
    curl ca-certificates \
    systemd systemd-libs \
    shadow \
    inetutils \
    tzdata \
    glibc \
    procps-ng \
    iproute2 \
    git \
    python-pip \
    nodejs npm \
    && pacman -Scc --noconfirm

# Install Dart SDK from AUR or official tarball
RUN curl -fsSL https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -o /tmp/dart.zip \
    && unzip /tmp/dart.zip -d /usr/lib \
    && rm /tmp/dart.zip \
    && ln -s /usr/lib/dart-sdk/bin/dart /usr/local/bin/dart \
    && ln -s /usr/lib/dart-sdk/bin/dart2native /usr/local/bin/dart2native 2>/dev/null || true

ENV HOME=/root
ENV PATH="$PATH:/usr/lib/dart-sdk/bin:$HOME/.pub-cache/bin"

WORKDIR /app
CMD ["dart", "test"]