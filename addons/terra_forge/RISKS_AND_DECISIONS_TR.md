# TerraForge — Karar Günlüğü, Risk Kaydı ve Geri Dönüş İlkeleri

> **GÜNCEL DEVİR — P1.5.8b1 CI_VERIFIED (24 Kasım 2026):** 65091b3b99271264fcd3d7d5c965229759c6216c, [60/60 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45480640069), [ham JSON](P1_5_8B1_ADAPTIVE_CI.json). 8 pairs fixed/adaptive, 16×150 ticks, disk reads674→546, denied78→66, builds216→168 (warmup included), abandoned8→0, no ground loss. Horizon133–200ms, one observed publication per adaptive case. No equal-work/Android claim. NEXT P1.5.8b2 multi-seam roundtrip, live direction reversal, stop/expiry, verified relocation invalidates old forecast; 16×480 ticks, four test processes, CI_PENDING. Preserve A default and fixed option, P1.4/P1.4R PARKED.


> **GÜNCEL DEVİR — P1.5.8a CI_VERIFIED (24 Kasım 2026):** 0a13c04a171d953a785c54ef218a381c73056825, [58/58 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45478566656), [ham JSON](P1_5_8A_PREFETCH_CI.json). 8 pairs, 16×150 ticks, denial 212→54 (-74.5%), longest24–29→2–3, no floor/ray gaps, reads240→452 (+88.3%), builds128→196 (includes warmup), no equal-work or Android claim. 24-speed common goal tick93/94→70/74; 12-speed neither reaches goal. Keep opt-in. NEXT P1.5.8b1 bounded adaptive horizon based on selected-to-first publication latency, CI_PENDING; fixed0.5 vs adaptive0.125–0.5, 16 traces TFM1/2 A/G cache9/16 speed24 cap4. No precise IO attribution, no adaptive default, P1.4/P1.4R PARKED.


> **P1.5.8a CI FAILURE / RETRY (24 Kasım 2026):** 26ba70f6860fe14e3e546d04346c71bbf68b99d0, [56/58 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45476545781), job 138738162573. Both first predictive A/12 traces had 5 denied ticks vs baseline24, longest2, zero missing/airborne, verified two transfers (both10,new-only13), old eviction13. Test incorrectly required eviction >=96 even after successful early transfer; failed before G/24 cases. Not full acceptance. Fix causal eviction invariant: OLD absent only after actual verified transfer, every post-pump footprint matches held keys, baseline time assertion unchanged. Paired comparison uses shared single-seam waypoint x536 (before next seam544) for both paths; original e3 route unchanged. Record demanded/admitted ticks, goal and actual position; no equal completed work claim. No production code or safety threshold change. Retry CI pending.


> **GÜNCEL DEVİR — P1.5.7e3 CI_VERIFIED (24 Kasım 2026):** b6610de889dd2bc93ac5c1c85a94990d95da55ae, [56/56 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45474716862), [ham JSON](P1_5_7E3_TRANSFER_CI.json). 16 ×150 actual physics ticks, zero missing ground or airborne, exactly two transfers, old eviction tick96, stalls24–30 ticks, resume32–34, max4 readiness rays/tick. Guard p95 upper0.138–0.248ms, pump A4.932–5ms / G1.432–2ms. Fixed synthetic camera return tick24; no production controller/device proof. NEXT P1.5.8a opt-in player motion corridor integrated, 16 paired traces cap4 and speeds12/24, CI_PENDING; no performance conclusion until logs. P1.4/P1.4R PARKED; A default unchanged.


> **GÜNCEL DEVİR — P1.5.7e2 CI_VERIFIED (24 Kasım 2026):** f17e311461f5d0b95fc3680d5d15b8dee4cbb3b6, [54/54 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45472547229), [ham JSON](P1_5_7E2_RETENTION_CI.json). 16 ×120 ticks; each baseline 102 missing rays/119 airborne/17 changed bodies, each held 0/0/0, drift0, three equal-height shape reuses, zero changed-height replacements. Caps4/8, pages16, geometry reservations <=2. Fixed synthetic camera jumps, stationary actor, no equal completed geometry or Android claim. A p95 upper bounds baseline3.485–3.617ms, held3.589–4ms; G both1ms upper bounds. NEXT P1.5.7e3 lease-aware movement admission and continuous measured cold seam transfer, 16 ×150 ticks, CI_PENDING. No production movement controller, default unchanged, P1.4/P1.4R PARKED. Prior CI failure retained.


> **GÜNCEL DEVİR — P1.5.7e1 (24 Kasım 2026):** Kod 4e7dfa8b2a032d6dd9e316c83a071987de600c6d, [52/52 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45470559534), pure selector 21 checks. [Raw JSON](P1_5_7E1_SELECTION_CI.json). NEXT P1.5.7e2 live opt-in support retention implemented, CI PENDING: current verified footprint session/revision, cap rejection, priority, sync neighbor signature check, equal-height shape reuse and changed-height real replacement. 16 controlled 120-tick baseline/held traces planned by test, TFM1/2 A/G cap4/8, two test processes for timeout headroom. No results or production guarantee yet. [Design](P1_5_7E_SUPPORT_RETENTION_TR.md). No default changes; P1.4/P1.4R PARKED; all experimental/device gates remain. User requested deeper engineering; compare metrics and failures, not file/test count.


