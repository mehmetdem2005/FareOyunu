# Sıradaki Uygulama İş Emri — P1.2 Canlı Streaming'e Hazırlık

**24 Kasım 2026.** Kod tabanı `734c9088d76603279599654d345249b0cc90e321`, dal `feat/terraforge-mobile-addon`. Aşağıdaki maddeler **PLAN**: kodlanmış gibi anlatılmayacak. Kullanıcı mobil telefon kullanıyor; CI GitHub Actions üzerinde çalışmalı.

## Önce kontrol

- [ ] GitHub'dan **güncel branch head** al. Bu belgede sabit görünen commit dokümantasyon öncesi kodun referansıdır.
- [ ] `HANDOFF_START_HERE_TR.md`, `ENGINE_ARCHITECTURE_TR.md`, `ROADMAP_MASTER_TR.md`, `RISKS_AND_DECISIONS_TR.md`, `QUALITY_TESTS_AND_BENCHMARKS_TR.md` oku.
- [ ] `core/region_store.gd`, `core/region_manifest.gd`, `core/region_export.gd`, `terrain/terra_forge_terrain.gd` ve `tests/run_all.sh` dosyalarını gerçekten fetch et.
- [ ] Referans CI run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45398690227 (20/20 Godot 4.7.2 PASS).
- [ ] Kodlar yalnız `addons/terra_forge/`, gerekli CI değişiklikleri yalnız `.github/workflows/terraforge-ci.yml`. `main`, oyun sahneleri ve `terraforge_data` korunur.

## PR 1 — P1.2 salt okunur paged sampler (İLK YAPILACAK)

**Yeni dosyalar:** `core/paged_height_source.gd` ve `tests/test_paged_height_source.gd`. `tests/run_all.sh` listesine test eklenecek.

- [ ] `open(directory,resident_limit) -> Error`: önce TFM1 manifest ve world metadata kontrolü; bozuk belge veya eksik region varsa başarı dönme.
- [ ] `get_height(x,z) -> {error,height}`: tüm küresel Float32 koordinatlar; negatif veya world dışı çağrılar için tanımlı hata; eksik veriyi asla gizlice 0'a çevirmeme.
- [ ] `sample_local(wx,wz) -> {error,height}`: height_store ile uyumlu bilinear interpolasyon; 32×32 page sınırı boyunca dört komşudan örnekleme; son x=max/z=max sınırları.
- [ ] `prefetch_rect(min_page,max_page,budget)`: her çağrıda yalnız belirtilen sayıda sayfa aç; öncelik ve cache sayısını ölç, maksimum resident limitine uy.
- [ ] `release_outside(bounds)`: read-only sayfalarda değişiklik yok; güvenli LRU eviction; cache hit/miss, disk reads, IO last/max ms ve bounded Float32 bytes istatistiği.
- [ ] TFR1 içerik checksum + TFM1 page list hash uyuşmazlığına fail-closed davranış; manifest SHA'sının onaylanmasını gerçek veri uyumluluğu sanma.
- [ ] İlk modülde **yazma, Undo/Redo, fırça veya mevcut sahneye otomatik bağlama yok**.
- [ ] Perf testte tek karede aşırı senkron IO olasılığını raporla; GPU hızlandığı iddiası yok.

**Zorunlu yeni testler:**
- [ ] 96×64 TFH fixture → `region_export.export_file()` ile yeni snapshot; 0/31/32/33/63/64/95/96 x, 0/31/32/33/63/64 z birebir Float32.
- [ ] Bilinear sample: 31.5/32.0/32.5 sınırları, köşe, eğimli yüzey, negatif/taşan adres.
- [ ] Cache budget 1/2/4 ve 50+ konumluk kamera izi; resident sayfa üst sınırı.
- [ ] Missing manifest, wrong-world page, bozuk checksum, değişmiş region hash, staging .tmp, truncated file; sahte boş height yok.
- [ ] TFL2 visible composite örnekleri ile TFH legacy karşılaştırması ve export kaynak byte-özdeşliği.
- [ ] Tüm eski 20 + yeni testler Godot 4.7.2 CI'da PASS; tam run linki ve commit kaydı.

**Kabul:** Yeni sampler headless CI üzerinden sağlam; fakat henüz canlı oyuna bağlı olmadığından RAM azaldı iddiası kurulmaz.

## PR 2 — P1.2 bounded IO ve prefetch (PLAN)

- [ ] Kamera yaklaşan region box ve 1 region halo; yakın/ekranda görünür tile daha yüksek öncelik.
- [ ] Frame/job budget; hızlı kamera zıplaması eski IO kuyruğunu generation ID ile geçersiz kılar.
- [ ] Godot Node, ArrayMesh, Physics nesnelerine worker thread'den dokunma. İşçi yalnız dosya/buffer işler; ana thread kontrollü uygular.
- [ ] Hata durumunda eski görünür veri korunur veya tile hatalı işaretlenir; boş sıfır arazi çıkmaz.
- [ ] Profiling cache hit, p95 IO, açılan sayfa, aşırı alloc, elle yükleme/boşaltma 30 dk.
- [ ] CI stress: zıt yönlü kamera trace, iptal yarışı, mem budget, bozulmuş page.

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
