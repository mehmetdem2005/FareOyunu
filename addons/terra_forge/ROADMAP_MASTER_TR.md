# TERRAFORGE — AÇIK DÜNYA TERRAIN MASTER ROADMAP (P0–P7)

**Tarih:** 2026-11-24. **Hedef:** Godot 4.7.2 / Android 11 / Mobile Renderer. **Yalnız arazi**: geometri, veri, erozyon, harita streaming, LOD, çarpışma, editör UX, ölçüm. Boya/texture paint, bitki, objeler ve sahne dekorasyonu **BU FAZLARDA YOKTUR**.

## Temel mühendislik ilkeleri

1. **Önce doğru veri sonra hız.** Float32 master gerçeğin tek kaynağı, hiçbir işlem başka biçimin üstüne sessizce yazamaz.
2. **Önce macro → mezo → micro.** Kütle/tektonik yükselti → dağ sırtı/havza → erozyon → yamaç/yer detayı. Rastgele noise birincil arazi inşa algoritması değildir.
3. **Süreç tabanlı doğallık.** Nehir, vadi, aşınma ve birikim fiziksel neden-sonuç zinciriyle ilişkili olmalı. Önceden yapılmış artist-driven Ridge/Valley yalnız bir başlangıçtır.
4. **Yükseklik tek sahibin altında.** Tile sınırında komşuların farklı değerleri olmayacak; dış sınır dahil Float32 eşitliği.
5. **Deterministik, tahribatsız, iptal edilebilir.** Seed, girdi ve parametreler aynıysa çıktı aynıdır; eski dosyalar korunur; kaydetme yarıda kesilirse veri kaybı olmamalıdır.
6. **Telefon kısıtı.** Sabit RAM/CPU/GPU ve termal bütçe; az yer kaplayan UI; tek dokunuş ile kamera kontrolü çakışmamalı; Godot node/mesh ana thread'de, dosya/hesap arka tarafta kontrollü.
7. **Her fazda çalışır kanıt.** Godot CI + gerçek Android testleri. Platform-sınırlı CI başarısı cihazda performans iddiası değildir.

## P0 — Doğrulama, ürün güvenliği ve proje izolasyonu

**Durum:** Linux headless CI ve kod regresyonları **DONE, 20/20 PASS**; Android son kullanıcı onayı **AÇIK**.

### P0.1 — DONE: altyapı
- İzole `feat/terraforge-mobile-addon` dalı; oyun ve `main` dosyaları korunuyor.
- Godot 4.7.2 headless CI, geçici test projesi, `bash -n`, script import, eklenti editör yükleme, 20 test.
- Mevcut bozuk/eksik TFH/TFL dosyalarında fail-closed read-only ve yedek kurtarma.
- `QUALITY_GATE.md` ve `MOBILE_TEST_PLAN.md` kabul belgeleri.

### P0.2 — DEVICE PENDING: gerçek cihaz QA
- Android 11 editör açılışı/aktivasyonu, dokunmatik ve çift-girdi önleme.
- 30 dakika gezinme/şekillendirme, artan RAM/sıcaklık, Save/Restore/kapanma testi.
- Görünür sınır yarığı, checkerboard/skirt, gölge normal kırılması, physics sapması.
- Ölçümler: p50/p95/p99 frame, GPU/CPU, peak/resident memory, disk IO, shader derleme, termal throttling.
- Kanıt: ekran kaydı + aynı sahnede tekrar edilebilir kamera rotası + log; issue varsa kök neden ve düzeltme.

**Geçiş kapısı:** CI yeşil **ve** Android editör/scene smoke + veri güvenliği testleri raporlanmış. P1 geliştirme paralel sürdürülebilir ama kararlı etiket verilemez.

## P1 — Büyük dünya veri mimarisi ve tahribatsız editing

**Durum:** P1.1–P1.3'ün bazı hazırlık bileşenleri DONE; kritik **canlı data streaming entegrasyonu PLAN**.

### P1.0 — DONE: TFH1 / TFL2 ve canlı katman
- TFH1 Float32 heightmap, küçük UI, 9 fırça.
- TFL2: temel Float32 + 8'e kadar additive sparse layer, enable/disable, opacity API, seçili layer sculpt; Undo/Redo; SHA-256 + .tmp/.bak + Restore; TFL1 geriye uyum.
- Bilinen sınır: katmanlar bütün base heightmap'i RAM'de tutuyor; çift yazım yerine tek TFL otorite; sınırsız layer yok.