> **GÜNCEL DEVİR — P1.5.7d (24 Kasım 2026):** Kod 674836b995d15f52dbbd12028de526d45d4d16ac, [51/51 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45468357023). [Rapor](P1_5_7D_GUARDED_CAPSULE_TR.md), [ham JSON](P1_5_7D_GUARDED_CAPSULE_CI.json). Four TFM1/2 × A/G diagnostic cases: six denied ticks, zero measured horizontal drift from first denial to resume, peak four readiness rays per observed tick, actual seam traversal after explicit staged pause. Not equal-speed A/G comparison or continuous streaming proof. NEXT P1.5.7e1 pure bounded support selection implemented, CI pending; no live preview changes. P1.5.7e2 only after CI: opt-in session-scoped current-support retention, actual physics checks and camera movement test; no guarantee yet, then P1.5.8. P1.4/P1.4R PARKED; A default and all device/experimental gates preserved.


> **GÜNCEL DEVİR — P1.5.7c (24 Kasım 2026):** Kod c29d538ef220c68ac735a31b692d7c6189787239, [50/50 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45463462975). [Rapor](P1_5_7C_COLLISION_READINESS_TR.md), [ham JSON](P1_5_7C_COLLISION_READINESS_CI.json). TFM1/2 × A/G four cases, cold and boundary missing_lod0, four center rays confirmed, pending/excluded/outside/stop rejected. Query only, not continuous sweep or movement guarantee. P1.5.7d isolated actual capsule horizontal admission experiment added next; CI PENDING. Explicit staging/settle is diagnostic only, no production controller, no predictive prefetch yet. P1.4/P1.4R PARKED, all device and experimental gates open.


> **GÜNCEL DEVİR — P1.5.7b (24 Kasım 2026):** Kod 1da154b8c98472cdbf2239c4bbd3dcce4039ee96, [49/49 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45462434054). [Rapor](P1_5_7B_DYNAMIC_PHYSICS_TR.md), [ham JSON](P1_5_7B_DYNAMIC_PHYSICS_CI.json). Eight warm actual capsule runs: zero airborne ticks/missed rays/penetration, both seams crossed at12/24 units/s. Separate 144-tick streaming route each 35 missing actual ray steps, longest A24/G25, metadata agrees at sampled points; includes teleport, not continuous player walking. P1.5.7c bounded collision readiness query implemented next, CI pending. No safety guarantee; no production movement change. P1.4/P1.4R PARKED.


> **GÜNCEL DEVİR — P1.5.7a (24 Kasım 2026):** Kod fe9cefc11d05c5dc2546d4db2caff58ff97d7af8, [48/48 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45460991716). [Rapor](P1_5_7A_PHYSICS_RAYCAST_TR.md), [ham JSON](P1_5_7A_PHYSICS_RAYCAST_CI.json). 648 actual in-tree successful ray probes, zero mesh diagonal mismatches, max delta 0.000009536743 world units, TFM1/2 A/G, spacing1 translation+yaw. Eviction, last-good after scratch missing page, recovery, stop no hit. Default physics setting on Linux, not Android or general all terrains. P1.5.7b dynamic capsule crossing + actual moving ray coverage implemented next, CI pending. P1.4/P1.4R PARKED.


> **GÜNCEL DEVİR — P1.5.6d (24 Kasım 2026):** Kod 9fdbef19e3f6ef02e76fb40e7dfdd841e68126de, [47/47 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45460013242). [Rapor](P1_5_6D_PUBLICATION_COMPARISON_TR.md), [ham JSON](P1_5_6D_PUBLICATION_COMPARISON_CI.json). 16 equal-work +24 trace runs; 64/128KiB reduces per-pump peak source allowance to116052 from up to261368 but slower equal-work wall and fewer trace publications; same sampled collision gaps. 256KiB close to disabled. Keep budget opt-in and A default. Stale deferred result discarded/recovered. P1.5.7a actual physics-space raycast experiment implemented next, CI pending. P1.4/P1.4R PARKED. No GPU/Android proof.


> **P1.5.6c CI closure (24 Kasım 2026):** Original run 45458966071 cancelled by docs-only push (workflow cancel-in-progress); identical code in f699c146402228288a4922b7b4a3bbb2996fcc12 passed [46/46 CI](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45459264528). [Raw JSON](P1_5_6C_TOPOLOGY_CI.json). G/H worker means 1.042/0.984ms, 5.53% lower, same coverage 32 missing steps. H experimental, no GPU/Android claim. P1.5.6d benchmark implemented in this commit; pending CI. P1.4/P1.4R PARKED.


> **GÜNCEL DEVİR — P1.5.6c (24 Kasım 2026):** Kod 2c34c8057b10a090b374974ac6d23daadf67b082, [CI](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45458966071). [P1_5_6C_TOPOLOGY_TR.md](P1_5_6C_TOPOLOGY_TR.md). Code pushed; CI in_progress/pending. Import and editor activation passed, full suite not yet verified. Do not claim 46/46 or benchmark result; FIRST retrieve CI logs and complete evidence. H mode6 opt-in, G unchanged; three per-session immutable-by-contract templates, 32256 bytes, independent copied output indices; no shared GPU buffers, no memory reduction claim. P1.5.6b 45/45 and report recorded. **NEXT verify P1.5.6c CI and save raw results, then P1.5.6d publication-budget comparison**. P1.4/P1.4R PARKED; all earlier experiments and unresolved device/physics gates retained.


