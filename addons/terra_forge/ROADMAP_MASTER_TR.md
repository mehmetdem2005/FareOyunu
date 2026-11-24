# TERRAFORGE — AÇIK DÜNYA TERRAIN MASTER ROADMAP (P0–P7)

> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

B1/B2 DONE, B3/B4 open.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

B1 format complete; B2–B4 open.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

P1.5.3a bounded fixture DONE / 30 CI; .3b planned.


> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

P1.5.0–.2 CI DONE; .3a–.10 ayrıntıları ana planda. Android gerçek ölçüm açık.


> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

- [x] P1.5.1 izole profil sahnesi, strict/lazy, JSON, sabit histogram (28/28 CI).
- [ ] 2048/4096/8192 gerçek dataset ve telefon performansı, termal/uzun soak; P1.4 henüz açık.


> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

- [x] P1.3c hata izolasyonu ve mevcut sağlam mesh/collision koruma (27/27 CI).
- [ ] Profil sahnesi, gerçek Android RSS/FPS/termal, collision boşlukları; P1.4 açık.


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

**Durum:** Linux headless CI ve kod regresyonları **DONE, 26/26 PASS**; Android son kullanıcı onayı **AÇIK**.

### P0.1 — DONE: altyapı
- İzole `feat/terraforge-mobile-addon` dalı; oyun ve `main` dosyaları korunuyor.
- Godot 4.7.2 headless CI, geçici test projesi, `bash -n`, script import, eklenti editör yükleme, 26 test.
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

### P1.2 — read-only sampler, kamera scheduler ve bounded async IO **DONE / CI PASS**

- [x] TFM1/TFR1 manifest + her sayfa checksum, dünyaya ait metadata, fail-closed.
- [x] Salt okunur Float32 get_height ve bilinear cross-region, LRU 1–64, cache/IO counters.
- [x] Senkron kamera prefetch nearest-first ve generation reset (korunan eski API).
- [x] **P1.2b:** `async_region_source.gd` tek Godot worker Thread, Mutex/Semaphore bounded 1–8 iş, SHA-256 **tek dosya buffer** üzerinden, main-thread sonuç kabulü, stale in-flight generation drop, explicit shutdown.
- [x] `camera_page_prefetch.configure_async()` opt-in; 23. test eski işi iptal/bozuk sayfa/safe join.
- [x] Kod SHA `4d5ed1bd`, [Godot 4.7.2 CI 23/23 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313).
- [x] **P1.5 read-only preview** TFM1 manifest-first + TFR1 on-demand SHA; strict eski varsayılan korunuyor. [26/26 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664).
- [ ] `close()` aktif dosya okumasını bekler; Android storage stalls ve gerçek frame p95/p99 ölçülecek.
- [ ] Canlı scene mesh/collision bağlantısı ve oyun RAM kazancı **yok**; P1.3 öncelikli.

**Kapı:** İZOLE async altyapı/test geçti, **gerçek canlı terrain ve Android cihaz kapısı AÇIK**. [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md).

### P1.3 — Read-only mesh/collision preview DONE; cihaz kabulü AÇIK

- [x] Gerçek paged `ArrayMesh` + LOD0 `HeightMapShape3D` üretimi; 32×32 tile, LOD0/1/2, normal halo ve mixed LOD kenar eşleme.
- [x] Yalnız yeni `paged_terrain_preview.gd` `Node3D` üzerinde opt-in; normal `TerraForgeTerrain` veya kullanıcının oyunu otomatik dönüştürülmedi.
- [x] Kamera öncelikli async disk page isteği → main-thread node, mesh ve collision update; bozuk sayfadan sahte düz tile yok.
- [x] `plugin.gd` editör 3D kamerayı aktarıyor, read-only info ve disabled Brush.
- [x] `test_paged_terrain_preview.gd` 24. test, legacy parity + corruption + source immutability, [24/24 Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421).
- [ ] Godot Android 11 gerçek Mobile Renderer görsel seam, 30 dk memory/CPU/GPU, p95/p99 ve fizik traversal onayı.
- [ ] Çok büyük dünya `open()` sync SHA, LRU halo thrash, hızlı kamera tile gap ve stale collision politikası için profiling/iyileştirme.
- [ ] Eski live `TerraForgeTerrain`'i ortak `HeightSource` adapter'a geçirmek henüz **PLAN**. Yeni preview farklı opt-in node.
- [ ] P1.4 atomik çok-region writable data transaction henüz **YOK**.

