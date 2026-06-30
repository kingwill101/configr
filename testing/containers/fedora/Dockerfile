# syntax=docker/dockerfile:1
FROM fedora:40

LABEL org.opencontainers.image.description="Configr test environment: Fedora 40"

RUN dnf install -y \
    curl ca-certificates \
    systemd systemd-libs systemd-container \
    shadow-utils \
    hostname \
    tzdata \
    glibc-langpack-en \
    procps-ng \
    iproute \
    cronie \
    git \
    python3-pip \
    nodejs npm \
    sudo \
    zip \
    unzip \
    && dnf clean all

# Install Dart SDK via the generic tarball (Fedora 40 no longer has the stable repo)
RUN curl -fsSL https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip -o /tmp/dart.zip \
    && unzip /tmp/dart.zip -d /usr/lib \
    && rm /tmp/dart.zip \
    && ln -s /usr/lib/dart-sdk/bin/dart /usr/local/bin/dart \
    && ln -s /usr/lib/dart-sdk/bin/dart2native /usr/local/bin/dart2native 2>/dev/null; true

ENV HOME=/root
ENV PATH="$PATH:/usr/lib/dart/bin:$HOME/.pub-cache/bin"

# Allow root to use sudo without password (for configr's NonInteractiveSudoEscalation)
RUN echo "root ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

WORKDIR /app

# Default: run tests (overridden by docker-compose or CI)
CMD ["dart", "test"]
