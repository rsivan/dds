#!/bin/bash
set -e

echo "Building DDS native library (macOS)..."
cd "$(dirname "$0")"

export CXX=/opt/homebrew/bin/g++-15
export CC=/opt/homebrew/bin/gcc-15

bazel build \
	//library/src:dds \
	//library/src/system:system \
	//library/src/solver_context:solver_context \
	//library/src/trans_table:trans_table \
	//library/src/moves:moves \
	//library/src/lookup_tables:lookup_tables \
	//library/src/heuristic_sorting:heuristic_sorting \
	//library/src/utility:constants

echo "✓ Build complete"
echo "Outputs:"
echo "  bazel-bin/library/src/libdds.a"
echo "  bazel-bin/library/src/system/libsystem.a"
echo "  bazel-bin/library/src/solver_context/libsolver_context.a"
echo "  bazel-bin/library/src/trans_table/libtrans_table.a"
echo "  bazel-bin/library/src/moves/libmoves.a"
echo "  bazel-bin/library/src/lookup_tables/liblookup_tables.a"
echo "  bazel-bin/library/src/heuristic_sorting/libheuristic_sorting.a"
echo "  bazel-bin/library/src/utility/libconstants.a"
