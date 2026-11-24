# TerraForge — CI, Test Matrisi, Android Performans ve Kalite Kapısı

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


> **GÜNCEL DEVİR — P1.5.4a (24 Kasım 2026):** Kod 285122ecc826616f3c3840a41ad4e34223afc0fa, [35/35 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45436882446). [P1_5_4A_TILE_VIEW_TR.md](P1_5_4A_TILE_VIEW_TR.md) as-built. Bounded synchronous tile view, exact TFM1/TFM2 geometry parity, deterministic LRU work reduction; experimental opt-in default false. **Sıradaki P1.5.4b:** fixed-workload CPU A/B microbenchmark and profile, reduce dictionary allocation per sample if evidence supports, maintain all-array parity and fail-closed. P1.4 parked; actual large-world and Android proof open; boya/obje yok.


> **GÜNCEL DEVİR — P1.5.3b B4 (24 Kasım 2026):** Kod 0ba10c27a66117eadf63e01e3563a7cb48bcf037, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45434699275). [P1_5_3B4_PROFILE_TR.md](P1_5_3B4_PROFILE_TR.md) as-built. B4 profil altyapısı DONE: dual format matched fixture, 81 byte-identical TFR1 pages, four strict/lazy runs, TF_PROFILE_3, 4096/8192 V2 generation options and storage gate. Actual large-world and Android benchmarks OPEN. **Sıradaki P1.5.4a:** profile-driven CPU sampling audit, bounded tile read views, no per-sample LRU touches, exact geometry parity. P1.4 parked; boya/obje yok.

Matched 81 byte-identical pages and four profile runs; large device benchmarks pending.


> **GÜNCEL DEVİR — P1.5.3b B3b (24 Kasım 2026):** Kod de0c6f1672b989ab5fd14169d7a54040962b98a0, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45433789697). [P1_5_3B3B_PREVIEW_TR.md](P1_5_3B3B_PREVIEW_TR.md) as-built. B3b DONE: explicit TFM2 preview, real ArrayMesh/HeightMapShape3D, 576² four interior shard intersection, LOD0/1/2 and mixed seam parity, last-good failure retention, camera recovery. **Sıradaki B4:** reproducible dual-format profile scene, explicit fixture format/size, bounded worker, disk estimate and cancel, root/shard and frame/collision telemetry, actual device profiling remains open. TFM1 default; P1.4 parked; boya/obje yok.

34. test_paged_preview_v2.gd real 576² four-shard mesh/collision, LOD and failure regression.


> **GÜNCEL DEVİR — P1.5.3b B3a (24 Kasım 2026):** Kod 03b37b1656616e442ec015d01433517e51700cb9, [33/33 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45432431156). [P1_5_3B3A_ASYNC_TR.md](P1_5_3B3A_ASYNC_TR.md) as-built. B3a DONE: explicit open_v2, pinned root, worker-owned bounded shard LRU, exact compact verification/error telemetry, cross-shard async tests. **Sıradaki B3b:** opt-in TFM2 paged preview mesh/LOD/normal/collision integration, actual cross-shard geometry parity and failure isolation; default TFM1 preserved. B4 device profiling after B3b. P1.4 parked; Android GPU/RSS/FPS proof open, boya/obje yok.

33. test_async_region_v2.gd; real fixture cross-shard, compact telemetry, corruption and 300 epochs.


> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

32. test_region_fixture_v2.gd actual 289 pages/4 shards; old async regressions passed.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

31. test_region_index_v2.gd, full codec validation and theoretical max; no actual huge terrain generated.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

30. test_profile_fixture_builder.gd, rectangular all-address parity, cancellation, preflight; existing profile test asynchronous. 2048 only preflight.


> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

29. test_io_pipeline.gd: 1000 camera epochs, accounting, bounded queue, no stale wakes after reopen. Timing distribution diagnostics not speed proof.


> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

28. test test_profile_scene.gd: histogram rank/overflow/null, RSS parser, scratch fixture, strict/lazy, gerçek collision shape, IO örnekleri, bounded pages, JSON save, manifest hash. Headless CI GPU veya Android RSS kanıtı değildir.


> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

27. test: test_paged_failure_isolation.gd; disposable cold missing page, aynı mesh/shape identity, bağımsız tile LOD0 collision, 9 page cap, no fake height, immutable TFH, no same-generation IO retry. Eski test_stream_budget.gd artık frame başına 1–2 iş, queue conservation ve eventual completion kontrol eder; üretim bütçesi değişmedi.


**Tarih:** 2026-11-24. **Baz kod:** v0.4.4-dev.1, `73603a15361766397854d11bad44ecb41e9bd53e`. **Son doğrulanmış run:** [GitHub Actions 45420063664, 26/26 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664).

