# Local build gotchas (SYCL + DNNL + CUDA + Vulkan, icpx + gcc)

> Work-in-progress working notes for rebuilding this exact setup. Not for upstream commit.
> Kept local alongside `local-build.sh` so the next agent doesn't re-derive these.

## What this machine builds (verified working)

```
icpx   (CXX, IntelLLVM)  -> SYCL backend + oneDNN + MKL SYCL BLAS
gcc-15 (C,  nvcc host)   -> C files + CUDA host (nvcc rejects gcc > 15)
CUDA 13.1  sm_120  •  Vulkan  •  SYCL + oneDNN (libdnnl.so.3)
```

All four backends link into one build and install to `~/.local/bin`.
`libggml-sycl.so` links `libdnnl.so.3`, `libtbb.so.12`, `libmkl_sycl_blas.so.6`, MKL core;
device detection finds 2x Intel Arc Pro B60 with SYCL optimization features.

## The core gotcha (why the build used to fail)

`ggml/cmake/common.cmake` `ggml_get_flags()` previously took ONE compiler ID (the CXX compiler,
which is `IntelLLVM`/icpx here) and applied that compiler's flags to **both** C and C++ compiles.
icpx is clang-based, so its default warning flags `-Wunreachable-code-break`,
`-Wunreachable-code-return`, `-Rno-debug-disables-optimization` are clang-only and broke the
gcc-15 C compilation:

```
gcc-15: error: unrecognized command-line option '-Wunreachable-code-break'
```

Fix (already applied to this repo): read `C_FLAGS` from `CMAKE_C_COMPILER_ID` (gcc) and
`CXX_FLAGS` from the passed `CCID` (icpx). gcc now gets only `-Wdouble-promotion`; icpx keeps
its IntelLLVM flags. Pure-GNU C++ flags (`-Wno-array-bounds`, `-Wextra-semi` for gcc>=8.1) are
still set from `CCID`/`CCVER`. Do NOT revert this split back to a single-`CCID` function — it
reintroduces the break.

Note: CMake 4.2 errors on calling a function with FEWER args than declared params but silently
ignores EXTRA args. So the function keeps its 2-arg signature `ggml_get_flags(CCID CCVER)` and
reads the C compiler ID globally via `CMAKE_C_COMPILER_ID` — extra args are unnecessary.

## Environment prerequisites (install once)

```bash
apt install -y gcc-15 g++-15 gcc-16 g++-16 libstdc++-16-dev   # gcc-15 is the nvcc host
source /opt/intel/oneapi/setvars.sh
```

- icpx needs libstdc++ headers that only exist once `libstdc++-16-dev` (and `g++-16`) are
  installed; otherwise icpx dies with "C++ header location not resolved".
- nvcc 13.1 hard-rejects gcc > 15 (`unsupported GNU version! gcc versions later than 15`).
  gcc-16 works for icpx's host but NOT for the nvcc CUDA host. Use gcc-15.

## CMake flags that actually matter (from local-build.sh)

- `-DTBB_DIR=/opt/intel/oneapi/tbb/2023.2/lib/cmake/tbb` — DNNL's `FindTBB` is broken (reads
  `$TBBROOT` and fails); pointing `find_package(TBB CONFIG)` at the TBB config bypasses it.
- `-DCMAKE_EXE_LINKER_FLAGS=/usr/lib/x86_64-linux-gnu/libstdc++.so.6` — absolute libstdc++ file
  path. Needed because DNNL's libdnnl.so pulls libtbb, which needs `__cxa_call_terminate@CXXABI`
  from libstdc++; icpx appends `-lstdc++` AFTER libtbb so libtbb can't resolve it. Passing the
  absolute `.so.6` file links libstdc++ BEFORE libtbb (un-prunable link order). Without it the
  SYCL backend never registers (`--list-devices` shows "Available devices: (none)").
- `-DCMAKE_INSTALL_RPATH='$ORIGIN/../lib'` + `-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON` — installed
  tools find sibling libs in `~/.local/lib` with NO `LD_LIBRARY_PATH`. The build tree itself has
  an rpath to its own `bin/`, so the build tree also works standalone.

## Build / run commands

```bash
source /opt/intel/oneapi/setvars.sh
./local-build.sh                      # configure (icpx CXX, gcc-15 C/nvcc) + build + install to ~/.local
# or the manual steps:
cmake -B build -DCMAKE_BUILD_TYPE=Release ... (flags above) -DBUILD_TESTING=OFF
cmake --build build --target all -j$(nproc)
cmake --install build --prefix ~/.local
```

Runtime check (no LD_LIBRARY_PATH needed thanks to rpath):

```bash
~/.local/bin/llama-ls-sycl-device | head -8        # finds 2 Intel Arc B60 GPUs
ldd ~/.local/lib/libggml-sycl.so | grep -E 'dnnl|mkl|tbb'
```

## Regressions to watch for

- Reverting `common.cmake` to a single-`CCID` `ggml_get_flags` reintroduces the
  `gcc-15: unrecognized command-line option '-Wunreachable-code-break'` failure.
- Using g++/gcc as CXX (instead of icpx) drops the SYCL backend entirely (no MKL::MKL_SYCL::BLAS
  import targets -> the SYCL `target_link_libraries` step fails).
- gcc-16+ as the nvcc CUDA host fails the CUDA compile ("unsupported GNU version").
