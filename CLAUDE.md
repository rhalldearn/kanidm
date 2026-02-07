# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kanidm is an identity management (IDM) platform written in Rust. It provides authentication and identity management via OAuth2/OIDC, LDAP, RADIUS, and Unix integration (PAM/NSS). The repository is a Cargo workspace monorepo with ~40 crates.

## Build Commands

**Prerequisites:** clang, lld, and platform-specific dev libraries are required. On Ubuntu: `sudo apt-get install libudev-dev libssl-dev libsystemd-dev pkg-config libpam0g-dev clang lld`

The project uses clang+lld instead of gcc+ld (configured in `.cargo/config.toml`) for faster linking and lower memory usage.

```bash
cargo build                    # Build everything
cargo test                     # Run all tests
cargo fmt --check              # Check formatting
cargo clippy                   # Lint (strict rules, see below)
```

### Running a Dev Server

```bash
cd server/daemon
./run_insecure_dev_server.sh                    # Start server on https://localhost:8443
./run_insecure_dev_server.sh recover-account admin  # Generate admin password
```

Data goes to `/tmp/kanidm/`. Self-signed certs are auto-generated.

### Running a Single Test

```bash
cargo test -p <crate_name> <test_name>          # Run specific test in a crate
cargo test -p kanidmd_lib <test_name>           # Example: test in server lib
```

### Other Useful Commands

```bash
make precommit                 # Run tests + codespell + python tests + doc format check
make codespell                 # Spell check
make doc/format                # Check markdown formatting (uses deno fmt)
make doc/format/fix            # Fix markdown formatting
make eslint                    # Lint Web UI JavaScript
make prettier                  # Check JS formatting
cargo install --path tools/cli --force  # Install CLI tool locally
```

## Architecture

### Core Crate Hierarchy

```
server/daemon (kanidmd binary)
  └── server/core (HTTP/LDAP handlers, Web UI, Axum routes, Askama templates)
        └── server/lib (kanidmd_lib - core logic: database, auth, IDM, plugins, replication)
              └── proto (kanidm_proto - protocol types, serde definitions)
```

- **server/lib** (`kanidmd_lib`): The heart of the system. Contains the backend (SQLite via rusqlite), identity management logic (`idm/`), access controls, credentials (WebAuthn, passwords, passkeys), plugins, replication, and schema/migrations.
- **server/core** (`kanidmd_core`): Web layer using Axum. Handles HTTPS, LDAP, OAuth2/OIDC endpoints, and the Web UI (Askama HTML templates + static JS).
- **server/daemon**: The `kanidmd` binary entry point. Parses config, starts the server.
- **proto** (`kanidm_proto`): Shared protocol/API types used by both server and client.

### Client & Tools

- **libs/client** (`kanidm_client`): Rust client SDK for talking to the server.
- **tools/cli** (`kanidm_tools`): The `kanidm` CLI binary.
- **tools/orca**: Load testing / benchmarking tool.
- **tools/iam_migrations/**: Migration tools from FreeIPA and LDAP.

### Unix Integration

- **unix_integration/resolver**: The `kanidm_unixd` daemon for Unix auth.
- **unix_integration/pam_kanidm**: PAM module (C ABI shared library).
- **unix_integration/nss_kanidm**: NSS module (C ABI shared library).

### Supporting Libraries

- **libs/crypto**: Cryptographic utilities.
- **libs/sketching**: Tracing/logging setup.
- **libs/profiles**: Build profile configurations (dev, release, container).
- **libs/scim_proto**: SCIM protocol definitions.

### Build Profiles

The `KANIDM_BUILD_PROFILE` environment variable selects a profile from `libs/profiles/`. The default "developer" profile uses paths relative to the monorepo. Release profiles (e.g., `release_linux`, `container_generic`) configure paths for installed deployments.

## Code Conventions and Constraints

### Clippy Rules (clippy.toml)

These are enforced and will cause CI failures:

- **No `std::collections::HashMap` or `std::collections::HashSet`** — use the project's custom replacements.
- **No `time::OffsetDateTime::now_utc()`** — time is passed as a parameter for testability.
- **No `std::thread::sleep()`** — time is a controlled parameter; sleeping blocks async threads.
- `unwrap()`, `expect()`, `panic!()`, `dbg!()`, and indexing/slicing are **only allowed in tests**.
- `too-many-arguments-threshold = 8`, `type-complexity-threshold = 300`.

### Testing Principles

- `git clone && cargo test` must always work with zero external dependencies.
- No external databases or services required for tests.
- The full stack is tested: database, server logic, client, and protocol.
- Server testkit (`server/testkit/`) provides test harness utilities.

### Web UI

JavaScript/CSS lives in `server/core/static/`. Templates are Askama (`.html` files in `server/core/templates/`). ESLint and Prettier are configured via `server/core/`. Run `make eslint` and `make prettier` for JS quality checks.
