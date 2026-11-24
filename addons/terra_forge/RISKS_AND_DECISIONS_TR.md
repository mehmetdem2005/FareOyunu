# TerraForge — Karar Günlüğü, Risk Kaydı ve Geri Dönüş İlkeleri

**Güncel as-built:** v0.4.2-dev.2 / 24 Kasım 2026. **Status:** Bazı çekirdekler Linux CI PASS; Android performans/doğallık kanıtı yok. Risklerin giderilmiş olması için ayrıca belirtilen kabul testi şarttır.

## A. Değiştirilmeyecek temel kararlar

| ID | Karar / gerekçe | Geriye dönük davranış |
|---|---|---|
| D-01 | Repo `mehmetdem2005/FareOyunu`, çalışma dalı `feat/terraforge-mobile-addon` | `main` veya oyun sahneleri değişmez; yalnız addon ve CI workflow |
| D-02 | Telefon / Android 11 / Godot 4.7.2 hedefi; küçük ekran ve kontrol | Kompakt 3D toolbar popup, büyük bottom dock yok |
| D-03 | Geometri, veri, fizik ve LOD öncelikli | Malzeme boyama ve obje/bitki yerleştirme durduruldu |
| D-04 | Float32 master, gerçek kaynak bit derinliği | JPEG/8-bit'lik kayıp veriyi EXR'e dönüştürmek gerçek 16-bit detay üretmez |
| D-05 | Mevcut `TFH1` source korunur | `Enable Layers` opt-in; TFH yedek, TFL2 tek otorite |
| D-06 | Eksik/bozuk source fail closed | Read-only, sahte düz height0 oluşturma yok; açık restore |
| D-07 | Staged, doğrulanmış export ve overwrite reddi | TFR1/TFM1 output yalnız yeni klasöre, kaynak sha korunur |
| D-08 | TFR1/TFL2/TFM1 checksum | SHA256 bütünlük kontrolü, yetkilendirme/şifreleme değil |
| D-09 | Sadece kanıtlı performans iddiası | CI Linux headless != Android GPU, daha hızlı oldu iddiası yok |
| D-10 | Jeomorfolojik nedensellik | Noise ve yuvarlak damga = referans doğa değildir; watershed + aşınma şart |
| D-11 | Tek sample/owner border | x=32, z=32 örnekleri iki disk sayfasında kopyalanmaz |
| D-12 | Render/physics node main thread | Worker sadece dosya/buffer/algoritma, Godot Node/Mesh güvenli uygulama ana thread |
| D-13 | Testte önce bağımsız prototip, sonra opt-in canlı mod | Eski sahnelere otomatik migration ve zorunlu format değişikliği YOK |
| D-14 | Godot ci çalıştırmadan “tamamlandı” deme | Dosya commit SHA + Actions run + PASS/FAIL logu gereklidir |

## B. Açık kritik riskler

### R-01 — Canlı RAM mimarisi hâlâ bütünü tutuyor
**Önem: ÇOK YÜKSEK.** TFR1/TFM1, read-only paged source, kamera scheduler ve asenkron worker çalışsa da `terrain/terra_forge_terrain.gd` doğrudan `height_data.heights` dizisini kullanır. UI'da “disk streaming” diye anlatılan resident tile yalnız mesh/collision'dır. 4096², 8192² ve 16k² için gerçek RAM yükü katlanır. **Önlem:** P1.2 sampler/senkron prefetch + P1.2b worker-thread IO DONE / 23 CI PASS; P1.3 read-only mesh/collision ve P1.4 edit transaction PLAN; gerçek Android profili yok.

### R-02 — Manifest/page tutarlılığı
**Önem: KRİTİK.** TFM1 `pages[].sha256` manifesti immutable snapshot'ı tanımlar. Bir TFR1 sayfası write_height/flush ile değiştiğinde manifest artık o sayfaya ait değildir. Page + manifest çift dosya yazımı sırasında crash, dünyanın “bir kısmı yeni, bir kısmı eski” olmasına yol açar. **Önlem:** Generations + copy-on-write + tek atomic head-pointer/manifest publish, journal, tüm sayfa SHA doğrulaması. Böyle bir transaction olmadan **canlı paged sculpt açma**.

### R-03 — Synchronous disk IO ve SHA frame hitch
**Önem: YÜKSEK.** TFR1 sayfa read/write, manifest full-check ve hashler senkron; TFL2 büyük dosya kaydı/main thread. Android düşük depolama hızı ve termal throttling ile dokunmatik editör donabilir. **Kısmi önlem DONE:** Bounded 1–8 **senkron** page read/tick, cache hit/miss ve IO last/max ms ölçülüyor. Bu bir frame-time garantisi değil. **Kalan:** background worker + bounded inflight, generation cancellation sonuç yayınında, cold source immutable buffer, main-thread scene commit.

