# llama.cpp Model-Group Feature Implementation

## Overview

The `--model-group` feature has been successfully implemented in llama.cpp. This feature allows multiple models to share a name in router mode, enabling load balancing and model failover scenarios.

## Feature Details

### What It Does
- Multiple models can declare the same group name via the `model-group` preset option
- A request for a group name is served by one of the members
- The router selects the best member based on: loaded > loading/sleeping > first (by last_used)

### Usage

Create a preset file with multiple models sharing the same group:

```ini
[small-flash]
hf-repo = ggml-org/test-model-stories260K
model-group = flash

[other-flash]
hf-repo = ggml-org/test-model-stories260K-infill
model-group = flash
```

Start the server with the preset:
```bash
llama-server --models-preset /path/to/preset.ini
```

Request the group by name:
```bash
curl -X POST http://localhost:8015/tokenize \
  -H "Content-Type: application/json" \
  -d '{"model":"flash","content":"hello"}'
```

### API Response

The `/models` endpoint now includes:
- `group` field for each model showing which group it belongs to
- Group entries as virtual models with `members` array

Example:
```json
{
  "data": [
    {
      "id": "small-flash",
      "group": "flash",
      "aliases": [],
      ...
    },
    {
      "id": "flash",
      "aliases": [],
      "group": [],
      "members": ["small-flash", "other-flash"],
      ...
    }
  ]
}
```

## Implementation Summary

### Modified Files

1. **common/arg.h** - Added `COMMON_ARG_PRESET_MODEL_GROUP` define
2. **common/arg.cpp** - Added `--model-group` preset-only option
3. **tools/server/server-models.h** - Added `group` field and `server_model_resolve_name()`
4. **tools/server/server-models.cpp** - Implemented group resolution and validation
5. **tests/test-server-component.cpp** - Added unit tests
6. **tests/CMakeLists.txt** - Updated test linkage

### Key Changes

1. **server_model_meta** struct now has a `group` field
2. **server_model_resolve_name()** resolves canonical names, groups, and aliases
3. **server_models::add_model()** validates groups don't conflict with existing names/aliases
4. **/models endpoint** includes group info and lists groups as virtual models

### Validation Rules

- A group name cannot conflict with an existing model name
- A group name cannot conflict with an existing alias
- An alias cannot conflict with an existing group name

## Verification

Build and test:
```bash
bash local-build.sh
```

Test with preset:
```bash
llama-server --models-preset /tmp/test-preset.ini --port 8015 &
curl http://localhost:8015/models | jq '.data[] | select(.id == "flash")'
```

## Syncing with Upstream

When syncing with upstream (ggml-org/llama.cpp):

1. Commit local changes:
   ```bash
   jj commit -m "server: implement model-group feature"
   ```

2. Fetch upstream:
   ```bash
   jj fetch git+https://github.com/ggml-org/llama.cpp --bookmark master@upstream
   ```

3. Rebase:
   ```bash
   jj rebase -r @ -d master@upstream
   ```

4. Build:
   ```bash
   bash local-build.sh
   ```

See `LOCAL_FEATURES.md` for detailed instructions.

## Original Implementation

This feature was originally implemented in commit `f942846021ffc2e2c34bbd07fe024d892ad95c40` and has been integrated into this fork.

## Notes

- The `--model-group` option is preset-only (set via preset files or `LLAMA_ARG_MODEL_GROUP` env var)
- Group resolution priority: canonical name > group name > alias
- Groups work alongside the existing `--cache-disk` feature
