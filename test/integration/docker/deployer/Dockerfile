FROM dart:stable AS builder

WORKDIR /build

COPY pubspec.yaml ./
COPY lib ./lib
COPY bin ./bin

RUN dart pub get && \
    dart compile exe bin/configr.dart -o /build/configr

FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openssh-client \
      iputils-ping \
      netcat-openbsd \
      jq && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/configr /usr/local/bin/configr

WORKDIR /configr

CMD ["sh", "-c", "mkdir -p /root/.ssh && cp /shared/ssh/id_rsa /root/.ssh/id_rsa 2>/dev/null || true && chmod 600 /root/.ssh/id_rsa 2>/dev/null || true && cp /shared/ssh/id_rsa.pub /root/.ssh/id_rsa.pub 2>/dev/null || true && for vm in vm1 vm2 vm3; do ssh-keyscan -H \\$vm >> /root/.ssh/known_hosts 2>/dev/null || true; done && echo 'Setup complete' && sleep infinity"]