> **P1.5.6b (24 Kasım 2026):** Kod 5e210c2f8f4b2737713bcbc82dba6811f586290c, [45/45 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45455416391). [Rapor](P1_5_6B_PUBLICATION_BUDGET_TR.md), [ham JSON](P1_5_6B_PUBLICATION_BUDGET_CI.json). Opt-in source-byte/count/measured publication time admission; four warm mixed tiles across 3 pumps, two first-item oversized exceptions, zero worker duplicates/drops. No GPU timing. NEXT P1.5.6c topology reuse experiment. P1.4/P1.4R PARKED.


> **P1.5.6a (24 Kasım 2026):** Kod 934f68bb0bce7cf43c48adcba191570c3fde5504, [44/44 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45453236978). [Rapor](P1_5_6A_PUBLICATION_TR.md), [ham JSON](P1_5_6A_PUBLICATION_CI.json). Optional observation; source-array allowance only, not GPU bytes/time. Six A/C/G traces at 8ms target, no 128KiB or 1ms publication overshoot with one tile/pump. NEXT P1.5.6b opt-in budget, defer worker result in original bounded queue, single-item progress. P1.4/P1.4R PARKED.


> **GÜNCEL DEVİR — P1.5.5e (24 Kasım 2026):** Kod 6051f1aceeefa56542a33a0603c3c614b8b658f1, [43/43 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45450882358). [P1_5_5E_SCALAR_WORKER_TR.md](P1_5_5E_SCALAR_WORKER_TR.md), [ham JSON](P1_5_5E_SCALAR_WORKER_CI.json). G explicit experimental sampling_strategy=5 (F priority + dense scalar). Exact 14 worker cases and 8 equal-work runs, 256 timed publications. Worker build mean F 1.151 ms vs G 0.809 ms (29.73% less); main/wall no material gain, same cadence F/G coverage identical 32 missing shape steps for both page caps. 16 C/E/F/G fixed 8ms traces. A default unchanged. **NEXT P1.5.6a publication instrumentation and byte/count/time budget design**, no claim of GPU measurement; remaining worker coverage/pending-prune and D live/topology gates stay open. P1.4/P1.4R PARKED per explicit user decision; no painting/objects.


> **GÜNCEL DEVİR — P1.5.5d (24 Kasım 2026):** Kod 161346b356abe59a38876fc243ff950b21d0c4a1, [42/42 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45449446366). [P1_5_5D_PRIORITY_WORKER_TR.md](P1_5_5D_PRIORITY_WORKER_TR.md), [ham JSON](P1_5_5D_PRIORITY_WORKER_CI.json). F=explicit experimental priority worker mode4; A default, E unchanged. 24 C/E/F traces, two cadences, two page caps, both formats. F reduces missing shape steps vs E in all measured groups; cap16 still behind C, modest pump overhead. 8ms target no full-period deadline misses in this run. No actual physics raycast/rendered FPS/Android proof. **USER DECISION: P1.5 first; P1.4/P1.4R PARKED until P1.5 work complete or user changes order.** NEXT P1.5.5e: isolate dense scalar worker compute latency, preserve exact output and compare E/F vs candidate; then P1.5.6. Keep all experiments, no painting/objects.


> **GÜNCEL DEVİR — P1.5.5c (24 Kasım 2026):** Kod 8479fdc8f8f6dd94db7b8816042d69e91859045a, [41/41 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45448297981). [P1_5_5C_WORKER_COMPARISON_TR.md](P1_5_5C_WORKER_COMPARISON_TR.md), [ham JSON](P1_5_5C_WORKER_COMPARISON_CI.json). 24 equal-work runs (768 timed tile publications, 96 warmup), 48 fixed 144-pump traces (6912 pumps). E reduces equal-work main elapsed but moving trace builds fewer tiles and has more missing collision-shape steps; keep E opt-in, A default. **NEXT: P1.4R read-only design checkpoint** (user explicitly asked whether P1.4 forgotten), [P1_4_RETURN_CHECKPOINT_TR.md](P1_4_RETURN_CHECKPOINT_TR.md). P1.4 writable implementation remains PARKED until design decision/authorization. Resume P1.5.5d worker coverage fix after checkpoint; P1.5.6+ remain open. No painting/objects; no Android/GPU/raycast proof.


> **GÜNCEL DEVİR — P1.5.5b (24 Kasım 2026):** Kod 16731d424112edda219355436a04b7337f631e8b, [40/40 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45446183057). [P1_5_5B_WORKER_PREVIEW_TR.md](P1_5_5B_WORKER_PREVIEW_TR.md), [ham JSON](P1_5_5B_WORKER_PREVIEW_CI.json). E worker explicit experimental sampling_strategy=3, A default unchanged; unique outstanding tile reservations, current epoch/LOD/neighbor validation, bounded synchronous publication, TFM1/2 real mesh/shape, missing-page retention and TFM2 cold missing shard recovery. 19 published, 2 discarded per format. **NEXT P1.5.5c:** controlled sync C vs worker E same fixed completed workload and separate moving trace; quantify main-thread copy/publish/pump, queue/delivery, coverage, wasted work; cap1/2/4 and repeat orders. No Android FPS/GPU proof. All EXP gates remain open, P1.4 parked, no painting/objects.


