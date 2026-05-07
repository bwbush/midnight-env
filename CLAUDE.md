# CLAUDE.md

## Project Goal

Curate a known-good, compatible set of **midnight node**, **indexer**, and **proofserver** executables, packaged as a Podman pod for the **mainnet**, **preprod**, and **preview** networks on the Midnight blockchain.

## Strategy

1. Get executables compiled, configured, and running inside the `nix develop` environment.
2. Package them as Podman container images and a pod Kube YAML file.

## Environment

- Running inside a `nix develop` shell within a Podman container.
- **Safe to run commands without asking for permission** -- the environment is ephemeral and sandboxed.
- Nix flake provides: `claude-code`, `gh`, `rustup`.
- Dev shell script: `dev-env.sh` (auto-generated nix shell env, do not edit).

## Repository Structure

- `flake.nix` -- Nix dev shell definition.
- `midnight-indexer/` -- Git submodule (currently at **v4.3.0**, tag `cf55cb9`). Rust workspace with `cloud` and `standalone` feature flags. See `midnight-indexer/CLAUDE.md` for its own build instructions.

## Submodule: midnight-indexer

- Two deployment modes: `cloud` (PostgreSQL + NATS) and `standalone` (SQLite + in-memory channels).
- Build/test with `just` recipes (e.g., `just check`, `just test`, `just all`).
- Always pass `--features cloud` or `--features standalone` -- no default feature.
- Supported node versions: see `midnight-indexer/NODE_VERSIONS` (currently 0.22.0, 1.0.0-rc.3).

## Target Components

| Component    | Source                          | Notes                        |
|--------------|---------------------------------|------------------------------|
| Node         | Midnight node binary            | Per-network chain spec       |
| Indexer      | `midnight-indexer/` submodule   | Standalone or cloud mode     |
| Proofserver  | Midnight proof server binary    | ZK proof verification        |

## Target Networks

- **mainnet** -- production network
- **preprod** -- pre-production testing
- **preview** -- early feature preview

## Conventions

- Keep a lessons-learned log in `lessons-learned.md` (date entries at H2 level, append new lessons, use `> [!NOTE]` for updates to old entries, strikeout where appropriate).
- Prefer simple, working configurations over clever ones.
- Pin exact versions/tags for reproducibility.
- Test each component individually in nix before containerizing.
