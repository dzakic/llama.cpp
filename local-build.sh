#!/usr/bin/env bash
# =============================================================================
#  llama.cpp  —  update / build / install
#
#  Target:  CUDA 13.1  •  Blackwell (RTX 5060 Ti, sm_120 / cc 12.0)  •  icpx
#  Backends: CUDA  •  Vulkan  •  SYCL + oneDNN (all in one build)
#  Features: GGML_CUDA_FORCE_MMQ=ON, GGML_CUDA_GRAPHS=ON, GGML_CUDA_FA=ON,
#            GGML_SYCL=ON, GGML_SYCL_DNN=ON (oneDNN opt. FlashAttention),
#            GGML_SYCL_F16=ON, GGML_SYCL_GRAPH=ON, GGML_SYCL_HOST_MEM_FALLBACK=ON
#  Install:  every tool + shared libs -> ~/.local/bin, standalone ($ORIGIN rpath).
#
#  Toolchain note (why two C compilers):
#    * nvcc (CUDA 13.1) only accepts gcc up to 15, so C/CUDA host must be gcc-15.
#    * The SYCL backend needs icpx as the CXX compiler (it creates the
#      MKL::MKL_SYCL::BLAS import targets; g++/gcc cannot).
#    * icpx is clang-based; its warning flags (-Wunreachable-code-break,
#      -Wunreachable-code-return, -Rno-debug-disables-optimization) are clang-only
#      and break the gcc-15 C compile. Upstream ggml_get_flags() keys both C and
#      CXX flags off the CXX compiler id; a local commit patches it so C_FLAGS
#      follow CMAKE_C_COMPILER_ID while CXX_FLAGS follow the CXX id. Do not use
#      icpx as the C compiler (nvcc rejects it).
#
#  Update flow (this repo is managed with jj on top of git, do NOT use
#  git fetch/merge/stash here - jj owns the working tree):
#    1. uncommitted local edits are saved as a commit
#    2. jj git fetch --remote upstream   (downloads new upstream commits)
#    3. jj rebase local commits onto master@upstream (jj does the merge)
#    4. on conflicts: edit the files (or: jj resolve), then jj squash,
#       then re-run this script
#
#  Usage:  ./local-build.sh
# =============================================================================
set -euo pipefail

SRC="$HOME/llama.cpp"
BUILD="$SRC/build"
PREFIX="$HOME/.local"
CUDA_HOME="/usr/local/cuda-13.1"        # nvcc 13.1.115
CC="/usr/bin/gcc-15"                    # nvcc host / C compiler (gcc-16 not supported by nvcc)
CXX="/opt/intel/oneapi/compiler/2026.2/bin/icpx"  # CXX compiler (SYCL needs icpx)
CUDART_LIB="/usr/local/cuda/targets/x86_64-linux/lib"
ONEAPI_COMPILER_LIB="/opt/intel/oneapi/compiler/2026.2/lib"
ONEAPI_MKL_LIB="/opt/intel/oneapi/mkl/2026.2/lib"
ONEAPI_SYCL_LIB="/opt/intel/oneapi/compiler/2026.2/lib"
TBB_DIR="/opt/intel/oneapi/tbb/2023.2/lib/cmake/tbb"
ONEAPI_DNNL_LIB="/opt/intel/oneapi/dnnl/2026.1/lib"
ONEAPI_TBB_LIB="/opt/intel/oneapi/tbb/2023.2/lib"
NPROC="$(nproc)"

echo "============================================================"
echo " llama.cpp update/build/install — CUDA ${CUDA_HOME##*/}, sm_120"
echo "  Backends: CUDA + Vulkan + SYCL + oneDNN (all in one build)"
echo "  Compilers: icpx (CXX), gcc-15 (C/CUDA host)"
echo "============================================================"

# -----------------------------------------------------------------------------
echo "==> [1/4] Update source (jj: commit local edits, fetch upstream, rebase local onto master@upstream)"
cd "$SRC"

# save uncommitted local edits as a commit so the rebase operates on commits
if ! jj status | grep -q '^The working copy has no changes'; then
    jj describe -m "local: wip $(date +%Y-%m-%d_%H%M)"
    jj new
fi