> **GÜNCEL DEVİR — P1.5.5a (24 Kasım 2026):** Kod cb63d03b665feccab7aca7d64b56569ea7aed3df, [39/39 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45443035828). [P1_5_5A_GEOMETRY_WORKER_TR.md](P1_5_5A_GEOMETRY_WORKER_TR.md). Isolated one-worker prototype, 14 exact array parity cases, owned dense input survives page eviction, bounded slots, stale neighbor/epoch/reopen rejection. No live preview integration yet; A default/B+C opt-in/D benchmark-only unchanged. **NEXT P1.5.5b:** audit worker ownership/lifetime, opt-in live integration with bounded publication and no duplicate outstanding tiles, test actual mesh/shape and failure/epoch/LOD isolation. Android/large-world and old EXP gates open. No painting/objects, P1.4 parked.


> **GÜNCEL DEVİR — P1.5.4d (24 Kasım 2026):** Kod 8c2f7675a3c78b9356aeb98f3dfbf850727c199f, [38/38 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45441554202). [P1_5_4D_SCALAR_BENCH_TR.md](P1_5_4D_SCALAR_BENCH_TR.md), [ham JSON](P1_5_4D_SCALAR_CI.json). B/D exact parity and equal work; 14 cases × 32 rounds × 2 methods = 896 timed builds. B 1190.16 us, D 827.09 us equal-weight mean; D 30.51% lower than B, 14/14 mean wins on one runner. 293312 height reads per method; D avoids per-sample result dictionary, not measured allocator bytes. A default, B/C opt-in, D benchmark-only. **NEXT P1.5.5a:** bounded pure-array worker design and ownership prototype; keep D experiment pending live trace and device. No painting/objects, P1.4 parked. Mandatory UNUTULMAYACAKLAR_TR.md.


> **GÜNCEL DEVİR — P1.5.4c (24 Kasım 2026):** Kod 94beaeb2cd068e7bf5a09fc9b23b97b98a44d92d, [37/37 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45440552536). [P1_5_4C_STREAM_TRACE_TR.md](P1_5_4C_STREAM_TRACE_TR.md), [ham JSON](P1_5_4C_STREAM_TRACE_CI.json). 12 fixed 144-pump traces (TFM1/2 × cache9/16 × A/B/C); B lower mean pump in all four groups, equal-weight means A 0.722, B 0.568, C 0.676 ms; 21.26% lower B vs A on one runner, work differs at cap16. Shape-missing steps 34/144 cap9,29/144 cap16 for all methods; no raycast or actual render frames. A default, B/C explicit experiments. **NEXT P1.5.4d:** isolate allocation/topology optimization via fixed resident benchmark; preserve exact geometry and opt-in. Device/long soak and real trace repeats open. P1.4 parked; no painting/objects. Read UNUTULMAYACAKLAR_TR.md.


> **GÜNCEL DEVİR — P1.5.4b (24 Kasım 2026):** Kod da123dca5be609cc67c6b18f181b91abdc962404, [36/36 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45439854530). [P1_5_4B_SAMPLING_BENCH_TR.md](P1_5_4B_SAMPLING_BENCH_TR.md), [ham ölçüm](P1_5_4B_SAMPLING_CI.json). A/B/C exact array parity, 14 warm-resident cases × 24 rounds × 3 methods = 1008 timed builds. Equal-weight mean A 1869.22 us, B 1390.05 us, C 1791.09 us; B 25.63% lower than A, wins 14/14 means on one Linux runner. Not mobile FPS or isolated CPU time. A default, B opt-in, C benchmark-only. **NEXT P1.5.4c:** fixed camera trace A/B/C, page/job/cache/RSS/reload and frame/pump comparison; device gates still open. [UNUTULMAYACAKLAR_TR.md](UNUTULMAYACAKLAR_TR.md) mandatory every turn. No painting/objects or P1.4 writes.


> **ZORUNLU İLK OKUMA — [UNUTULMAYACAKLAR_TR.md](UNUTULMAYACAKLAR_TR.md):** Kullanıcının 24 Kasım 2026 kararı: deneysel yöntemleri, önceki açık ölçüm/cihaz kapılarını ve ertelenen işleri unutma. Her turda bu dosyayı güncelle. P1.5.4b sıradaki iş: A (eski), B (tile view), C (bitişik Float32 tampon) karşılaştırması; varsayılan değişikliği yok. CI kanıtı performans/Android kabulü değildir. Bu güncel talimat tarihsel plan satırlarından önceliklidir.


> **GÜNCEL DEVİR — P1.5.4a (24 Kasım 2026):** Kod 285122ecc826616f3c3840a41ad4e34223afc0fa, [35/35 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45436882446). [P1_5_4A_TILE_VIEW_TR.md](P1_5_4A_TILE_VIEW_TR.md) as-built. Bounded synchronous tile view, exact TFM1/TFM2 geometry parity, deterministic LRU work reduction; experimental opt-in default false. **Sıradaki P1.5.4b:** fixed-workload CPU A/B microbenchmark and profile, reduce dictionary allocation per sample if evidence supports, maintain all-array parity and fail-closed. P1.4 parked; actual large-world and Android proof open; boya/obje yok.


