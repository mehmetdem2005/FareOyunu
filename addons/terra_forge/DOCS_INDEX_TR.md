# TerraForge Mobile — Kalıcı Proje Hafızası ve Teknik Doküman İndeksi

> **GÜNCEL DEVİR — P1.5.4a (24 Kasım 2026):** Kod 285122ecc826616f3c3840a41ad4e34223afc0fa, [35/35 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45436882446). [P1_5_4A_TILE_VIEW_TR.md](P1_5_4A_TILE_VIEW_TR.md) as-built. Bounded synchronous tile view, exact TFM1/TFM2 geometry parity, deterministic LRU work reduction; experimental opt-in default false. **Sıradaki P1.5.4b:** fixed-workload CPU A/B microbenchmark and profile, reduce dictionary allocation per sample if evidence supports, maintain all-array parity and fail-closed. P1.4 parked; actual large-world and Android proof open; boya/obje yok.


> **GÜNCEL DEVİR — P1.5.3b B4 (24 Kasım 2026):** Kod 0ba10c27a66117eadf63e01e3563a7cb48bcf037, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45434699275). [P1_5_3B4_PROFILE_TR.md](P1_5_3B4_PROFILE_TR.md) as-built. B4 profil altyapısı DONE: dual format matched fixture, 81 byte-identical TFR1 pages, four strict/lazy runs, TF_PROFILE_3, 4096/8192 V2 generation options and storage gate. Actual large-world and Android benchmarks OPEN. **Sıradaki P1.5.4a:** profile-driven CPU sampling audit, bounded tile read views, no per-sample LRU touches, exact geometry parity. P1.4 parked; boya/obje yok.

B4 profile reference; P1.5.4a next.


> **GÜNCEL DEVİR — P1.5.3b B3b (24 Kasım 2026):** Kod de0c6f1672b989ab5fd14169d7a54040962b98a0, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45433789697). [P1_5_3B3B_PREVIEW_TR.md](P1_5_3B3B_PREVIEW_TR.md) as-built. B3b DONE: explicit TFM2 preview, real ArrayMesh/HeightMapShape3D, 576² four interior shard intersection, LOD0/1/2 and mixed seam parity, last-good failure retention, camera recovery. **Sıradaki B4:** reproducible dual-format profile scene, explicit fixture format/size, bounded worker, disk estimate and cancel, root/shard and frame/collision telemetry, actual device profiling remains open. TFM1 default; P1.4 parked; boya/obje yok.

B3b preview reference; B4 next.


> **GÜNCEL DEVİR — P1.5.3b B3a (24 Kasım 2026):** Kod 03b37b1656616e442ec015d01433517e51700cb9, [33/33 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45432431156). [P1_5_3B3A_ASYNC_TR.md](P1_5_3B3A_ASYNC_TR.md) as-built. B3a DONE: explicit open_v2, pinned root, worker-owned bounded shard LRU, exact compact verification/error telemetry, cross-shard async tests. **Sıradaki B3b:** opt-in TFM2 paged preview mesh/LOD/normal/collision integration, actual cross-shard geometry parity and failure isolation; default TFM1 preserved. B4 device profiling after B3b. P1.4 parked; Android GPU/RSS/FPS proof open, boya/obje yok.

B3a async source reference; B3b next.


> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

B2 actual fixture reference; B3 next.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

B1 codec reference new; B2 next.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

P1.5.3a ve .3b tasarım notları güncel.


> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

P1.5 ana planı ve IO teknik raporu yeni devir otoritesidir.


> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

Profil aracı ve sahne yolu yeni teknik kayıtta.


> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

Yeni P1.3c teknik notu güncel devir otoritesidir.


**Hazırlanma:** 24 Kasım 2026. **Aktif dal:** `feat/terraforge-mobile-addon`. **Kod tabanı:** v0.4.4-dev.1.  
Bu dosyalar GitHub dalında saklanır, **sohbet hafızasına bağlı değildir**. Başka sohbet, model veya geliştirici ile devam edildiğinde önce bu indeks ve merkez devir dosyası okunacak.

## 1. Yeni sohbetin başlangıç sırası

