# Lessons Learned

## 2026-05-07

- **Project bootstrapped.** Repository initialized with a Nix flake providing `claude-code`, `gh`, and `rustup` in a Podman-based dev container.
- **midnight-indexer submodule** added at tag **v4.3.0**. It supports node versions 0.22.0 and 1.0.0-rc.3 (per `NODE_VERSIONS`).
- **Indexer has two deployment modes**: `cloud` (PostgreSQL + NATS, microservices) and `standalone` (SQLite, single binary). For local dev/testing, `standalone` is simpler. For the final pod, `cloud` mode with separate containers is the target.
- **No default Cargo feature** in the indexer -- must always pass `--features cloud` or `--features standalone`, otherwise the build will fail.
