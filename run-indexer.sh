#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Figment config: APP__ prefix, __ splits into nesting levels.
# Use single _ for underscores within field names (e.g., network_id, cnn_url).
export APP__APPLICATION__NETWORK_ID="preprod"
export APP__INFRA__STORAGE__CNN_URL="/data/midnight/preprod/indexer.sqlite"
export APP__INFRA__LEDGER_DB__CNN_URL="/data/midnight/preprod/ledger-db.sqlite"
export APP__INFRA__NODE__URL="ws://localhost:9944"
export APP__INFRA__SPO_NODE__URL="ws://localhost:9944"
export APP__INFRA__SPO_NODE__BLOCKFROST_ID=""
export APP__INFRA__API__PORT="8088"
export APP__INFRA__SECRET="0a0076255e6b232f8656cb3f2516a16680639eb3dc4589cc12b090a1496131d7"

export RUST_LOG="indexer=info,chain_indexer=info,indexer_api=info,wallet_indexer=info,indexer_common=info,fastrace_opentelemetry=info,info"

mkdir -p $REPO_ROOT

cd "$REPO_ROOT/midnight-indexer/indexer-standalone"
exec "$REPO_ROOT/midnight-indexer/target/release/indexer-standalone"
