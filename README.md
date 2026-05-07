# Midnight Podman Pod

Known-good, compatible set of midnight node, indexer, and proofserver executables packaged as a Podman pod for the mainnet, preprod, and preview networks.

## Compiling

| Component        | Version | Repository                                                             |
|------------------|---------|------------------------------------------------------------------------|
| midnight-indexer | v4.3.0  | https://github.com/midnight-ntwrk/midnight-indexer                     |

### midnight-indexer

Inside `nix develop`, the standalone indexer builds with:

```bash
cd midnight-indexer
cargo build --release --features standalone
```

**Source patch required**: The v4.3.0 SPO indexer unconditionally requires a Blockfrost API key. We patch `indexer-standalone/src/main.rs` to skip the SPO task when `blockfrost_id` is empty, and add the missing `blockfrost_id` field to `indexer-standalone/config.yaml`. See `lessons-learned.md` for details.

## Running

Use `run-indexer.sh` to start the standalone indexer against a network. The script configures the indexer via environment variables using the figment convention (`APP__` prefix, `__` for nesting, `_` for underscores within field names).

```bash
bash run-indexer.sh
```

Key environment variables (set in the script):

| Variable | Description |
|---|---|
| `APP__APPLICATION__NETWORK_ID` | Network to index (`preprod`, `preview`, or `mainnet`) |
| `APP__INFRA__NODE__URL` | WebSocket URL of the Midnight node RPC |
| `APP__INFRA__STORAGE__CNN_URL` | Path to the main SQLite database |
| `APP__INFRA__LEDGER_DB__CNN_URL` | Path to the ledger SQLite database |
| `APP__INFRA__API__PORT` | GraphQL API listen port (default `8088`) |
| `APP__INFRA__SECRET` | Secret key for wallet session encryption |
| `APP__INFRA__SPO_NODE__BLOCKFROST_ID` | Blockfrost project ID (leave empty to disable SPO indexer) |

Public RPC endpoints use `wss://` (TLS, port 443):
- preprod: `wss://rpc.preprod.midnight.network`
- preview: `wss://rpc.preview.midnight.network`
- mainnet: `wss://rpc.midnight.network`

## Health Check

The indexer exposes a readiness endpoint:

```bash
curl -s -o /dev/null -w '%{http_code}' http://localhost:8088/ready
```

- **200** -- the indexer has caught up with the node
- **503** -- the indexer is still syncing

The GraphQL API is available at `http://localhost:8088/api/v4/` (also aliased at `/api/v3/` for backwards compatibility).