**Kapı:** İlk izole gerçek render/collision CI PASS, **cihaz ve oyun içine migration kapıları AÇIK**. [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

### P1.3b — Kamera sıçraması ve cache halo stresi DONE

- [x] `async_region_source.prioritize_resident(required)`: geçerli tile'ın cache'deki doğrulanmış height/normal sayfalarını LRU'da korumak için öne alır; kapasite 9–64 sınırını aşmaz.
- [x] `async_region_source.is_requested(page)`: duplicate job submit, background inflight sonuçların gereksiz tekrar sayılmasını engeller.
- [x] `paged_terrain_preview._sync_tiles`: büyük kamera sıçramasında generation-id değiştirir, eski pending/inflight sonuçlar render cache'e kabul edilmez; normal sınır geçişlerinde gereksiz cancellation yok.
- [x] `test_paged_camera_stress.gd`: 9 resident page + 2 outstanding worker job, köşe kamera zıplaması, LOD0 real collision, source SHA koruma. [25/25 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507).
- [ ] Gerçek Android 11 GPU, RSS, p95/p99, 30 dk cihaz sürüşü halen AÇIK; eski editable `TerraForgeTerrain` global height array'ini tutmaya devam ediyor.

### P1.4 — PLAN: çok-bölge düzenleme / transaction / layer geçişi
- [ ] Çok sayfalı fırça darbesini tek Undo/Redo kaydı; kaynak ve diff, daha önce kaydedilmiş bölgeler dışında veri değiştirme.
- [ ] Birden fazla TFR1 sayfasını düzenlemek manifestin page SHA değerlerini geçersiz kılar: **versiyonlu transaction manifesti**, copy-on-write/journal/durable commit tasarla.
- [ ] İşlem sırasında kapanma, depolama doluluğu, farklı bölge sürümleri, .tmp / .bak / manifest mismatch testleri.
- [ ] TFL2 tahribatsız katmanlarını region-backed hâle getirme veya layer-source-stack olarak ayrı tutma kararı; dönüşüm kayıpsız olmalı.
- [ ] Eski .tfh/.tfl biçimlerinden **tek yönlü zorunlu** geçiş YOK; kullanıcı açıkça seçebilir ve geri dönebilir.
- **Kapı:** Çok bölgeli sculpt edit/undo + crash injection ile tutarlı commit; hiçbir ara sürüm “geçerli dünya” gibi açılmaz.

### P1.5 — Manifest-first lazy opening DONE; gerçek dev harita profili PLAN

- [x] `async_region_source.open(..., verify_all_pages=false)` checksummed TFM1 manifest-first, TFR1 sayfaları yalnız ihtiyaç duyulunca worker SHA doğrulanır; strict varsayılan korunur.
- [x] `paged_terrain_preview.verify_pages_on_demand=true` (yalnız read-only preview), Inspector'dan strict geri dönüş; ON-DEMAND/FULL doğrulama sayıları `plugin.gd` panelinde.
- [x] `test_lazy_world_open.gd` 26. regresyon; missing/corrupt page, bozuk TFM1, yakın gerçek mesh/collision, stale işçi kaynakları güvenli kapanış. [26/26 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664).
- [ ] Manifest-only open tüm dünyanın **sağlam olduğunu kanıtlamaz**; cold page hata verir. Android 11 FPS / RSS / startup süre ölçümü yok.
- [ ] Gerçek 2048²/4096² harita, FileAccess latency ve 30 dk kamera testleri bekliyor. Ayrıntı [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).

### P1.5.1 — PLAN: dev harita/bellek profili
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
