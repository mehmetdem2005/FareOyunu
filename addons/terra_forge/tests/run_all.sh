#!/usr/bin/env bash
# TerraForge P0 regression suite for real Godot 4.7.2 (desktop/CI).
# Usage: bash addons/terra_forge/tests/run_all.sh /project/path [godot_binary]
set -u

PROJECT_PATH="${1:-}"
GODOT_BIN="${2:-${GODOT_BIN:-godot}}"
LOG_DIR="${TERRAFORGE_LOG_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/terraforge-regressions}"
mkdir -p "$LOG_DIR"

if [[ -z "$PROJECT_PATH" || ! -f "$PROJECT_PATH/project.godot" ]]; then
  echo "ERROR: Give a real Godot project path containing project.godot." >&2
  exit 2
fi
if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "ERROR: Godot binary not found: $GODOT_BIN" >&2
  exit 2
fi
if ! "$GODOT_BIN" --version | grep -Eq '^4[.]7[.]2[.]'; then
  echo "ERROR: Godot 4.7.2 required; found:" >&2
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
  log="$LOG_DIR/$name.log"
  # A GDScript parse failure can sometimes exit 0, or hang with a failed
  # assertion. Require the explicit PASS marker; never trust exit code alone.
  if timeout 90s "$GODOT_BIN" --headless --path "$PROJECT_PATH" --script "res://addons/terra_forge/tests/$name.gd" >"$log" 2>&1; then
    code=0
  else
    code=$?
  fi
  cat "$log"
  if (( code != 0 )) \
      || grep -Eq 'SCRIPT ERROR:|Parse Error:|Parser Error:|Compile Error:|Failed to load script|Failed to parse script' "$log" \
      || ! grep -q '^PASS:' "$log"; then
    echo "FAIL $name (status=$code; see $log)" >&2
    failures=$((failures + 1))
  else
    echo "PASS $name"
  fi
done
echo "Total: ${#suite[@]} | Fails: $failures"
if (( failures != 0 )); then exit 1; fi
