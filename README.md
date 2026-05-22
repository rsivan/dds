## Introduction to DDS3

DDS3 is a double dummy solver for bridge hands. It is a drop-in replacement for DDS 2.9.0 which has been the leading solver for many years, based on the initial work of Bo Haglund in 2006 and the previous modernisation by Søren Hein in 2014.  With Søren's encouragement, I have updated the official release in order to retain continuity for the user base, and I have been added as an administrator.

DDS3 is a double dummy solver for bridge hands. Version 3.0 uses the same
search algorithm as version 2.x, but the source code has been modernised. The
project has been split into several subcomponents, each responsible for a
specific part of the search algorithm. This modularisation makes the codebase
easier to read and reason about, which helps not only humans but also modern
coding agents. Throughout the codebase, you will find evidence that Claude
Code and GitHub Copilot have made significant contributions to the
modernisation.

There are build scripts for macOS, Linux, and Windows but I have myself only used the library on macOS.

Plenty people like to use a double dummy solver for statistical analysis, typically in Python. I have added barebone Python interface to the solver.

### Motivation for creating version 3

I wanted to use DDS 2.9.0 for training declarer models, but memory management
prevented me from solving several hands in parallel while also preserving the
transposition table. Preserving the table is required when making repeated
calls for the same hand while training a declarer model against double-dummy
perfect defenders.

To address these issues, and also take advantage of modern C++ features, I had to update the project to a more modular build structure. This allowed me to create a library with dynamic memory management.

Martin Nygren, May 2026

## Version 3.0 Documentation

[C++ Interface](docs/c++_interface.md)

[Python Interface](docs/python_interface.md)

[Legacy C Interface](docs/legacy_c_api.md)

[Migrating to the modern API](docs/api_migration.md)

[Notes about the buidl system](docs/BUILD_SYSTEM.md)


## Version 3.0 Release Status

Current baseline for this branch:

- C++ toolchain uses `bazel-contrib/toolchains_llvm` pinned to LLVM 20.1.8 for
    `darwin-aarch64` and LLVM 21.1.8 for `linux-x86_64`.
- Full non-ASAN validation passes with `bazelisk test //...`.
- Doxygen docs target is available as a manual developer target (`//:doxygen_docs`)
    and requires `doxygen` and `zip` on `PATH`.

## 2.9 Documentation

You can find the original [README](doc/README_2_9_0.md) and descriptions of the search algorithm in the doc folder.

---

# Docker Image — Local Usage

The DDS Docker image is built and published by the [DDS fork repo](https://github.com/rsivan/dds) and serves three purposes:

1. **CI** — adapter (and related) tests run inside it via GitHub Actions
2. **Local CI-parity verification** — reproduce CI behavior on your laptop
3. **Future production deployment** — base layer for the bot service image

The image is published to GitHub Container Registry at `ghcr.io/rsivan/dds`.

> **Note on Mac performance**: The image is `linux/amd64`. On Apple Silicon (M-series) Macs, it runs under Docker Desktop's emulation, which is meaningfully slower than native. Use it for verification and debugging — not for daily development. Daily Mac development continues to use the locally-built native DDS.

---

## Prerequisites

### Docker Desktop

Install Docker Desktop from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) if you don't have it.

Verify it's installed and running:

```bash
docker version
```

If the command errors, start Docker Desktop from Applications and wait a few seconds before retrying.

### GHCR Authentication (only if the package is private)

GitHub Container Registry requires authentication for private packages. The DDS image is open source and **should be made public** on its GHCR settings page — if it is, you can skip this section.

If the package is private, create a Personal Access Token:

