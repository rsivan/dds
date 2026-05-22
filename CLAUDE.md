# DDS (Double Dummy Solver)

Bridge double-dummy solver library (perfect-information analyzer). Used by bridge-project as the core evaluation engine for a bot's card play decisions.

## Project Context

- **Location**: ~/GitHub/dds
- **Usage**: Linked into Node.js N-API binding at `/bridge-project/packages/dds-adapter`
- **Consumer**: Bridge bot sampler (Monte Carlo) calls DDS for each candidate card play
- **Constraint**: Must run fast enough for 10k+ samples per decision

## Fork Scope

This is a fork of dds-bridge/dds (Apache 2.0). Upstream DDS itself is stable
(last upstream release 2.9.0, August 2018). This fork does NOT modify the
C++ source. Permitted changes:

- Build infrastructure (Bazel config, Makefile tweaks if needed)
- Docker image definition and publishing workflows
- Documentation (this file, READMEs)

Do NOT modify files under `library/src/`, `include/`, or other upstream paths
without an explicit reason. Such changes create merge pain when tracking
upstream.

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
- Multi-language wrappers (Python, etc.) — separate adapter repos belong elsewhere
- Bridge bot logic of any kind
- Test corpora, PBN handling beyond what DDS itself ships

# Need to investigate

## DDS static library (libdds.a built by Bazel) doesn't embed transitive dependencies

- **Root cause confirmed by consumer (dds-adapter)**: Bazel's cc_library doesn't embed transitive dependencies in static archives by design
- **Symptom**: N-API binding compiles fine, but runtime `dlopen` fails with undefined Memory symbols
- **Reason**: libdds.a depends on //library/src/system and other libraries, but their object files aren't embedded in the archive

### Solutions evaluated:

1. ❌ **C++ compilation flags** (already done): `-fexceptions -frtti -fopenmp` help but insufficient
2. ❌ **Monolithic cc_library**: Causes Bazel to emit .lo (shared object) instead of static archive
3. ❌ **Post-processing with ar/genrule**: Complex and doesn't work well in Bazel sandbox
4. ✅ **N-API binding links all dependencies**: Real solution — binding should link against all transitive deps

### Recommended fix:

The **N-API binding in bridge-project should explicitly link**:
- libdds.a
- libsystem.a
- libsolver_context.a
- libtrans_table.a
- libmoves.a
- liblookup_tables.a
- libheuristic_sorting.a
- libconstants.a (from utility)
- libapi_definitions.a

Instead of relying on Bazel's automatic transitive linking, add these to binding.gyp's link phase.

See `/bridge-project/packages/dds-adapter/CLAUDE.md` for implementation details.

---

# Docker Image

## Purpose

In addition to local development on macOS, this fork publishes a Linux
Docker image containing DDS built and installed system-wide. The image
serves three consumers:

1. **dds-adapter CI** — runs Node tests inside this image via GHA
   `container:` directive, eliminating DDS build cost from every test run.
2. **Local CI-parity verification** — same image runs on the M5 Mac
   (under Docker Desktop emulation) to reproduce CI failures.
3. **Future production deployment** — bridge-project's bot service will
   use this image as a base layer in its multi-stage production build.

The image is built FROM this repo's source. Branch/PR/release builds
naturally produce matching images.

## Image Contents

- **Base**: `node:24-slim` (includes Node.js, npm for dds-adapter CI)
- **Compiled artifacts**: All `.a` files (libdds.a, libconstants.a, libsystem.a, etc.) at `/usr/local/lib/`, headers with subdirectories at `/dds/library/src/`
- **Build tools (runtime stage only)**: libstdc++6, libgomp1 (minimal runtime deps) + python3, make, g++ (for N-API binding compilation)
- **Result**: ~790 MB (multi-stage optimization)

**Why all transitive .a files?** Bazel automatically links transitive dependencies within its build system. However, when libdds.a is extracted as a standalone artifact, it contains undefined symbols that must be resolved by linking against transitive libraries (libconstants.a, libsystem.a, libtrans_table.a, etc.). dds-adapter's binding-linux.gyp needs all these .a files available at `/usr/local/lib/` to compile and link the native binding successfully.

The image does NOT contain:

- Build toolchain (gcc, g++, Bazel — removed in runtime stage)
- Application code or bot logic
- The N-API adapter or any Node packages beyond what Node itself ships

## Build Strategy

**Architecture**: Multi-stage Dockerfile (builder + runtime)
- **Builder stage** (ubuntu:24.04): Full toolchain + Bazel, compiles DDS, produces libdds.a + headers
- **Runtime stage** (node:24-slim): Copies only compiled artifacts + minimal runtime deps
- **Benefit**: Reduces bloat from build tools, final image ~570 MB (was ~1.5 GB)

**Linux x64 only.** ARM64 builds are not produced. On Apple Silicon Macs, use `--platform linux/amd64` to pull/run the x86_64 version (runs under emulation).

**Build system**: Bazel (same as macOS dev build, hermetic and reproducible)


## Tagging Strategy

Three tags per build, published to GitHub Container Registry:

- `ghcr.io/<owner>/dds:<dds-version>-<short-sha>` — exact pin
- `ghcr.io/<owner>/dds:<dds-version>` — moved deliberately to blessed build
- `ghcr.io/<owner>/dds:latest` — moved deliberately to canonical build

`latest` is NOT auto-updated on every push. It is moved explicitly
when a build is deemed canonical.

Consumers should pin to the SHA tag in CI, the version tag in production.

## Build Triggers

Image builds run on:

- Push of tags matching `image-v*` (deliberate image release)
- Manual `workflow_dispatch`
- Optionally: push to main when files under `docker/` or DDS sources change

The image does NOT rebuild on every commit. Most commits to this fork
are docs/Bazel/CI changes that don't affect the published image.

## File Layout (Docker-Related Additions)

- `docker/Dockerfile` — the image definition
- `docker/README.md` — image usage notes (optional)
- `.github/workflows/docker-image.yml` — GHA workflow to build and publish

These are additions to the upstream layout. Do not place Docker files
inside `src/`, `library/`, or other upstream-managed directories.

## Local Docker Use on Mac

The image runs on the M5 via Docker Desktop, but:

- It is linux/amd64, so runs under Rosetta/qemu emulation on ARM64
- Performance is meaningfully worse than native macOS DDS
- File I/O across volume mounts is slow
- Use it for CI-parity verification, NOT for daily development

Daily development on the Mac continues to use the locally-built DDS
(Bazel + g++-15). The Docker image is a CI tool and a debugging tool,
not a replacement for the native build.

## Open Questions Before Implementation

1. **Base image**: `node:24-slim` vs `ubuntu:24.04`? Lean toward
   node-slim since the only consumer is Node-based.
2. **Single-stage vs multi-stage Dockerfile?** Single-stage is simpler;
   multi-stage produces a smaller image by dropping build tools. For
   a CI image, single-stage is fine — the build tools are useful for
   the N-API binding compilation inside the same image.
3. **Where does `npm`/`node-gyp` live?** Almost certainly in the same
   image, since the dds-adapter's CI needs to build its native binding
   against the installed DDS.
4. **Linux build flags**: Does the linking issue documented above
   ("Need to investigate" section) also affect the Linux shared-library
   build? Test before assuming the Mac investigation transfers.

## Out of Scope for Docker Work

- The Mac development build is unaffected by Docker changes.
- The Bazel linking investigation is independent of Docker.
- Production deployment images (the bot service) live in
  bridge-project, not here. This image is a *base* for those, not
  the final deliverable.