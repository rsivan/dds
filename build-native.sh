#!/bin/bash
set -e

echo "Building DDS native library (macOS)..."
cd "$(dirname "$0")"

export CXX=/opt/homebrew/bin/g++-15
export CC=/opt/homebrew/bin/gcc-15

bazel build //library/src:dds

echo "✓ Build complete"
echo "Output: bazel-bin/library/src/libdds.a"
