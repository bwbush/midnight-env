# Lessons Learned

## 2026-05-07

- **Project bootstrapped.** Repository initialized with a Nix flake providing `claude-code`, `gh`, and `rustup` in a Podman-based dev container.
- **midnight-indexer submodule** added at tag **v4.3.0**. It supports node versions 0.22.0 and 1.0.0-rc.3 (per `NODE_VERSIONS`).
- **Indexer has two deployment modes**: `cloud` (PostgreSQL + NATS, microservices) and `standalone` (SQLite, single binary). For local dev/testing, `standalone` is simpler. For the final pod, `cloud` mode with separate containers is the target.
- **No default Cargo feature** in the indexer -- must always pass `--features cloud` or `--features standalone`, otherwise the build will fail.
- **Figment config env var naming**: The indexer uses figment with `APP__` prefix and `__` as the nesting separator. Single `_` represents an underscore within a field name. E.g., `APP__INFRA__SPO_NODE__CNN_URL` maps to `infra.spo_node.cnn_url`. Getting this wrong silently creates wrong nesting instead of overriding the intended field.
- **config.yaml must contain all required fields**: Figment's env overlay cannot add fields that are entirely absent from the YAML. The shipped `config.yaml` at v4.3.0 is missing `blockfrost_id` under `spo_node` -- it must be added manually.
- **SQLite file ownership**: When running outside containers, the SQLite database files may be owned by a different UID (e.g., 160000 from a previous container run). `sudo chown` is needed before the indexer can open them.
- **SPO indexer requires Blockfrost API key**: The `spo-indexer` component needs a real Blockfrost project ID (from blockfrost.io) and will fail immediately with an empty string. We patched `main.rs` to skip SPO when `blockfrost_id` is empty (parks the task with `pending()`). The source patch was unavoidable: `spo_node_config` is not `Option`, `blockfrost_id` is a required `String`, and the SPO task is unconditionally spawned in `select!`. No env-var-only workaround exists.
- **SPO indexer is not needed for a full indexer**: SPO tracks Stake Pool Operator registrations, committee membership, and pool metadata via Cardano L1 (Blockfrost). Chain-indexer, wallet-indexer, and indexer-api handle blocks, transactions, contracts, and wallets independently.
- **Cannot compile Rust inside the claude container**: The `nix develop` shell inside the podman container is missing `collect2`/`posix_spawnp` for linking. Cargo builds must be run from the host (`/scratch/iohk/midnight-env/`), not from the container's `/work` mount.
- **Public RPC endpoints use `wss://` on port 443**, not `ws://` on port 9944. Port 9944 is for local/private nodes. Correct URL format: `wss://rpc.preprod.midnight.network` (no port needed, defaults to 443).
