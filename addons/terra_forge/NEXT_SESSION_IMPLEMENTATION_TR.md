# Sıradaki Uygulama İş Emri — P1.3 Sahada Doğrulama ve P1.4 Veri İşlemleri

> **GÜNCEL DEVİR — P1.5.3b B3b (24 Kasım 2026):** Kod de0c6f1672b989ab5fd14169d7a54040962b98a0, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45433789697). [P1_5_3B3B_PREVIEW_TR.md](P1_5_3B3B_PREVIEW_TR.md) as-built. B3b DONE: explicit TFM2 preview, real ArrayMesh/HeightMapShape3D, 576² four interior shard intersection, LOD0/1/2 and mixed seam parity, last-good failure retention, camera recovery. **Sıradaki B4:** reproducible dual-format profile scene, explicit fixture format/size, bounded worker, disk estimate and cancel, root/shard and frame/collision telemetry, actual device profiling remains open. TFM1 default; P1.4 parked; boya/obje yok.

B4 profile scene explicit format/size, disk estimate, cancellation, reproducible telemetry.


> **GÜNCEL DEVİR — P1.5.3b B3a (24 Kasım 2026):** Kod 03b37b1656616e442ec015d01433517e51700cb9, [33/33 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45432431156). [P1_5_3B3A_ASYNC_TR.md](P1_5_3B3A_ASYNC_TR.md) as-built. B3a DONE: explicit open_v2, pinned root, worker-owned bounded shard LRU, exact compact verification/error telemetry, cross-shard async tests. **Sıradaki B3b:** opt-in TFM2 paged preview mesh/LOD/normal/collision integration, actual cross-shard geometry parity and failure isolation; default TFM1 preserved. B4 device profiling after B3b. P1.4 parked; Android GPU/RSS/FPS proof open, boya/obje yok.

B3b explicit TFM2 preview integration with real interior shard boundary and LOD/collision parity.


> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

B3 pinned root/worker shard cache, bounded metadata; B4 after reader parity.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

P1.5.3b B1 DONE; B2 strict/lazy verified scratch exporter next, then B3.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

P1.5.3a DONE, .3b B1 binary root/shard codec and tests; no reader until codec passes.


> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

P1.5.2 tamamlandı, P1.5.3a kapasite/preflight/direct bounded fixture builder; P1.4 beklemede.


> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

P1.5.1 profil sahnesi DONE/CI PASS. P1.4 ilk adım: mevcut manifest ve region_store güvenlik sözleşmesini incele; ayrı scratch dünyada generation publication, stale reader isolation, crash rollback test et.


> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

P1.3c DONE: aynı generation içinde hata izolasyonu, last-good mesh/shape retention, 27. test. İlk açık kod görevi ayrı profil sahnesi ve ölçüm/export, telefon QA ayrıca.


**24 Kasım 2026.** Kod tabanı `73603a15361766397854d11bad44ecb41e9bd53e`, dal `feat/terraforge-mobile-addon`. P1.2b worker IO ve P1.3 opt-in read-only preview + P1.3b kamera/cache stresi DONE / 26/26 CI PASS. P1.3 gerçek Android kalite kapısı + P1.4 writable transaction PLAN. Kullanıcı mobil telefon kullanıyor; CI GitHub Actions üzerinde çalışmalı.

## Önce kontrol

- [ ] GitHub'dan **güncel branch head** al. Bu belgede sabit görünen commit dokümantasyon öncesi kodun referansıdır.
- [ ] `HANDOFF_START_HERE_TR.md`, `ENGINE_ARCHITECTURE_TR.md`, `ROADMAP_MASTER_TR.md`, `RISKS_AND_DECISIONS_TR.md`, `QUALITY_TESTS_AND_BENCHMARKS_TR.md` oku.
- [ ] `core/region_store.gd`, `core/region_manifest.gd`, `core/region_export.gd`, `terrain/terra_forge_terrain.gd` ve `tests/run_all.sh` dosyalarını gerçekten fetch et.
- [ ] Son doğrulanan CI run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664 (26/26 Godot 4.7.2 PASS).
- [ ] Kodlar yalnız `addons/terra_forge/`, gerekli CI değişiklikleri yalnız `.github/workflows/terraforge-ci.yml`. `main`, oyun sahneleri ve `terraforge_data` korunur.

## PR 1 — DONE: manifest-verified read-only paged source

- [x] `core/paged_height_source.gd` ve `tests/test_paged_height_source.gd`; commit `d516147`, 21/21 CI https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404375645 .
- [x] TFM1/TFR1 SHA doğrulama, cold reload hash, Float32 `get_height`, cross-page `sample_local`, bounded 1–64 LRU, `prefetch_rect`, `release_outside`, IO timing + cache stats.
- [x] TFH1/TFL2 snapshot ve sınır örnekleri, bozuk/eksik dosya, korunmuş kaynak testi.
- [ ] **Canlı sahneye bağlı değil**; salt okunur prototip.

