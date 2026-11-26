#!/usr/bin/env bash
# TerraForge P0 regression suite for real Godot 4.7.2 (desktop/CI).
# Usage: bash addons/terra_forge/tests/run_all.sh /project/path [godot_binary] [shard_number shard_count]
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
  test_reader_delivery_abba
  test_profile_fixture_builder
  test_region_index_v2
  test_region_fixture_v2
  test_async_region_v2
  test_paged_preview_v2
  test_tile_read_view
  test_sampling_benchmark
  test_sampling_stream_trace
  test_scalar_sampling_benchmark
  test_geometry_worker
  test_worker_halo
  test_geometry_worker_preview
  test_geometry_worker_comparison
  test_camera_worker_halo
  test_worker_priority
  test_scalar_worker
  test_publication_accounting
  test_publication_budget
  test_publication_budget_oracle
  test_e2_staged_resource
  test_e2_verified_revision
  test_topology_worker
  test_hybrid_i_v0
  test_hybrid_policy
  test_hybrid_i_v0_faults
  test_publication_comparison
  test_physics_raycast
  test_physics_ready_latency
  test_physics_footprint_latency
  test_readiness_horizon_candidate
  test_dynamic_terrain_physics
  test_collision_footprint
  test_held_seam_transition
  test_guarded_capsule
  test_support_tile_selection
  test_support_retention
  test_support_retention_v2
  test_support_transfer
  test_support_transfer_v2
  test_motion_prefetch
  test_motion_prefetch_v2
  test_adaptive_motion_horizon
  test_adaptive_motion_horizon_v2
  test_motion_roundtrip
  test_f2_live_shadow_v1
  test_f2_live_shadow_v2
  test_f2_long_shadow_v1
  test_f2_long_shadow_v2
  test_motion_roundtrip_e
  test_motion_roundtrip_f
  test_motion_roundtrip_g
  test_motion_roundtrip_v2
  test_motion_roundtrip_v2_g
  test_hybrid_halo_motion_v1_g
  test_hybrid_halo_motion_v1_h
  test_hybrid_halo_motion_v2_g
  test_hybrid_halo_motion_v2_h
  test_large_world_e
  test_large_world_f
  test_large_world_v2_e
  test_large_world_v2_f
  test_cold_shard_motion_e
  test_cold_shard_motion_f
  test_hybrid_i_v0_motion
  test_hybrid_policy_motion_v1_g
  test_hybrid_policy_motion_v1_h
  test_hybrid_policy_motion_v2_g
  test_hybrid_policy_motion_v2_h
  test_hybrid_i_v0_cold
  test_hybrid_policy_cold_h
  test_motion_fault_recovery
  test_motion_fault_recovery_v2
  test_adaptive_view_budget
  test_adaptive_view_budget_v2
  test_adaptive_work_budget
  test_adaptive_work_budget_v2
  test_critical_worker_reservation
  test_critical_worker_reservation_v2
  test_critical_slot_lending
  test_critical_slot_lending_v2
  test_geometry_latency_profile
  test_geometry_latency_profile_v2
  test_capacity_wait_profile
  test_saturation_fairness
  test_live_queue_diagnostics
  test_live_queue_diagnostics_v2
  test_lod_policy
  test_surface_faces
  test_lod_normals
  test_lod_seams
  test_geometry_dirty_shadow
  test_geometry_dirty_curved
  test_g2_seam_patch
  test_g2_verified_physics
  test_g2_natural_opportunities
  test_normal_edge_candidate
  test_g1_owned_resource
  test_g1_base_cache
  test_g1_worker_candidate
  test_edge_normals
  test_stream_budget
  test_brush_sampling
  test_offtree_transform
  test_advanced_brushes
  test_geomorphology
  test_shape_quality
  test_drainage_analysis
)
# Interleave adjacent physics scenarios across independent CI runners.
shard_number="${3:-1}"
shard_count="${4:-1}"
if [[ ! "$shard_number" =~ ^[1-9][0-9]*$ || ! "$shard_count" =~ ^[1-9][0-9]*$ ]] ||
    (( shard_number > shard_count || shard_count > ${#suite[@]} )); then
  echo "Invalid test shard: $shard_number/$shard_count" >&2
  exit 2
fi
selected=()
for ((index=shard_number-1; index<${#suite[@]}; index+=shard_count)); do
  selected+=("${suite[index]}")
done
failures=0
for name in "${selected[@]}"; do
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
echo "Total: ${#selected[@]} | Fails: $failures"
if (( failures != 0 )); then exit 1; fi
