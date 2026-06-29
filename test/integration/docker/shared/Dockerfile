FROM alpine:3.19

RUN apk add --no-cache openssh openssh-keygen

WORKDIR /shared
RUN mkdir -p /shared/ssh /shared/certs

# Generate SSH host keys and test keypair on first run
RUN ssh-keygen -A && \
    ssh-keygen -t ed25519 -f /shared/ssh/id_ed25519 -N "" -q && \
    cp /shared/ssh/id_ed25519.pub /shared/ssh/authorized_keys

CMD ["sh", "-c", "mkdir -p /root/.ssh && cp /shared/ssh/authorized_keys /root/.ssh/authorized_keys 2>/dev/null || true && chmod 700 /root/.ssh 2>/dev/null || true && chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true && sleep infinity"]

HEALTHCHECK --interval=2s --timeout=1s --retries=10 CMD test -f /shared/ssh/id_ed25519.pub || exit 1
