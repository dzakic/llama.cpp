#!/usr/bin/env bash
# =============================================================================
#  llama.cpp  —  INSTALL built artifacts to ~/.local/bin
#
#  This is the INSTALL half of the build pipeline. It copies the freshly built
#  build/bin/{llama,llama-*,lib*.so*} into ~/.local/bin, rewrites their rpath to
#  $ORIGIN + the oneapi runtime trees, and refreshes the ld.so.cache so the
#  tools run with no LD_LIBRARY_PATH. Build first (local-build.sh), then install.
#
#  Usage:  ./local-install.sh [--from DIR]   (default DIR = $HOME/llama.cpp/build/bin)
# =============================================================================
set -euo pipefail

SRC="${LLAMA_BUILD_SRC:-$HOME/llama.cpp}"
BUILD_SRC="$SRC/build/bin"
DST="$HOME/.local/bin"
PREFIX="/opt/intel/oneapi"

if [ "${1:-}" = "--from" ]; then shift; BUILD_SRC="$1"; shift; fi

mkdir -p "$DST"

# oneapi runtime dirs (kept self-contained; transitive SVML/imf/irng/mkl/dnnl
# deps resolve here via /etc/ld.so.conf.d, so the binaries need no LD_LIBRARY_PATH)
ONEAPI_RPATH="\$ORIGIN:"
ONEAPI_RPATH="$ONEAPI_RPATH$PREFIX/compiler/2026.2/lib:"
ONEAPI_RPATH="$ONEAPI_RPATH$PREFIX/compiler/2026.2/lib/intel64:"
ONEAPI_RPATH="$ONEAPI_RPATH$PREFIX/mkl/2026.2/lib:"
ONEAPI_RPATH="$ONEAPI_RPATH$PREFIX/dnnl/2026.1/lib"
ONEAPI_RPATH="$ONEAPI_RPATH:$PREFIX/tbb/2023.2/lib"

echo "==> Installing from $BUILD_SRC -> $DST"

# executables (the unified 'llama' binary has no dash, so copy it too)
for f in "$BUILD_SRC"/llama "$BUILD_SRC"/llama-*; do
  [ -e "$f" ] && cp -f "$f" "$DST/"
done
# shared libs WITH versioned symlinks (cp -p preserves the .so.0.27.0 links)
for f in "$BUILD_SRC"/lib*.so*; do
  [ -e "$f" ] && cp -pf "$f" "$DST/"
done

# rpath: $ORIGIN lets each binary find sibling libs in ~/.local/bin; the rest
# are the runtime trees the binaries directly NEED (cudart + oneapi).
for f in "$DST"/llama "$DST"/llama-* "$DST"/lib*.so.0.27.0 "$DST"/lib*.so.0.7.0; do
  [ -e "$f" ] || continue
  patchelf --set-rpath "$ONEAPI_RPATH" --force-rpath "$f" 2>/dev/null || true
done

# refresh ld.so.cache: drop old oneapi entries, point transitive deps at the
# 2026.x trees, rebuild cache. Requires sudo (kept here, not run by the build).
echo "==> Refreshing ld.so.cache (oneapi 2026.x)"
sudo rm -f /etc/ld.so.conf.d/oneapi-dnnl.conf /etc/ld.so.conf.d/oneapi-2026.1.conf /etc/ld.so.conf.d/intel-sycl.conf
sudo bash -c "cat > /etc/ld.so.conf.d/60-intel-oneapi.conf <<EOF
$PREFIX/compiler/2026.2/lib
$PREFIX/compiler/2026.2/lib/intel64
$PREFIX/mkl/2026.2/lib
$PREFIX/mkl/2026.2/lib/intel64
$PREFIX/dnnl/2026.1/lib
$PREFIX/tbb/2023.2/lib
\$ORIGIN
EOF"
sudo ldconfig
echo "    ld.so.cache now: $(ldconfig -p | grep -c oneapi) oneapi entries"

echo "==> Installed:"
ls -la "$DST"/ | grep -E "llama|libggml|libllama|libmtmd|libserver" | awk '{print $9, $5}'
echo "Sanity checks:"
echo "    $DST/llama-bench --help | head -3"
echo "    ldd \$DST/llama-bench | grep -E 'ggml|cuda|sycl|vulkan|not found'"
echo "    ldd \$DST/libggml-sycl.so | grep -E 'sycl|dnnl|mkl|not found'"
