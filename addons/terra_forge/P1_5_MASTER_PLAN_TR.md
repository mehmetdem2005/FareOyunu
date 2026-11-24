# TerraForge P1.5 — Derin mobil performans mühendisliği ana planı

> **GÜNCEL DEVİR — P1.5.3b B4 (24 Kasım 2026):** Kod 0ba10c27a66117eadf63e01e3563a7cb48bcf037, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45434699275). [P1_5_3B4_PROFILE_TR.md](P1_5_3B4_PROFILE_TR.md) as-built. B4 profil altyapısı DONE: dual format matched fixture, 81 byte-identical TFR1 pages, four strict/lazy runs, TF_PROFILE_3, 4096/8192 V2 generation options and storage gate. Actual large-world and Android benchmarks OPEN. **Sıradaki P1.5.4a:** profile-driven CPU sampling audit, bounded tile read views, no per-sample LRU touches, exact geometry parity. P1.4 parked; boya/obje yok.

P1.5.3b implementation DONE; P1.5.4a CPU sampling optimization next.


> **GÜNCEL DEVİR — P1.5.3b B3b (24 Kasım 2026):** Kod de0c6f1672b989ab5fd14169d7a54040962b98a0, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45433789697). [P1_5_3B3B_PREVIEW_TR.md](P1_5_3B3B_PREVIEW_TR.md) as-built. B3b DONE: explicit TFM2 preview, real ArrayMesh/HeightMapShape3D, 576² four interior shard intersection, LOD0/1/2 and mixed seam parity, last-good failure retention, camera recovery. **Sıradaki B4:** reproducible dual-format profile scene, explicit fixture format/size, bounded worker, disk estimate and cancel, root/shard and frame/collision telemetry, actual device profiling remains open. TFM1 default; P1.4 parked; boya/obje yok.

B3b DONE; B4 then P1.5.4.


> **GÜNCEL DEVİR — P1.5.3b B3a (24 Kasım 2026):** Kod 03b37b1656616e442ec015d01433517e51700cb9, [33/33 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45432431156). [P1_5_3B3A_ASYNC_TR.md](P1_5_3B3A_ASYNC_TR.md) as-built. B3a DONE: explicit open_v2, pinned root, worker-owned bounded shard LRU, exact compact verification/error telemetry, cross-shard async tests. **Sıradaki B3b:** opt-in TFM2 paged preview mesh/LOD/normal/collision integration, actual cross-shard geometry parity and failure isolation; default TFM1 preserved. B4 device profiling after B3b. P1.4 parked; Android GPU/RSS/FPS proof open, boya/obje yok.

B3a DONE; B3b preview parity then B4.


> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

B2 DONE; B3 worker shard LRU and compact metadata next.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

B1 DONE; B2 next, B3/B4 pending.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

P1.5.3a DONE / CI, P1.5.3b B1 next; 2048 source cap, 4096+ unsupported until new format.

> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

## 0. Kapsam / invariants
Yalnız geometry, data, physics, streaming, ölçüm. Android 11 düşük bellekli telefon ve Godot 4.7.2 hedefi. Ana dal, gerçek TFH/TFL, immutable snapshot, eski strict varsayılanlar korunur. Hiçbir fail durumunda sıfır yükseklik veya sahte collision. Performans varsayımı cihaz ölçümü değildir. P1.4 transaction ile koordinasyon: yeni read-only disk index ileride generation-pinned backend'e uygun olmalı; transaction/brush bu fazda açılmaz.

