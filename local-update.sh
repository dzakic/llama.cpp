#!/usr/bin/env bash
# =============================================================================
#  llama.cpp  —  sync the fork with upstream (do this ~once a week)
#
#  Chases upstream while keeping the local features + local helper scripts on
#  top of it. This is the ONLY script that pulls upstream into the build branch.
#
#  Usage:
#    ./local-update.sh            # fetch + rebase onto upstream + push
#    ./local-update.sh --no-push  # fetch + rebase only; review before pushing
#    PUSH=0 ./local-update.sh     # same as --no-push (env override)
#
#  After a successful sync, rebuild the changed files with:
#    ./local-build.sh
# =============================================================================
set -euo pipefail

SRC="$HOME/llama.cpp"
cd "$SRC"
PUSH=1
[ "${1:-}" = "--no-push" ] && PUSH=0

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "============================================================"
echo "  llama.cpp fork sync — upstream -> ${BRANCH}  (PUSH=${PUSH})"
echo "============================================================"

echo "==> [1/3] Fetch upstream"
git fetch --quiet upstream

echo "==> [2/3] Rebase '${BRANCH}' onto upstream/master"
# Replay only the private-feature commits on top of the latest upstream.
# --no-merges drops the old sync-point merges so history stays linear; the
# feature commits carry the local changes (task queue + --cache-disk, the
# gcc/icpx build fix, and the router shared-name edit). The only file that
# realistically conflicts is tools/server/server-models.cpp — if rebase stops
# there, resolve it (keep the upstream shape, re-add the router logic) and
# continue with: git rebase --continue
git rebase --no-merges upstream/master
echo "    HEAD: $(git log -1 --pretty='%h %s')"

if [ "$PUSH" -eq 1 ]; then
  echo "==> [3/3] Push ${BRANCH} -> origin/master"
  git push origin "${BRANCH}:master" --force-with-lease
else
  echo "    --no-push: review the rebase above, then:"
  echo "      git push origin ${BRANCH}:master --force-with-lease"
fi
echo "==> Done. Rebuild with: ./local-build.sh"
