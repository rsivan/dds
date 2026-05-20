# DDS (Double Dummy Solver)

Bridge double-dummy solver library (perfect-information analyzer). Used by bridge-project as the core evaluation engine for a bot's card play decisions.

## Project Context

- **Location**: ~/GitHub/dds
- **Usage**: Linked into Node.js N-API binding at `/bridge-project/packages/dds-adapter`
- **Consumer**: Bridge bot sampler (Monte Carlo) calls DDS for each candidate card play
- **Constraint**: Must run fast enough for 10k+ samples per decision

## Build Setup

**Current build**: Bazel (hermetic, reproducible)

```bash
cd ~/GitHub/dds
CXX=/opt/homebrew/bin/g++-15 CC=/opt/homebrew/bin/gcc-15 bazel build //library/src:dds
```

Output: `bazel-bin/library/src/libdds.a` (static library, ~4MB)

**Target platform**: macOS Sonoma M5 (Apple Silicon ARM64)
- Compiler: g++-15 via Homebrew (NOT clang — required for OpenMP)
- OpenMP: Essential for multi-threaded solve performance

## Known Issues

### Linking Problem (As of 2026-05-20)

**Symptom**: N-API binding compiles but fails at runtime with `dlopen` error.

**Error**: Undefined symbol `__ZN6MemoryD1Ev` (Memory class destructor)

**Root cause**: Static libdds.a has undefined Memory symbols; likely missing C++ build flags.

**Investigation steps**:
1. Check Bazel config for C++ exception handling (`-fexceptions`)
2. Enable RTTI if needed (`-frtti`)
3. Verify libstdc++ ABI compatibility (g++-15 vs Node.js runtime)
4. Consider alternative build: CMake or direct g++-15 compilation
5. Test with `nm -u libdds.a | grep Memory` — should find no undefined Memory symbols after fix

**Build flags to verify** in `//library/src/BUILD`:
- `-fexceptions` (C++ exceptions)
- `-frtti` (Runtime type information)
- `-fopenmp` (OpenMP threading)
- `-std=c++17` (C++ standard)

## API Surface (Relevant to N-API Binding)

**Primary function** (used by bridge-project):

```c
int SolveBoardPBN(
  struct dealPBN dl,           // deal + current trick in PBN format
  int target,                  // -1 = optimize all tricks
  int solutions,               // 3 = return all cards + score
  int mode,                    // 0 = default
  struct futureTricks *fut,    // output: tricks achievable per card
  int threadIndex              // 0 for single threaded
);
```

**Threading setup** (call once before solving):

```c
void SetThreading(int numThreads, int strategy);
void SetMaxThreads(int numThreads);
```

## Integration with bridge-project

N-API binding at `packages/dds-adapter/src/binding.cc` wraps DDS:
- **Input**: PBN deal string + PlayState (trump, leader, current trick)
- **Execution**: Synchronous solve (DDS is fast enough, no async needed)
- **Output**: `Record<card, tricksAchievable>` back to JavaScript

See `bridge-project/packages/dds-adapter/CLAUDE.md` for complete binding architecture.

## Testing

Once linking is fixed, validate with:

```bash
cd bridge-project/packages/dds-adapter
npm run build:native
node test.js
```

Expected output: Tricks achievable per card for a sample deal.

## Next Phase

1. ✅ Verify test passes
2. Integrate into bot sampler (Monte Carlo sampling layer)
3. Profile OpenMP scaling on M5 (target: 10k+ solves/sec)
4. Consider caching strategies for repeated positions

## Out of Scope

- Bidding engine (separate)
- UI integration
- Convention cards