## 1. Kod denetimi ve boyut modeli
- TFR1 32x32 Float32, payload 4096 bytes, dosya 4184 bytes. Sınır örnekleri tek owner; dünya C hücre ise (C/32+1)^2 sayfa. 2048: 4225, 3168: 10000, 4096: 16641, 8192: 66049. 3168² mevcut TFM1 page-count teorik kare üst sınırı; 2 MiB JSON limiti de ayrıca geçilmeli. 32768 region_store sınırı TFM1'in bunu desteklediği anlamına gelmez. TFH/TFL legacy 2048 sınırı ayrı.
- TFM1 full manifest parse/hash ve dictionary map synchronous. Strict tüm page dosyaları da okuyor. Lazy open yalnız manifest doğruluyor. Büyük dünya için TFM1 limiti gevşetme değil opt-in yeni format.
- Async source bir worker, 1–8 iş ve 9–64 preview resident page. Her get_height için LRU touch Array.find/remove/append; vertex/normal inner loop'ta çok kez çağrılır. Profil ile ispat et; tile-level pinned page view ve batched reads aday. Cache bytes != total RSS (decoded buffers, metadata, jobs, mesh arrays, physics, engine overhead).
- Preview nearest tile öncelikli, 3x3 halo; main-thread geometri ve upload tek işin süresi budget'ı aşabilir. Tile sayısı limiti GPU/upload byte/time limiti değil. Yüksek hızda yeni alan boş kalabilir; last-good yalnız aynı konumda mevcut tile için.
- Profil sahnesi gerçek frame interval ölçer fakat GPU timing değil. Worker service dosya + hash + decode birleşik. P1.5.2 queue/service/delivery/total ayrımı ve cancellation accounting var. Başlatma hatasında eski world_extent artık sıfırlanır.
- 256 fixture yalnız smoke; 2k+ fixture üretirken global heights allocate etme, storage maliyet ve süresi raporla. OS page cache, shader warm-up, CPU scheduling, termal ve profiler overhead karıştırılmamalı.

