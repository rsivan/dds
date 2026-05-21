FROM node:24-slim

# Install build dependencies
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

# Copy DDS source
WORKDIR /dds
COPY . .

# Build DDS using Bazel
RUN bazel build --check_direct_dependencies=off //library/src:dds

# Install libdds.a and headers
RUN mkdir -p /usr/local/lib /usr/local/include/dds && \
    cp bazel-bin/library/src/libdds.a /usr/local/lib/ && \
    cp include/*.h include/*.hpp /usr/local/include/dds/ 2>/dev/null || true && \
    ldconfig

WORKDIR /workspace
