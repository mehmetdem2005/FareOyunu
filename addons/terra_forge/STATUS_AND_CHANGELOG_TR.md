# TerraForge Mobile — Tam İlerleme Kaydı, Kanıt Düzeyi ve Sürüm Günlüğü

> **GÜNCEL DEVİR — P1.5.5b (24 Kasım 2026):** Kod 16731d424112edda219355436a04b7337f631e8b, [40/40 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45446183057). [P1_5_5B_WORKER_PREVIEW_TR.md](P1_5_5B_WORKER_PREVIEW_TR.md), [ham JSON](P1_5_5B_WORKER_PREVIEW_CI.json). E worker explicit experimental sampling_strategy=3, A default unchanged; unique outstanding tile reservations, current epoch/LOD/neighbor validation, bounded synchronous publication, TFM1/2 real mesh/shape, missing-page retention and TFM2 cold missing shard recovery. 19 published, 2 discarded per format. **NEXT P1.5.5c:** controlled sync C vs worker E same fixed completed workload and separate moving trace; quantify main-thread copy/publish/pump, queue/delivery, coverage, wasted work; cap1/2/4 and repeat orders. No Android FPS/GPU proof. All EXP gates remain open, P1.4 parked, no painting/objects.


> **GÜNCEL DEVİR — P1.5.5a (24 Kasım 2026):** Kod cb63d03b665feccab7aca7d64b56569ea7aed3df, [39/39 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45443035828). [P1_5_5A_GEOMETRY_WORKER_TR.md](P1_5_5A_GEOMETRY_WORKER_TR.md). Isolated one-worker prototype, 14 exact array parity cases, owned dense input survives page eviction, bounded slots, stale neighbor/epoch/reopen rejection. No live preview integration yet; A default/B+C opt-in/D benchmark-only unchanged. **NEXT P1.5.5b:** audit worker ownership/lifetime, opt-in live integration with bounded publication and no duplicate outstanding tiles, test actual mesh/shape and failure/epoch/LOD isolation. Android/large-world and old EXP gates open. No painting/objects, P1.4 parked.


> **GÜNCEL DEVİR — P1.5.4d (24 Kasım 2026):** Kod 8c2f7675a3c78b9356aeb98f3dfbf850727c199f, [38/38 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45441554202). [P1_5_4D_SCALAR_BENCH_TR.md](P1_5_4D_SCALAR_BENCH_TR.md), [ham JSON](P1_5_4D_SCALAR_CI.json). B/D exact parity and equal work; 14 cases × 32 rounds × 2 methods = 896 timed builds. B 1190.16 us, D 827.09 us equal-weight mean; D 30.51% lower than B, 14/14 mean wins on one runner. 293312 height reads per method; D avoids per-sample result dictionary, not measured allocator bytes. A default, B/C opt-in, D benchmark-only. **NEXT P1.5.5a:** bounded pure-array worker design and ownership prototype; keep D experiment pending live trace and device. No painting/objects, P1.4 parked. Mandatory UNUTULMAYACAKLAR_TR.md.


> **GÜNCEL DEVİR — P1.5.4c (24 Kasım 2026):** Kod 94beaeb2cd068e7bf5a09fc9b23b97b98a44d92d, [37/37 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45440552536). [P1_5_4C_STREAM_TRACE_TR.md](P1_5_4C_STREAM_TRACE_TR.md), [ham JSON](P1_5_4C_STREAM_TRACE_CI.json). 12 fixed 144-pump traces (TFM1/2 × cache9/16 × A/B/C); B lower mean pump in all four groups, equal-weight means A 0.722, B 0.568, C 0.676 ms; 21.26% lower B vs A on one runner, work differs at cap16. Shape-missing steps 34/144 cap9,29/144 cap16 for all methods; no raycast or actual render frames. A default, B/C explicit experiments. **NEXT P1.5.4d:** isolate allocation/topology optimization via fixed resident benchmark; preserve exact geometry and opt-in. Device/long soak and real trace repeats open. P1.4 parked; no painting/objects. Read UNUTULMAYACAKLAR_TR.md.