## 2. Alt fazlar ve kapılar
### P1.5.0 DONE: manifest-first fast open
Strict default ve lazy fail-closed. 26/26 tarihsel.
### P1.5.1 DONE: ölçüm aracı
28/28 tarihsel, profile scene, sampled RSS/null, fixed histogram, JSON. Headless Android değildir.
### P1.5.2 DONE / CI: IO pipeline
Binary wake ownership, bounded queue, cancellation conservation, 1000 epoch stress, accepted-only latency histograms. Sonraki IO optimizasyonları ölçüm gerektirir; servis süresini file open/read/hash/decode olarak ayırmak P1.5.4 ile birlikte. No extra threads until data.
### P1.5.3a NEXT: large dataset ve kapasite
Dosya: core/profile_fixture_builder.gd (yeni). Önce TFM1 preflight dimensions, page_count, worst-case serialized byte bound, source/scratch isolation, explicit space estimate, cancel/error cleanup (yalnız kendi staging), hash-provenance (synthetic ayrı test provenance; TFM1 sözleşmesini bozma). 256/512/1024/2048/3168 desteklenebilir sınırlar; 4096/8192 TFM1 için explicit unsupported. Üretimi page by page, bounded background worker, output absent until publication. Synthetic deterministik terrain gerçek yüksekliği doğru Float32/edge ownership. Mevcut TFH export değiştirme. Gerekirse synthetic provenance için ayrı fixture-only manifest schema veya geçici TFH (legacy sınırı dahilinde); TFM1'e sahte TFH digest yazma. Regression: preflight oversized rejection before any files, exact sample/hash, missing page, cancellation, path safety, no global height array in generator. CI küçük fixture + 2048 optional benchmark, büyük dataset CI her push'a zorunlu yük olmasın.
### P1.5.3b: hierarchical index
Yeni opt-in manifest root + bounded shards (ör. 16x16 page block, 256 entries). Root schema/dim/spacing/hash list validated, per-shard cold SHA and per-page SHA same immutable bytes. Deterministic mapping, sorted canonical entries, reject duplicate/missing/out-of-bounds/nonhex, max bytes/count and no path traversal. Shard cache separate bounded cap; old TFM1 reader intact. Strict full scan opt-in preserved. 4096/8192/32768 synthetic geometry limits checked without huge file fixture. Async root parse/lookup proof, shard failure never returns data. P1.4 generation identity compatible; don't implement writes. Index byte estimate and storage measured, not claim production before parity.
### P1.5.4: memory and cache
Account page payload, manifest/shard, pending bytes, mesh arrays, engine RSS separately; telemetry fixed-size. Batched tile page views verified immutable, hard pin max nine with explicit lifetime; no global array; prohibit evict pinned, bounded fallback. O(1) LRU only after benchmark proves cost, avoid per-sample mutation on tile view. IO service stages timings and cache hit semantics (sample hits vs page request hits separate). Test exact page cap and release, halo read parity, cancellation, 30min no rising retained resource count. Compression candidate benchmark raw vs lossless block; no lossy quantization or SHA removal. 
### P1.5.5: CPU geometry
Separate pure worker-array construction from scene publication, generation/LOD signature + neighbor halo identity, stale outputs dropped. Precompute reusable topology index arrays per LOD, bulk Float32 sampling, normals/seams parity against current renderer. Worker pool start one geometry worker only, bounded jobs/results/bytes, no SceneTree/Mesh/Physics worker access. No GDScript inner-loop replacement without profiling; compare direct arrays vs cached data. Unit vertex/index/normal/collision parity, deterministic extreme slopes and mixed LOD. Main thread upload remains.
### P1.5.6: GPU publication / render
Mesh creation/update on supported thread, measured per-tile upload count + estimated bytes + main time. Prioritize near physics/visible camera, defer distant tiles, reuse topology/material/mesh resources only where verified. Avoid doubling mesh/VRAM unbounded. Renderer GPU time available only real device supported profiler; frame interval not GPU time. Compare draw calls, triangle count, visual seam; no arbitrary quality reduction. Single large upload stall explicitly monitored.
### P1.5.7: collision
Near-focus coverage window with explicit world positions, raycast in physics tick, actual missing collision frames and longest gap; no fake flat fallback. Last-good collision during rebuild; update shape and mesh with coherent generation/LOD, bounded retiring resources. Separate physics priority, far collision cap and hysteresis. Test border crossings/fast motion/teleports/blocked pages, raycast vs canonical height. Actual player integration remains opt-in; fail safe for unavailable region, not teleporting arbitrary player.
### P1.5.8: predictive prefetch
Camera velocity EWMA + direction corridor, latency estimate => lookahead distance clamped, stationary no churn, jump cancellation separate epoch from data generation. Priority immediate focus/halo > impending crossing > optional view. Queue hard cap and byte cap, no prefetch evict pin. Compare fixed trace baseline vs predictive, miss rate, wasted IO, longest gaps, frame p95/p99; keep only measured win.
### P1.5.9: adaptive budgets
Explicit user quality presets; moving average + hysteresis/cooldown; prioritize collision and stable near geometry. Adjust far tile uploads, view distance/LOD gradually, avoid oscillation; never lower Float32 precision or skip checks. Frame target 30/60 FPS = budgets 33.33/16.67 ms; tentative p95 target <= frame budget, p99 tracked; no device promise. Test deterministic overload simulation, quality bounds, recovery and memory cap, user override. 
### P1.5.10: device gates
Profile same map/renderer/resolution/route/cache/job limits; record OS/device, renderer, version, commit, sample count. Strict/lazy repeat ABBA and fresh app sessions; no OS cache flush claims. Stationary / slow traverse / fast trace / teleport / 30min soak. Report median per-run p95/p99, max, longest collision gap, sampled RSS baseline/peak/end, disk IO latency, cancelled work, GPU profiling separately, thermal/clock when available else null. First startup to valid focus, no conflation shape attached vs actual raycast. Verify source hashes. No synthetic/headless result as Android proof. Regression thresholds from measured baseline, not fabricated numbers.

## 3. CI and rollout
Each small implementation commit: parser/editor load, full test suite, new targeted regression, real run link, logs, doc update. Baseline 29/29. Performance assertions use hard invariants/counts rather than flaky wall-clock thresholds on shared CI. Benchmark artifacts separately, machine metadata. On failure no next stage. Device verification open in parallel. P1.4 resumes after user decision and stable read-only index interfaces.