### R-04 — Android gerçek test eksik
**Önem: YÜKSEK.** Godot 4.7.2 Linux headless CI 23/23 PASS, ancak Redmi/Android sürücü/gesture/perf kanıtı yok. Önemli yüzey mesh, collision ve UI problemleri önceden yalnız kullanıcı görselinden tespit edilmişti. **Önlem:** P0 cihaz smoke, 30 dk memory, FPS/ısınma; hata raporu ve birebir sahne.

### R-05 — Görsel LOD topoloji gerçekten stitched değil
**Önem: YÜKSEK.** Mevcut LOD komşu height uyarlaması ve normals daha iyi fakat T-junction, aşırı eğim normal, ani transition/popping, physics sınırı olabilir. **Önlem:** Analytical seam tests + ground-camera screenshot; gerekirse edge stitching ve geomorph; hızlı kamera hareketi test.

### R-06 — Çakma tepe / doğal olmayan drainage
**Önem: YÜKSEK.** Organic Stamp ve kıvrılmış Ridge/Valley **daha az simetrik**, fakat doğanın jeolojisini simüle etmez. MFD lokal analiz, akarsu/basin graph ve sediment taşınımı değildir. **Önlem:** Ridge graph + watershed + hidrolik/sediment fizik ve gerçek referans topografya kıyası. “Doğal” etiketi kullanımda ölçümsüz değil.

### R-07 — TFL2 backup sınırlılığı
**Önem: ORTA-YÜKSEK.** .bak yalnız önceki başarılı kayıt; ilk kayıt sonrası yok. Restore veriyi eski zamana alır. Disk doluluğu ve .bak / .tmp kopyalama zamanını Android henüz doğrulamadı. **Önlem:** Staging/yedek alanı ölçümü, backup retention, eylem öncesi kullanıcı uyarısı; test dünya ve kaynak export.

### R-08 — Layer + scene double-save semantiği
**Önem: ORTA-YÜKSEK.** `layer_mode` ve `layer_file` Godot .tscn ile, height deltas TFL2 ile saklanır. Kullanıcı yalnız `Terrain > Save` yapıp scene'i kaydetmezse yeni node özellikleri kalıcı olmayabilir. **Önlem:** Mobile UI uyarısı, sahne değiştiğinde guard, tekrar açılan packed scene testi (CI var), gerçek telefon UX.

### R-09 — Region snapshot editable layer kaybı
**Önem: YÜKSEK.** TFL1/TFL2 → TFR1 export yalnız visible composite; her layer'ı bağımsız edit edemezsin. Kaynak TFL silinirse non-destructive düzenleme verisi kaybolur. **Önlem:** TFL kaynak korunur; manifest `flattened_layers=true`; sonradan region layer schema/graph tasarla. Snapshot'ı TFL'nin yerine geçirme.

### R-10 — Boyut, dosya ve bellek üst sınırları
**Önem: ORTA.** RegionStore MAX_WORLD_CELLS=32768 ama Manifest max 10k sayfa ve 2MiB, yani bütün teorik MAX_WORLD_CELLS manifestle kullanılamaz. TFH/TFL max 2048 cell. Tek büyük aşırı IO veya milyonlarca metadata satırı olabilir. **Önlem:** World bounds/manifest kapasitesi/fail codes testleri ve gerekirse hiyerarşik manifest.

### R-11 — Float32 ve heightmap representasyon sınırı
**Önem: ORTA.** Heightfield tek (x,z) için tek y değeri tutar; gerçek mağara, overhang, düşey duvar altı “kapalı hacim” gösteremez. Float32 büyük dünyada konum hassasiyeti de sınıra yaklaşabilir. **Önlem:** Gerektikçe ayrı voxel/SDF veya mesh geçişi P5; mevcut basit heightfield'ı aşırı karmaşıklaştırma.

### R-12 — Mobil cihazın gerçek bütçesi
**Önem: ORTA-YÜKSEK.** CPU budget tile/frame sayı + ms vardır ama tek tile uzunluğu bütçeyi aşabilir. RAM raw page bytes ≠ gerçek RSS. GPU VRAM/driver state, terrain mesh draw call maliyeti hâlâ bilinmiyor. **Önlem:** p95/p99 profiler, GPU upload önbellek, aynı rota, 30 dk soak.

### R-13 — Android dosya izinleri ve export staging
**Önem: YÜKSEK.** `res://` write erişimi ve `user://` dosya yolları Android editörde farklı; staging klasörü disk doluluğu veya izin nedeniyle yarım kalabilir. **Önlem:** output path yazma kontrolü, staging çöp dosya recovery, kaynak SHA tekrar doğrulama, Android sahasında manuel test. `main`/oyun dosyalarına dokunma.