> **GÜNCEL DEVİR — P1.5.3b B4 (24 Kasım 2026):** Kod 0ba10c27a66117eadf63e01e3563a7cb48bcf037, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45434699275). [P1_5_3B4_PROFILE_TR.md](P1_5_3B4_PROFILE_TR.md) as-built. B4 profil altyapısı DONE: dual format matched fixture, 81 byte-identical TFR1 pages, four strict/lazy runs, TF_PROFILE_3, 4096/8192 V2 generation options and storage gate. Actual large-world and Android benchmarks OPEN. **Sıradaki P1.5.4a:** profile-driven CPU sampling audit, bounded tile read views, no per-sample LRU touches, exact geometry parity. P1.4 parked; boya/obje yok.

R-31: session recipe hint not external content proof; strict scan synchronous; no GPU/phone claims.


> **GÜNCEL DEVİR — P1.5.3b B3b (24 Kasım 2026):** Kod de0c6f1672b989ab5fd14169d7a54040962b98a0, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45433789697). [P1_5_3B3B_PREVIEW_TR.md](P1_5_3B3B_PREVIEW_TR.md) as-built. B3b DONE: explicit TFM2 preview, real ArrayMesh/HeightMapShape3D, 576² four interior shard intersection, LOD0/1/2 and mixed seam parity, last-good failure retention, camera recovery. **Sıradaki B4:** reproducible dual-format profile scene, explicit fixture format/size, bounded worker, disk estimate and cancel, root/shard and frame/collision telemetry, actual device profiling remains open. TFM1 default; P1.4 parked; boya/obje yok.

R-30: headless shape/mesh evidence not raycast/GPU/mobile proof; mixed LOD geometry parity not all possible seams.


> **GÜNCEL DEVİR — P1.5.3b B3a (24 Kasım 2026):** Kod 03b37b1656616e442ec015d01433517e51700cb9, [33/33 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45432431156). [P1_5_3B3A_ASYNC_TR.md](P1_5_3B3A_ASYNC_TR.md) as-built. B3a DONE: explicit open_v2, pinned root, worker-owned bounded shard LRU, exact compact verification/error telemetry, cross-shard async tests. **Sıradaki B3b:** opt-in TFM2 paged preview mesh/LOD/normal/collision integration, actual cross-shard geometry parity and failure isolation; default TFM1 preserved. B4 device profiling after B3b. P1.4 parked; Android GPU/RSS/FPS proof open, boya/obje yok.

R-29: cached verified bytes stable not hot reload; strict synchronous, lazy error array max ~1MiB; device measurement pending.


> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

R-28: read_from_shard precondition pinned root; no crash-power durability, no huge-world device proof. 8192 preflight only.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

R-27: checksums not authentication, B1 index validation not page verification, private buffers by convention. Large world device capacity unproven.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

R-26: estimated free-space gate not reservation, inode/actual bytes differ, orphan stage after kill, flush/rename not power-loss proof. 2048 performance not verified.


> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

R-23: stale semaphore backlog mitigated, in-flight uncancellable. R-24: TFM1 10k/2MiB limits block 4096²+. R-25: per-sample LRU touch suspected cost, measure before rewrite.


> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

R-22: profiler ölçüm overhead, OS page cache, shader warm-up, process-wide sampled RSS; headless GPU süresi yok. First collision shape attached, raycast/traversal değil. RSS unsupported null, Godot static ayrı. Strict/lazy ters sırada tekrarlanmalı.


> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

R-21: Hasarlı page yakın tile üzerinden head-of-line blocking yapabiliyordu. Artık generation-local blocked tile; aynı koordinatta mevcut sağlam geometry korunur. Hiç yüklenmeyen tile veya view dışı tile için collision garanti edilmez. Retained LOD komşu seam QA gerekir; gerçek Android ve P1.4 açık.


**Güncel as-built:** v0.4.4-dev.1 / 24 Kasım 2026. **Status:** Bazı çekirdekler Linux CI PASS; Android performans/doğallık kanıtı yok. Risklerin giderilmiş olması için ayrıca belirtilen kabul testi şarttır.

## A. Değiştirilmeyecek temel kararlar

| ID | Karar / gerekçe | Geriye dönük davranış |
|---|---|---|
| D-01 | Repo `mehmetdem2005/FareOyunu`, çalışma dalı `feat/terraforge-mobile-addon` | `main` veya oyun sahneleri değişmez; yalnız addon ve CI workflow |
| D-02 | Telefon / Android 11 / Godot 4.7.2 hedefi; küçük ekran ve kontrol | Kompakt 3D toolbar popup, büyük bottom dock yok |
| D-03 | Geometri, veri, fizik ve LOD öncelikli | Malzeme boyama ve obje/bitki yerleştirme durduruldu |
| D-04 | Float32 master, gerçek kaynak bit derinliği | JPEG/8-bit'lik kayıp veriyi EXR'e dönüştürmek gerçek 16-bit detay üretmez |
| D-05 | Mevcut `TFH1` source korunur | `Enable Layers` opt-in; TFH yedek, TFL2 tek otorite |
| D-06 | Eksik/bozuk source fail closed | Read-only, sahte düz height0 oluşturma yok; açık restore |
| D-07 | Staged, doğrulanmış export ve overwrite reddi | TFR1/TFM1 output yalnız yeni klasöre, kaynak sha korunur |
| D-08 | TFR1/TFL2/TFM1 checksum | SHA256 bütünlük kontrolü, yetkilendirme/şifreleme değil |
| D-09 | Sadece kanıtlı performans iddiası | CI Linux headless != Android GPU, daha hızlı oldu iddiası yok |
| D-10 | Jeomorfolojik nedensellik | Noise ve yuvarlak damga = referans doğa değildir; watershed + aşınma şart |
| D-11 | Tek sample/owner border | x=32, z=32 örnekleri iki disk sayfasında kopyalanmaz |
| D-12 | Render/physics node main thread | Worker sadece dosya/buffer/algoritma, Godot Node/Mesh güvenli uygulama ana thread |
| D-13 | Testte önce bağımsız prototip, sonra opt-in canlı mod | Eski sahnelere otomatik migration ve zorunlu format değişikliği YOK |
| D-14 | Godot ci çalıştırmadan “tamamlandı” deme | Dosya commit SHA + Actions run + PASS/FAIL logu gereklidir |