1. Go to https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Check the `read:packages` scope
4. Generate and copy the token immediately (it won't be shown again)

Then authenticate Docker to GHCR:

```bash
echo "<your-pat>" | docker login ghcr.io -u <your-github-username> --password-stdin
```

You should see `Login Succeeded`.

---

## Use Case 1: Pull and Run the Published Image

This is the **common case** — you want to use the image as CI does, without modifying it.

### Check what's published

Before pulling, see what tags are available:

- Web UI: https://github.com/rsivan?tab=packages — click the `dds` package
- Or via CLI:

  ```bash
  docker search ghcr.io/rsivan/dds
  ```

Tags produced by the DDS fork's publish workflow:

| Tag pattern              | Meaning                                      | Use for             |
|--------------------------|----------------------------------------------|---------------------|
| `image-v<version>`       | Deliberate release, triggered by git tag     | Manual exploration  |
| `sha-<short-sha>`        | Exact commit pin                             | CI pinning          |
| `latest`                 | Most recent build on default branch          | Quick local testing |

### Pull the image

```bash
docker pull ghcr.io/rsivan/dds:latest
```

First pull downloads several hundred MB. Subsequent pulls use Docker's layer cache.

For exact pinning (matches what CI uses):

```bash
docker pull ghcr.io/rsivan/dds:sha-abc1234
```

Or, on Arm64:

```bash
docker pull --platform linux/amd64 ghcr.io/rsivan/dds:latest
```

### Run interactively to explore

```bash
docker run --rm -it ghcr.io/rsivan/dds:latest bash
```

Or, on Arm64:

```bash
docker run --rm -it --platform linux/amd64 ghcr.io/rsivan/dds:latest bash
```

Flags:
- `--rm` — delete the container when you exit
- `-it` — interactive terminal
- `bash` — shell to run inside

Once inside, verify DDS is installed:

```bash
ls /usr/local/lib/libdds*       # libdds.a (static library)
ls /usr/local/include/dds       # DDS headers
which g++                       # C++ compiler
```

Type `exit` to leave the container.

---

## Use Case 2: Build the Image Locally from the Dockerfile

This is the **uncommon case** — you only need it when modifying the Dockerfile itself in the DDS fork.

### When to use this

- Iterating on the Dockerfile (adding packages, changing base image, optimizing layers)
- Testing Dockerfile changes before pushing
- Debugging a failed image build in CI

If you're not changing the Dockerfile, use Use Case 1 instead.

### Build the image

> **Note for Mac users**: Building locally in Docker does not work on Apple Silicon due to Bazel binary incompatibility with emulation. Use the native Bazel build instead (`CXX=/opt/homebrew/bin/g++-15 CC=/opt/homebrew/bin/gcc-15 bazel build //library/src:dds`). The Docker image is intended for CI and Linux users.

The image uses a **multi-stage build** to minimize size:
- **Builder stage** (ubuntu:24.04): Compiles DDS with Bazel, keeps build tools
- **Runtime stage** (node:24-slim): Copies only compiled artifacts + headers, installs minimal runtime deps (libstdc++6, libgomp1) + build tools needed for N-API binding compilation (python3, make, g++)
- **Result** (before adding tools): ~570 MB (reduced from ~1.5 GB), fits on GHA runners
- **Result** (with tools added): ~790 MB (reduced from ~1.5 GB), fits on GHA runners

> **Why all .a files?** Bazel's build system automatically links transitive dependencies when compiling within Bazel. However, when libdds.a is extracted as a standalone artifact (as happens in Docker), it contains undefined symbols that need to be resolved by transitive libraries (libconstants.a, libsystem.a, etc.). All .a files are copied to `/usr/local/lib` so dds-adapter's native binding can link against them all.

```bash
cd ~/GitHub/dds
docker build -f docker/Dockerfile -t dds:local .
```

Flags:
- `-f docker/Dockerfile` — path to the Dockerfile
- `-t dds:local` — tag the resulting image (any name works; `dds:local` is a convention to distinguish from published images)
- `.` — build context (everything Docker can `COPY` from)

First build is slow — DDS compiles from scratch (a few minutes). Subsequent builds use Docker's layer cache; only layers affected by your changes rebuild.

### Run the locally-built image

Same commands as Use Case 1, but with the local tag:

```bash
docker run --rm -it -v "$PWD:/work" -w /work dds:local bash
```

### Iteration tips

- **Order layers from least-changing to most-changing** in the Dockerfile. Layers after the first change rebuild; layers before it are cached. Put apt installs early, source copying late.
- **Use `--no-cache` to force a fresh build** when you suspect cache poisoning:
  ```bash
  docker build --no-cache -f docker/Dockerfile -t dds:local .
  ```
- **Inspect intermediate layers** if a build fails. Each successful step prints a hash; you can `docker run --rm -it <hash> bash` to poke around.
- **Clean up old images** occasionally to reclaim disk:
  ```bash
  docker images           # see what's taking space
  docker image prune      # remove dangling images
  ```

---

## Triggering a Fresh Image Build (No Local Build Needed)

If you don't need to build locally but need a newer published image:

### Via tag push (recommended for releases)

```bash
cd ~/GitHub/dds
git tag image-v0.1.1
git push origin image-v0.1.1
```

This triggers the publish workflow and produces a new `image-v0.1.1` tag in GHCR.

### Via manual workflow dispatch

1. Go to https://github.com/rsivan/dds/actions/workflows/docker-image.yml
2. Click **Run workflow** → select branch → **Run workflow**
3. Wait a few minutes for completion
4. New image tagged with the commit SHA appears in GHCR

---

## Troubleshooting

### `docker: command not found`

Docker Desktop isn't installed. See Prerequisites.

### `Cannot connect to the Docker daemon`

Docker Desktop is installed but not running. Start it from Applications.

### `denied: requested access to the resource is denied`

You're pulling a private image without authentication. Either:
- Make the package public on GHCR, OR
- Authenticate via `docker login ghcr.io` with a PAT that has `read:packages`

### `WARNING: The requested image's platform (linux/amd64) does not match the detected host platform`

Expected on Apple Silicon. The image runs under emulation. Performance is slower but functionality is unaffected.

### Tests pass locally but fail in CI (or vice versa)

Check that the image tag matches. CI pins to a specific SHA tag; if you're pulling `latest` locally, you may be running a different image. Pull the exact same tag CI uses:

```bash
# Check the CI workflow for the pinned tag
grep "image:" .github/workflows/ci.dds.yml

# Pull that exact tag
docker pull ghcr.io/rsivan/dds:sha-<that-sha>
```

### Mounted file changes don't appear in the container

On macOS, file watchers across the Docker mount boundary can be unreliable. Restart the container if files seem stale. Avoid using mounted volumes for tools that rely on `inotify` (typical Node test watchers, etc.).

---

## Summary

| Task                                              | Command                                                              |
|---------------------------------------------------|----------------------------------------------------------------------|
| Verify Docker is installed                        | `docker version`                                                     |
| Authenticate to GHCR (if private)                 | `docker login ghcr.io -u <user>`                                     |
| Pull the published image                          | `docker pull ghcr.io/rsivan/dds:latest`                              |
| Run interactively                                 | `docker run --rm -it ghcr.io/rsivan/dds:latest bash`                 |
| Build image locally from Dockerfile               | `docker build -f docker/Dockerfile -t dds:local .` (Linux only)      |
| Trigger fresh published build (via tag)           | `git tag image-v<n> && git push origin image-v<n>`                   |
