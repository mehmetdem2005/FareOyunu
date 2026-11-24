# P1.5.6a — Publication accounting
> **P1.5.6a (24 Kasım 2026):** Kod 934f68bb0bce7cf43c48adcba191570c3fde5504, [44/44 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45453236978). [Rapor](P1_5_6A_PUBLICATION_TR.md), [ham JSON](P1_5_6A_PUBLICATION_CI.json). Optional observation; source-array allowance only, not GPU bytes/time. Six A/C/G traces at 8ms target, no 128KiB or 1ms publication overshoot with one tile/pump. NEXT P1.5.6b opt-in budget, defer worker result in original bounded queue, single-item progress. P1.4/P1.4R PARKED.

LOD0 1089 vertices,2048 triangles,116052 bytes including4356 shape bytes; LOD1 289/512/29264; LOD2 81/128/8016. Conservative 80 bytes/vertex (two Vector3 24 each, UV16, color16), index4, shape Float32 4. CPU source-array allowance, not actual allocation, upload, GPU residency or draw calls. Optional observe_publication pinned at open, enabled in profile only. Structural array validation when observing, no exhaustive sample scan. Count/size/time and per-pump peaks, resident counts after pump, reset on close. Histograms include zero-publish pumps, shape timing includes clearing on non-LOD0. Synthetic two-LOD0 overshoot verified. Both formats A/C/G exact resource counts, replacement, eviction, invalid structure retains old mesh, close/reopen. Six off-tree fixed 8ms traces, one publish per pump, 16 pages, 2 geometry slots. No actual GPU or raycast; no speed claim.

| Format | Mode | Count | Total source bytes | Mean main publish ms | Peak triangles |
|---|---:|---:|---:|---:|---:|
| TFM1 | 0 | 52 | 4212156 | 0.107 | 13312 |
| TFM1 | 2 | 51 | 4182892 | 0.104 | 13312 |
| TFM1 | 5 | 47 | 4152624 | 0.121 | 12800 |
| TFM2 | 0 | 52 | 4212156 | 0.101 | 13312 |
| TFM2 | 2 | 51 | 4182892 | 0.101 | 13312 |
| TFM2 | 5 | 47 | 4152624 | 0.120 | 12800 |

NEXT budget enforcement separate opt-in; keep original default; no extra queue.