> **GÜNCEL DEVİR — P1.5.4b (24 Kasım 2026):** Kod da123dca5be609cc67c6b18f181b91abdc962404, [36/36 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45439854530). [P1_5_4B_SAMPLING_BENCH_TR.md](P1_5_4B_SAMPLING_BENCH_TR.md), [ham ölçüm](P1_5_4B_SAMPLING_CI.json). A/B/C exact array parity, 14 warm-resident cases × 24 rounds × 3 methods = 1008 timed builds. Equal-weight mean A 1869.22 us, B 1390.05 us, C 1791.09 us; B 25.63% lower than A, wins 14/14 means on one Linux runner. Not mobile FPS or isolated CPU time. A default, B opt-in, C benchmark-only. **NEXT P1.5.4c:** fixed camera trace A/B/C, page/job/cache/RSS/reload and frame/pump comparison; device gates still open. [UNUTULMAYACAKLAR_TR.md](UNUTULMAYACAKLAR_TR.md) mandatory every turn. No painting/objects or P1.4 writes.


> **GÜNCEL DEVİR — P1.5.4a (24 Kasım 2026):** Kod 285122ecc826616f3c3840a41ad4e34223afc0fa, [35/35 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45436882446). [P1_5_4A_TILE_VIEW_TR.md](P1_5_4A_TILE_VIEW_TR.md) as-built. Bounded synchronous tile view, exact TFM1/TFM2 geometry parity, deterministic LRU work reduction; experimental opt-in default false. **Sıradaki P1.5.4b:** fixed-workload CPU A/B microbenchmark and profile, reduce dictionary allocation per sample if evidence supports, maintain all-array parity and fail-closed. P1.4 parked; actual large-world and Android proof open; boya/obje yok.


> **GÜNCEL DEVİR — P1.5.3b B4 (24 Kasım 2026):** Kod 0ba10c27a66117eadf63e01e3563a7cb48bcf037, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45434699275). [P1_5_3B4_PROFILE_TR.md](P1_5_3B4_PROFILE_TR.md) as-built. B4 profil altyapısı DONE: dual format matched fixture, 81 byte-identical TFR1 pages, four strict/lazy runs, TF_PROFILE_3, 4096/8192 V2 generation options and storage gate. Actual large-world and Android benchmarks OPEN. **Sıradaki P1.5.4a:** profile-driven CPU sampling audit, bounded tile read views, no per-sample LRU touches, exact geometry parity. P1.4 parked; boya/obje yok.

0ba10c27 code; 34/34 CI; test expanded, no new test count.


> **GÜNCEL DEVİR — P1.5.3b B3b (24 Kasım 2026):** Kod de0c6f1672b989ab5fd14169d7a54040962b98a0, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45433789697). [P1_5_3B3B_PREVIEW_TR.md](P1_5_3B3B_PREVIEW_TR.md) as-built. B3b DONE: explicit TFM2 preview, real ArrayMesh/HeightMapShape3D, 576² four interior shard intersection, LOD0/1/2 and mixed seam parity, last-good failure retention, camera recovery. **Sıradaki B4:** reproducible dual-format profile scene, explicit fixture format/size, bounded worker, disk estimate and cancel, root/shard and frame/collision telemetry, actual device profiling remains open. TFM1 default; P1.4 parked; boya/obje yok.

de0c6f16 code; 34/34 CI, plugin version unchanged.


> **GÜNCEL DEVİR — P1.5.3b B3a (24 Kasım 2026):** Kod 03b37b1656616e442ec015d01433517e51700cb9, [33/33 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45432431156). [P1_5_3B3A_ASYNC_TR.md](P1_5_3B3A_ASYNC_TR.md) as-built. B3a DONE: explicit open_v2, pinned root, worker-owned bounded shard LRU, exact compact verification/error telemetry, cross-shard async tests. **Sıradaki B3b:** opt-in TFM2 paged preview mesh/LOD/normal/collision integration, actual cross-shard geometry parity and failure isolation; default TFM1 preserved. B4 device profiling after B3b. P1.4 parked; Android GPU/RSS/FPS proof open, boya/obje yok.

03b37b16 code; 33/33 CI, plugin version unchanged.


> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

90147bcf code, 32/32 CI, plugin version unchanged.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

a2793e06 code; 31/31 CI; no plugin version change.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

