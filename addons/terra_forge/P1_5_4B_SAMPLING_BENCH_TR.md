# P1.5.4b — A/B/C resident sampling benchmark
> **GÜNCEL DEVİR — P1.5.4b (24 Kasım 2026):** Kod da123dca5be609cc67c6b18f181b91abdc962404, [36/36 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45439854530). [P1_5_4B_SAMPLING_BENCH_TR.md](P1_5_4B_SAMPLING_BENCH_TR.md), [ham ölçüm](P1_5_4B_SAMPLING_CI.json). A/B/C exact array parity, 14 warm-resident cases × 24 rounds × 3 methods = 1008 timed builds. Equal-weight mean A 1869.22 us, B 1390.05 us, C 1791.09 us; B 25.63% lower than A, wins 14/14 means on one Linux runner. Not mobile FPS or isolated CPU time. A default, B opt-in, C benchmark-only. **NEXT P1.5.4c:** fixed camera trace A/B/C, page/job/cache/RSS/reload and frame/pump comparison; device gates still open. [UNUTULMAYACAKLAR_TR.md](UNUTULMAYACAKLAR_TR.md) mandatory every turn. No painting/objects or P1.4 writes.

## Implementation
core/tile_dense_buffer.gd: C copies stride-aligned rectangular canonical Float32 heights and one-stride halo via B's validated short-lived view; no disk or source reference after copy. World edge clipped, dimensions max 35x35=4900 bytes LOD0, 19x19=1444 LOD1, 11x11=484 LOD2. Internal scalar read_finite_or_nan rejects invalid access; nonfinite never published. Dense get_height retains dictionary contract; rejects off-grid/out-of-buffer. Same generate algorithm for all 3, no precision or geometry change. generate_with_dense includes acquire, copy, release, geometry generation, buffer disposal; C only benchmark path, not runtime preview option. A default, B opt-in unchanged.
core/tile_sampling_benchmark.gd: exact resident halo, prewarm all paths, 6 balanced permutations repeated 4 times (24 per case, max120). Time.get_ticks_usec calling-thread wall elapsed, NOT hardware CPU time; excludes stats calls, parity comparison, IO and ArrayMesh/physics upload. Counts direct reads/view reads/LRU and dense payload only (no actual allocations/RSS measurement). No timing threshold in CI. Timed results checked exact vertices/normals/colors/UV/indices/collision each run. test_sampling_benchmark.gd: two genuine matched 576² fixtures, 7 cases each incl. interior shard crossing, mixed edges, LOD0/1/2 and world corners; no disk reads/evictions during case, missing resident page ERR_BUSY, off-grid/out-of-view rejection. 1008 timed builds + warmups.
## Measured result, one Linux headless CI run
AMD EPYC 9V74, Godot 4.7.2 official. Microseconds per build, arithmetic mean of 24 samples for each case.
| Format | Tile | LOD | Neighbor | A | B | C |
|---|---|---:|---|---:|---:|---:|
| TFM1 | 15,15 | 0 | same | 3428.5 | 2515.7 | 3268.9 |
| TFM1 | 15,15 | 1 | same | 989.3 | 728.5 | 959.8 |
| TFM1 | 15,15 | 2 | same | 316.3 | 244.3 | 325.9 |
| TFM1 | 15,15 | 0 | mixed | 3647.5 | 2687.4 | 3434.1 |
| TFM1 | 0,0 | 0 | same | 3360.0 | 2521.3 | 3209.5 |
| TFM1 | 17,17 | 2 | same | 285.4 | 230.7 | 298.6 |
| TFM1 | 16,16 | 1 | mixed | 1013.4 | 758.9 | 991.5 |
| TFM2 | 15,15 | 0 | same | 3518.3 | 2545.3 | 3321.6 |
| TFM2 | 15,15 | 1 | same | 992.0 | 751.6 | 967.8 |
| TFM2 | 15,15 | 2 | same | 318.7 | 248.3 | 330.6 |
| TFM2 | 15,15 | 0 | mixed | 3646.6 | 2699.8 | 3453.6 |
| TFM2 | 0,0 | 0 | same | 3345.0 | 2529.9 | 3198.0 |
| TFM2 | 17,17 | 2 | same | 287.5 | 232.2 | 303.7 |
| TFM2 | 16,16 | 1 | mixed | 1020.7 | 766.9 | 1011.9 |
Equal-weight mean A 1869.22 us, B 1390.05 us, C 1791.09 us. B mean lower by 25.63% vs A and wins 14/14; C mean lower by 4.18% vs A but slower than B in every case. Individual tails vary; 24 samples means p99 is max, not robust tail distribution. Raw per-case p50/p95/p99 and work counters retained in P1_5_4B_SAMPLING_CI.json. These are one runner's warm resident results, not game FPS, Android CPU/RAM or universal performance ranking. C copies data and still returns per-sample Dictionary; do not generalize result to future scalar/worker-owned buffer implementation.
## Decision
Keep A default, B experimental, C benchmark-only. B promising; neither accepted/rejected permanently. No claim of overall cache win; LRU ordering differs, real reload and streaming effects unknown. 36/36 CI, previous 35 preserved.
## Next P1.5.4c — trace validation
1. Read this, UNUTULMAYACAKLAR_TR.md EXP-01, preview, profile scene, async reader, B/C code. Add explicit experimental sampling strategy in preview/profile while preserving old bool compatibility (A default; B toggle legacy mapping; C opt-in only). Capture chosen effective mode in report. No implicit fallback.
2. Deterministic fixed step camera trace (not variable wall-time route only), same matched world/route/cache/job caps, stationary/slow/fast/teleport, minimal 9 and normal 16 cache; compare A/B/C reload/evictions/hits/queue cancel, geometry builds and actual pump/frame time, RSS/bytes, missing collision shapes. Cold/warm order repeat; no flaky CI timing gate. CI bounded small fixtures, Android repeat separately; no fabricated GPU or actual physics claims. Test failure isolation with B and C across shard and stale camera, preserve last-good. 
3. Only after trace evidence choose whether to pursue scalar/dictionary removal or reusable topology; isolate changes and preserve parity. P1.5.5 worker input ownership remains separate, copied dense C may be useful even if slower synchronously; explicit byte cap and worker lifetime required. Device acceptance still EXPERIMENTAL, see all EXP entries. No P1.4/painting/objects.