## A. GitHub CI gerçek kapsamı

Workflow: `.github/workflows/terraforge-ci.yml`. Sadece `feat/terraforge-mobile-addon` dalında `addons/terra_forge/**` değişince otomatik; `workflow_dispatch` da var. Ubuntu 24.04 runner, Godot **4.7.2-stable**, geçici isolated `project.godot`, script import/parse, headless EditorPlugin startup, sonra her script.

Test çalıştırıcı: `addons/terra_forge/tests/run_all.sh`. Her test logu, exit code + explicit `PASS:` + Godot engine Error/Parse Error analizi; beklenen özel veri koruma hata satırları kontrollü olarak filtrelenir. Özet ve log artifact Actions içinde. Bu **Android build, Vulkan/OpenGL sürücü testi, gerçek GPU p95 FPS testi** değildir.

### Mevcut 26 test ve neyi kanıtladıkları

| # | Dosya | Kapsanan davranış |
|---:|---|---|
| 1 | `test_height_store.gd` | TFH1 Float32 initialize, serialize/deserialize ve height invariants |
| 2 | `test_data_safety.gd` | Eksik bağlı TFH read-only; yeni sahne explicit create ve dosyanın tekrar açılması |
| 3 | `test_height_layers.gd` | Sparse additive Float32 layers, görünürlük, opacity, kaydet/aç ve bozuk veri reddi |
| 4 | `test_live_layers.gd` | Katmanlar canlı brush, per-layer Undo/Redo, visible composite, TFH byte dokunulmazlığı |
| 5 | `test_layer_scene_roundtrip.gd` | Godot PackedScene içinde layer_mode + layer_file ve yeniden açma |
| 6 | `test_layer_integrity.gd` | TFL2 SHA, önceki sağlam .bak, manuel Restore, TFL1 geriye uyum, bozuk primary koruması |
| 7 | `test_region_store.gd` | TFR1 32×32 tek sahip örnek, LRU, dirty writeback, SHA, restart, eksik/bozuk page |
| 8 | `test_region_export.gd` | TFH/TFL1/TFL2 staged export, Float32 seam equivalence, TFM1 SHA, bozuk/eksik region, kaynağa dokunmama |
| 9 | `test_lod_policy.gd` | LOD policy, tile candidate seçimi ve sınırlar |
| 10 | `test_surface_faces.gd` | Triangle face/winding ve görünür yüzey geometrisi |
| 11 | `test_lod_normals.gd` | LOD0/1/2 analitik eğim normali |
| 12 | `test_lod_seams.gd` | Komşu LOD yükseklik seam davranışı |
| 13 | `test_edge_normals.gd` | Aynı LOD komşu tile için kenar normal eşitliği |
| 14 | `test_stream_budget.gd` | Tile hazırlama queue, tile sayısı ve budget |
| 15 | `test_brush_sampling.gd` | Seyrek/sık stroke inputta benzer yükseklik etkisi, Undo/Redo |
| 16 | `test_offtree_transform.gd` | Headless off-tree brush koordinat dönüşümü hatası üretmeme |
| 17 | `test_advanced_brushes.gd` | Ridge/Valley/Ramp/Stamp şekillendirme ve Undo/Redo |
| 18 | `test_geomorphology.gd` | Ridge/Valley süreklilik, Weather kütle aktarımı ve sabit miktar |
| 19 | `test_shape_quality.gd` | Organic Stamp, scan-independent Smooth, LOD hysteresis, dirty tile halo |
| 20 | `test_drainage_analysis.gd` | Priority-flood depression fill, MFD, flat/downhill flow, rainfall mass balance |
| 21 | `test_paged_height_source.gd` | TFM1/TFR1 SHA, Float32 sınır/bilinear, LRU, bozulmuş/eksik source, TFL2 immutable composite |
| 22 | `test_camera_page_prefetch.gd` | Kamera öncelik, read/tick, generation cancel, 80 konumlu trace, fail-closed corruption |

| 23 | `test_async_page_io.gd` | Gerçek Thread/Mutex/Semaphore, bounded jobs, Float32 cross-page, stale generation drop, missing/corrupt page, close/join ve source immutability |

| 24 | `test_paged_terrain_preview.gd` | Gerçek opt-in TFR1 → ArrayMesh + HeightMapShape3D; legacy LOD0/1/2 vertices/normals/collision parity, mixed LOD seam, bozuk sayfa fail-closed, kaynak dokunulmazlığı |

| 25 | `test_paged_camera_stress.gd` | 9-page cache + 2 outstanding IO, büyük kamera teleport generation cancellation, origin stale mesh unload, LOD0 HeightMapShape3D oluşturma, TFH SHA değişmezlik |

