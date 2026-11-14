#!/usr/bin/env bash
# =============================================================================
#  llama.cpp  —  sync the fork with upstream (do this ~once a week)
#
#  Pulls the latest upstream into the build branch while keeping the local
#  features + local helper scripts on top. This is the ONLY script that pulls
#  upstream in. (Fork merges upstream with --no-ff; this git build has no
#  `git rebase --no-merges`, and the local files live in the merge history, so
#  a merge is the robust way to keep everything.)
#
#  Usage:
#    ./local-update.sh            # fetch + merge upstream + push origin
#    ./local-update.sh --no-push  # fetch + merge only; review before pushing
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

echo "============================================================"
echo "  llama.cpp fork sync — upstream -> master  (PUSH=${PUSH})"
echo "============================================================"

echo "==> [1/3] Fetch upstream"
git fetch --quiet upstream

echo "==> [2/3] Merge upstream/master into master (keep local edits on top)"
# --no-ff keeps a merge commit so the fork history shows each sync. If upstream
# touched tools/server/server-models.cpp (the router shared-name feature edit),
# merge stops for a conflict: keep the upstream shape and re-add the router
# logic, then `git add tools/server/server-models.cpp && git commit --no-edit`.
git merge --no-ff --no-commit upstream/master
if git diff --name-only --diff-filter=U | grep -q .; then
  echo "    ! Conflict (likely server-models.cpp). Resolve, then:"
  echo "        git add -A && git commit --no-edit"
  echo "    Aborting without pushing."
  git merge --abort
  exit 1
fi
# only commit if the merge actually brought in new upstream commits
if git diff --cached --quiet 2>/dev/null; then
  echo "    Already up to date with upstream"
else
  git commit -m "chase upstream: merge $(git rev-parse --short=8 upstream/master) into master" >/dev/null
  echo "    HEAD: $(git log -1 --pretty='%h %s')"
fi

if [ "$PUSH" -eq 1 ]; then
  echo "==> [3/3] Push master -> origin/master"
  git push origin master --force-with-lease
else
  echo "    --no-push: review the merge above, then:"
  echo "      git push origin master --force-with-lease"
fi
echo "==> Done. Rebuild with: ./local-build.sh"
