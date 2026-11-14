---
name: fork-upstream-sync
description: Keep dzakic/llama.cpp (origin) chasing ggml-org/llama.cpp (upstream) while preserving the user's private features. Use when syncing the fork to upstream (weekly), when a merge/rebase produced server-models.cpp conflicts, or when chasing upstream features.
---

# Keep the fork in sync with upstream without losing private features

## Layout

- `upstream`  = `github.com/ggml-org/llama.cpp`  (canonical, always latest).
- `origin`    = `github.com/dzakic/llama.cpp`   (user's fork, push target).
- `master`    = the single working branch. It holds upstream + the private features +
  the local helper scripts (`local-build.sh`, `local-install.sh`, `AGENTS.local.md`, ...).
  `origin/master` mirrors `master`.

The build branch (`master`) is the only branch that matters. Private features sit on top of
upstream as a few clean commits; chasing upstream merges the newest upstream in (keeping the
local edits on top).

## Private features (committed on `master`, absent from upstream)

Describe by name, not hash (hashes change on rebase):

1. `server: add task queue for deferred background work` — also carries `--cache-disk` /
   `--cache-disk-max` (added to `common/arg.cpp` in the same commit) plus
   `tools/server/server-task.{c,h}`.
2. `build: keep mixed gcc/icpx toolchain flag split in ggml_get_flags` — `ggml/cmake/common.cmake`.
3. `server: allow several models to share a name in router mode` — touches
   `tools/server/server-models.cpp` (see conflict note below).

## Weekly sync (the only upstream-pull script)

```sh
./local-update.sh            # fetch + rebase master onto upstream + push origin
./local-update.sh --no-push  # same, but review before pushing
```

`local-update.sh` does: `git fetch upstream`, `git merge --no-ff upstream/master` (keeps the
3 feature commits + local scripts on top), then pushes `master -> origin/master
--force-with-lease`. Then rebuild:

```sh
./local-build.sh             # incremental; only changed files recompile
```

## Conflict resolution (server-models.cpp)

The only file that realistically conflicts: upstream refactored it while the router shared-name
feature edited it. When merge stops, reconstruct git's true 3-way merge instead of taking one
side wholesale:

```sh
MB=$(git merge-base HEAD upstream/master)
git show HEAD:tools/server/server-models.cpp        > /tmp/ours.cpp
git show $MB:tools/server/server-models.cpp         > /tmp/base.cpp
git show upstream/master:tools/server/server-models.cpp > /tmp/theirs.cpp
git merge-file --diff3 /tmp/ours.cpp /tmp/base.cpp /tmp/theirs.cpp
# keep the auto-merged hunks, resolve only the real conflict (re-add the router logic),
# then: cp /tmp/ours.cpp tools/server/server-models.cpp && git rebase --continue
```

Verify the struct-initializer layout still matches `server_model_meta` in `server-models.h`
before continuing.

## What NOT to do

- Do not let `local-build.sh` auto-merge upstream on every build. Chasing upstream is the
  deliberate `local-update.sh` step; the build script only builds the current checkout.
- Do not `git rebase --no-merges` to chase upstream on this repo: this git build lacks that
  option, and the local helper scripts live in the merge history (a merge keeps them).
- Do not squash private commits into upstream commits; keep them a distinct, rebasable layer.
- Do not push a half-resolved rebase. Verify `--cache-disk` survived and the build installs:
  ```sh
  ./build/bin/llama-server --help | grep cache-disk
  ```
- Do not reset `origin/master` to a state missing the private features.

## If history gets messy

If a merge left `master` as a long mixed history with merge commits on top of features,
rebuild the clean layer on a fresh upstream base (cherry-pick is version-independent):

```sh
git stash
git checkout -b zk upstream/master
git cherry-pick <task-queue> <build-fix> <router>   # rebuild the clean layer
```
then push `zk -> origin/master --force-with-lease` and rebuild from `zk`.
