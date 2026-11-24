# Sıradaki Uygulama İş Emri — P1.3 Sahada Doğrulama ve P1.4 Veri İşlemleri

**24 Kasım 2026.** Kod tabanı `bf5c1dde57cf4f56a08b606b03c89270d09599c2`, dal `feat/terraforge-mobile-addon`. P1.2b worker IO ve P1.3 opt-in read-only preview + P1.3b kamera/cache stresi DONE / 25/25 CI PASS. P1.3 gerçek Android kalite kapısı + P1.4 writable transaction PLAN. Kullanıcı mobil telefon kullanıyor; CI GitHub Actions üzerinde çalışmalı.

## Önce kontrol

- [ ] GitHub'dan **güncel branch head** al. Bu belgede sabit görünen commit dokümantasyon öncesi kodun referansıdır.
- [ ] `HANDOFF_START_HERE_TR.md`, `ENGINE_ARCHITECTURE_TR.md`, `ROADMAP_MASTER_TR.md`, `RISKS_AND_DECISIONS_TR.md`, `QUALITY_TESTS_AND_BENCHMARKS_TR.md` oku.
- [ ] `core/region_store.gd`, `core/region_manifest.gd`, `core/region_export.gd`, `terrain/terra_forge_terrain.gd` ve `tests/run_all.sh` dosyalarını gerçekten fetch et.
- [ ] Son doğrulanan CI run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507 (25/25 Godot 4.7.2 PASS).
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