### P1.1 — DONE ve CI PASS: izole bölge formatı ve dönüşüm
- TFR1 32×32 Float32 height sayfaları, tek-sahipli border sample, sayfa SHA-256, LRU; read/write/evict.
- TFM1 manifest: page listesi/koordinat/sha, world cells/spacing, kaynak format/hash.
- Dışa aktarım: TFH1/TFL1/TFL2 → **yeni dünya klasörüne** doğrulanmış, staged, orijinal kaynak değiştirilmeden. TFL snapshot visible composite; yeniden düzenlenebilir TFL katmanları ayrıca korunur.
- CI: `test_region_store.gd`, `test_region_export.gd`, toplam 20/20.
- **Önemli:** Bu bileşenler canlı render/physics/fırçada kullanımda değil; kullanıcı oyununun RAM'i bu çalışmadan dolayı henüz azalmıyor.

### P1.2 — **SIRADAKİ İŞ / PLAN**: salt okunur canlı sayfa kaynağı
- [ ] `core/paged_height_source.gd`: manifest açık ve doğrulanmış, GDScript `get_height` + bilinear `sample_local`, çok-bölge sınırı; API sonucu hata kodu ile birlikte gelsin.
- [ ] Kameraya göre sınırlı bölge prefetch, LRU unload, cache hit/miss/disk ms sayaçları; cache < limit koşulu; “eksik sayfa = sıfır arazi” YASAK.
- [ ] Ardışık/rasgele kamera rotalarında senkron okumanın frame spike maliyetini ölç; sonra işçi thread'de yalnız veri IO, main thread'de node/mesh.
- [ ] Global world coordinates ↔ region coordinates dönüşümü için overflow, negatif yerel adres, dış sınır ve bilinear testleri.
- [ ] TFM1 sayfa SHA/manifest doğrulamasını **açılışta**, çalışma sırasında staging/corrupt koşullarını **fail-closed** ele al.
- [ ] `test_paged_height_source.gd` ve stres fixture'ları ekle; CI tam yeşil.
- **Kapı:** 3×3 sayfa sınırı, x=32/z=32 bilinear örneği, köşe örneği, malformed/missing data, bellek limitleri ve eski dosyanın dokunulmazlığı kanıtlandı.

### P1.3 — PLAN: opt-in region üzerinden mesh/LOD/collision
- [ ] `HeightStore`'a doğrudan dizin erişimi kullanan renderer bağımlılıklarını `HeightSource` soyutlamasına geçir; legacy in-memory kaynak korunur.
- [ ] Yalnız bir **test scene** üzerinde region-backed read-only mode; toggle varsayılan KAPALI, eski kullanıcı sahneleri otomatik migrasyonsuz.
- [ ] 32×32 mesh için komşu sayfalardan “halo” örnekleri, seam, normals ve physics heightmap; görünür tile sayısı CPU ve GPU bütçesine bağlı.
- [ ] Kamera hızına göre prefetch mesafesi/öncelik, generation ID/cancellation (eski istek geç geldiyse kullanma), gerçek frame-time budget.
- [ ] Stale/missing page üzerinde boş arazi üretme; önce görünür veriyi muhafaza et veya okunamadı işaretle.
- [ ] CI: legacy vs region-backed mesh yüksekliği, normals, fizik, LOD, başarısız IO ve hızlı kamera geçişi.
- **Kapı:** Aynı Float32 örnekler, aynı görsel geometriler; CPU frame spike, resident RAM gözlemi; Android minimal sahnede doğrulama.

### P1.4 — PLAN: çok-bölge düzenleme / transaction / layer geçişi
- [ ] Çok sayfalı fırça darbesini tek Undo/Redo kaydı; kaynak ve diff, daha önce kaydedilmiş bölgeler dışında veri değiştirme.
- [ ] Birden fazla TFR1 sayfasını düzenlemek manifestin page SHA değerlerini geçersiz kılar: **versiyonlu transaction manifesti**, copy-on-write/journal/durable commit tasarla.
- [ ] İşlem sırasında kapanma, depolama doluluğu, farklı bölge sürümleri, .tmp / .bak / manifest mismatch testleri.
- [ ] TFL2 tahribatsız katmanlarını region-backed hâle getirme veya layer-source-stack olarak ayrı tutma kararı; dönüşüm kayıpsız olmalı.
- [ ] Eski .tfh/.tfl biçimlerinden **tek yönlü zorunlu** geçiş YOK; kullanıcı açıkça seçebilir ve geri dönebilir.
- **Kapı:** Çok bölgeli sculpt edit/undo + crash injection ile tutarlı commit; hiçbir ara sürüm “geçerli dünya” gibi açılmaz.

