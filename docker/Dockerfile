# Stage 1: Builder
FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    build-essential \
    libomp-dev \
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
# Headers: all .h and .hpp from library/src needed by binding-linux.gyp
# Libraries: all .a files from bazel-bin needed for static linking
RUN mkdir -p /build/lib /build/include && \
    cp library/src/*.h library/src/*.hpp /build/include/ 2>/dev/null || true && \
    find bazel-bin/library/src -name "lib*.a" -exec cp {} /build/lib/ \;

# Stage 2: Runtime
FROM node:24-slim

# Install runtime dependencies for DDS + N-API binding compilation
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libgomp1 \
    python3 \
    python-is-python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy DDS artifacts from builder.
# Headers: binding-linux.gyp expects them at /dds/library/src/
# Libraries: all .a files needed for static linking
RUN mkdir -p /dds/library/src
COPY --from=builder /build/include /dds/library/src/
COPY --from=builder /build/lib /usr/local/lib

# libdds is currently built as static archives (.a files), so ldconfig
# isn't strictly required — but keep it for completeness in case a
# future build produces .so files as well.
RUN ldconfig

WORKDIR /workspace

