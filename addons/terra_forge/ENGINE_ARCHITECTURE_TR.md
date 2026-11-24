# TerraForge — As-Built Mimari, Veri Formatları ve Modül Envanteri

**Kod tabanı:** v0.4.1-dev.2, `734c9088d76603279599654d345249b0cc90e321`. **Hedef:** Godot 4.7.2 / Android 11 Mobile. **Kural:** Bu belgeyi kod değiştikçe güncelle; doğrulanmamış bileşenleri CANLI diye sunma.

## 1. Modül envanteri

| Yol | Sorumluluk | Durum |
|---|---|---|
| `plugin.cfg` | Addon tanımı ve göreli `script="plugin.gd"` | CANLI |
| `plugin.gd` | EditorPlugin, kompakt Terrain/Brush toolbar, touch raycast, layer UI, Check | CANLI |
| `terrain/terra_forge_terrain.gd` | Terrain Node3D, tile mesh/LOD/collision, sculpt, Undo/Redo, save | CANLI |
| `core/height_store.gd` | TFH1 global Float32 grid, bilinear örnek, yükleme/kayıt | CANLI |
| `core/height_layers.gd` | TFL1 geriye uyum, TFL2, sparse additive layers, SHA256, .bak/Restore | İSTEĞE BAĞLI CANLI |
| `core/lod_policy.gd` | LOD seçimi, stride 1/2/4, 8m hysteresis, tile candidates | CANLI |
| `core/brush_shapes.gd` | Araç ID'leri, organik Hill/Crater/Mesa ve kesit profilleri | CANLI |
| `core/landform_paths.gd` | World-space Ridge/Valley; bounded noise cache | CANLI |
| `core/thermal_weathering.gd` | Talus-eşikli lokal termal height transfer | CANLI |
| `core/drainage_analysis.gd` | Bounded priority-flood ve MFD accumulation | SALT OKUNUR ANALİZ |
| `core/self_test.gd` | Terrain > Check scratch veri tanılaması | CANLI |
| `core/region_store.gd` | TFR1 disk page, LRU, load/save/evict | İZOLE, CANLIYA BAĞLI DEĞİL |
| `core/region_manifest.gd` | TFM1 world manifest + source/page hash kontrolü | İZOLE |
| `core/region_export.gd` | TFH/TFL snapshot → staged TFR1 pages + manifest | İZOLE |
| `tests/*.gd` | 20 Godot headless regresyon | CI PASS |
| `tests/run_all.sh` | 4.7.2 version, PASS çıktısı, exit code, engine log kontrolleri | CI PASS |
| `.github/workflows/terraforge-ci.yml` | Ubuntu, geçici Godot projesi, 20 test, log artifacts | CI PASS |

**Kesin ayrım:** `region_store.gd` bulunması, çalışan oyunda RAM tasarruflu streaming yapıldığı anlamına GELMEZ. Canlı terrain hâlâ `height_data.heights` için bütün world Float32 yükseklik dizisini bellekte tutuyor.

## 2. Canlı veri akışları

### TFH legacy (varsayılan)
1. Scene `TerraForgeTerrain` yaratır; `layer_mode=false`.
2. `height_store.gd` veri dosyasını tüm grid olarak RAM'e yükler. 32–2048 cell sınırı; örnek sayısı (cells.x+1)×(cells.z+1).
3. Bağlı dosya eksik/hasarlıysa read-only. Yalnız açıkça yeni terrain yaratma akışı geçici `allow_data_creation` kullanabilir.
4. Fırça global Float32 diziyi değiştirir; mesh ve collision değişen tile'larla yeniden kurulur; Undo/Redo görünür heights kayıtlarından oluşur.
5. `Save` TFH veri dosyasına yazar; Godot scene ayrıca kaydedilmelidir.

