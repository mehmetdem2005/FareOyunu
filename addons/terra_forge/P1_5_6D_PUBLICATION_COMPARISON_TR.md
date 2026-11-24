# P1.5.6d — Publication budget comparison
> **GÜNCEL DEVİR — P1.5.6d (24 Kasım 2026):** Kod 9fdbef19e3f6ef02e76fb40e7dfdd841e68126de, [47/47 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45460013242). [Rapor](P1_5_6D_PUBLICATION_COMPARISON_TR.md), [ham JSON](P1_5_6D_PUBLICATION_COMPARISON_CI.json). 16 equal-work +24 trace runs; 64/128KiB reduces per-pump peak source allowance to116052 from up to261368 but slower equal-work wall and fewer trace publications; same sampled collision gaps. 256KiB close to disabled. Keep budget opt-in and A default. Stale deferred result discarded/recovered. P1.5.7a actual physics-space raycast experiment implemented next, CI pending. P1.4/P1.4R PARKED. No GPU/Android proof.

Same G mode5, cap4, 16 pages, observation both sides, 1ms time target, updates2/3. 16 equal-work cases each32 measured +4 warmup, exact resource fingerprints, no extra IO, no duplicate jobs. 24 fixed 144-position traces 4/8ms, both formats. Stale deferred ID retained, neighbor removed, rejected then fresh ID recovered. One run per condition and format, no statistical confidence. Source-array allowance not GPU bytes; shape attached not raycast.

| Target bytes (0=off) | Mean wall us/tile | Mean main us/tile | Max peak source bytes |
|---:|---:|---:|---:|
| 0 | 1577.63 | 687.70 | 153332 |
| 65536 | 1892.72 | 716.48 | 116052 |
| 131072 | 1885.55 | 719.53 | 116052 |
| 262144 | 1599.04 | 697.98 | 153332 |

| updates/cadence us | off/64/128/256 KiB builds | missing steps | peak source bytes |
|---|---|---|---|
| 2/8000 | 55 / 54 / 54 / 55 | 33 / 33 / 33 / 33 | 232104 / 116052 / 116052 / 232104 |
| 3/8000 | 58 / 55 / 55 / 58 | 32 / 32 / 32 / 32 | 232104 / 116052 / 116052 / 232104 |
| 3/4000 | 56 / 55 / 55 / 56 | 32 / 32 / 32 / 32 | 261368 / 116052 / 116052 / 261368 |

64/128KiB caps reduce burst allowance but cost wall time; no collision improvement. 64KiB first-item exception needed for LOD0, not a hard cap. 256KiB nearly no deferrals. No default change or FPS/GPU claim. Remaining persistent churn, device, topology and physics gates retained.