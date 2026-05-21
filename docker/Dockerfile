# Stage 1: Builder
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    build-essential \
    git \
    python3 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Bazel
RUN wget https://github.com/bazelbuild/bazelisk/releases/download/v1.29.0/bazelisk-linux-amd64 -O /usr/local/bin/bazel && \
    chmod +x /usr/local/bin/bazel

WORKDIR /dds
COPY . .

# Build DDS using Bazel
RUN bazel build --check_direct_dependencies=off //library/src:dds

# Copy artifacts to a clean build directory
RUN mkdir -p /build/lib /build/include && \
    cp bazel-bin/library/src/libdds.a /build/lib/ && \
    cp include/*.h include/*.hpp /build/include/ 2>/dev/null || true

# Stage 2: Runtime
FROM node:24-slim

# Install only runtime dependencies (no build tools)
RUN apt-get update && apt-get install -y \
    libomp-dev \
    libstdc++6 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy DDS artifacts from builder
COPY --from=builder /build/lib /usr/local/lib
COPY --from=builder /build/include /usr/local/include/dds

# Make library discoverable
RUN ldconfig

WORKDIR /workspace

