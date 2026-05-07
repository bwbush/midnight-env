#!/usr/bin/env bash
# make-patches.sh - Regenerate midnight-node and partner-chains patches
#
# Usage: ./make-patches.sh [NODE_TAG] [NODE_DIR] [PC_DIR]
#
#   NODE_TAG  midnight-node git tag         (default: node-0.22.5)
#   NODE_DIR  path to midnight-node repo    (default: /extra/iohk/midnight-node)
#   PC_DIR    path to partner-chains repo   (default: /extra/iohk/partner-chains)
#
# WHY THIS FIX EXISTS
# -------------------
# Midnight nodes fail to sync because get_mc_state_reference rejects Cardano blocks
# whose wall-clock timestamp falls outside a derived "expected window" relative to
# the Midnight slot clock.  This window check is too strict for genesis / early blocks
# on mainnet and preprod (observed with partner-chains v1.8.1).
#
# The fix (partner-chains.patch) bypasses the window check with a fallback: if the
# strict lookup returns nothing but the block exists by hash, accept it and log a
# warning.  A matching diagnostic was added to the db-sync data source.
#
# Because partner-chains is a git dependency of midnight-node, the fix is applied to
# a local partner-chains checkout and midnight-node's Cargo files are patched to
# redirect all partner-chains crates to that local copy (midnight-node.patch).
#
# UPGRADING TO A NEW MIDNIGHT-NODE VERSION
# ----------------------------------------
# 1. Run: ./make-patches.sh node-X.Y.Z
# 2. If partner-chains tag unchanged → partner-chains.patch is identical; only
#    midnight-node.patch changes (new Cargo.lock blob hash).
# 3. If partner-chains tag changed → the script will fail with a clear message;
#    you must manually port the fix to the new partner-chains version, update the
#    source files, then re-run the script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODE_TAG="${1:-node-0.22.5}"
NODE_DIR="${2:-/extra/iohk/midnight-node}"
PC_DIR="${3:-/extra/iohk/partner-chains}"

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "--- $*"; }

# ── 1. Prepare midnight-node at target tag ────────────────────────────────────
info "Resetting midnight-node to $NODE_TAG"
cd "$NODE_DIR"
[[ -d .git ]] || die "$NODE_DIR is not a git repository"

git stash --include-untracked --quiet 2>/dev/null || true
git checkout "$NODE_TAG" --quiet 2>/dev/null \
    || git checkout "refs/tags/$NODE_TAG" --quiet \
    || die "Cannot checkout $NODE_TAG in $NODE_DIR"

info "midnight-node at $(git describe --tags HEAD 2>/dev/null || git rev-parse --short HEAD)"

# ── 2. Extract partner-chains dependency tag ──────────────────────────────────
PC_TAG=$(python3 - <<'PYEOF'
import re, sys
with open("Cargo.toml") as f:
    content = f.read()
# Match either  tag = "v1.x.y"  inside a partner-chains git dependency
m = re.search(
    r'git\s*=\s*"https://github\.com/input-output-hk/partner-chains"[^}]*?'
    r'tag\s*=\s*"([^"]+)"',
    content, re.DOTALL
)
if not m:
    sys.exit("Cannot find partner-chains tag in Cargo.toml")
print(m.group(1))
PYEOF
)
info "partner-chains dependency: $PC_TAG"

# ── 3. Prepare partner-chains: checkout tag and apply fix ─────────────────────
info "Preparing partner-chains at $PC_TAG"
cd "$PC_DIR"
[[ -d .git ]] || die "$PC_DIR is not a git repository"

git stash --include-untracked --quiet 2>/dev/null || true
git checkout "$PC_TAG" --quiet || die "Cannot checkout $PC_TAG in $PC_DIR"

if git diff --quiet; then
    info "Applying timestamp-window bypass fix to partner-chains..."
    if git apply --check "$SCRIPT_DIR/partner-chains.patch" 2>/dev/null; then
        git apply "$SCRIPT_DIR/partner-chains.patch"
    else
        die "partner-chains.patch does not apply cleanly to $PC_TAG.
partner-chains may have been updated.  Port the fix manually to the new version:
  toolkit/data-sources/db-sync/src/block/mod.rs  (timestamp-window logging + fallback)
  toolkit/sidechain/sidechain-mc-hash/Cargo.toml (add log dep)
  toolkit/sidechain/sidechain-mc-hash/src/lib.rs  (get_mc_state_reference fallback)
Then re-run this script."
    fi
else
    info "partner-chains already modified (patch in effect)"
fi

# Regenerate partner-chains.patch from current working tree
git diff > "$SCRIPT_DIR/partner-chains.patch"
info "partner-chains.patch: $(git diff --stat | tail -1)"

