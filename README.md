# Midnight Podman Pod

Known-good, compatible set of midnight node, indexer, and proofserver executables packaged as a Podman pod for the mainnet, preprod, and preview networks.

## Compiling

| Component        | Version | Repository                                                             |
|------------------|---------|------------------------------------------------------------------------|
| midnight-indexer | v4.3.0  | https://github.com/midnight-ntwrk/midnight-indexer                     |

### midnight-indexer

Inside `nix develop`, the standalone indexer builds with:

```bash
cargo build --release --features standalone
```
