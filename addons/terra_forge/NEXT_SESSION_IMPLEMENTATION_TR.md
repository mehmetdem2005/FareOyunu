# Sıradaki Uygulama İş Emri — P1.2 Canlı Streaming'e Hazırlık

**24 Kasım 2026.** Kod tabanı `a214c907b6fba2d3cd7dba32f883ee5fad7ed446`, dal `feat/terraforge-mobile-addon`. P1.2 ilk iki parça DONE / 22/22 CI PASS. Aşağıdaki P1.2b/P1.3/P1.4 işleri PLAN. Kullanıcı mobil telefon kullanıyor; CI GitHub Actions üzerinde çalışmalı.

## Önce kontrol

- [ ] GitHub'dan **güncel branch head** al. Bu belgede sabit görünen commit dokümantasyon öncesi kodun referansıdır.
- [ ] `HANDOFF_START_HERE_TR.md`, `ENGINE_ARCHITECTURE_TR.md`, `ROADMAP_MASTER_TR.md`, `RISKS_AND_DECISIONS_TR.md`, `QUALITY_TESTS_AND_BENCHMARKS_TR.md` oku.
- [ ] `core/region_store.gd`, `core/region_manifest.gd`, `core/region_export.gd`, `terrain/terra_forge_terrain.gd` ve `tests/run_all.sh` dosyalarını gerçekten fetch et.
- [ ] Son doğrulanan CI run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825 (22/22 Godot 4.7.2 PASS).
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

## PR 2b — HEMEN SIRADAKİ İŞ: worker-thread-safe asenkron disk IO (PLAN)

1. [ ] `paged_height_source.gd` için FileAccess/SHA/Float32 verisini thread-safe immutable result ile açan bounded worker tasarla.
2. [ ] `camera_page_prefetch.gd` pending/inflight sınırı ve generation ile **geç gelen** istek sonucunu atma; yüklenemeyen sayfayı sahte 0 yapma.
3. [ ] TFR1 hash doğrulamasında mümkünse tek-buffer snapshot ve tutarlı TOCTOU önlemleri; manifest kimliğini koru.
4. [ ] Full manifest startup doğrulaması ve soğuk disk erişimini ölç; lazy validation alternatifi güvenli fail-closed olmalı.
5. [ ] `tests/test_async_page_io.gd` ve stress test: kamera teleport, bozuk/missing file, thread shutdown, disk full, bounded memory; CI en az 23/23.
6. [ ] Gerçek Android FPS/görsel ve canlı mesh/collision **henüz** yok. Teknik sözleşme: [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md).

## PR 3 — P1.3 opt-in read-only render + collision (PLAN)

- [ ] Önce `terrain/terra_forge_terrain.gd` içindeki tüm `height_data.heights` doğrudan erişimlerini envanterle.
- [ ] Yeni `HeightSource` abstraction ile legacy in-memory yol ve region read-only yol yan yana çalışabilsin.
- [ ] **Varsayılan legacy**, yeni mod yalnız açıkça seçilen TEST sahnesinde. Regional mod açıkken Brush kapalı.
- [ ] Tile mesh/slope normal/collision halo border read; LOD 0/1/2 legacy birebir yükseklik ve normal testi.
- [ ] CPU frame, resident RAM, page IO, display seams ile gerçek cihaz kıyası; tam height array yanlışlıkla RAM'de kaldıysa “streaming başarılı” sayılmaz.
- [ ] CI + Android kontrol onayından önce normal kullanıcı sahnelerini migrate etme.

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