| Okuma sırası | MD | İçerik / neden zorunlu |
|---:|---|---|
| 1 | [HANDOFF_START_HERE_TR.md](HANDOFF_START_HERE_TR.md) | Repo, branch, güncel sürüm, güvenli çalışma, hangi iş sırada, yeni sohbet promptu |
| 2 | [STATUS_AND_CHANGELOG_TR.md](STATUS_AND_CHANGELOG_TR.md) | Başlangıçtan v0.4.4-dev.1'e kadar tarihçe, commit prefix, DONE/CI/PENDING |
| 3 | [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md) | **P0–P7** fazları, alt fazlar, bağımlılıklar, kabul kapıları |
| 4 | [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md) | **ŞİMDİ BAŞLANACAK P1.3 cihaz kalite kapısı / P1.4 tasarım** dosya, API ve test düzeyinde iş listesi |
| 5 | [ENGINE_ARCHITECTURE_TR.md](ENGINE_ARCHITECTURE_TR.md) | Mevcut gerçek kod akışı, TFH/TFL/TFR/TFM formatları, LOD/collision, sınırlamalar |
| 6 | [RISKS_AND_DECISIONS_TR.md](RISKS_AND_DECISIONS_TR.md) | Sözleşmeler, kritik riskler, eski veri/backup/manifest koruma ve rollback |
| 7 | [QUALITY_TESTS_AND_BENCHMARKS_TR.md](QUALITY_TESTS_AND_BENCHMARKS_TR.md) | 26 test, GitHub Actions ve cihazda ölçülmesi gereken gerçek performans/kalite |
| 8 | [TERRAIN_GEOMORPHOLOGY_TR.md](TERRAIN_GEOMORPHOLOGY_TR.md) | Profesyonel doğal arazi algoritmaları, su/erozyon, LOD alternatifleri ve kaynaklar |
| 9 | [MOBILE_WORKFLOW_TR.md](MOBILE_WORKFLOW_TR.md) | Telefon editör kullanım kuralları, CI'ı GitHub'dan izleme, güvenli ZIP yükleme |

**P1.2 teknik ek:** [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md) — salt okunur Float32 sampler, kamera ön yükleme, API ve CI 22/22, kalan async IO işi.

**Yeni P1.2b teknik ek:** [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md) — worker Thread, Mutex/Semaphore, bounded IO, camera cancellation, 23/23 CI ve P1.3 geçiş koşulları.

**P1.3b kamera/cache iyileştirmesi:** [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md) — 9 sayfa cache stress, eski background IO cancellation, 25/25 CI.

**Yeni P1.3 teknik ek:** [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md) — ilk gerçek opt-in TFR1 ArrayMesh/HeightMapShape3D, editör kamerası, 24/24 CI, Android bekleyen testler ve READ-ONLY güvenlik.

**Yeni P1.5 as-built notu:** [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md) — strict eski API, TFM1 manifest-first + TFR1 cold SHA, 26. test, güvenlik sınırları ve Android kalite kapısı.

## 2. Eski ama korunan proje belgeleri

Bu belgeler silinmez. Zaman içinde bir bölümü tarihsel kalmıştır; **as-built son durum için güncel kod + yukarıdaki yeni MD'leri kullan**.

| Belge | Ne anlatıyor |
|---|---|
| [README.md](README.md) | Özellik tarihçesi, kullanım, kurulum, CI ve sonraki adımlar |
| [KULLANIM_TR.md](KULLANIM_TR.md) | Android ekranı, 9 sculpt tool, layer/restore ve eski sürüm talimatları |
| [QUALITY_GATE.md](QUALITY_GATE.md) | İlk geometri/performans kabul kapısı, mobil test hedefleri |
| [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md) | Android smoke, UI/touch/LOD/soak kontrol listesi |
| [P0_P1_IMPLEMENTATION_TR.md](P0_P1_IMPLEMENTATION_TR.md) | İlk data layer fazları ve sonraki TFL2 güvenlik adımları, tarihsel ekler |
| [REGION_STREAMING_PLAN_TR.md](REGION_STREAMING_PLAN_TR.md) | TFR1 LRU/TFM1 export prototipi ve canlıya bağlama sınırları |

## 3. Değişmeyen kararlar

