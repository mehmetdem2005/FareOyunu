# P1.3 — Gerçek Bölgesel ArrayMesh ve Çarpışma Entegrasyonu (Salt Okunur)

**Durum:** v0.4.4-dev.1 / **izole opt-in prototip UYGULANDI**. **25/25 Godot 4.7.2 CI PASS**: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507  
**Kod commit'leri:** `4422e0b6` (ilk prototip), `c0068833` (adil mesh-normal parity testi), `286b135d` (editör kamerası köprüsü).  
**Dal:** `feat/terraforge-mobile-addon`. Ana `main`, Fare oyununun mevcut sahneleri ve `terraforge_data` korunmuştur.

## Kullanıcı için: gerçekten ne değişti?

Daha önce TFR1 verisini küçük bloklar olarak diskte saklamak, SHA-256 ile doğrulamak ve background worker ile okumak mümkündü; fakat **oyun görünür mesh'i hâlâ global TFH/TFL Float32 dizisinden üretiliyordu**. Şimdi **yeni, ayrı ve salt okunur** `paged_terrain_preview.gd` düğümü, async TFR1 sayfalarından gerçek `ArrayMesh`, vertex normals ve LOD0 `HeightMapShape3D` collision üretiyor. Kamera yer değiştirdikçe en yakın tile'lar isteniyor. Hazır olmayan sayfa hiçbir zaman **0 yüksekliğinde sahte mesh** olarak gösterilmiyor. Yüksekliğin tüm 2D dünyası Float32 dizi olarak RAM'e kopyalanmıyor.

Bu, **legacy `TerraForgeTerrain` düğümünün değiştiği anlamına gelmez**; eski fırçalar, Undo/Redo, TFH/TFL save ve kullanıcı oyun sahneleri aynen çalışıyor.

## Uygulanan dört değişiklik

1. **`core/paged_tile_geometry.gd`**: TFR1 backend'in cache'inden 32-cell tile mesh üretimi. LOD0/1/2 stride 1/2/4, coarse komşu kenar interpolasyonu ve same-LOD normal halo. Sadece hazır Float32 örnekleri okur. Herhangi bir sayfa hazır değil/bozuksa `{error}` döndürür; vertex/collision dizisini kısmi yayınlamaz.
2. **`terrain/paged_terrain_preview.gd`**: Node3D tabanlı, **@tool**, `preview_enabled=false` varsayılan. `region_directory` export alanı, RAM resident limit 9–64 sayfa (varsayılan 16), max 1–8 background job (varsayılan 4). `start_preview(dir,cache_pages,max_jobs)`, `set_stream_center(global_position)`, `pump_stream()`, `stop_preview()`, `stats()`. 32×32 tile `ArrayMesh` + LOD0 `HeightMapShape3D` / `StaticBody3D` yaratır. Kamera uzağa gidince eski görünür tile ve collision bellekten çıkar; in-flight yüklemeler eksik olduğunda görünür boş/0 yükseklik yaratılmaz. Ana thread mesh/shape yapar.
3. **`plugin.gd`**: Godot editöründe yeni preview düğümünü tanır, aktif seçiliyken 3D editör kamerasının konumunu preview'ya iletir. Mevcut kompakt popup **READ-ONLY** durumu ve tile/page/read sayaçlarını gösterir. Brush düğmesi devre dışı; Save/Undo/Redo eski `TerraForgeTerrain` veri düzenleme yollarını çalıştırmaz. Legacy editor akışı korunur.
4. **`tests/test_paged_terrain_preview.gd`** ve `tests/run_all.sh`: 24. regresyon, bütün LOD'lardaki visible vertices/normals/triangle indices, mixed LOD0→LOD2 seam ve LOD0 collision heightmap'i **eski legacy renderer ile** karşılaştırır. Gerçek Node mesh/collision üretiliyor mu, RAM page bound, kaynak TFH dokunulmazlığı, bozuk TFR1 sayfadan sahte mesh oluşmaması ve yok world'ün reddi sınanır.