## B. Açık kritik riskler

### R-01 — Canlı RAM mimarisi hâlâ bütünü tutuyor
**Önem: ÇOK YÜKSEK.** TFR1/TFM1, read-only paged source, kamera scheduler ve asenkron worker çalışsa da `terrain/terra_forge_terrain.gd` doğrudan `height_data.heights` dizisini kullanır. UI'da “disk streaming” diye anlatılan resident tile yalnız mesh/collision'dır. 4096², 8192² ve 16k² için gerçek RAM yükü katlanır. **Önlem:** P1.2 sampler/senkron prefetch + P1.2b worker-thread IO DONE / 23 CI PASS; P1.3 read-only mesh/collision ve P1.4 edit transaction PLAN; gerçek Android profili yok.

### R-02 — Manifest/page tutarlılığı
**Önem: KRİTİK.** TFM1 `pages[].sha256` manifesti immutable snapshot'ı tanımlar. Bir TFR1 sayfası write_height/flush ile değiştiğinde manifest artık o sayfaya ait değildir. Page + manifest çift dosya yazımı sırasında crash, dünyanın “bir kısmı yeni, bir kısmı eski” olmasına yol açar. **Önlem:** Generations + copy-on-write + tek atomic head-pointer/manifest publish, journal, tüm sayfa SHA doğrulaması. Böyle bir transaction olmadan **canlı paged sculpt açma**.

### R-03 — Synchronous disk IO ve SHA frame hitch
**Önem: YÜKSEK.** TFR1 sayfa read/write, manifest full-check ve hashler senkron; TFL2 büyük dosya kaydı/main thread. Android düşük depolama hızı ve termal throttling ile dokunmatik editör donabilir. **Kısmi önlem DONE:** Bounded 1–8 **senkron** page read/tick, cache hit/miss ve IO last/max ms ölçülüyor. Bu bir frame-time garantisi değil. **Kalan:** background worker + bounded inflight, generation cancellation sonuç yayınında, cold source immutable buffer, main-thread scene commit.

### R-04 — Android gerçek test eksik
**Önem: YÜKSEK.** Godot 4.7.2 Linux headless CI 26/26 PASS, ancak Redmi/Android sürücü/gesture/perf kanıtı yok. Önemli yüzey mesh, collision ve UI problemleri önceden yalnız kullanıcı görselinden tespit edilmişti. **Önlem:** P0 cihaz smoke, 30 dk memory, FPS/ısınma; hata raporu ve birebir sahne.

### R-05 — Görsel LOD topoloji gerçekten stitched değil
**Önem: YÜKSEK.** Mevcut LOD komşu height uyarlaması ve normals daha iyi fakat T-junction, aşırı eğim normal, ani transition/popping, physics sınırı olabilir. **Önlem:** Analytical seam tests + ground-camera screenshot; gerekirse edge stitching ve geomorph; hızlı kamera hareketi test.

### R-06 — Çakma tepe / doğal olmayan drainage
**Önem: YÜKSEK.** Organic Stamp ve kıvrılmış Ridge/Valley **daha az simetrik**, fakat doğanın jeolojisini simüle etmez. MFD lokal analiz, akarsu/basin graph ve sediment taşınımı değildir. **Önlem:** Ridge graph + watershed + hidrolik/sediment fizik ve gerçek referans topografya kıyası. “Doğal” etiketi kullanımda ölçümsüz değil.

### R-07 — TFL2 backup sınırlılığı
**Önem: ORTA-YÜKSEK.** .bak yalnız önceki başarılı kayıt; ilk kayıt sonrası yok. Restore veriyi eski zamana alır. Disk doluluğu ve .bak / .tmp kopyalama zamanını Android henüz doğrulamadı. **Önlem:** Staging/yedek alanı ölçümü, backup retention, eylem öncesi kullanıcı uyarısı; test dünya ve kaynak export.

### R-08 — Layer + scene double-save semantiği
**Önem: ORTA-YÜKSEK.** `layer_mode` ve `layer_file` Godot .tscn ile, height deltas TFL2 ile saklanır. Kullanıcı yalnız `Terrain > Save` yapıp scene'i kaydetmezse yeni node özellikleri kalıcı olmayabilir. **Önlem:** Mobile UI uyarısı, sahne değiştiğinde guard, tekrar açılan packed scene testi (CI var), gerçek telefon UX.

