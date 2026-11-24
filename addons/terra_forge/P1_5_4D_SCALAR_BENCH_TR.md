# P1.5.4d — Scalar sampling experiment
> **GÜNCEL DEVİR — P1.5.4d (24 Kasım 2026):** Kod 8c2f7675a3c78b9356aeb98f3dfbf850727c199f, [38/38 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45441554202). [P1_5_4D_SCALAR_BENCH_TR.md](P1_5_4D_SCALAR_BENCH_TR.md), [ham JSON](P1_5_4D_SCALAR_CI.json). B/D exact parity and equal work; 14 cases × 32 rounds × 2 methods = 896 timed builds. B 1190.16 us, D 827.09 us equal-weight mean; D 30.51% lower than B, 14/14 mean wins on one runner. 293312 height reads per method; D avoids per-sample result dictionary, not measured allocator bytes. A default, B/C opt-in, D benchmark-only. **NEXT P1.5.5a:** bounded pure-array worker design and ownership prototype; keep D experiment pending live trace and device. No painting/objects, P1.4 parked. Mandatory UNUTULMAYACAKLAR_TR.md.

## Implementation
core/paged_tile_geometry.gd adds generate_with_scalar_view: same validated bounded B lease, uses existing read_finite_or_nan for inner-loop heights and halo. Pre-acquisition preserves real page errors. Invalid/nonfinite internal samples return ERR_FILE_CORRUPT, no output arrays or fake zero; release lease on success/error. Same _generate body for array construction, normals, UV, color, indices, collision; separate scalar seam routine mirrors old corner precedence, mixed interpolation; future seam changes must update both and preserve exact tests. A/B/C baseline Dictionary path retained, no topology/preallocation/worker changes. D benchmark-only; no preview flag change. Success reads return scalar instead of Dictionary; not proof of measured heap allocation bytes.
core/scalar_sampling_benchmark.gd fixed resident 32 B/D rounds alternating ABBA; same actual page refs, reads, LRU and geometry; prewarm, stats and parity comparison outside timed interval. test_scalar_sampling_benchmark.gd two genuine matched 576² fixtures, 14 LOD0/1/2 same/mixed edge and corner cases, interior shard boundaries; all arrays exact against A on every build. Test missing resident data, invalid neighbor halo, revoked view NAN, cold missing page error propagated and no arrays/lease. No timed disk IO/eviction. 896 timed builds + warmups. No flaky timing threshold.
## Evidence
One Intel Xeon 6975P-C Linux headless runner, Godot 4.7.2 official. Elapsed calling-thread microseconds, not hardware CPU counters.
| Format | Tile | LOD | Neighbors | B mean us | D mean us |
|---|---|---:|---|---:|---:|
| TFM1 | 15,15 | 0 | same | 2179.5 | 1518.2 |
| TFM1 | 15,15 | 1 | same | 631.2 | 445.0 |
| TFM1 | 15,15 | 2 | same | 219.1 | 159.3 |
| TFM1 | 15,15 | 0 | mixed | 2318.5 | 1573.7 |
| TFM1 | 0,0 | 0 | same | 2116.0 | 1483.3 |
| TFM1 | 17,17 | 2 | same | 207.4 | 153.4 |
| TFM1 | 16,16 | 1 | mixed | 660.8 | 456.2 |
| TFM2 | 15,15 | 0 | same | 2184.5 | 1515.2 |
| TFM2 | 15,15 | 1 | same | 634.2 | 443.3 |
| TFM2 | 15,15 | 2 | same | 226.0 | 169.2 |
| TFM2 | 15,15 | 0 | mixed | 2301.0 | 1573.4 |
| TFM2 | 0,0 | 0 | same | 2115.5 | 1478.6 |
| TFM2 | 17,17 | 2 | same | 205.4 | 152.4 |
| TFM2 | 16,16 | 1 | mixed | 663.1 | 458.0 |
Equal-weight B 1190.16 us, D 827.09 us, 30.51% lower D vs B, 14/14 mean wins. 293312 scalar reads per method over the fixed timed workload, equal LRU count; no allocator/RSS delta measured. Different runner from earlier A/B/C benchmark: do not multiply percentages or compare absolute timings across runs. Raw per-case p50/p95/p99 retained; 32 samples p99=max. Not Android FPS, render frame, or raycast proof.
## Decision and next
Keep A default, B/C opt-in, D benchmark-only; no default change. D promising but live-stream comparison, cold shard variant, actual device acceptance still open. Optional topology/preallocation experiment deferred, not silently dropped.
P1.5.5a: read geometry, dense buffer, async reader, preview and all EXP records. Design separate worker-owned immutable input: explicit tile/LOD/neighbor signature, source snapshot identity + camera epoch, bounded input/output job and byte accounting, no borrowed main-thread lease or SceneTree/Mesh/Physics access from worker. First implement/test pure-array worker in isolation, one worker, explicit close/join and stale rejection; preserve sync preview default. Dense copy may be candidate for transferable ownership; benchmark cost separately. Add D runtime/trace only as explicit experiment after parity and failure checks; don't bundle with worker rollout. P1.5.4 remaining gates: topology/preallocation, IO phase timings, live D traces, Android repeated trace/30min soak, actual RSS/GPU/raycast remain open. P1.4 parked; no painting/objects.
