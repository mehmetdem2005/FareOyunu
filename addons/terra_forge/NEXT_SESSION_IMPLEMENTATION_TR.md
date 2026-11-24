# Sıradaki Uygulama İş Emri — P1.3 Canlı Terrain Read-only Entegrasyonu

**24 Kasım 2026.** Kod tabanı `4d5ed1bdce11727f5bc129087432198956ff2ce5`, dal `feat/terraforge-mobile-addon`. P1.2b worker-thread IO dâhil üç çekirdek parça DONE / 23/23 CI PASS. P1.3/P1.4 işleri PLAN. Kullanıcı mobil telefon kullanıyor; CI GitHub Actions üzerinde çalışmalı.

## Önce kontrol

- [ ] GitHub'dan **güncel branch head** al. Bu belgede sabit görünen commit dokümantasyon öncesi kodun referansıdır.
- [ ] `HANDOFF_START_HERE_TR.md`, `ENGINE_ARCHITECTURE_TR.md`, `ROADMAP_MASTER_TR.md`, `RISKS_AND_DECISIONS_TR.md`, `QUALITY_TESTS_AND_BENCHMARKS_TR.md` oku.
- [ ] `core/region_store.gd`, `core/region_manifest.gd`, `core/region_export.gd`, `terrain/terra_forge_terrain.gd` ve `tests/run_all.sh` dosyalarını gerçekten fetch et.
- [ ] Son doğrulanan CI run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313 (23/23 Godot 4.7.2 PASS).
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

## PR 3 — ŞİMDİ SIRADAKİ: P1.3 opt-in read-only render + collision (PLAN)

- [ ] Önce `terrain/terra_forge_terrain.gd` içindeki tüm `height_data.heights` doğrudan erişimlerini envanterle.
- [ ] Yeni `HeightSource` abstraction ile legacy in-memory yol ve region read-only yol yan yana çalışabilsin.
- [ ] **Varsayılan legacy**, yeni mod yalnız açıkça seçilen TEST sahnesinde. Regional mod açıkken Brush kapalı.
- [ ] Tile mesh/slope normal/collision halo border read; LOD 0/1/2 legacy birebir yükseklik ve normal testi.
- [ ] CPU frame, resident RAM, page IO, display seams ile gerçek cihaz kıyası; tam height array yanlışlıkla RAM'de kaldıysa “streaming başarılı” sayılmaz.
- [ ] CI + Android kontrol onayından önce normal kullanıcı sahnelerini migrate etme.

**P1.3 ilk küçük commit kabulü:** `height_data.heights` bağımlılık envanteri + `HeightSource` adapter/test; eski TFH/TFL ve normal sahne varsayılan kalsın. Sonraki commit'de opt-in read-only render/collision; CI en az 24 test. Güncel kaynak API'leri [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md).

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
