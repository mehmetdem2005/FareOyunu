#!/usr/bin/env bash
# TerraForge P0 regression suite. Needs a REAL Godot 4.7.2 binary.
# Usage: bash addons/terra_forge/tests/run_all.sh /path/to/your/godot/project [godot_binary]
# The supplied project must contain project.godot and addons/terra_forge/.
set -u
PROJECT_PATH="${1:-}"
GODOT_BIN="${2:-${GODOT_BIN:-godot}}"

if [[ -z "$PROJECT_PATH" || ! -f "$PROJECT_PATH/project.godot" ]]; then
  echo "ERROR: Give an existing Godot project directory containing project.godot." >&2
  exit 2
fi
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "ERROR: Godot binary not found: $GODOT_BIN" >&2
  exit 2
fi
if ! "$GODOT_BIN" --version | grep -Eq '^4\.7\.2\.'; then
  echo "ERROR: Expected Godot 4.7.2; found:" >&2
  "$GODOT_BIN" --version >&2
  exit 2
fi

suite=(
  test_height_store
  test_data_safety
  test_height_layers
  test_lod_policy
  test_surface_faces
  test_lod_normals
  test_lod_seams
  test_edge_normals
  test_stream_budget
  test_brush_sampling
  test_advanced_brushes
  test_geomorphology
  test_shape_quality
  test_drainage_analysis
)
failures=0
for name in "${suite[@]}"; do
  echo "=== $name ==="
  if "$GODOT_BIN" --headless --path "$PROJECT_PATH" --script "res://addons/terra_forge/tests/$name.gd"; then
    echo "PASS $name"
  else
    echo "FAIL $name" >&2
    failures=$((failures + 1))
  fi
done
echo "Total: ${#suite[@]} | Fails: $failures"
if (( failures != 0 )); then exit 1; fi