2c3227c4 code; 30/30 PASS; 2048 selectable but generation performance not measured.


> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

P1.5.2 code 13d5019d; 29/29 CI PASS; plugin version unchanged. TF_PROFILE_2 additive diagnostics.


> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

P1.5.1 kodu 73f3b7b0; 28. test geçti. Profil sahnesi plugin sürüm etiketi değiştirilmeden geliştirildi. Ölçüm altyapısı hazır; hızlanma iddiası yok.


> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

P1.3c: 79f27560 (kod), 0b41af31 (test), 241e28f3 (runner), 4790ef5b (legacy test zamanlama düzeltmesi). İlk CI 26/27; yeni test geçti, eski test 3ms altında her zaman iki mesh bekliyordu. Son CI 27/27. Plugin.cfg sürümü değiştirilmedi.


**Son durum tarihi:** 2026-11-24. **Aktif kod tabanı:** v0.4.4-dev.1, `73603a15361766397854d11bad44ecb41e9bd53e` (dokümantasyon öncesi uygulama commit'i). **Dal:** `feat/terraforge-mobile-addon`.  
**Durum anahtarı:** **DONE** = kod commit edildi; **CI PASS** = GitHub Actions Godot Linux headless testleri geçti; **DEVICE PENDING** = Android kullanıcı testinde henüz kanıt yok; **PLAN** = uygulanmadı. GitHub CI sonuçları, “kullanıcının telefonunda sorunsuz” anlamına gelmez.

## 1. En son kanıt ve geçerlilik

- **GitHub Actions run:** https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664  
  **Sonuç:** 26/26 GDScript regresyonu PASS, Godot 4.7.2 stable, ubuntu-24.04 headless. Son kod SHA `73603a15361766397854d11bad44ecb41e9bd53e`.
- İş akışı kaynağı: `.github/workflows/terraforge-ci.yml`. Eklentiyi geçici `project.godot` ile parse eder, editör eklentisinin başlatılmasını kontrol eder, `tests/run_all.sh` ile tek tek test çalıştırır. Exit code + `PASS:` + istenmeyen Godot ERROR/SCRIPT ERROR denetimi vardır.
- İstisna: bazı testler **bilerek** salt okunur kaynak-koruma hatası üretir; test çalıştırıcısı yalnız bu beklenen mesajları filtreler.
- Gerçek **Android 11 Mobile Renderer**, GPU, touch davranışı, uzun stres, VRAM, sıcaklık, 30/60 FPS, görsel doğallık ve Terrain3D karşılaştırması **DEVICE PENDING**.
- Kod değişiklikleri `addons/terra_forge/` ve tek GitHub CI workflow'u ile sınırlı; main ve oyun dosyaları korunmuş.

## 2. Sürümler ve işlenen kilometre taşları (kronolojik)

| Aşama | Yaklaşık commit/prefix | Gerçek yapılan iş | Doğrulama notu |
|---|---|---|---|
| v0.1.x — başlangıç | Tarihsel | Godot Android terrain editor eklentisi, Float32 yükseklik, ilk mesh + sculpt | Erken sürümler telefon ekranında UI ve yüzey sorunları gösterdi |
| v0.2.0 | `c8c9557` | `plugin.cfg` göreli `script="plugin.gd"` yolu; yanlış `res://addons/.../res://...` plugin yükleme hatasını giderme | Sürüm tarihinde Android gözlem vardı, kapsamlı CI yoktu |
| v0.2.1 | `6f6b632` | Yüzey triangle winding düzeltmesi; dev alt dock yerine kompakt 3D toolbar popup | İlk büyük görsel/telefon UI düzeltmeleri |
| v0.2.2 | `df00a911` | LOD seam yükseklik uyarlaması; checkerboard/grimsi etek sorunu; tile kurulum bütçesi; ilk HeightStore/LOD testleri | Gerçek cihaz görsel geçişleri sonra da kontrol edilmeli |
| v0.2.3 | `805c207` | Touch event sayısına bağımlılığı azaltan dünya-mesafesine göre fırça stroke örneklemesi; seyrek/sık input regresyonu | Sayısal yaklaşım kodlandı; yüksek hızdaki patolojiler benchmark ister |
| v0.3.0 | `e04524c` | Ridge, Valley, Ramp, Stamp; dört yeni şekillendirme aracı ve ilgili test/kılavuz | Başlangıçta doğal olmayan “boncuk” biçimli yol riski vardı |
| v0.3.1 | `d0bee77` | Tek parça kıvrımlı asimetrik Ridge/Valley; termal Weather; edit CPU/mesh sayaçları, bütçe, QA kapısı | **Bu fiziksel su erozyonu değildir** |
| v0.3.2 | `d45d863` | Organic Stamp; Smooth snapshot/bilateral; LOD histerezis, görünür mesh normalleri; bölgesel dirty işaretleme | Gölge/parlama iyileşmesi cihazda görsel olarak onaylanmadı |
| v0.3.3 | `098030b` | Yerel priority-flood/MFD drenaj analizi (salt okunur); eksik TFH read-only koruması; komşu tile sınır normal düzeltmesi; noise cache | Drenaj hâlâ arazi oymaz; canlıya akış çizimi eklenmedi |
| v0.4.0-dev.1 | `418e9fe` | İzole sparse additive Float32 katman çekirdeği, ilk `TFL1`, test çalıştırıcısı | Bu sürümde katmanlar live sculpt'a bağlı **değildi** |
| CI başlangıç ve düzeltmeleri | `0a54e7`, `68df408` | GitHub Actions workflow; geçici Godot projesi, script parse, editör start; off-tree transform uyarısı düzeltmesi; sıkı log filtreleri | 15/15 headless CI |
| v0.4.0-dev.2 | `27324d0` → `b09b017` | **Opt-in live layers**: Enable Layers, +, On; katman bazlı Undo/Redo, tek TFL otorite, sahne kaydet/aç regresyonu | 17/17 CI; eski TFH korunuyor |
| v0.4.0-dev.3 | `32e59fb` | `TFL2` SHA-256, .tmp staging, .bak önceki sağlam kayıt, manuel Restore, bozuk dosyanın korunması, TFL1 okumak | 18/18 CI; eşzamanlı/asenkron kayıt çözülmedi |
| v0.4.1-dev.1 | `1a36674` | **İzole** `region_store.gd`: `TFR1` 32×32 Float32 disk sayfası, LRU resident limit, güvenli kayıt ve checksum | 19/19 CI. **Oyun RAM'i henüz azalmadı** |
| v0.4.1-dev.2 | `c0e3a0d` → `734c908` | `TFM1` world manifest, kaynak SHA + tüm TFR1 page SHA doğrulaması; `TFH1/TFL1/TFL2` için staged, kaynağa dokunmayan snapshot export; kaynak değişim kontrolü | **20/20 CI PASS**. Canlı mesh/physics/brush entegrasyonu henüz yok |

| v0.4.2-dev.1 | `d516147` → `a214c907` | İzole `paged_height_source.gd` ile TFM1/TFR1 read-only Float32 ve bilinear LRU; `camera_page_prefetch.gd` ile nearest-first senkron read budget + generation, 2 yeni test | **22/22 CI PASS**; canlı renderer/physics henüz bağlı değil |

| v0.4.2-dev.2 | `f7b3413` → `4d5ed1b` | `async_region_source.gd` düşük öncelikli Godot Thread, bounded job/result+LRU, tek snapshot SHA, `camera_page_prefetch.configure_async()`, stale generation drop ve `test_async_page_io.gd` | **23/23 Godot CI PASS**; full manifest open senkron; canlı mesh bağlı değil |

| v0.4.3-dev.1 | `4422e0b6` → `286b135d` | `paged_tile_geometry.gd`, opt-in `paged_terrain_preview.gd`: TFR1 async → ArrayMesh + LOD0 HeightMapShape3D; editor camera bridge ve read-only toolbar; legacy LOD0/1/2 parity regression | **24/24 Godot CI PASS**; Android ve legacy migration henüz yok |

| v0.4.3-dev.2 | `bf5c1dde` | P1.3b: büyük kamera sıçraması worker generation iptali; mevcut tile halo sayfalarını LRU'da öne al; duplicate cold request job-budget koruması; 9 sayfa/2 job kamera stres testi | **25/25 CI PASS**; mobil ölçüm bekliyor |

| v0.4.4-dev.1 | `a582c862` → `73603a15` | Read-only preview için TFM1 **manifest-first** açık dünya başlangıcı, TFR1 worker cold SHA doğrulama, strict eski API varsayılan, 26. missing/corrupt manifest/page testi, off-tree thread cleanup | **26/26 CI PASS**; Android startup ölçümü yok |

Not: erken commit prefix'leri tarihsel kayıt amacıyla verilmiştir; yeni dal ilerledikçe tam baş SHA'yı **GitHub'dan yeniden okuyun**. `main`'e merge edilmedi.

## 3. Güncel özellik envanteri (gerçek / kısmi / plan)

| Alt sistem | Durum | Detay |
|---|---|---|
| Godot eklenti aktivasyonu | DONE / CI PASS | Android editörde son sürüm cihaz teyidi bekleniyor |
| Küçük Terrain popup / dokunmatik | DONE / CI parse | Ekran alanı ve çoklu touch cihaz testi bekleniyor |
| Raise, Lower, Smooth, Flatten | DONE / CI PASS | Smooth snapshot ve bilateral bileşen var |
| Ridge / Valley sürekli koridor | DONE / CI PASS | Ağırlıklar/noktalar path boyunca; gerçek havza kontrolü değil |
| Ramp / Hill-Crater-Mesa Stamp | DONE / CI PASS | Organik warp var; geolojik olarak bütünüyle gerçekçilik garantisi yok |
| Weather termal aşınma | DONE / CI PASS | Lokal malzeme aktarımı; sediment-su simülasyonu değil |
| Yerel priority-flood + MFD | DONE / CI PASS | Salt okunur analiz; 97×97 örnek sınırı |
| Float32 TFH | DONE / CI PASS | Kodda hücre aralığı 32–2048; base master tüm RAM'de |
| Opt-in TFL2 katmanlar | DONE / CI PASS | En fazla 8, sparse 32×32 Float32 delta; görünürlük ve Undo/Redo; non-destructive |
| TFL2 checksum/yedek/Restore | DONE / CI PASS | SHA-256; önceki kayda dönme olası değişiklik kaybı |
| 3 LOD ve tile mesh resident yönetimi | DONE / CI PASS | Tam crack-free stitched topology / geomorph henüz onaylı değil |
| Gerçek TFR1 disk sayfaları | DONE / CI PASS **izole** | Canlı scene height kaynağında kullanılmıyor |
| TFM1 dünya manifesti/export | DONE / CI PASS **izole** | Snapshot, TFL edit katmanlarını düzleştirir; gerçek runtime değil |
| Kamera yönlü **senkron** bounded prefetch | DONE / CI PASS **izole** | P1.2 |
| Worker-thread asenkron disk IO | **DONE / CI PASS (izole)** | P1.2b; tek worker, bounded IO, late cancellation |
| Manifest-first read-only preview açılışı / sayfaya özel SHA | **DONE / CI PASS (opt-in preview)** | P1.5; strict default korunur |
| Ana thread manifest JSON ve editable full-world verification profil/optimizasyonu | **PLAN** | P1.5 sonraki çalışma |
| Salt okunur paged sampler + LRU | DONE / CI PASS **izole** | P1.2 |
| Opt-in **ayrı read-only** regional preview ArrayMesh/collision | **DONE / CI PASS (izole)** | P1.3; eski live node unchanged |
| Eski TerraForgeTerrain'e ortak HeightSource adaptörü, bölgesel edit/sculpt | **PLAN** | P1.3 sonrası / P1.4 |
| Multi-page atomik düzenleme ve Undo/Redo | **PLAN** | P1.4 |
| Ridge graph, watershed graph | **PLAN** | P2 |
| Gerçek hidrolik erozyon/sediment | **PLAN** | P3 |
| Quadtree/CDLOD/geometry clipmap karşılaştırması | **PLAN** | P4 |
| Gerçek Android profiler ve cihaz onayı | **DEVICE PENDING** | P0/P5/P7 |
| Malzeme boyama/obje | **KAPSAM DIŞI** | Kullanıcı izin vermedi |

## 4. Kullanıcının geçmişten getirdiği önemli sorunlar / dersler

- Yanlış plugin script yolu: `res://addons/terra_forge/res://addons/terra_forge/plugin.gd` biçiminde hata vermişti. Bu yüzden `plugin.cfg` daima `script="plugin.gd"` kalmalı.
- Terrain önce boş/altı oyulmuş gibi ve kareli görünmüştü; triangle winding, skirt, normals, LOD seam ve tile budget bu yüzden düzeltildi. **Yeni gerçek cihazda yakın görüş kontrolü yine gerekli.**
- Büyük alt dock telefon ekranını kaplamıştı; mobil toolbar + geçici popup kuralı kritik, UI'ı tekrar dev panel yapma.
- 8-bit/JPEG kaynaklı yükselti basamaklanmaları kullanıcı için kabul edilemez. Float32 native kayıt var ama JPEG'den dönüştürme kaybolmuş kaynağı geri getirmez; gerçek kaynak doğruluğu ayrıca test edilmeli.
- Kullanıcı “çakma dağ”, kopya dairesel yükseltiler ve detaysız profil istemiyor. Jeomorfolojik neden-sonuç ilişkisi ve fare-boyutunda yakın kamera önemlidir.
- Birden fazla sistemin tek anda değiştirilmesi Android hata ayıklamayı zorlaştırır; izole dal, küçük CI ile onaylanmış aşamalara devam.
- Dönüşümlerin eski veriyi değiştirmemesi ve yedekleri koruması birincil gereklilik.

## 5. Şimdiki öncelik / sıradaki değişiklik

**P1.5 DONE / [26/26 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664):** `async_region_source.open(..., verify_all_pages=false)` TFM1 checksum/şemasıyla açılır, TFR1 sayfalarını yalnız worker cold load'da SHA + finite metadata ile doğrular. `paged_terrain_preview.verify_pages_on_demand=true` varsayılan; `plugin.gd` read-only ON-DEMAND/FULL sayacı sunar. Strict source default değiştirilmedi. Dünyanın uzak bozuk sayfaları **ilk talebe kadar bilinmez**, ama hatalı sayfa asla mesh/height dönmez. Android startup/FPS/RAM ölçülmedi. Yeni source: [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).



**P1.3b uygulandı:** `async_region_source.is_requested/prioritize_resident` ve `paged_terrain_preview` camera generation cancellation. `test_paged_camera_stress.gd` ile 9 sayfa/2 job/çoklu teleport, LOD0 collision ve source SHA regresyonu, [25/25 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507). Bu, gerçek Android render/FPS ölçümü değildir; eski editable TerrainNode full Float32 RAM yolu değişmedi. Bir sonraki iş Android Mobile Renderer görsel/deliksizlik ve gerçek RSS/p95 ölçümü, ardından kaynak abstraction ve atomik P1.4 işlemler.



**P1.3 ilk gerçek render/collision prototipi UYGULANDI / [24/24 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421):** ayrı `paged_terrain_preview.gd` Node3D, `paged_tile_geometry.gd` ve editör kamera forwarding. Legacy `TerraForgeTerrain` ve TFH/TFL dosyaları korunur; **eski oyun RAM'i otomatik azalmadı**. Sırada Android 11 gerçek Mobile Renderer UI/görsel/collision/memory profiler, hızlı kamera tile gaps/LOD normal seam ve ortak `HeightSource` adapter ile güvenli legacy geçiş; P1.4 atomik multi-page transaction yok. Ayrıntı [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## 6. Kanıt ve geçmiş kuralları

- CI'da **gerçek run ID** bulunmadan test geçişi yazılmaz.
- Başarısız eski run'lar kayıttan silinmez; sonraki düzeltilmiş run ile ilişkilendirilir (örnek: v0.4.0-dev.3 ilk 17/18 beklenen uyarı, sonra 18/18).
- Kullanıcı donanımı üzerinde kanıt olmayan hız/RAM/GPU iyileşmesi **“mimari hazır” veya “test bekliyor”** olarak ifade edilir.
- Yeni değişikliklerde bu günlüğe “neyi değiştirdik, neden, test sonucu, risk, geri dönüş” maddeleri ekle.
