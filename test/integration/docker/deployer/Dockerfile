FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openssh-client \
      iputils-ping \
      netcat-openbsd \
      jq && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /configr

CMD ["sh", "-c", "mkdir -p /root/.ssh && cp /shared/ssh/id_ed25519 /root/.ssh/id_ed25519 2>/dev/null || true && chmod 600 /root/.ssh/id_ed25519 2>/dev/null || true && cp /shared/ssh/id_ed25519.pub /root/.ssh/id_ed25519.pub 2>/dev/null || true && for vm in vm1 vm2 vm3; do ssh-keyscan -H \\$vm >> /root/.ssh/known_hosts 2>/dev/null || true; done && echo 'Setup complete' && sleep infinity"]