| 26 | `test_lazy_world_open.gd` | Strict default tüm sayfa doğrulama, TFM1 checksum ve schema, lazy TFR1 cold worker SHA, missing/corrupt page no flat height, yakın gerçek mesh/collision, off-tree stop/join, TFH integrity |

**Doğrulanmış:** 26 testin tümü `73603a15` commit'i için geçti. [GitHub Actions](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664). Yeni dokümantasyon commit'i kod değişikliği yapmazsa 26 testlik kod sonucu aynı referans kalır; Actions otomatik yeni run başlatmışsa ayrı kaydedilmelidir.

**CI'da YOK / GERÇEK CİHAZ BEKLİYOR:** 3D editörde gerçek Android finger/tap, Mobile renderer görüntüsü, telefon GPU driver, shader upload, uzun süreli RAM/VRAM leak, fizik adımı, termal throttling, kalıcı depolama izinleri ve kullanıcı ekranı.

## B. Yeni test ekleme standardı

- Yeni özelliği izole modülde uygula; `tests/test_*.gd` dosyasında başarılı olunca `print("PASS: ...")`, hata olunca push_error + nonzero quit.
- `tests/run_all.sh` içine ekle; runner suite sayısı gerçek test sayısına eşit olsun.
- `.github/workflows/terraforge-ci.yml` script import/EditorPlugin startup testini kaldırma.
- CI run job logunu aç, **total fails 0** görmeden başarılı deme. Beklenen hata mesajını sadece ilgili testte filtrele; bütün `ERROR:` satırlarını globally gizleme.
- SHA, run URL, test sayısı, yeni risk ve rollback'i `STATUS_AND_CHANGELOG_TR.md` dosyasına kaydet.
- P1.5 manifest-first read-only preview regresyonuyla toplam **26 test**. Android gerçek render/performans ayrı zorunlu doğrulama; sonraki kod değişikliği 24 testin hepsini koruyacak.

## C. Teknik doğruluk kabul kapıları

| Alan | Asgari kabul | Son durum |
|---|---|---|
| TFH/TFL veri doğruluğu | Byte-özdeş eski kaynak, Float32 roundtrip, eksik dosya locked | CI PASS / Android bekliyor |
| Katmanlar | Görünürlük, Undo/Redo, scene reopen, max layer sınırı, backup | CI PASS / Android bekliyor |
| TFR1 world snapshot | Sınır örneği = tek sahip, tüm dosya/manifest SHA, output-overwrite reddi | CI PASS / canlı yok |
| Paged sampler | Bilinear cross-page, cache limit, bozuk page fail closed, 1–64 limit | **İZOLE CI PASS** / canlıya bağlı değil |
| Worker-thread IO | Mutex/Semaphore, job cap 1–8, stale generation, SHA buffer, join/close | **İZOLE CI PASS** / Android profili yok |
| Opt-in ayrı regional mesh + collision preview | Legacy parity LOD0/1/2, mixed LOD, fail-closed corruption | **İZOLE CI PASS** / Android onayı yok |
| Legacy live node'un gerçek regional HeightSource'a geçirilmesi | Varsayılan eski yol, opt-in migration, page halo, main-thread mesh commit | **PLAN** |
| Live collision | Görsel height ile yüzey hata toleransı altında eşit, boş collision yok | **PLAN** |
| LOD0↔LOD1↔LOD2 | Görünür yarık, gap, checkerboard skirt, yanlış normal, popping yok | Headless kısmi / Android QA bekliyor |
| Sculpt sampling | Slow vs fast drag aynı fiziksel yol üzerinde tutarlı derinlik, crash/undo yok | Headless kısmi / Android QA bekliyor |
| Hidrolojik süreç | NaN yok, kütle dengesi ve gerçek drenaj bağlantıları | Yalnız lokal analiz CI PASS |
| Ekran ergonomisi | Terrain popup kapalıyken 3D viewport kullanılabilir, dev dock yok | Telefon son sürüm QA bekliyor |
| 30 dk dayanıklılık | Memory monotonic growth yok, crash yok, veri geri açılıyor | DEVICE PENDING |

## D. Android 11 sahasında standart test senaryosu

**Aynı test koşulları:** telefonda aynı pil/ısınma başlangıcı; aynı world, quality profile, camera rota, viewport ölçeği, renderer ve sensör/kayıt yöntemi. Warm-up ile ölçüm ayrı. Önerilen kayıt: minimum 5 dakika baseline, 30 dakika stability.

