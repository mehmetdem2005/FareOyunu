# P1.5.5c — C synchronous vs E geometry worker
> **GÜNCEL DEVİR — P1.5.5c (24 Kasım 2026):** Kod 8479fdc8f8f6dd94db7b8816042d69e91859045a, [41/41 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45448297981). [P1_5_5C_WORKER_COMPARISON_TR.md](P1_5_5C_WORKER_COMPARISON_TR.md), [ham JSON](P1_5_5C_WORKER_COMPARISON_CI.json). 24 equal-work runs (768 timed tile publications, 96 warmup), 48 fixed 144-pump traces (6912 pumps). E reduces equal-work main elapsed but moving trace builds fewer tiles and has more missing collision-shape steps; keep E opt-in, A default. **NEXT: P1.4R read-only design checkpoint** (user explicitly asked whether P1.4 forgotten), [P1_4_RETURN_CHECKPOINT_TR.md](P1_4_RETURN_CHECKPOINT_TR.md). P1.4 writable implementation remains PARKED until design decision/authorization. Resume P1.5.5d worker coverage fix after checkpoint; P1.5.6+ remain open. No painting/objects; no Android/GPU/raycast proof.

## Design and evidence
One AMD EPYC 7763 Linux Godot 4.7.2 headless run, no rendered frames or physics raycast. No production changes except experimental trace instrumentation. Equal-work: 4 fixed adjacent mixed-LOD tiles, 16 verified resident halo pages, 8 timed rebuild batches plus one warmup; C and E produce 32 tiles/run, 24 runs, ABBA for each format/cap combination. Identical resource fingerprints SHA256 from ArrayMesh surface arrays and collision data for all modes/repeats within each format; no IO/eviction in timed workload. Counts prevent duplicate submission; close with outstanding job tested. main_us_per_tile includes cumulative scheduler, submit/copy, poll and publish time; wall includes sleep and test-loop overhead; parity hashing after timing. Worker queue and build overlap main thread. P95 histograms in raw JSON; no flaky timing thresholds. 
| Cap | C main us/tile | E main us/tile | C wall us/tile | E wall us/tile | Main reduction % | Wall reduction % |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 2790.0 | 876.8 | 3087.6 | 3686.8 | 68.57 | -19.40 |
| 2 | 2801.0 | 875.3 | 3099.3 | 3116.6 | 68.75 | -0.56 |
| 4 | 2794.4 | 922.4 | 3092.0 | 2637.8 | 66.99 | 14.69 |
Means equal weight over both formats and two ABBA repeats per cap/mode; negative wall reduction = slower. Not hardware CPU time.

## Separate moving trace
Same fixed 144 steps and 2ms sleep, cache9/16, IO jobs4, max8 tiles, one publish and one submit per pump, 48 runs. ABBA groups, cap1/2/4. No OS cache flush, same process sampled RSS. Work differs; do not claim FPS or equal-work acceleration.
| Pages | E cap | C pump ms | E pump ms | C builds | E builds | C missing shape steps | E missing shape steps | E dropped |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 9 | 1 | 1.226 | 0.537 | 42 | 33 | 34 | 44 | 1 |
| 9 | 2 | 1.231 | 0.575 | 42 | 35 | 34 | 44 | 5 |
| 9 | 4 | 1.228 | 0.573 | 42 | 35 | 34 | 44 | 5 |
| 16 | 1 | 1.389 | 0.574 | 51 | 34 | 29 | 46 | 8 |
| 16 | 2 | 1.386 | 0.644 | 51 | 45 | 29 | 43 | 9 |
| 16 | 4 | 1.383 | 0.641 | 51 | 45 | 29 | 43 | 9 |
All final focus recovery passed outside measured trace. Missing shape at sampled focus is not actual raycast, falling, or elapsed collision-gap time. E main-thread reduction alone insufficient: moving coverage is worse. Keep A default, B/C/E explicit experiments, D benchmark-only. Cap4 improves warm batch throughput but does not improve moving coverage vs cap2 on this trace; don't increase default. Hypotheses (not yet isolated): additional copy/queue/delivery latency, low priority worker, near-focus priority vs far work, one submit/publish per pump, stale epoch discard; faster pump also advances synthetic camera faster in wall time. Compare fixed wall-clock camera trace and fixed work, not just pump steps. 
## Next actions
P1.4R now mandatory design review checkpoint, not implementation authorization. Then P1.5.5d: isolate near-focus scheduling/latency and obsolete pending jobs, actual physics coverage remains P1.5.7, maintain bounded ownership, no unsafe fake collision. Test neighbor removal and actual cap behavior, priority and missed shape count; preserve sync baseline. P1.5.6 publication budget and later phases still open. All earlier EXP records retained.