- **Boyama ve obje yerleştirmeye geçilmiyor**; yalnız terrain geometrisi, erozyon, veri, LOD, collision, editör ve performans.
- Telefon Android 11, Godot 4.7.2 hedefi; UI kompakt.
- Branch `feat/terraforge-mobile-addon`; `main`, diğer oyun dosyaları, harita verisi ve `terraforge_data` korunacak.
- Gerçek data Float32; JPEG yükseltmesi kaybolan yükseklik bilgisi değildir.
- TFH/TFL asıl kaynak korunur; TFR1/TFM1 şu an sadece **izole snapshot** veri prototipi. Canlı data RAM streaming henüz yok.
- Godot GitHub CI **Linux headless**, Android GPU/gesture/ısınma kanıtı sayılmaz.
- Her yeni kod değişimi için GitHub Actions sonuçları; son gerçek 26/26 PASS run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664 .

## 4. Güncelleme disiplini — yeni sohbette unutulmayı engelle

Her yeni geliştirme turu sonunda:
1. **Gerçek kod SHA**'yı GitHub'dan kontrol et. Eski dokümandaki SHA'yı canlı HEAD sanma.
2. Test ekle/çalıştır; GitHub CI run linkini ve sonucu kaydet.
3. `STATUS_AND_CHANGELOG_TR.md`'de yeni sürüm ve commit, gerçek tamamlanan kod/fail logu/Android sınırı.
4. `ROADMAP_MASTER_TR.md`'de görev checkbox/status, kabul kapısı ve bağımlılıkları.
5. `NEXT_SESSION_IMPLEMENTATION_TR.md`'de sıradaki açık iş, gerçek dosya yolları, test ve rollback.
6. `RISKS_AND_DECISIONS_TR.md`'de çözülmüş/yeni risk, veri güvenliği kararları.
7. `QUALITY_TESTS_AND_BENCHMARKS_TR.md`'de yeni test adı, test sayısı ve yeni Android ölçümü.
8. `ENGINE_ARCHITECTURE_TR.md`'de data schema/API/LOD/physics değişiklikleri; `TERRAIN_GEOMORPHOLOGY_TR.md`'de bilimsel algoritma değişimleri.
9. `HANDOFF_START_HERE_TR.md` başlangıç özeti ve “sonraki tek görev” güncel mi kontrol et.
10. GitHub commit docs + CI sonucu; belge dosyalarının gerçekten remote branch'te varlığını doğrula.

**Tutarsızlık politikası:** Kod gerçeği > başarılı CI > yeni status notu > tarihsel README. Geçmiş not “henüz yok” diyorsa yeni sürümde gerçekten kodlanmış olabilir; kodu yeniden oku. Aksi yönde de salt plan başlığı kodlandı sanılmaz.

## 5. Copy-paste yeni sohbet mesajı

> FareOyunu / TerraForge Mobile projesini GitHub'da sürdür. Depo `mehmetdem2005/FareOyunu`, dal `feat/terraforge-mobile-addon`. Önce `addons/terra_forge/DOCS_INDEX_TR.md`, `HANDOFF_START_HERE_TR.md` ve oradan bağlı tüm güncel MD belgelerini **repo içinden oku**; gerekiyorsa gerçek kodu kontrol et. v0.4.4-dev.1 snapshot: `73603a15`, GitHub Actions CI 26/26 PASS (Linux Godot 4.7.2); Android cihaz GPU testi yok. Boyama ve obje yok, sadece profesyonel gerçekçi terrain; main ve kullanıcı veri dosyalarını koru. `NEXT_SESSION_IMPLEMENTATION_TR.md`'deki P1.3 Android kalite kapısını ve P1.4 ilk açık işe uygulamayla başla, test ekle, CI çalıştır, en son Markdown kayıtlarını güncelle. Telefon kullanıyorum; testleri GitHub CI üzerinden yap.

## 6. Tamamlanma statüsü

**Güncelleme:** İzole read-only sampler, kamera scheduler ve worker-thread async IO veri çekirdeğidir, CI 23/23 PASS; canlı terrain render/physics/Brush entegrasyonu **yapılmadı**. Belgeler GitHub'da commit edildikten sonra kodun regression CI sonucu ayrıca doğrulanır. Belgelerin kapsamı bugüne kadar konuşulmuş ve kodda görülebilen özellik/planları açık biçimde korumayı amaçlar; gelecekteki her küçük kararın otomatik kaydedildiğini varsaymayın.