# ── 4. Modify midnight-node Cargo.toml (add [patch] section) ─────────────────
info "Modifying midnight-node Cargo files"
cd "$NODE_DIR"

python3 - "$PC_TAG" <<'PYEOF'
import sys

pc_tag = sys.argv[1]

PATCH_BLOCK = """\
[patch."https://github.com/input-output-hk/partner-chains"]
ariadne-simulator = { path = "../partner-chains/toolkit/committee-selection/selection-simulator" }
authority-selection-inherents = { path = "../partner-chains/toolkit/committee-selection/authority-selection-inherents" }
byte-string-derive = { path = "../partner-chains/toolkit/utils/byte-string-derivation" }
cli-commands = { path = "../partner-chains/toolkit/cli/commands" }
db-sync-sqlx = { path = "../partner-chains/toolkit/utils/db-sync-sqlx" }
ogmios-client = { path = "../partner-chains/toolkit/utils/ogmios-client" }
pallet-address-associations = { path = "../partner-chains/toolkit/address-associations/pallet" }
pallet-block-participation = { path = "../partner-chains/toolkit/block-participation/pallet" }
pallet-block-producer-fees = { path = "../partner-chains/toolkit/block-producer-fees/pallet" }
pallet-block-producer-fees-rpc = { path = "../partner-chains/toolkit/block-producer-fees/rpc" }
pallet-block-producer-metadata = { path = "../partner-chains/toolkit/block-producer-metadata/pallet" }
pallet-block-producer-metadata-rpc = { path = "../partner-chains/toolkit/block-producer-metadata/rpc" }
pallet-block-production-log = { path = "../partner-chains/toolkit/block-production-log/pallet" }
pallet-governed-map = { path = "../partner-chains/toolkit/governed-map/pallet" }
pallet-partner-chains-bridge = { path = "../partner-chains/toolkit/bridge/pallet" }
pallet-partner-chains-session = { path = "../partner-chains/substrate-extensions/partner-chains-session" }
pallet-session-validator-management = { path = "../partner-chains/toolkit/committee-selection/pallet" }
pallet-session-validator-management-rpc = { path = "../partner-chains/toolkit/committee-selection/rpc" }
pallet-sidechain = { path = "../partner-chains/toolkit/sidechain/pallet" }
pallet-sidechain-rpc = { path = "../partner-chains/toolkit/sidechain/rpc" }
partner-chains-cardano-offchain = { path = "../partner-chains/toolkit/smart-contracts/offchain" }
partner-chains-cli = { path = "../partner-chains/toolkit/partner-chains-cli" }
partner-chains-data-sources-cli = { path = "../partner-chains/toolkit/data-sources/cli" }
partner-chains-db-sync-data-sources = { path = "../partner-chains/toolkit/data-sources/db-sync" }
partner-chains-mock-data-sources = { path = "../partner-chains/toolkit/data-sources/mock" }
partner-chains-node-commands = { path = "../partner-chains/toolkit/cli/node-commands" }
partner-chains-plutus-data = { path = "../partner-chains/toolkit/smart-contracts/plutus-data" }
partner-chains-smart-contracts-commands = { path = "../partner-chains/toolkit/smart-contracts/commands" }
plutus-datum-derive = { path = "../partner-chains/toolkit/utils/plutus/plutus-datum-derive" }
plutus = { path = "../partner-chains/toolkit/utils/plutus" }
sc-partner-chains-consensus-aura = { path = "../partner-chains/substrate-extensions/aura/consensus" }
selection = { path = "../partner-chains/toolkit/committee-selection/selection" }
sidechain-block-search = { path = "../partner-chains/toolkit/sidechain/sidechain-block-search" }
sidechain-domain = { path = "../partner-chains/toolkit/sidechain/domain" }
sidechain-mc-hash = { path = "../partner-chains/toolkit/sidechain/sidechain-mc-hash" }
sidechain-slots = { path = "../partner-chains/toolkit/sidechain/sidechain-slots" }
sp-block-participation = { path = "../partner-chains/toolkit/block-participation/primitives" }
sp-block-producer-fees = { path = "../partner-chains/toolkit/block-producer-fees/primitives" }
sp-block-producer-metadata = { path = "../partner-chains/toolkit/block-producer-metadata/primitives" }
sp-block-production-log = { path = "../partner-chains/toolkit/block-production-log/primitives" }
sp-governed-map = { path = "../partner-chains/toolkit/governed-map/primitives" }
sp-partner-chains-bridge = { path = "../partner-chains/toolkit/bridge/primitives" }
sp-partner-chains-consensus-aura = { path = "../partner-chains/substrate-extensions/aura/primitives" }
sp-session-validator-management = { path = "../partner-chains/toolkit/committee-selection/primitives" }
sp-session-validator-management-query = { path = "../partner-chains/toolkit/committee-selection/query" }
sp-sidechain = { path = "../partner-chains/toolkit/sidechain/primitives" }
time-source = { path = "../partner-chains/toolkit/utils/time-source" }
"""