### R-09 — Region snapshot editable layer kaybı
**Önem: YÜKSEK.** TFL1/TFL2 → TFR1 export yalnız visible composite; her layer'ı bağımsız edit edemezsin. Kaynak TFL silinirse non-destructive düzenleme verisi kaybolur. **Önlem:** TFL kaynak korunur; manifest `flattened_layers=true`; sonradan region layer schema/graph tasarla. Snapshot'ı TFL'nin yerine geçirme.

### R-10 — Boyut, dosya ve bellek üst sınırları
**Önem: ORTA.** RegionStore MAX_WORLD_CELLS=32768 ama Manifest max 10k sayfa ve 2MiB, yani bütün teorik MAX_WORLD_CELLS manifestle kullanılamaz. TFH/TFL max 2048 cell. Tek büyük aşırı IO veya milyonlarca metadata satırı olabilir. **Önlem:** World bounds/manifest kapasitesi/fail codes testleri ve gerekirse hiyerarşik manifest.

### R-11 — Float32 ve heightmap representasyon sınırı
**Önem: ORTA.** Heightfield tek (x,z) için tek y değeri tutar; gerçek mağara, overhang, düşey duvar altı “kapalı hacim” gösteremez. Float32 büyük dünyada konum hassasiyeti de sınıra yaklaşabilir. **Önlem:** Gerektikçe ayrı voxel/SDF veya mesh geçişi P5; mevcut basit heightfield'ı aşırı karmaşıklaştırma.

### R-12 — Mobil cihazın gerçek bütçesi
**Önem: ORTA-YÜKSEK.** CPU budget tile/frame sayı + ms vardır ama tek tile uzunluğu bütçeyi aşabilir. RAM raw page bytes ≠ gerçek RSS. GPU VRAM/driver state, terrain mesh draw call maliyeti hâlâ bilinmiyor. **Önlem:** p95/p99 profiler, GPU upload önbellek, aynı rota, 30 dk soak.

### R-13 — Android dosya izinleri ve export staging
**Önem: YÜKSEK.** `res://` write erişimi ve `user://` dosya yolları Android editörde farklı; staging klasörü disk doluluğu veya izin nedeniyle yarım kalabilir. **Önlem:** output path yazma kontrolü, staging çöp dosya recovery, kaynak SHA tekrar doğrulama, Android sahasında manuel test. `main`/oyun dosyalarına dokunma.

### R-14 — Çalışma bağlamı/sonraki sohbet unutması
**Önem: ÇOK YÜKSEK.** Uzun sohbet değişince son commit, biten faz ve koruma kuralları kaybolabilir. **Önlem:** `HANDOFF_START_HERE_TR.md` başlangıç otoritesi, bu karar/roadmap/status belgeleri, her commit sonunda güncelleme ve gerçek GitHub head okuma; asla eski özetleri kodun yerine koyma.

### R-15 — P1.2 doğrulama başlangıcında çok sayfalı senkron tarama ve kamera prefetch sınırları

**Önem: YÜKSEK.** `paged_height_source.open()` TFM1 manifestteki her TFR1 sayfasını senkron doğrular; büyük dünyada açılış beklemesi oluşabilir. `camera_page_prefetch.tick()` çağrı başına 1–8 disk okumasını sınırlar ancak tek okuma yavaş NAND'de frame süresini aşabilir. Pending generation iptali yalnız henüz başlamamış işleri kapsar, in-flight thread sonucu kavramı henüz yok. **Önlem:** P1.2b async/worker-safe IO, full-file SHA + data buffer snapshot, bounded pending/inflight, gerçek kamera stress ve Android p95/p99.

### R-16 — P1.2b thread lifetime / async başlangıç maliyeti

**Önem: ORTA-YÜKSEK.** Yeni `async_region_source.gd` worker Thread/Mutex/Semaphore ile 23/23 CI geçti, fakat `open()` tüm TFM1/TFR1 sayfalarını senkron tarar. `close()` thread içindeki son IO bitene kadar `wait_to_finish()` ile bloklanabilir; her karede aç/kapat yapılmaz. Mutable world source/manifest değişirse cache daha önce doğrulanmış height gösterebilir; P1.4 editable mode'da generation-bound immutable manifest gerekir. **Önlem:** P1.3 opt-in read-only test, P1.5 async full-world startup policy, Android uzun süreli IO thread stress.

### R-17 — İlk canlı render entegrasyonu yalnız ayrı preview

**Önem: ORTA-YÜKSEK.** Yeni `paged_terrain_preview.gd` gerçek ArrayMesh ve HeightMapShape3D oluşturur, fakat eski `TerraForgeTerrain` sistemi global height_data/heights dizisinde kalıyor. İki düğüm aynı dünya koordinatında birlikte açılırsa üst üste geometri/physics oluşabilir. [24/24 Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421) geometrik sayısal parity, Android Mobile Renderer görsel/driver/sıcaklık kanıtı değil. **Önlem:** Ayrı test sahnesinde opt-in; boyama/Undo/save disabled; eski live node migration ancak read-only phase ve regression sonrası.

### R-18 — Page halo, görünür tile ve collision bekleme

