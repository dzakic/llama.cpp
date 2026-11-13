#!/usr/bin/env bash
# =============================================================================
#  llama.cpp  —  compatibility shim
#
#  Old local-update.sh copied build/bin -> ~/.local/bin (an INSTALL step). That
#  install logic now lives in local-install.sh; this shim just forwards to it
#  so any existing shortcuts/aliases keep working.
#
#  Usage:  ./local-update.sh [--from DIR]
# =============================================================================
set -euo pipefail
here="${BASH_SOURCE[0]}"
exec bash -c "cd \"$(dirname \"$here\")\" && exec ./local-install.sh \"$@\"" _ "$@"