# jj shares the git remotes: origin = personal fork, upstream = ggml-org/llama.cpp
jj git fetch --remote upstream

# move local commits (those not on any remote, including the empty working-copy
# commit @ so it follows the stack) onto the new upstream tip; jj does the merge
if [ -n "$(jj log -r 'remote_bookmarks()..@' -T 'commit_id.short() ++ "\n"')" ]; then
    jj rebase -r 'remote_bookmarks()..@' -d 'master@upstream' || echo "    ! rebase reported conflicts"

    if [ -n "$(jj log -r '(remote_bookmarks()..@) & conflicts()' -T 'commit_id.short() ++ "\n"')" ]; then
        echo "    ! CONFLICTS after rebase. Resolve, then re-run this script:"
        echo "        jj resolve     # conflict editor (or edit the files directly)"
        echo "        jj squash      # fold the resolution into the commit below @"
        exit 1
    fi
fi
echo "    HEAD: $(jj log -r '@-' -T 'commit_id.short() ++ " " ++ description.first_line()' | sed 's/^[^ ]* *//')"

# -----------------------------------------------------------------------------
echo "==> [2/4] Configure & build (DNNL needs -DTBB_DIR to bypass its FindTBB bug)"
# icpx (clang) as CXX for the SYCL backend; gcc-15 as C so nvcc accepts the host.
# CMAKE_INSTALL_RPATH=$ORIGIN/../lib makes installed tools self-contained.
rm -rf "$BUILD"
mkdir -p "$BUILD"
cmake -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER="$CXX" \
  -DCMAKE_C_COMPILER="$CC" \
  -DCMAKE_CUDA_COMPILER="$CUDA_HOME/bin/nvcc" \
  -DCMAKE_CUDA_HOST_COMPILER="$CC" \
  -DCMAKE_CUDA_ARCHITECTURES=120 \
  -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib' \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
  -DGGML_CUDA=ON \
  -DGGML_CUDA_FORCE_MMQ=ON \
  -DGGML_CUDA_GRAPHS=ON \
  -DGGML_CUDA_COMPRESSION_MODE=size \
  -DGGML_CUDA_FA=ON \
  -DGGML_VULKAN=ON \
  -DGGML_SYCL=ON \
  -DGGML_SYCL_DNN=ON \
  -DGGML_SYCL_F16=ON \
  -DGGML_SYCL_GRAPH=ON \
  -DGGML_SYCL_HOST_MEM_FALLBACK=ON \
  -DMKL_DIR="$ONEAPI_MKL_LIB/cmake/mkl" \
  -DTBB_DIR="$TBB_DIR" \
  -DCMAKE_PREFIX_PATH="$ONEAPI_SYCL_LIB:$ONEAPI_MKL_LIB" \
  -DSYCL_DEPRECATION_WARNING=off \
  -DCMAKE_CXX_FLAGS="-Wno-deprecated-declarations" \
  -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
  -DCMAKE_CUDA_FLAGS="-O3 -DNDEBUG" \
  -DBUILD_TESTING=OFF
cmake --build "$BUILD" --target all -j"$NPROC"
echo "    Build complete → $BUILD/bin/"

# -----------------------------------------------------------------------------
echo "==> [3/4] Install to $PREFIX (standalone via \$ORIGIN rpath, no ld.so hack)"
cmake --install "$BUILD" --prefix "$PREFIX" >/dev/null
echo "    Installed binaries: $(ls "$PREFIX"/bin/llama-* 2>/dev/null | grep -vc '\.old\|\.bak')"
echo "    Installed libs:      $(ls "$PREFIX"/lib/libggml-*.so* 2>/dev/null | grep -vc '\.old\|\.bak')"
echo
echo "  Sanity checks:"
echo "    ldd \$PREFIX/bin/llama-server | grep -E 'ggml-sycl|dnnl|cuda|cudart|not found'"
echo "    \$PREFIX/bin/llama-ls-sycl-device | head -6"
echo "    ldd \$PREFIX/lib/libggml-sycl.so | grep -E 'dnnl|mkl|tbb|not found'"
echo
echo "==> Done (CUDA 13.1 + Vulkan + SYCL + oneDNN), installed to $PREFIX"
