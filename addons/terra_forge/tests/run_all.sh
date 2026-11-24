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
  test_live_layers
  test_layer_scene_roundtrip
  test_layer_integrity
  test_region_store
  test_region_export
  test_paged_height_source
  test_camera_page_prefetch
  test_async_page_io
  test_paged_terrain_preview
  test_paged_camera_stress
  test_lazy_world_open
  test_paged_failure_isolation
  test_profile_scene
  test_io_pipeline
  test_profile_fixture_builder
  test_region_index_v2
  test_region_fixture_v2
  test_async_region_v2
  test_paged_preview_v2
  test_lod_policy
  test_surface_faces
  test_lod_normals
  test_lod_seams
  test_edge_normals
  test_stream_budget
  test_brush_sampling
  test_offtree_transform
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
  # Fail for any Godot ERROR, including engine runtime errors that still
  # return exit code 0. The missing-file safety test intentionally emits
  # one explicit warning while proving that protected data cannot be saved.
  filtered_errors="$LOG_DIR/$name.unexpected-errors.log"
  grep -E '(^ERROR:|^SCRIPT ERROR:|Parse Error:|Parser Error:|Compile Error:|Failed to load script|Failed to parse script)' "$log" >"$filtered_errors" || true
  if [[ "$name" == "test_live_layers" || "$name" == "test_layer_integrity" ]]; then
    grep -vF 'TerraForge: Layer file missing/corrupt, terrain locked:' "$filtered_errors" >"$filtered_errors.tmp" || true
    mv "$filtered_errors.tmp" "$filtered_errors"
  fi
  if [[ "$name" == "test_data_safety" ]]; then
    grep -vF 'TerraForge: Height data is missing or unreadable.' "$filtered_errors" >"$filtered_errors.tmp" || true
    mv "$filtered_errors.tmp" "$filtered_errors"
  fi
  if (( code != 0 )) \
      || [[ -s "$filtered_errors" ]] \
      || ! grep -q '^PASS:' "$log"; then
    if [[ -s "$filtered_errors" ]]; then
      echo "Unexpected engine errors in $name:" >&2
      cat "$filtered_errors" >&2
    fi
    echo "FAIL $name (status=$code; see $log)" >&2
    failures=$((failures + 1))
  else
    echo "PASS $name"
  fi
done
echo "Total: ${#suite[@]} | Fails: $failures"
if (( failures != 0 )); then exit 1; fi
