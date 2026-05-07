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
- **midnight-proof-server (ledger-8.0.3) works out of the box** -- no source patches needed. Builds with `cargo build --release -p midnight-proof-server` in the midnight-ledger repo. Configured entirely via env vars / CLI args (clap). Downloads zswap proving keys on first run.
- ~~**midnight-node requires partner-chains patch for preprod/mainnet sync**: Block verification fails at genesis due to a timestamp-window check in `sidechain-mc-hash`.~~ The patch is **not needed** when using `CARDANO_SECURITY_PARAMETER=2160` (the correct upstream value from `res/cfg/preprod.toml` and `pc-chain-config.json`). The previous value of 432 was incorrect and narrowed the timestamp window to ~7.2h, too small for the ~0.6d genesis-era offset. With 2160, the window is 3k/f = 129600s = 1.5 days, which covers the offset. The patches are retained for reference.

> [!NOTE]
> 2026-05-07: Root cause identified. The upstream configs specify `cardano_security_parameter = 2160`. The value 432 was likely confused with `432000000` (epoch duration in milliseconds). Using 2160 eliminates the need for partner-chains patches entirely.

- **Official Docker images work without patches**: `midnightntwrk/midnight-node`, `midnightntwrk/indexer-standalone`, and `midnightntwrk/proof-server` on Docker Hub work correctly with proper configuration. No source patches needed.
- **Compatibility matrix**: Different networks require different node versions. Mainnet = 0.22.1, preprod = 0.22.2, preview = 0.22.5. Using the wrong version (e.g., 0.22.5 on mainnet) causes 0.0 bps sync failure. Check https://docs.midnight.network/relnotes/support-matrix for current versions.
- **Node must run from its repo directory** (when building from source): The node reads `res/cfg/default.toml` relative to CWD. The run script must `cd` into the midnight-node directory before exec. The official Docker images have `res/` baked in at `/res/`.
- **Pod YAML files**: `midnight-mainnet.yaml` and `midnight-preprod.yaml` define complete pods with node + indexer + proofserver. Each pod shares a `/data` volume. The node and indexer communicate via `ws://localhost:9944` within the pod. Host ports are offset to avoid conflicts when running multiple networks simultaneously.