## PR 2 — DONE: senkron kamera-öncelikli bounded page scheduler

- [x] `core/camera_page_prefetch.gd`, `tests/test_camera_page_prefetch.gd`; commit `a214c907`, [22/22 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825).
- [x] Yakın kamera sayfası + hareket yönü önceliği, cache capacity kadar queued page, 1–8 synchronous reads/tick, pending generation cancellation.
- [x] 80 konum kamera trace, bozuk sayfa fail-closed, cache limit ve source byte immutability.
- [ ] **Senkron IO frame-time garantisi değildir.** Thread işi yapılmadı.

## PR 2b — DONE: bounded worker-thread TFR1 IO

- [x] `core/async_region_source.gd`, `tests/test_async_page_io.gd` ve `camera_page_prefetch.configure_async()` eklendi. Commit'ler `f7b3413` / `4d5ed1b`, [CI 23/23 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313).
- [x] Tek worker Thread, Mutex/Semaphore queue; max 1–8 pending/inflight/finished iş; cache 1–64 sayfa, main-thread commit.
- [x] TFR1 tek byte-buffer'dan world+manifest SHA ve internal SHA, Float32 finite doğrulaması; eksik/bozuk page fail closed.
- [x] Kamera generation ile pending ve late worker sonucu iptali; yeni generation sadece kendi tamamlanan verisini kullanır.
- [x] Worker join/close, corruption after open, deleted file, stale race, Float32 cross-page bilinear regresyonu.
- [ ] `open()` **tam dünya doğrulaması hâlâ senkron**, büyük dünyada açılış takılmasını çözmedik.
- [ ] `close()` aktif tek IO okuması bitene kadar engelleyebilir; gerçek Android stres testi yok.
- [ ] Bu read-only worker **henüz canlı terrain'e bağlanmadı**; yeni FPS/RAM kazancı ölçülmedi. [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md).

## PR 3 — DONE: ilk opt-in read-only ArrayMesh + collision bağlama

- [x] `core/paged_tile_geometry.gd` yazıldı: read-only paged Float32 üzerinden 32×32 tile LOD0/1/2 mesh, normals ve HeightMapShape3D samples.
- [x] `terrain/paged_terrain_preview.gd`: test için ayrı Node3D; default OFF, `region_directory`, resident cache 9–64 page, worker IO, nearest tile prioritization, no global heights dizisi, no writes.
- [x] `plugin.gd`: editör viewport kamera position forwarding, küçük popup'ta read-only status/page + IO sayacı, Brush disabled.
- [x] `tests/test_paged_terrain_preview.gd`: 24. regression; legacy ile LOD0/1/2 vertex/normal/collision, LOD0/2 seam, cold corrupt page, source file safety; [CI 24/24 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421).
- [ ] **Gerçek Android 11 cihaz kalite/profil testi yok**. Mobil UI, shader, memory RSS, GPU frame, collision traversability, değişen kamera bölgelerinde delik olmadığı test edilmeli.
- [ ] Bu **ayrı preview node**; legacy `TerraForgeTerrain` varsayılan tam heightmap tutmaya devam ediyor, tam oyun RAM optimizasyonu tamam değil.
- [ ] Full manifest `open()` sync, `close()` join stall, >9 required page halo, high-speed camera tile gaps ve 30 dk stability açık risk.

