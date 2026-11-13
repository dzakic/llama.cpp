# Local Repository Notes (not for upstream)

This checkout is a **local dev repo**, not for upstream PRs. The goal is the
latest, most performant **SYCL build with oneDNN (GGML_SYCL_DNN=ON)**, all
optimizations enabled.

- Build with: `./local-build.sh` (git pull -> configure -> build -> install to `~/.local/bin`).
- Backends in one tree: **SYCL** (oneAPI 2026.2 compiler/MKL, oneDNN 2026.1, SYCL 9.0) + **CUDA** (13.1, Blackwell sm_120) + **Vulkan**.
- Hardware: RTX 5060 Ti (sm_12.0) + 2x Intel Arc Pro B60.
- Uses **upstream** CMakeLists; the oneDNN manual-target patches previously applied are now redundant (see `BUILD_NOTES.md`). Keep the tree at upstream `master`.
- Full details: `BUILD_NOTES.md`.

## Updating after upstream moves

Run `~/llama.cpp/local-update.sh` (git pull --ff-only + jj rebase) to keep local
changes on top of new upstream without conflicts.
