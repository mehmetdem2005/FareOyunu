# P1.5.5e — Dense scalar geometry worker experiment
> **GÜNCEL DEVİR — P1.5.5e (24 Kasım 2026):** Kod 6051f1aceeefa56542a33a0603c3c614b8b658f1, [43/43 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45450882358). [P1_5_5E_SCALAR_WORKER_TR.md](P1_5_5E_SCALAR_WORKER_TR.md), [ham JSON](P1_5_5E_SCALAR_WORKER_CI.json). G explicit experimental sampling_strategy=5 (F priority + dense scalar). Exact 14 worker cases and 8 equal-work runs, 256 timed publications. Worker build mean F 1.151 ms vs G 0.809 ms (29.73% less); main/wall no material gain, same cadence F/G coverage identical 32 missing shape steps for both page caps. 16 C/E/F/G fixed 8ms traces. A default unchanged. **NEXT P1.5.6a publication instrumentation and byte/count/time budget design**, no claim of GPU measurement; remaining worker coverage/pending-prune and D live/topology gates stay open. P1.4/P1.4R PARKED per explicit user decision; no painting/objects.

## Implementation
G mode5 uses same F priority reconciliation, same worker-owned dense Float32 copy, same queue and geometry output. tile_dense_buffer.gd adds read_finite_or_nan with off-grid, bounds and nonfinite checks. paged_tile_geometry.gd generate_owned_dense_scalar reuses D-style scalar generation body, no borrowed lease, no new height precision or geometry algorithm. geometry_worker.start optional scalar_sampling=false pinned before thread start and reset after join; worker stats report selection. Existing A/B/C/E/F choices preserved, D remains benchmark-only. G profile dropdown. No default change, no new thread or payload capacity.

## Evidence
43/43 CI. 14 cases on TFM1/2 across LOD0/1/2, edge and mixed seams, direct dense scalar and worker arrays exact vs A, bad coordinates/off-grid/nonfinite scratch sample returns NAN, owned input survives cache eviction, stale neighbor/epoch/reopen, cap2 and close. Nonfinite scratch read tested; separate full corrupted buffer generation fault path not exhaustively tested. No source data mutation. Eight equal-work F/G runs (ABBA per format), 32 timed publications each, 4 warmup, 16 resident pages, identical SHA-256 resource fingerprints within format, no disk IO during timed batch, no duplicate job, outstanding close. Worker stage means include warmup. Same priority reconciliation for F/G, no timing pass gate.

| Mode | Main us/tile | Wall us/tile | Worker build ms incl warmup |
|---|---:|---:|---:|
| F | 495.27 | 1605.49 | 1.151 |
| G | 497.27 | 1601.49 | 0.809 |
Worker build 29.73% less elapsed for G, but no material end-to-end gain. Main and wall means include scheduler polling/interval costs as documented in P1.5.5c. One AMD EPYC 9V45 Linux headless runner, not Android/device.

## Same cadence camera experiment
16 runs, both formats, 9/16 page caps, cap2, C/E/F/G, 144 target 8ms positions each. No OS cache flush. Mean across two formats, C/E/F/G respectively.
| Page cap | Pump ms | Published | Missing shape steps | Worker build ms E/F/G |
|---:|---|---|---|---|
| 9 | 0.762 / 0.400 / 0.417 / 0.426 | 42 / 37 / 37 / 37 | 34 / 39 / 32 / 32 | 1.445 / 1.525 / 1.089 |
| 16 | 0.844 / 0.400 / 0.438 / 0.455 | 51 / 46 / 47 / 47 | 29 / 37 / 32 / 32 | 1.435 / 1.508 / 1.078 |
All full-period deadline misses zero, recovery gates passed. G reduces compute time but not sampled collision gap or published count versus F. Main pump modestly higher in G. No proof of exact cause of residual gap; candidates: IO, scheduling cadence, publish count/budget, arrival priority and queue/delivery wait. Do not infer GPU or physics raycast/FPS. Keep A default, B/C/E/F/G explicit experiments. D runtime not silently promoted. Pending prune deterministic test remains open.

## NEXT P1.5.6a — Publication accounting before optimization
Read current preview _publish_geometry, worker and profile/report, existing LOD/mesh tests. Separate resource creation on main from worker computation and actual GPU transfer, estimated payload vs GPU residency. First add explicit conservative packed-array payload accounting per LOD, mesh/shape creation elapsed and per-pump publish counts/bytes/time overshoot, visible vertex/triangle and resource counts; include both sync and worker. Validate formula against actual arrays, exact geometry, no invalid/stale publication, bounded counters, reset/close. Design soft byte/count/time limits and one-item progress rule without indefinitely starving LOD0; implement enforcement in separate step only after accounting. No GPU-time claim on headless; real renderer/device proof P1.5.10, raycast P1.5.7. Prior topology reuse/preallocation, pending prune and collision gaps retained. P1.4/P1.4R parked by user. No painting/objects.