# P1.5.4c — Fixed camera streaming experiment
> **GÜNCEL DEVİR — P1.5.4c (24 Kasım 2026):** Kod 94beaeb2cd068e7bf5a09fc9b23b97b98a44d92d, [37/37 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45440552536). [P1_5_4C_STREAM_TRACE_TR.md](P1_5_4C_STREAM_TRACE_TR.md), [ham JSON](P1_5_4C_STREAM_TRACE_CI.json). 12 fixed 144-pump traces (TFM1/2 × cache9/16 × A/B/C); B lower mean pump in all four groups, equal-weight means A 0.722, B 0.568, C 0.676 ms; 21.26% lower B vs A on one runner, work differs at cap16. Shape-missing steps 34/144 cap9,29/144 cap16 for all methods; no raycast or actual render frames. A default, B/C explicit experiments. **NEXT P1.5.4d:** isolate allocation/topology optimization via fixed resident benchmark; preserve exact geometry and opt-in. Device/long soak and real trace repeats open. P1.4 parked; no painting/objects. Read UNUTULMAYACAKLAR_TR.md.

## Code and compatibility
Preview sampling_strategy -1 uses old use_tile_read_view boolean (false A, true B); explicit 0/1/2 overrides old flag, invalid explicit values refuse start, selected strategy pinned at successful start, restart required. A remains default, B/C experimental. Profile scene explicit sampling dropdown, resolved strategy report setting, dense peak and accepted page reloads (successful accepted read count minus distinct accepted pages; excludes canceled/failed reads and physical storage-cache effects). Legacy bool retained. C dense payload peak <=4900 bytes, not total memory.
core/sampling_stream_trace.gd: off-tree real async reader + actual ArrayMesh/HeightMapShape3D resources, 576² matched fixtures, 144 pump steps, fixed positions and synchronization opportunity each step, 2ms sleep, stationary/slow/fast/teleports, max8 tiles, 4 jobs, 9/16 pages, V2 shard cap2, 1 tile build/pump, 8ms soft cap. Real scheduler timing varies; route fixed, not equal completed work or simulated seconds. Histograms measure pump and pump interval, not rendered frames or CPU hardware time. RSS sampled process-wide (same process for all runs, allocator retention confounds). Final recovery gate outside timed trace. Order alternates A/B/C or C/B/A between groups; no OS cache flush.
test_sampling_stream_trace.gd: 12 runs, bounds, legacy compatibility, final focus shape recovery, source manifest unchanged, B/C TFM2 cold missing page retains same-coordinate last-good mesh/shape, healthy origin recovery and old tile eviction, disposable page restored. No cold shard corruption variant specifically for B/C this turn; existing B3a/B3b verification tests remain, targeted shard case open. No physics raycasts.

## Measured on one headless Linux AMD EPYC 9V45 runner
| Format | Page cap | Mode | Mean pump ms | Builds | Accepted reads | Reloads | Evictions | Missing shape steps |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| TFM1 | 9 | A | 0.654 | 42 | 249 | 153 | 240 | 34 |
| TFM1 | 9 | B | 0.526 | 42 | 249 | 153 | 240 | 34 |
| TFM1 | 9 | C | 0.637 | 42 | 249 | 153 | 240 | 34 |
| TFM1 | 16 | A | 0.765 | 52 | 170 | 73 | 154 | 29 |
| TFM1 | 16 | B | 0.580 | 51 | 171 | 74 | 155 | 29 |
| TFM1 | 16 | C | 0.721 | 51 | 171 | 74 | 155 | 29 |
| TFM2 | 9 | A | 0.668 | 42 | 249 | 153 | 240 | 34 |
| TFM2 | 9 | B | 0.595 | 42 | 249 | 153 | 240 | 34 |
| TFM2 | 9 | C | 0.639 | 42 | 249 | 153 | 240 | 34 |
| TFM2 | 16 | A | 0.800 | 52 | 170 | 73 | 154 | 29 |
| TFM2 | 16 | B | 0.572 | 51 | 171 | 74 | 155 | 29 |
| TFM2 | 16 | C | 0.709 | 51 | 171 | 74 | 155 | 29 |

Equal-weight mean pump A 0.722 ms, B 0.568 ms, C 0.676 ms. B 21.26% lower than A, wins all 4 group means. At cap9 all modes identical accepted reads/reloads/build counts; cap16 A 52 builds/170 reads vs B/C 51/171. Thus not identical work; no broad CPU or FPS claim. At cap16 fewer reloads and missing steps than cap9 for this route, extra 7*4096=28672 bytes resident payload capacity. All cases same sampled RSS peak 124796928 bytes; cannot conclude memory equality or savings. No stale discarded jobs observed in this trace even though camera epochs changed; existing dedicated cancellation tests remain necessary. All 12 recovery gates passed. Raw reports retain p95/p99 bounds, counts, queue/camera and memory telemetry.

## Decisions and next P1.5.4d
Keep A default; B promising, C slower but potentially useful independent worker input; both explicit opt-in. No device acceptance. Before P1.5.5, isolate per-sample Dictionary allocation and/or reusable topology/preallocated geometry arrays as separate experiment, not bundled optimization. Read core/paged_tile_geometry.gd, tile_read_view.gd, tile_dense_buffer.gd, tile_sampling_benchmark.gd and tests. Prefer one minimal change first, e.g. a stride-aligned scalar geometry path with explicit finite/error contract or reusable topology arrays; compare old/new exact all-array parity, LOD0/1/2, mixed seams, world edges, failed pages, no changed physics/precision. Benchmark fixed resident workload and include allocation/copy cost; no flaky timing gate; leave default unchanged. If slower, keep experimental evidence and avoid deploying. Then worker ownership design P1.5.5 (single bounded pure-array worker, immutable input, cancellation identity). Device rendered frame/real raycast/long soak, repeated cold/warm trace and B/C cold shard targeted failure remain open; do not close EXP-01/02/03/04/05/06/07.