### P1.5 — PLAN: dev harita/bellek profili
- [ ] 2048², 4096², 8192² world profile; yakın ~24/48/96 sayfa bütçesi; region resident memory ve mesh budget ayrı.
- [ ] IO gecikme histogramı, RAM peak, cache hit ratio, kamera rotası, sayfa aç/kapat, depolama hızı/ısınma.
- [ ] Sık gzip/zstd sıkıştırma veya sayfa boyutu optimizasyonunu **ölçümden sonra** düşün; CPU maliyetini artıran rastgele optimizasyon yok.

## P2 — Jeomorfolojik iskelet (terrain only)

**Durum:** **PLAN**. Halihazırdaki artist-directed Ridge/Valley, gerçek havza ağı anlamına gelmez.

### P2.1 — Makro relief
- [ ] Kullanıcı kontrollü dağ omurgası/ridge graph; ana-ikincil sırt, gerçekçi vadi birleşimleri, havzalar, plato ve kıyı düzlükleri.
- [ ] Kontrol çizgileri spline/graph, değiştirilebilir node parametreleri; seed ve boyut ölçekleri.
- [ ] Düşük frekans, directional curvature, crest asymmetry ve fold relief; rastgele FBM yalnız kontrollü varyasyon.

### P2.2 — Catchment/watershed graph
- [ ] Açık çıkış/kapalı havza analizi, flow accumulation, fill/breach stratejileri, yönlü yağış ve akış hiyerarşisi.
- [ ] Flat alanlarda keyfi yön şeritlerini engelle; D8'e tek başına bel bağlama; MFD/D-infinity ve doğrulama kıyasları.
- [ ] Topolojik akarsu birleşimi, her vadi kolu fiziksel olarak daha büyük drenajla ilişkili.
- [ ] Analiz katmanı salt okunur, görsel hata teşhisi için debug contours/basin boundaries.

### P2.3 — Artist control vs process
- [ ] “Bu dağ sırtı buradan geçsin” kontrolü + gerçek jeomorfolojik sonuçlar; parametre katmanlarını yeniden hesaplama.
- [ ] 1:1 farenin göz seviyesinde near-ground örneklemeler, sırt silüeti ve yamaç kırıkları; tekrar eden daire/noise olmaması.
- **Kapı:** Referans gerçek topografyayla yapı karşılaştırması, farklı seed aynı erozyon karakteri, işlem deterministik.

## P3 — Erozyon, sediment ve kaya dirençleri (geometri)

**Durum:** **PLAN**. Mevcut Weather = 4-yönlü sınırlı termal süreç; drenaj MFD = analiz; **hidrolik erozyon yok**.

### P3.1 — Fizik temelli küçük alan prototipi
- [ ] Yağış kaynak haritası → yüzey suyu → taşınma kapasitesi → incision → deposit/evaporation.
- [ ] Su ve sediment ayrı Float32 alanları, gerekirse sabit zaman adımı ve CFL benzeri kararlılık kontrolü.
- [ ] Analitik kütle/malzeme denkliği, negatif sediment/su yok, uzaya yükseklik taşması yok.
- [ ] Farklı zemin dirençleri ve eğime bağlı transport, tutarlı delta çıkışı.

### P3.2 — Büyük bölge ve sınırlar
- [ ] Region/halo sınırlarında su/sediment akışı; çok bölgeli transaction; snapshot+undo.
- [ ] Flow acceleration, derin kanal, tali derecik, heyelan, birikim konisi, gerçekçi havza bağları.
- [ ] CPU job budget, iptal, cache; Mobile Renderer'da sınırsız GPU compute varsayma.

### P3.3 — Yüzey ayrıntı skalaları
- [ ] Tekerlek/fare ölçeği micro-relief, akış izleri, teraslar, çentikler, talus taş dağılımının **geometrik bileşeni**.
- [ ] İki aşamalı/noise ile doku taklidi YAPMA; gerçek height geometrisi ve LOD ayarları.
- **Kapı:** Aşınma doğruluğu hem sayısal hem referans görüntüyle; mobil tekrarlanabilir bütçe.

## P4 — Profesyonel görünür geometri / LOD / dev dünya

**Durum:** mevcut 3 stride distance LOD **DONE**, daha gelişmiş seçenekler **PLAN**.