### Testte yakalanıp giderilen hata

İlk 24'lü CI, normalde `~2×10^-5` fark gösterdi. Sebep eski normalin **Godot ArrayMesh'e paketlenip geri okunmuş**, yeninin ise ham Float32 hesap dizisi olmasıydı. Her iki tarafta **aynı ArrayMesh roundtrip** yapıldı; tolerans rastgele artırılmadı ve 24/24 PASS alındı. Başarısız CI geçmişleri de korunur; güncel yeşil çalıştırma https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421 .

## Android / Godot editörde ilk kullanım (opt-in, test haritası)

1. Kullanıcının asıl TFH/TFL/harita dosyalarını ve sahnesini değiştirme. **Ayrı test sahnesi** oluştur, eklentiyi aç.
2. Eski `.tfh` veya `.tfl` verisinden `region_export.gd` ile hazırlanmış, **TFM1 manifesti ve TFR1 sayfaları doğrulanmış yeni dünya klasörü** gerekir. Bu işlem terminal/API üzerinden izolasyonla yapılır; henüz Android UI'da export butonu yok.
3. Godot editörde ayrı `Node3D` oluştur; `res://addons/terra_forge/terrain/paged_terrain_preview.gd` script'ini bağla. Inspector'da `region_directory` alanına doğrulanmış klasör path'ini (ör. `res://.../world` veya erişilebilir `user://...`) yaz; `preview_enabled` işaretle.
4. Düğümü seç; mevcut küçük TerraForge popup'ta **Read-only** ibaresi görülmeli. Godot 3D editör kamerayla gezildiğinde düğüm `set_stream_center` aracılığıyla görünür tile taleplerini günceller.
5. `stats()`: tiles, pending_tiles, vertices, source.resident/limit, disk_reads, IO max ms, error. Error varsa eksik dosyayı önce kontrol et; source üzerine yazma.
6. Sahneyi kaydedebilirsin; ama bu düğüm `save_data()` ve `paint_at()` için `ERR_UNAVAILABLE` döndürür. **Burada şekillendirme, boya, obje düzenleme yoktur.**

## P1.3b — Kamera ve minimum-cache stres düzeltmesi (DONE)

- `async_region_source.gd`: `prioritize_resident(required_pages)` mesh oluşturulacak tile'ın hazır Float32 ve normal halo sayfalarını LRU önceliğinde tutar; gerçek page lock değil ve toplam cache limitini yükseltmez. `is_requested(page)` zaten kuyruktaki bir page'yi yeniden submit saymaz.
- `paged_terrain_preview.gd`: kamera merkezi önceki queue odağından en az 2 region uzaklaşınca worker `generation` değiştirir. Eski queued ve geç tamamlanan disk işleri yeni kamera hedefinin önüne geçemez. Küçük hareketlerde gereksiz cancellation yapılmaz.
- `test_paged_camera_stress.gd`: 9-page minimum cache, 2 worker job, 128×128 bölgesel dünya, çoklu uzak kamera sıçraması ve gerçek LOD0 HeightMapShape3D collision ile senkron karşılaştırmalı stres. [CI 25/25 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507).
- **Dikkat:** Bu CI Linux Godot headless testidir; Android 11 RAM/GPU/FPS ve gerçek görüntü deliksizlik testi hâlâ gerekli.

## P1.5 güncellemesi — manifest-first preview DONE

**Tarihsel P1.3 açıklamalarına güncel ek:** `paged_terrain_preview.verify_pages_on_demand=true` ile yeni preview ilk açılışta yalnız checksummed TFM1'i doğrular, tüm TFR1 dosyalarını taramaz. İstenen sayfa worker'da SHA geçmeden mesh/collision olmaz; bozuk uzak sayfa ilk istenene kadar bilinmeyebilir. `false` seçilirse önceki full-world strict açılış çalışır. [26/26 Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664), gerçek Android süre profili yok. İlgili yeni otorite: [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).

