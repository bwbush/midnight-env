#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

export MIDNIGHT_PROOF_SERVER_PORT="6300"
export MIDNIGHT_PROOF_SERVER_NUM_WORKERS="2"
export MIDNIGHT_PROOF_SERVER_JOB_TIMEOUT="600"
export MIDNIGHT_PROOF_SERVER_JOB_CAPACITY="0"

export RUST_LOG="info"

exec "$REPO_ROOT/midnight-ledger/target/release/midnight-proof-server"