### P4.1 — Render seçeneklerini deneysel karşılaştır
- [ ] Mevcut CPU-generated tile mesh'i referans baseline olarak sakla.
- [ ] Sabit mesh + shader displacement / geometry clipmaps prototipi (Mobile Renderer'da API/texture format uyumuyla).
- [ ] CDLOD / quadtree ve ekran uzayı hata metrikleri; tek seçenek baştan doğru varsayılmayacak.
- [ ] Ekran-piksel hata üst sınırı, vertex sayısı, draw call, ana thread meshi yeniden kurma, GPU upload ölçümü.

### P4.2 — Görsel seam doğruluğu
- [ ] Gerçek topolojik edge stitching veya geomorph; mevcut interpolated border/normal tek başına yüzde yüz crack-free kanıtı değil.
- [ ] Hızlı kamera rotasında LOD popping/flicker/histerezis, komşu LOD farklılıkları (LOD0↔1↔2).
- [ ] Nadir derin vadiler, uçurum kenarları, negatif yükseklikler, büyük eğimler için görsel/physics uyumu.
- **Kapı:** Çatlak ve flicker yok + p95/p99 ve fizik maliyetini makul tutma.

## P5 — Yakın oyuncu fiziği ve oyun etkileşimi (yalnız terrain)

- [ ] HeightMapShape3D yakın fizik kapsaması; render LOD'undan farklı çarpışma çözünürlüğü politikası.
- [ ] Mesh/physics sınır sapmaları; fırça ve stream'in collision'ı güncellemesi.
- [ ] Fare karakter kameranın 5–50 cm yüksekliğine yakın yerde mikro detay gerektirir; world ölçüsünde doğru örnekleme.
- [ ] Suyun yakınındaki kıyı/kayalık/oyuk geometri; ayrı görsel nehir objelerini yerleştirme bu kapsama dahil değil.
- [ ] Floating-origin / large world coords, precision loss ve koordinat taşıma; gerekirse çift hassas master/global page key.
- **Kapı:** Karakter traversal simülasyonu, yere batma/boşluk/çarpışma kaybı yok, Android frame time raporu.

## P6 — Profesyonel editor operatör deneyimi

- [ ] Tahribatsız generator graph ve layer dependency; yalnız height/erosion parametreleri.
- [ ] Spline/ridge graph editor ve gizlenebilir önizlemeler; ekranı kaplamayan 3D toolbar popup.
- [ ] Ölçüm/analiz araçları: kesit yükseklik profili, eğim/eğim yönü, izohips, havza sınırları, normal ve LOD debug.
- [ ] Geri al/ileri al ve yıkıcı olmadan önizleme; uzun işlemde cancel/resume ve telefonda autosave (yeterli tutarlı transaction sonrası).
- [ ] Heightmap import kalitesi: JPEG 8-bit kaynaklar için uydurma 16-bit detay iddiası yok; gerçek float/16-bit kaynak iş akışı.
- **Kapı:** Kullanıcı senaryoları, ekran kullanım alanı, yanlış dokunma ve veri kaybı sıfıra yakın davranış.

## P7 — Profesyonel kalite ve teslim öncesi gate

- [ ] GitHub CI, data format migration matrix, Android 11 gerçek renderer smoke + 30–60 dk dayanıklılık.
- [ ] 30 FPS sınıfı başlangıç hedefi p95 ≤ 33.3ms, p99 ≤ 50ms (**hedef**, ölçülmüş değil); kullanıcı cihazı ve sahneye göre yeniden değerlendir.
- [ ] RAM sürekli artışı yok, GPU ani yük/driver reset/crash yok, render/physics seam yok.
- [ ] Aynı sahne ve kamera rotasında Terrain3D veya uygun uzman motorla **adil, normalize performans karşılaştırması**; doğrulanmamış “daha iyi” iddiası yok.
- [ ] Dış kaynak heightmap geometri karşılaştırması, yakın zemin fare-bakış testi, görsel doğallık raporu.
- [ ] Basılacak stable sürüm, geri dönüş ZIP'i, migration docs ve test sertifikası.

## Yol haritası yönetimi

- Her alt görev için: **status, branch commit SHA, CI run URL, cihaz raporu, bilinen risk, rollback** kaydet.
- Sıradaki öncelik P1.2'dir; P2/P3'e ilerlemek için P1 veri mimarisinin tamamının bitmesi şart değil, fakat uygulama **izole prototipte** kalır.
- Kodlanan ancak test edilmeyen özellik “DONE / CI PENDING”; Godot Linux CI geçen ama Android bilinmeyen “CI PASS / DEVICE PENDING”.
- Teknik detaylar için [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md), [ENGINE_ARCHITECTURE_TR.md](ENGINE_ARCHITECTURE_TR.md), [QUALITY_TESTS_AND_BENCHMARKS_TR.md](QUALITY_TESTS_AND_BENCHMARKS_TR.md).
