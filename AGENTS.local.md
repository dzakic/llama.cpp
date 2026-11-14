# Local Repository Notes (not for upstream)

This checkout is a **local dev repo**, not for upstream PRs. The goal is the
latest, most performant **SYCL build with oneDNN (GGML_SYCL_DNN=ON)**, all
optimizations enabled.

- Build with: `./local-build.sh` (git pull -> configure -> build -> install to `~/.local/bin`).
- Backends in one tree: **SYCL** (oneAPI 2026.2 compiler/MKL, oneDNN 2026.1, SYCL 9.0) + **CUDA** (13.1, Blackwell sm_120) + **Vulkan**.
- Hardware: RTX 5060 Ti (sm_12.0) + 2x Intel Arc Pro B60.
- Uses **upstream** CMakeLists; the oneDNN manual-target patches previously applied are now redundant (see `BUILD_NOTES.md`). Keep the tree at upstream `master`.
- Full details: `BUILD_NOTES.md`.

## Keeping the fork (origin) in sync with upstream

Full workflow: `skills/fork-upstream-sync/SKILL.md`. Short version:

- `upstream`  = ggml-org/llama.cpp (latest). `origin`  = dzakic fork (push target).
- `master` is the single working branch: upstream + the private features + the local helper
  scripts. `origin/master` mirrors `master`.
- Private features (task queue + `--cache-disk`, gcc/icpx build fix, router shared-name) are
  committed on `master`, absent from upstream.
- Weekly sync: `./local-update.sh` (fetch + rebase `master` onto upstream + push). Rebuild:
  `./local-build.sh` (incremental by default; `--clean` for a full wipe).
- The only realistic conflict is `tools/server/server-models.cpp` (see the skill).
