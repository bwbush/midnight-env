# Midnight Podman Pod

Known-good, compatible set of midnight node, indexer, and proofserver executables packaged as a Podman pod for the mainnet, preprod, and preview networks.

## Official Docker Images (Recommended)

The official Midnight Docker images work without patches when using the correct `CARDANO_SECURITY_PARAMETER=2160` and the versions from the [compatibility matrix](https://docs.midnight.network/relnotes/support-matrix).

| Network  | Node               | Indexer                      | Proof Server                    |
|----------|--------------------|------------------------------|---------------------------------|
| mainnet  | `midnight-node:0.22.1` | `indexer-standalone:4.0.1` | `proof-server:8.0.3`           |
| preprod  | `midnight-node:0.22.2` | `indexer-standalone:4.0.1` | `proof-server:8.0.3`           |
| preview  | `midnight-node:0.22.5` | `indexer-standalone:4.0.2` | `proof-server:8.0.3`           |

All images are on `docker.io/midnightntwrk/`.

### Pod YAML Files

| File | Network | Host Ports (RPC / Indexer API / P2P / Prometheus / Proofserver) |
|------|---------|----------------------------------------------------------------|
| `midnight-mainnet.yaml` | mainnet | 9945 / 8089 / 30334 / 9616 / 6301 |
| `midnight-preprod.yaml` | preprod | 9946 / 8090 / 30335 / 9617 / 6302 |

Each pod runs three containers (node, indexer, proofserver) sharing a `/data` volume. The node and indexer communicate over `ws://localhost:9944` within the pod.

```bash
# Start
podman kube play midnight-preprod.yaml

# Stop
podman kube down midnight-preprod.yaml

# Logs
podman pod logs --follow midnight-preprod
```

Prerequisites:
- A Cardano db-sync PostgreSQL instance (update `DB_SYNC_POSTGRES_CONNECTION_STRING` in each YAML)
- Host data directory created: `mkdir -p preprod` / `mkdir -p mainnet`

## Compiling from Source

For building from source (e.g., for custom patches or development):

| Component        | Version      | Repository                                                         |
|------------------|--------------|--------------------------------------------------------------------|
| midnight-node    | node-0.22.5  | https://github.com/midnightntwrk/mn4                              |
| midnight-indexer | v4.3.0       | https://github.com/midnight-ntwrk/midnight-indexer                 |
| midnight-ledger  | ledger-8.0.3 | https://github.com/midnight-ntwrk/midnight-ledger                  |
| partner-chains   | v1.8.1       | https://github.com/input-output-hk/partner-chains                  |

### midnight-node

```bash
cd midnight-node
cargo build --release -p midnight-node
```

### midnight-indexer

```bash
cd midnight-indexer
cargo build --release --features standalone
```

### midnight-proof-server

```bash
cd midnight-ledger
cargo build --release -p midnight-proof-server
```


## Running from Source

### Node

Use `run-node.sh` to start a non-validating archive node on preprod.

```bash
bash run-node.sh
```

The node stores chain data in `/data/midnight/preprod/`. It requires a Cardano db-sync PostgreSQL instance for partner-chains block validation.

| Variable | Description |
|---|---|
| `CFG_PRESET` | Network preset (`preprod`, `preview`, `mainnet`) |
| `DB_SYNC_POSTGRES_CONNECTION_STRING` | PostgreSQL connection string for cardano-db-sync |
| `CARDANO_SECURITY_PARAMETER` | Cardano security parameter (`2160` for preprod/mainnet) |

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

When running against a local node, point the indexer at `ws://localhost:9944`. The indexer stores its SQLite databases alongside the node data in `/data/midnight/preprod/`.

Public RPC endpoints (for running without a local node) use `wss://` (TLS, port 443):
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