### R-14 — Çalışma bağlamı/sonraki sohbet unutması
**Önem: ÇOK YÜKSEK.** Uzun sohbet değişince son commit, biten faz ve koruma kuralları kaybolabilir. **Önlem:** `HANDOFF_START_HERE_TR.md` başlangıç otoritesi, bu karar/roadmap/status belgeleri, her commit sonunda güncelleme ve gerçek GitHub head okuma; asla eski özetleri kodun yerine koyma.

### R-15 — P1.2 doğrulama başlangıcında çok sayfalı senkron tarama ve kamera prefetch sınırları

**Önem: YÜKSEK.** `paged_height_source.open()` TFM1 manifestteki her TFR1 sayfasını senkron doğrular; büyük dünyada açılış beklemesi oluşabilir. `camera_page_prefetch.tick()` çağrı başına 1–8 disk okumasını sınırlar ancak tek okuma yavaş NAND'de frame süresini aşabilir. Pending generation iptali yalnız henüz başlamamış işleri kapsar, in-flight thread sonucu kavramı henüz yok. **Önlem:** P1.2b async/worker-safe IO, full-file SHA + data buffer snapshot, bounded pending/inflight, gerçek kamera stress ve Android p95/p99.

### R-16 — P1.2b thread lifetime / async başlangıç maliyeti

**Önem: ORTA-YÜKSEK.** Yeni `async_region_source.gd` worker Thread/Mutex/Semaphore ile 23/23 CI geçti, fakat `open()` tüm TFM1/TFR1 sayfalarını senkron tarar. `close()` thread içindeki son IO bitene kadar `wait_to_finish()` ile bloklanabilir; her karede aç/kapat yapılmaz. Mutable world source/manifest değişirse cache daha önce doğrulanmış height gösterebilir; P1.4 editable mode'da generation-bound immutable manifest gerekir. **Önlem:** P1.3 opt-in read-only test, P1.5 async full-world startup policy, Android uzun süreli IO thread stress.

## C. Acil veri kaybı anında yapılacaklar

1. **Önce hiçbir dosyanın üzerine yazma.** GitHub kod dalı ve gerçek kullanıcının `terraforge_data` proje klasörünü ayrı yedekle.
2. Eski sahne `.tfh` eksik uyarısı veriyorsa yeni terrain ile üzerine yazma; aynı isimli orijinal TFH'yi geri getir.
3. `.tfl` bozuksa read-only; valid `.bak` varsa Restore **önceki kayıt** anlamına gelir; .corrupt_* kopyası korunmalı.
4. `TFR1` bir page bozuksa world manifest validation fail closed; eksik sayfa 0 olarak doldurulmaz. Önce bütün kaynak .tfh/.tfl korunur; tekrar **farklı hedef klasöre** export denenebilir.
5. Yarım `.tmp` veya `.staging_*` dosyalarını kaynak sanma; ne olduğunu doğrulamadan silme.
6. GitHub CI başarılı ama telefonda çökme varsa cihaz crash log/ekran kaydı topla; kurulumla ilgisiz sahne dosyasını asla değiştirme.
7. Geçerli kodda sorun varsa son doğrulanmış SHA arşivine geri dön; veri formatı geri dönüşü koddan bağımsız olabilir, yedekleri koru.

## D. Açık araştırma/karar konuları

- En iyi runtime LOD seçeneği **ölçümle** belirlenecek: CPU-generated tile baseline vs quadtree/CDLOD vs GPU-displacement clipmaps.
- Bölge sayfa boyutu 32 örnek prototip; disk IO overhead ve cache locality için 64/128 deneyleri ancak sonrası veri uyumu stratejisiyle yapılabilir.
- Büyük haritalarda manifest hiyerarşisi, checksum yazma modeli ve thread-safe IO protokolü netleştirilmeli.
- Erozyon gerçek zamanlı mı offline preprocess mi? Android CPU gereksinimi ve deterministik katmanlar nedeniyle önce offline/bounded job prototipi.
- Layer graph yalnız additive mi kalacak, procedural modifier DAG mı olacak? P6'da yeniden değerlendirilir.
- Kıyı/nehir height geometry'nin su render modülüne entegrasyonu gelecekte olabilir ama bugün sadece terrain geometri.
- Collision LOD ya render'dan bağımsız mı olmalı? Yakın fare-bakış kalitesine göre gerçek testle karar.

## E. Karar güncelleme şablonu

**D-XX:** karar başlığı | alternatifler | neden seçildi | kaybedilenler | değişen dosya/commit | CI run | Android test | geri dönüş yolu.  
**R-XX:** risk şiddeti | yeniden üretme senaryosu | zarar | koruyucu invariant | test / kabul | açık sorumlu faz.

Referans: [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md), [STATUS_AND_CHANGELOG_TR.md](STATUS_AND_CHANGELOG_TR.md), [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md).
