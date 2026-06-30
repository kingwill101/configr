FROM ubuntu:22.04

WORKDIR /work

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      openssh-server \
      openssh-client \
      sudo \
      iproute2 \
      iputils-ping \
      netcat-openbsd \
      ca-certificates \
      curl \
      jq && \
    rm -rf /var/lib/apt/lists/*

COPY test/integration/docker/vm/boot.sh .
RUN chmod +x boot.sh

RUN useradd -m -s /bin/bash tester && \
    echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester && \
    chmod 440 /etc/sudoers.d/tester && \
    mkdir -p /home/tester/.ssh && \
    chown -R tester:tester /home/tester/.ssh

RUN mkdir -p /var/run/sshd

EXPOSE 22

HEALTHCHECK --interval=1s CMD nc -z localhost 22 || exit 1

CMD ["./boot.sh"]
