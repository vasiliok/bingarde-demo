# gcc for x86_64 plus the aarch64 cross compiler and binutils.
FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc libc6-dev binutils file \
        gcc-aarch64-linux-gnu libc6-dev-arm64-cross binutils-aarch64-linux-gnu \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
