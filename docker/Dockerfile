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

# Build DDS using Bazel - build all transitive dependencies
RUN bazel build --check_direct_dependencies=off \
    //library/src:dds \
    //library/src/utility:constants \
    //library/src/lookup_tables:lookup_tables \
    //library/src/heuristic_sorting \
    //library/src/trans_table \
    //library/src/moves:moves \
    //library/src/system \
    //library/src/solver_context:solver_context \
    //library/src/api:api_definitions

# Copy all .a files from bazel-bin and headers to system directories
RUN mkdir -p /usr/local/lib /dds/library/src && \
    find bazel-bin/library/src -name "lib*.a" -exec cp {} /usr/local/lib/ \; && \
    cp -r library/src /dds/ && \
    ldconfig

WORKDIR /workspace