### Opt-in TFL2 canlı katman
1. `Enable Layers` eski TFH'yi korur, ayrı TFL belgesi oluşturur. Scene'i kaydetmek `layer_mode` ve `layer_file` yolunu kalıcı yapar.
2. Base Float32 + en çok 8 sparse additive 32×32 layer delta block; layer görünürlük ve opacity API'si; canlı sculpt yalnız etkin, %100 opacity seçili layer.
3. Stroke sonu delta kayıtları; Undo/Redo hem delta hem visible composite restore. Görünürlük değişince kompozit yeniden hesaplanır, geçmiş tutarlılığı için Undo geçmişi temizlenir.
4. TFL2 **tek otorite veri dosyası**; TFH yedek snapshot olarak kalır, değiştirilmez.
5. TFL2 SHA-256, .tmp staging, önceki sağlam .bak, açık Restore; eksik/bozuk TFL2 read-only, sessiz TFH fallback YOK.

### İzole bölgesel export
1. `region_export.gd` TFH1 veya TFL1/TFL2 dosyasını yükler; katmanlı kaynakta sadece **görünen birleşik** Float32 yükseklik hesaplanır (layer editing kaynakta kalır).
2. Benzersiz staging klasöründe 32×32 sample page'ler yazılır, her page SHA doğrulanır.
3. TFM1 world manifest source SHA, dimensions, spacing, page list+SHA tutar. Kaynak son anda tekrar hashlenir.
4. Tüm sayfalar doğrulanır ve staging tek directory rename ile yayınlanır. Zaten var olan hedef klasörü overwrite ETMEZ.
5. Export **canlı sahneyi yeni data source'a bağlamaz**; RAM düşüşü iddiası yok.

## 3. Beş formatın kesin sözleşmesi

### TFH1 — temel yükseklik
- Little-endian magic `TFH1`, cells.x/z, Float32 spacing, row-major Float32 sample.
- Örnek sayısı `(cells.x+1)*(cells.z+1)`; global indis `index_of(x,z)=z*(cells.x+1)+x`.
- Varsayılan 256×256 cell, spacing=1; script export 32–2048 cell ve spacing 0.25–4.0. Yalnız base 2049² sample yaklaşık **16 MiB**.
- Dosya bozulursa sıfırdan yeniden oluşturma/sessiz overwrite YASAK.

### TFL1/TFL2 — katman belgesi
- TFL2 magic; Float32 base + max 8 layer; layer: name, enabled, opacity, sparse 32×32 Float32 delta pages.
- Max 2048 cells/eksen, 64 UTF8 byte layer adı, 192 MiB dosya limiti.
- TFL2 full-payload SHA-256 **64 ASCII hex footer**; TFL1 geriye okunur ve açık save ile TFL2 migrasyonu.
- .tmp → doğrulama → .bak.tmp/.bak (önceki sağlam sürüm) → yeni otoriteye rename. İlk kayıt sonunda .bak yok; ikinci başarılı kayıtla oluşur.
- Restore eski yedek sürüme döner, son değişiklikleri kaybedebilir; bozuk orijinali .corrupt_* kopyasına alır. SHA-256 şifreleme/imzalama değildir.
- Additive layer sırası görsel toplama sonucunu değiştirmez; gelecekte noncommutative graph ayrı mimari gerekir.

### TFR1 — region disk sayfası
- Magic `TFR1`; **24 byte header** (world cells.x/z, page x/z, sample spacing); 1024×Float32 = 4096 byte; 64 ASCII SHA hex; **toplam 4184 byte/sayfa**.
- Filename `r_00000_00000.tfr` vb. Page key = (gx/32, gz/32), local index = (gz%32)*32 + gx%32.
- Örnek tek sayfanın sahibi: x=32 sample, bir önceki page x=32 kopyası değil, sonraki page offset 0'dır.
- Dış dünya sınırı için ek page vardır. 96×96 cells → 4×4=16 sayfa.
- Default resident 4 sayfa (1–64 sınırı), saf Float32 data 4×4096=16KiB; Dictionary/mesh/physics/engine overhead hariç.
- .tmp, page SHA, .bak; eksik sayfa ERR_FILE_NOT_FOUND, bozuk sayfa ERR_FILE_CORRUPT; otomatik düz zemin YASAK.
- MAX_WORLD_CELLS 32768/eksen fakat manifest sayfa sayısı daha dar sınır getirebilir.

