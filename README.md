# Midnight Podman Pod

Known-good, compatible set of midnight node, indexer, and proofserver executables packaged as a Podman pod for the mainnet, preprod, and preview networks.

## Compiling

| Component        | Version      | Repository                                                         |
|------------------|--------------|--------------------------------------------------------------------|
| midnight-node    | node-0.22.3  | https://github.com/midnightntwrk/mn4                              |
| midnight-indexer | v4.3.0       | https://github.com/midnight-ntwrk/midnight-indexer                 |
| midnight-ledger  | ledger-8.0.3 | https://github.com/midnight-ntwrk/midnight-ledger                  |
| partner-chains   | v1.8.1       | https://github.com/input-output-hk/partner-chains                  |

### midnight-node

The node requires patches to partner-chains to sync with preprod/mainnet (see [Patches](#patches) below). Apply patches first, then build:

```bash
cd partner-chains
git apply ../partner-chains.patch

cd ../midnight-node
git apply ../midnight-node.patch

cargo build --release -p midnight-node
```

### midnight-indexer

Inside `nix develop`, the standalone indexer builds with:

```bash
cd midnight-indexer
cargo build --release --features standalone
```

**Source patch required**: The v4.3.0 SPO indexer unconditionally requires a Blockfrost API key. We patch `indexer-standalone/src/main.rs` to skip the SPO task when `blockfrost_id` is empty, and add the missing `blockfrost_id` field to `indexer-standalone/config.yaml`. See `lessons-learned.md` for details.

### midnight-proof-server

Inside `nix develop`, the proof server builds with:

```bash
cd midnight-ledger
cargo build --release -p midnight-proof-server
```

## Patches

### partner-chains.patch

Midnight nodes fail to sync preprod/mainnet because `get_mc_state_reference` in `sidechain-mc-hash` rejects Cardano anchor blocks whose timestamps fall outside a strict stability window. Genesis-era Midnight blocks reference Cardano blocks that are too old for this window — a fixed property of the committed chain history.

The patch adds a hash-only fallback: if the strict timestamp-filtered lookup returns nothing but the block exists by hash, accept it and log a warning. Diagnostic `WARN` messages show the reference timestamp, stability window, actual block timestamp, and offset.

**Target**: `partner-chains` @ `v1.8.1` (checked out as a sibling directory)

### midnight-node.patch

Adds a `[patch]` section to `Cargo.toml` redirecting all `partner-chains` git dependencies to the local patched checkout, and updates `Cargo.lock` accordingly.

**Target**: `midnight-node` @ `node-0.22.3`

**Assumption**: `partner-chains/` is a sibling directory of `midnight-node/`.

### midnight-indexer.patch

Adds the missing `blockfrost_id` field to `config.yaml` and patches `main.rs` to skip the SPO indexer task when `blockfrost_id` is empty.

**Target**: `midnight-indexer` @ `v4.3.0`

## Running

### Node

Use `run-node.sh` to start a non-validating archive node on preprod.

```bash
bash run-node.sh
```

The node requires a Cardano db-sync PostgreSQL instance for partner-chains block validation. Set `DB_SYNC_POSTGRES_CONNECTION_STRING` in the script to point at your instance.

| Variable | Description |
|---|---|
| `CFG_PRESET` | Network preset (`preprod`, `preview`, `mainnet`) |
| `DB_SYNC_POSTGRES_CONNECTION_STRING` | PostgreSQL connection string for cardano-db-sync |
| `CARDANO_SECURITY_PARAMETER` | Cardano security parameter (432 for preprod/mainnet) |

Check the current block height:

```bash
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"chain_getHeader","params":[]}' \
  http://localhost:9944
```

The block number is in `result.number` (hex-encoded).

### Indexer

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

### Proof Server

Use `run-proofserver.sh` to start the proof server.

```bash
bash run-proofserver.sh
```

On first run, the server downloads zswap proving keys automatically. This can take a few minutes.

| Variable | Default | Description |
|---|---|---|
| `MIDNIGHT_PROOF_SERVER_PORT` | `6300` | HTTP listen port |
| `MIDNIGHT_PROOF_SERVER_NUM_WORKERS` | `2` | Parallel proof worker threads |
| `MIDNIGHT_PROOF_SERVER_JOB_TIMEOUT` | `600` | Job timeout in seconds |
| `MIDNIGHT_PROOF_SERVER_JOB_CAPACITY` | `0` | Job queue capacity (0 = unbounded) |
| `MIDNIGHT_PROOF_SERVER_NO_FETCH_PARAMS` | `false` | Skip downloading proving keys on startup |

## Health Check

The indexer exposes a readiness endpoint:

```bash
curl -s -o /dev/null -w '%{http_code}' http://localhost:8088/ready
```

- **200** -- the indexer has caught up with the node
- **503** -- the indexer is still syncing

The GraphQL API is available at `http://localhost:8088/api/v4/` (also aliased at `/api/v3/` for backwards compatibility).