with open("Cargo.toml") as f:
    content = f.read()

MARKER = '[patch."https://github.com/input-output-hk/partner-chains"]'
if MARKER in content:
    print("Cargo.toml already has [patch] section — skipping")
    sys.exit(0)

ANCHOR = '[workspace.metadata.cargo-shear]'
if ANCHOR not in content:
    # Append at end
    content = content.rstrip('\n') + '\n\n' + PATCH_BLOCK + '\n'
else:
    content = content.replace(
        '\n' + ANCHOR,
        '\n' + PATCH_BLOCK + '\n' + ANCHOR
    )

with open("Cargo.toml", "w") as f:
    f.write(content)
print("Cargo.toml: [patch] section added")
PYEOF

# ── 5. Modify Cargo.lock ──────────────────────────────────────────────────────
python3 - "$PC_TAG" <<'PYEOF'
import re, sys

pc_tag = sys.argv[1]  # e.g. "v1.8.1"
# Derive version number (strip leading "v")
pc_ver = pc_tag.lstrip("v")

PC_SOURCE_RE = re.compile(
    r'^source = "git\+https://github\.com/input-output-hk/partner-chains[^"]*"\n',
    re.MULTILINE,
)

# [[patch.unused]] entries for packages that are patched but not used by midnight-node.
# These are computed once per partner-chains version and hardcoded here.
# If partner-chains is upgraded and the set changes, update this list.
UNUSED_PKGS = [
    "ariadne-simulator",
    "pallet-block-participation",
    "pallet-block-producer-fees",
    "pallet-block-producer-fees-rpc",
    "pallet-block-producer-metadata",
    "pallet-block-producer-metadata-rpc",
    "pallet-block-production-log",
    "partner-chains-data-sources-cli",
    "sp-block-participation",
    "sp-block-producer-fees",
    "sp-block-production-log",
]
PATCH_UNUSED_BLOCK = "\n" + "\n".join(
    f'[[patch.unused]]\nname = "{pkg}"\nversion = "{pc_ver}"\n'
    for pkg in UNUSED_PKGS
)

with open("Cargo.lock") as f:
    content = f.read()

# 5a. Remove all partner-chains git source lines
n_removed = len(PC_SOURCE_RE.findall(content))
content = PC_SOURCE_RE.sub("", content)
print(f"Cargo.lock: removed {n_removed} partner-chains source lines")

# 5b. Add "log" dep to sidechain-mc-hash (needed by the fix)
lines = content.split("\n")
mc_hash_idx = None
for i, line in enumerate(lines):
    if line == 'name = "sidechain-mc-hash"':
        mc_hash_idx = i
        break

if mc_hash_idx is None:
    print("WARNING: sidechain-mc-hash not found in Cargo.lock")
else:
    # Find "derive-new" within the deps block of this package
    i = mc_hash_idx
    while i < len(lines) and '"derive-new"' not in lines[i]:
        i += 1
    if i < len(lines) and '"log"' not in lines[i + 1]:
        lines.insert(i + 1, ' "log",')
        print("Cargo.lock: added log dep to sidechain-mc-hash")
    else:
        print("Cargo.lock: sidechain-mc-hash already has log dep")
    content = "\n".join(lines)

# 5c. Append [[patch.unused]] entries if not already present
if "[[patch.unused]]" not in content:
    content = content.rstrip("\n") + "\n" + PATCH_UNUSED_BLOCK
    print(f"Cargo.lock: added {len(UNUSED_PKGS)} [[patch.unused]] entries")
else:
    print("Cargo.lock: [[patch.unused]] entries already present")

with open("Cargo.lock", "w") as f:
    f.write(content)
PYEOF

# ── 6. Generate midnight-node patch ──────────────────────────────────────────
git diff > "$SCRIPT_DIR/midnight-node.patch"
info "midnight-node.patch: $(git diff --stat | tail -1)"

# ── 7. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "=== Patches regenerated successfully ==="
echo "  $SCRIPT_DIR/midnight-node.patch   (midnight-node $NODE_TAG)"
echo "  $SCRIPT_DIR/partner-chains.patch  (partner-chains $PC_TAG)"
echo ""
echo "To apply to a fresh checkout:"
echo "  cd $NODE_DIR && git stash && git checkout $NODE_TAG"
echo "  cd $PC_DIR  && git stash && git checkout $PC_TAG"
echo "  git -C $PC_DIR  apply $SCRIPT_DIR/partner-chains.patch"
echo "  git -C $NODE_DIR apply $SCRIPT_DIR/midnight-node.patch"