## Büyük açık sınırlar — bitmiş gibi anlatma

- **Büyük dünya açılışı:** Eski strict `async_region_source.open()` tüm TFR1 sayfalarını başta doğrular. Yeni read-only preview **ON-DEMAND** varsayılanında yalnız TFM1 manifestini senkron açar, TFR1 SHA'ları ihtiyaç anına erteler. Bu mod tüm dünya hasarsız garantisi değildir.
- **Eski editör Terrain node değişmedi:** `TerraForgeTerrain` hâlâ global `height_data.heights` kullanır. Şu andaki RAM tasarrufu yalnız **yeni test önizleme düğümünün** kaynak dizi tutmamasıyla sınırlı; tüm oyunda karşılaştırmalı RSS/GPU kanıtı yok.
- **Tek tile için page halo:** Normal/çarpışma dahil up to 3×3 = 9 TFR1 sayfa gerekebilir; bu yüzden preview cache min=9, default=16. Main-thread `ArrayMesh` oluşturma ve `HeightMapShape3D` collision upload maliyeti ayrıca profillenmeli.
- **Fizik LOD0 ile sınırlı**, legacy davranış gibi uzak LOD1/2 fizik shape boş. Near-fare kamera ve hızlı hareket halinde collision coverage ayrı incelenmeli.
- **Ortam/Android 11 / gerçek Mobile Renderer testleri henüz YOK**. Godot Linux headless test geçişi GPU performansı, shader sürücü sorunu, gerçek screenshot/görsel yarıksızlık kanıtı değildir.
- **Readonly immutable snapshot:** TFR1 sayfaları değişirse TFM1 checksum eskir. Multi-region atomic write transaction olmadan bölgesel fırça, katman veya Undo/Redo açılmayacak.
- Aynı test projesinde legacy ve preview node'u aynı koordinata koyarsan **iki görünür arazi üst üste binebilir**; karşılaştırmada ayrı sahne/konum veya yalnız birini göster.
- `start_preview` ve `stop_preview` normal karede tekrar edilmemeli: birincisi senkron dosya doğrular, ikincisi worker join yapar.

## Sıradaki mühendislik alt işleri (P1.3 kalite kapısı → P1.4)

- [ ] Gerçek Android 11 Godot 4.7.2 Mobile Renderer test sahnesi; kamerayla gez ve 30 dk RAM/GPU/CPU p95/p99/IO gözle. Tekil tile yeni sayfa beklerken **önceki tile korunuyor mu** ve geçiş sırasında delik kalıyor mu? Gerekirse önceki LOD/collision son sağlam shape'i bırak.
- [ ] Komşu **farklı LOD'lar** arasında yüzey geometrisi + normals ve fizik sahası için ekran görüntüsü ile gerçek kontrol; salt sayısal vertex parity tek başına kusursuz crack-free topoloji kanıtı değildir.
- [ ] Gizli global full-grid data kopyası olmadan eşit sahnede legacy vs region-backed RSS, p95/p99 CPU ve GPU upload karşılaştırması.
- [ ] Büyük world `open()` tam SHA taramasını background/manifest-first için **fail-closed** tasarla; önce var/bozuk world kontrolünü koru, yalnız ertelenen doğrulanmamış sayfalar yüklenmemiş olarak gösterilsin.
- [ ] Düğümler arasında ortak `HeightSource` abstraction, daha sonra eski live node'un read-only region mode'a kademeli geçişi; fırça tamamen kapalı.
- [ ] P1.4 çok-sayfalı, manifest generation tutarlı, crash-safe transaction; non-destructive layer delta + Undo/Redo; kaynaktaki TFH/TFL **dokunulmaz**.

Detaylı fazlar [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md), teknik mimari [ENGINE_ARCHITECTURE_TR.md](ENGINE_ARCHITECTURE_TR.md), sonraki iş [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md).