**Önem: YÜKSEK.** 32-cell tile için kenar normal ve collision üretiminde 3×3'e kadar TFR1 sayfa gerekir. Cache min 9 / varsayılan 16. Kamera hızla atlarsa en yakın tile hazır olmadan yeni bölgeler kısa süre boş olabilir; uzak LOD1/2 collision legacy gibi devre dışı. `open()` full world SHA senkron; `close()` join bloklayabilir. **Önlem:** Android 11 test, p95/p99 ve RSS profili; öncelikli prefetch/old LOD preservation; sonra büyük world lazy verification (fail-closed).

### R-19 — Gereksiz uzak sayfa IO ve minimum-cache halo thrash

**Önem: ORTA (İZOLE düzeltme uygulandı).** Önceki P1.3 önizleme, kamera hızla zıpladığında eskiden kalan worker job'ları iptal etmiyordu. 9 sayfalık cache'de gereken edge halo sayfalarının MRU önceliği de yoktu. `bf5c1dde`: >=2 region kamera sıçramasında `set_generation()`, `prioritize_resident()` (MRU hint, hard pin değil), `is_requested()` duplicate submit engeli. [CI 25/25 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507). **Kalan risk:** yavaş Android flash, GPU upload ve 30 dk gerçek kamera yürüyüşü ölçülmedi. Editör ve oyun sahnesi hâlâ ayrı test yolları.

### R-20 — Hızlı açılışta uzak sayfa sonradan bozuk/missing çıkabilir

**Önem: YÜKSEK (KABUL EDİLEN read-only mod semantiği).** `v0.4.4-dev.1` ile `async_region_source.open(...,false)` yalnız checksummed TFM1 manifestini doğrular; bütün TFR1 SHA kontrolleri **worker cold read** anına ertelenir. Uzak bozuk/missing sayfa başlangıçta kabul edilmiş dünyada sonradan tespit edilebilir. **Bu tam dünya onayı DEĞİL!** `get_height` başarısızlıkta sahte 0 döndürmez, ilgili tile mesh/collision oluşturulmaz. Eski `open()` strict default korunur; preview Inspector'da `verify_pages_on_demand=true` varsayılan, false strict. `stats.verified_at_open` ve Checked/Total, kullanıcıyı yanlış güvene sokmaz. [26/26 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664). **Kalan:** telefon cihazında gerçek render/IO, eski mesh koruma ve collision coverage testi, immutable generation-pinned multi-page transaction P1.4.

## C. Acil veri kaybı anında yapılacaklar

1. **Önce hiçbir dosyanın üzerine yazma.** GitHub kod dalı ve gerçek kullanıcının `terraforge_data` proje klasörünü ayrı yedekle.
2. Eski sahne `.tfh` eksik uyarısı veriyorsa yeni terrain ile üzerine yazma; aynı isimli orijinal TFH'yi geri getir.
3. `.tfl` bozuksa read-only; valid `.bak` varsa Restore **önceki kayıt** anlamına gelir; .corrupt_* kopyası korunmalı.
4. `TFR1` bir page bozuksa world manifest validation fail closed; eksik sayfa 0 olarak doldurulmaz. Önce bütün kaynak .tfh/.tfl korunur; tekrar **farklı hedef klasöre** export denenebilir.
5. Yarım `.tmp` veya `.staging_*` dosyalarını kaynak sanma; ne olduğunu doğrulamadan silme.
6. GitHub CI başarılı ama telefonda çökme varsa cihaz crash log/ekran kaydı topla; kurulumla ilgisiz sahne dosyasını asla değiştirme.
7. Geçerli kodda sorun varsa son doğrulanmış SHA arşivine geri dön; veri formatı geri dönüşü koddan bağımsız olabilir, yedekleri koru.

## D. Açık araştırma/karar konuları

- En iyi runtime LOD seçeneği **ölçümle** belirlenecek: CPU-generated tile baseline vs quadtree/CDLOD vs GPU-displacement clipmaps.
- Bölge sayfa boyutu 32 örnek prototip; disk IO overhead ve cache locality için 64/128 deneyleri ancak sonrası veri uyumu stratejisiyle yapılabilir.
- Büyük haritalarda manifest hiyerarşisi, checksum yazma modeli ve thread-safe IO protokolü netleştirilmeli.
- Erozyon gerçek zamanlı mı offline preprocess mi? Android CPU gereksinimi ve deterministik katmanlar nedeniyle önce offline/bounded job prototipi.
- Layer graph yalnız additive mi kalacak, procedural modifier DAG mı olacak? P6'da yeniden değerlendirilir.
- Kıyı/nehir height geometry'nin su render modülüne entegrasyonu gelecekte olabilir ama bugün sadece terrain geometri.
- Collision LOD ya render'dan bağımsız mı olmalı? Yakın fare-bakış kalitesine göre gerçek testle karar.

## E. Karar güncelleme şablonu

**D-XX:** karar başlığı | alternatifler | neden seçildi | kaybedilenler | değişen dosya/commit | CI run | Android test | geri dönüş yolu.  
**R-XX:** risk şiddeti | yeniden üretme senaryosu | zarar | koruyucu invariant | test / kabul | açık sorumlu faz.

Referans: [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md), [STATUS_AND_CHANGELOG_TR.md](STATUS_AND_CHANGELOG_TR.md), [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md).