### TFM1 — dünya manifesti
- `manifest.tfm`: magic TFM1, 32-bit JSON payload byte count, UTF8 JSON, 64 ASCII SHA256 over JSON bytes.
- Alanlar: `schema,page_format,page_width,cells_x,cells_z,spacing,pages_x,pages_z,source_format,source_sha256,flattened_layers,pages`.
- Her page öğesi `{x,z,sha256}`; koordinat sırası ve world config doğrulanır. max 10.000 pages, manifest max 2 MiB.
- **KRİTİK:** Sayfa değişirse manifest SHA listesi eskir. Şu an manifest **immutable snapshot** için. Canlı edit-mode multi-page commit için copy-on-write / journal / generation ID / manifest atomic publish YOK. Bunu çözmeden bölgesel düzenleme açmak veri bozulmasına yol açabilir.
- Manifest/page checksum veri bütünlüğünü sağlar, kriptografik imza değildir.

## 4. Render / fizik / UI temel parametreleri

- Tile boyutu **32×32 cell**. LOD stride **1, 2, 4**; yaklaşık vertex count her tile için sırasıyla **1089, 289, 81** (tümü tam 32×32 tile varsayımıyla).
- LOD sınırında komşu coarse height'a uyarlama, normal komşu ile hesaplama ve 8 metre hysteresis var. Ancak tam topolojik stitch/continuous geomorph henüz kanıtlanmadı.
- Varsayılan Balanced: view 224m, near 72m, middle 144m, resident ≤96, 2 rebuild/frame, yaklaşık 4ms CPU iş sınırı. Light: 160m/64/1, High 320m/160/3. Bir ağır tile yine bütçeyi aşabilir.
- CPU üretilen ArrayMesh, HeightMapShape3D collision + StaticBody3D; görsel mesh ve collision birebir eşitliği gerçek telefonda henüz onaylı değil.
- Touch event mesafeye dayalı brush sampling, segment üst sınırı; active viewport raycast; sentetik touch→mouse çift işlem guard.
- Termal Weather radius ≤32m, 1–6 iterasyon; drenaj priority-flood/MFD patch radius ≤48 sample (max 97×97). Bunlar **tam hidrolik erozyon değildir**.
- Ridge/Valley maksimum path uzunluğu ve örnek sayısı, noise cache üst sınırı; fare gözüne yakın geometri için mikro relief ayrı plan.
- Kompakt popup, widget durumu; ekranı kaplayan bottom dock geri gelmemeli.

## 5. Planlanan data-source abstraction (HENÜZ YOK)

Önerilen `core/paged_height_source.gd`:
- `open_manifest(dir) -> Error`, `get_height(x,z) -> {error,height}`, `sample_local(x,z) -> {error,height}`, `prefetch(page_rect,budget)`, `unload_outside(page_rect)`, `stats()`.
- Bu API `region_store.gd` ve `region_manifest.gd` üzerinde çalışacak; önce izole **read-only** prototip, sonra isteğe bağlı render/collision node.
- Çekirdekte istisna/eksik veri sessiz 0'a dönmez; border bilinear iki page okuyabilir; LRU limit sürekli korunmalı.
- Daha sonra `height_data.heights[index]` doğrudan erişimlerinin yerine height source abstraction; Undo/Redo/write için multi-page transaction ayrı faz.
- Node/Mesh ana thread; arka planda bounded IO ve CPU data processing, async result versioning ve cancellation tasarımı gerekli.

## 6. Bilinen operasyonel sınırlar

- Disk okuma, SHA, manifest tüm sayfa doğrulaması, stage export **senkron**; Android frame sırasında uzun işlem = takılma. Önce bütçe/IO ölçümü gerekir.
- `res://` ile `user://` Android izin/yazma farkları, data-file path ve direct editor mode gerçek telefonda test edilmeli.
- Terrain create/save ve .tscn sahnesi iki farklı kayıt; kullanıcıya ikisini kaydettir.
- CPU/memory hesapları sadece raw data; draw call, GPU upload, collision, engine overhead ayrıca ölçülür.
- En güncel uygulama ayrıntıları: `REGION_STREAMING_PLAN_TR.md`, `README.md`; ilk yeni görev: `NEXT_SESSION_IMPLEMENTATION_TR.md`.