1. **Başlatma / UI:** Godot 4.7.2 Android projesini aç, plugin etkin, yanlış `res://addons/.../res://...` path hatası yok, kompakt Terrain popup alt dock yerine görünüyor. Popup telefon ekranına sığıyor.
2. **Terrain geometri:** 256×256 flat yeni test world; editörde yüzey solid ve üstten/alttan doğru; kamera dış köşelere; LOD tile resident/pending değişiyor.
3. **Fırçalar:** 9 aracı test et. Ridge/Valley şekil aralıkları, Ramp rise pozitif/negatif, Organic Hill/Crater/Mesa, Weather dik vs düz alan.
4. **Touch:** bir dokunuş iki kere sculpt yapmamalı, mouse-synth guard; hızlı sürükleme vs yavaş sürükleme; bir pinch/kamera hareketi yanlış sculpt başlatmamalı.
5. **LOD seam:** yakın-orta-uzak geçiş, kamerayla ~72/144m sınır geçişi; zorlu sırt/çukur/kenar ve LOD0/1/2 karışımlarında gri dik duvar/gap/normal şerit yok.
6. **Mesh/collision:** fare karakter kapsülünün/yer testinin zemine batmaması, LOD değişiminde collision tutarlı; görünür mesh collision arasındaki height farkını ölç.
7. **Layer:** TFH yedeğini koru; Enable Layers, farklı iki layer, On toggle, Undo/Redo, Save, scene Save, kapanıp açma.
8. **Recovery:** yalnız kopya test dünyasında sahte bozuk TFL; read-only; Restore önceki bak; .corrupt_* korunuyor. Kullanıcının asıl haritasını bozma.
9. **Disk streaming (gelecek):** 10× hızlı uzun kamera rota, 200–1000 page load, resident count limite uyma, bozuk page fail closed, cancellation ve no UI freeze.
10. **Stres:** 30 dk farklı quality profil, hızlı kamera, üst üste brush; kullanıcı veri yeniden açınca kayıt kaybı yok; RAM ve GPU reset/driver crash yok.

## E. Ölçümler ve gerçekçi başlangıç hedefleri

**Bunlar ölçülmüş sonuç değil, hedef/karşılaştırma noktalarıdır.**

| Metri̇k | Hedef / ölçüm şekli |
|---|---|
| FPS/frame time | 30 FPS sınıfında frame 33.33ms; önceki kriter p95 ≤33.3ms, p99 ≤50ms. Bu salt hedef ve sahneye göre yeniden ele alınır |
| 60 FPS sınıfı | 16.67ms frame; hedefe ulaşma garantisi yok |
| RAM | Resident height page sayısı ×4096 byte **ham veri**; gerçek RSS/peak ve Godot Node/Dictionary overhead ayrı |
| CPU build | `Mesh last/max ms`; tek tile CPU budget aşabilir; p95 frame farklı metriktir |
| Sculpt/Drain | `Sculpt last/max ms`, `Terrain > Check` Float32/Path/Weather/Shape/Drain/Layers CPU süreleri |
| GPU | Renderer GPU frame time, drawcalls, vertex sayısı, upload/reallocation ve VRAM; CI headless bunu ölçmez |
| IO | Cached vs cold page load latency, hash verify latency, page read/write totals, flush spike |
| Paged streaming | 4/8/16/32 cache limit kıyası, hit ratio, resident sample bytes ve gerçek RSS |
| Dayanıklılık | 30 dk boyunca RAM sürekli artış eğimi, telefon aşırı ısınma/thermal throttle, scene reload ve CRC |
| Visual | Ground-level before/after, saçma dairesel tekrar, soluk düz relief, LOD seam parlaması yok |

**En önemli karar:** “Performans arttı” demek için aynı sahne ve rota üzerinde karşılaştırmalı gerçek ölçüm veya en azından ayrıntılı CPU/GPU profili gerekir. Tile sayısını azaltmak otomatik toplam GPU performans iyileşmesi değildir.

## F. Başarı/başarısızlık kayıt şablonu

Her GitHub PR/commit sonrası burada veya STATUS belgesinde:
- Commit SHA / version / çalıştırılmış run URL ve sonucu.
- 23 + yeni test adı ve PASS/FAIL; CI raw logs varsa nerede.
- Dönüşümde kaynak SHA değişti mi, yeni dosyalar doğrulandı mı?
- Test platformu: Linux headless mı Android gerçek mi?
- Görsel/kare süreleri varsa cihaz modeli, Android sürümü, renderer, quality profile, kamera ve test world.
- Açık regresyonlar, known limit, önceki çalışan commit'e rollback.
- **Bu bilgiler olmadan “profesyonel / optimize / tam kararlı” ibaresi kullanılmaz.**

İlgili belgeler: [QUALITY_GATE.md](QUALITY_GATE.md), [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md), [RISKS_AND_DECISIONS_TR.md](RISKS_AND_DECISIONS_TR.md).