**Sıradaki küçük uygulanabilir iş:** Aynı exported snapshot test sahnesi için Android editör camera trace, LOD/mixed-LOD visual seam, collision ve RAM profiler; gerekirse `paged_terrain_preview.gd` tile streaming retry/prefetch/old LOD preserve iyileştirmesi. Detay [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## PR 3b — DONE: kamera sıçraması + minimum cache LRU önceliği

- [x] `async_region_source.gd`: `prioritize_resident()` tile'ın hazır halo sayfalarını MRU yapar, `is_requested()` duplicate IO çağrılarının tick submit bütçesini tüketmesini önler.
- [x] `paged_terrain_preview.gd`: büyük kamera sıçramasında worker generation iptali (>=2 tile/world sayfası), stale page işlerini çöpe atar. Küçük kamera hareketinde gereksiz iptal yapmaz.
- [x] `test_paged_camera_stress.gd` 25. test: **9 sayfa** cache, **2 job** limit, harita köşeleri arasında uzun kamera sıçramaları, LOD0 gerçek collision ve TFH verisi değişmezliği. [25/25 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507).
- [ ] Gerçek Android GPU/RAM/FPS sayıları ve görsel boşluk/seam testi hâlâ yok.
- [ ] Büyük world manifest first-open senkron SHA ve worker join beklemesi sürüyor.

**Bundan sonra ilk iş:** gerçek cihaz QA (editor+Mobile Renderer), kısa/yavaş/hızlı kamera trace, eski TFH ile bölgesel snapshot RSS/fps karşılaştırması. Cihaz sınamasını yapmadan başardık deme. Sonra P1.4 veri bütünlüğü tasarım/uygulama.

## PR 3c / P1.5 — DONE: manifest-first hızlı açılış

- [x] `async_region_source.open(directory,resident_limit,max_jobs, verify_all_pages=true)` eski **strict** davranışını varsayılan tutar; `false` TFM1 bütünlüğünü senkron doğrular, bütün TFR1 sayfalarını açılışta taramaz.
- [x] TFR1 SHA-256, internal SHA, world/page metadata, finite Float32 worker tarafından sayfanın ilk talebinde mutlaka kontrol edilir. Eksik sayfa `ERR_FILE_NOT_FOUND`, bozuk `ERR_FILE_CORRUPT`, hazır olmayan `ERR_BUSY`; asla düz zemin yok.
- [x] `paged_terrain_preview.verify_pages_on_demand=true` yalnız opt-in read-only node'da varsayılan. `plugin.gd` ON-DEMAND/FULL ve Checked/manifest sayıları.
- [x] `test_lazy_world_open.gd` (26. test): strict missing/corrupt startup refusal, manifest-first success, lazy cold SHA, TFM1 tamper refusal, yakın mesh+collision, TFH değişmezlik, off-tree worker stop. [26/26 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664).
- [ ] **Gerçek Android süre/kare kazancı ÖLÇÜLMEDİ**; TFM1 JSON açılışı hâlâ küçük fakat senkron, `close()` join tek IO bitene kadar bekleyebilir.
- [ ] Missing/corrupt **uzak** sayfa, lazy modda ilgili sayfa ilk istenene kadar bilinmez. `verified_at_open=false` bunu açıkça gösterir.
- [ ] Legacy editable `TerraForgeTerrain` global Float32 source kullanmaya devam ediyor; atomik region write P1.4 hâlâ PLAN.

**Sonraki uygulanabilir tek adım:** Android test sahnesinde manifest-first vs strict açılış süresi/RSS ölçümü, fast-camera/hole ve LOD collision visual QA; ardından güvenli generation-pinned P1.4 write transaction'ın ilk küçük testi. Detay: [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).

## PR 4 — P1.4 edit-mode region transaction (PLAN)

- [ ] **KRİTİK:** Her region dosyası değiştiğinde TFM1 manifestteki SHA eski olur. Sayfa + manifesti ayrı ayrı yazmak **YASAK**.
- [ ] Generation-based / copy-on-write transaction, tek atomik current generation pointer/manifest, recovery journal.
- [ ] Çok bölge geçen stroke, Undo/Redo ve delta layer; fizik/mesh/görsel invariant.
- [ ] Crash, disk-full, Android kill, bozuk page ve eski manifest testleri; bütün durumlar ya önceki sürüme ya yeni tam sürüme açılmalı, karışık duruma açılmamalı.
- [ ] TFL2 canlı layer verilerinin paged derivative olup olmayacağı tasarlanmalı. Kaynak TFH/TFL kullanıcı dosyaları **asla kaybolmayacak**.
- [ ] Büyük dünya perf, save latency, orphan staging temizleme stratejisi ve açık yedek/geri dönüş.

## Sonraki fazlar (hemen değil)

P2 jeomorfolojik ridge/watershed graph; P3 kütle korunumlu hidrolik erozyon ve tortu; P4 clipmap/CDLOD/geomorph kıyası; P5 fare ölçeğinde yakın geometri ve collision; P6 non-destructive terrain editor/analiz araçları; P7 gerçek Android benchmark + kalite gate. Tüm detay [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md).

## Her tamamlanan turda kaydedilecekler

1. Değişen dosyalar + yapılan somut davranış.
2. Kod commit tam SHA ve branch, GitHub Actions run linki, PASS sayısı veya tam başarısızlık.
3. Korunan `main`/oyun/TFH/TFL/backup; bekleyen riskler ve Android cihaz kanıtı.
4. `STATUS_AND_CHANGELOG_TR.md` ve bu dosyada işaretlenmiş checkbox/durum.
5. Sıradaki **tek uygulanabilir görev**. Kullanıcı “Devam” dediğinde yeniden uzun plan değil, bu dosyadan ilk eksik görev uygulanmalı.
