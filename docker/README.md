# DDS Docker Image

Pre-built Double Dummy Solver library for Linux CI environments.

## Usage in GHA

In dds-adapter CI, use as a container for test jobs:

```yaml
name: Test with DDS

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/dds-bridge/dds:1.0.0
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
      - run: npm install
      - run: npm run build:native
      - run: npm test
```

## Image Contents

- **libdds.a** — DDS static library at `/usr/local/lib/libdds.a`
- **Headers** — DDS headers at `/usr/local/include/dds/`
- **Build tools** — gcc, g++, build-essential, libomp-dev
- **Bazel** — for reproducible builds

## Image Tags

- `ghcr.io/dds-bridge/dds:<version>-<sha>` — exact pin (use this in CI)
- `ghcr.io/dds-bridge/dds:<version>` — version tag
- `ghcr.io/dds-bridge/dds:latest` — latest blessed build

## Building Locally

```bash
docker build -t dds:local docker/
docker run -it --rm dds:local bash
```

## What's NOT Included

- dds-adapter source (mount at runtime)
- Application code or bot logic
- Production deployment setup

This image is for testing only. Production images live in bridge-project.
