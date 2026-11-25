# llama.cpp Local Features and Sync Guide

This document describes the locally developed features in this llama.cpp fork and the process for periodically syncing with upstream.

## Features

### 1. `--model-group` (Server Router Mode)

**Description:** Allows multiple models to share a name in router mode. Several models can declare the same group, and a request for that group name is served by one of the members.

**Implementation:**
- Added `group` field to `server_model_meta` struct in `tools/server/server-models.h`
- Added `server_model_resolve_name()` function to resolve canonical names, groups, and aliases
- Added `--model-group` preset-only option in `common/arg.cpp` and `common/arg.h`
- Added group tracking in `server_models::add_model()`
- Added group validation to prevent ambiguous names (a group cannot conflict with model names or aliases)
- Updated `/models` endpoint to include `group` field for each model and list groups as virtual models with `members` field

**Files Modified:**
- `common/arg.h` - Added `COMMON_ARG_PRESET_MODEL_GROUP` define
- `common/arg.cpp` - Added `--model-group` preset option
- `tools/server/server-models.h` - Added `group` field and `server_model_resolve_name()` declaration
- `tools/server/server-models.cpp` - Added implementation of group resolution and validation
- `tools/server/tests/unit/test_router.py` - Added unit tests (can be cherry-picked from commit `f942846`)
- `tests/test-server-component.cpp` - Added test for `server_model_resolve_name()`
- `tests/CMakeLists.txt` - Updated to link `llama-server-impl` for tests

**Usage Example:**
```ini
[small-flash]
hf-repo = user/some-small-model
model-group = flash

[other-flash]
hf-repo = user/some-other-small-model
model-group = flash
```

A request for `"model": "flash"` is routed to the loaded member of the group. A request that names a model goes to that model. The group is a router concept and is not passed to the model instances.

### 2. `--cache-disk` (Persistent Prompt Checkpoint Cache)

**Description:** Adds persistent prompt checkpoint cache for llama-server.

**Note:** This feature was already implemented and verified in previous work.

## Syncing with Upstream

### Process

1. **Commit Local Changes:**
   ```bash
   cd /home/dz/llama.cpp
   jj commit -m "server: implement model-group feature"
   ```

2. **Push to Remote (Optional, for backup):**
   ```bash
   # Push current working copy to a new branch
   git push origin HEAD:refs/heads/local-model-group
   ```

3. **Fetch and Rebase:**
   ```bash
   # Fetch upstream changes
   jj fetch git+https://github.com/ggml-org/llama.cpp --bookmark master@upstream
   
   # Rebase local changes onto upstream master
   jj rebase -r @ -d master@upstream
   ```

4. **Build and Test:**
   ```bash
   bash local-build.sh
   ```

5. **Verify Features:**
   - Check that `--model-group` works with preset files
   - Test that `/models` endpoint shows group information
   - Run the test suite: `test-server-component`

### Conflict Resolution

If conflicts arise during rebase:

1. **Identify conflicting files:**
   ```bash
   jj status
   ```

2. **Resolve conflicts manually:**
   - Use `jj diff` to see upstream changes
   - Use `jj diff --base @-` to see local changes
   - Manually merge changes preserving both upstream and local modifications

3. **Rebuild after resolution:**
   ```bash
   bash local-build.sh
   ```

### Checking Feature Status

To verify features are present after a sync:

```bash
# Check for model-group implementation
grep -r "COMMON_ARG_PRESET_MODEL_GROUP" .
grep -r "server_model_resolve_name" tools/server/

# Check for cache-disk implementation
grep -r "cache.*disk\|CACHE_DISK" . --include="*.cpp" --include="*.h"
```

### Recent Commits with Model-Group Changes

The model-group feature was originally implemented in commit `f942846021ffc2e2c34bbd07fe024d892ad95c40`.

To view the original diff:
```bash
git show f942846021ffc2e2c34bbd07fe024d892ad95c40
```

Key files from that commit:
- `common/arg.h` - `COMMON_ARG_PRESET_MODEL_GROUP` define
- `common/arg.cpp` - `--model-group` preset option
- `tools/server/server-models.h` - `group` field, `server_model_resolve_name()` declaration
- `tools/server/server-models.cpp` - Implementation
- `tests/test-server-component.cpp` - Unit tests
- `tools/server/tests/unit/test_router.py` - Integration tests

## Notes

- **Preset-only options:** `--model-group` is a preset-only option (set via `set_preset_only()`), so it won't appear in `--help` output. It must be specified in preset files or via environment variable `LLAMA_ARG_MODEL_GROUP`.

- **Group resolution priority:** When resolving a name, the router checks in this order:
  1. Canonical model name
  2. Group name
  3. Alias

- **Group conflicts:** A group name cannot:
  - Be the same as an existing model name
  - Be the same as an alias of any model

- **Load/unload behavior:** When a model is loaded or unloaded, the group automatically serves the appropriate member (loaded > loading/sleeping > first).
