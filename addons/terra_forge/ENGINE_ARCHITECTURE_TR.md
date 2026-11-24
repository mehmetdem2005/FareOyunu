# TerraForge — As-Built Mimari, Veri Formatları ve Modül Envanteri

> **GÜNCEL DEVİR — P1.5.4d (24 Kasım 2026):** Kod 8c2f7675a3c78b9356aeb98f3dfbf850727c199f, [38/38 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45441554202). [P1_5_4D_SCALAR_BENCH_TR.md](P1_5_4D_SCALAR_BENCH_TR.md), [ham JSON](P1_5_4D_SCALAR_CI.json). B/D exact parity and equal work; 14 cases × 32 rounds × 2 methods = 896 timed builds. B 1190.16 us, D 827.09 us equal-weight mean; D 30.51% lower than B, 14/14 mean wins on one runner. 293312 height reads per method; D avoids per-sample result dictionary, not measured allocator bytes. A default, B/C opt-in, D benchmark-only. **NEXT P1.5.5a:** bounded pure-array worker design and ownership prototype; keep D experiment pending live trace and device. No painting/objects, P1.4 parked. Mandatory UNUTULMAYACAKLAR_TR.md.


> **GÜNCEL DEVİR — P1.5.4c (24 Kasım 2026):** Kod 94beaeb2cd068e7bf5a09fc9b23b97b98a44d92d, [37/37 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45440552536). [P1_5_4C_STREAM_TRACE_TR.md](P1_5_4C_STREAM_TRACE_TR.md), [ham JSON](P1_5_4C_STREAM_TRACE_CI.json). 12 fixed 144-pump traces (TFM1/2 × cache9/16 × A/B/C); B lower mean pump in all four groups, equal-weight means A 0.722, B 0.568, C 0.676 ms; 21.26% lower B vs A on one runner, work differs at cap16. Shape-missing steps 34/144 cap9,29/144 cap16 for all methods; no raycast or actual render frames. A default, B/C explicit experiments. **NEXT P1.5.4d:** isolate allocation/topology optimization via fixed resident benchmark; preserve exact geometry and opt-in. Device/long soak and real trace repeats open. P1.4 parked; no painting/objects. Read UNUTULMAYACAKLAR_TR.md.


> **GÜNCEL DEVİR — P1.5.4b (24 Kasım 2026):** Kod da123dca5be609cc67c6b18f181b91abdc962404, [36/36 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45439854530). [P1_5_4B_SAMPLING_BENCH_TR.md](P1_5_4B_SAMPLING_BENCH_TR.md), [ham ölçüm](P1_5_4B_SAMPLING_CI.json). A/B/C exact array parity, 14 warm-resident cases × 24 rounds × 3 methods = 1008 timed builds. Equal-weight mean A 1869.22 us, B 1390.05 us, C 1791.09 us; B 25.63% lower than A, wins 14/14 means on one Linux runner. Not mobile FPS or isolated CPU time. A default, B opt-in, C benchmark-only. **NEXT P1.5.4c:** fixed camera trace A/B/C, page/job/cache/RSS/reload and frame/pump comparison; device gates still open. [UNUTULMAYACAKLAR_TR.md](UNUTULMAYACAKLAR_TR.md) mandatory every turn. No painting/objects or P1.4 writes.


> **GÜNCEL DEVİR — P1.5.4a (24 Kasım 2026):** Kod 285122ecc826616f3c3840a41ad4e34223afc0fa, [35/35 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45436882446). [P1_5_4A_TILE_VIEW_TR.md](P1_5_4A_TILE_VIEW_TR.md) as-built. Bounded synchronous tile view, exact TFM1/TFM2 geometry parity, deterministic LRU work reduction; experimental opt-in default false. **Sıradaki P1.5.4b:** fixed-workload CPU A/B microbenchmark and profile, reduce dictionary allocation per sample if evidence supports, maintain all-array parity and fail-closed. P1.4 parked; actual large-world and Android proof open; boya/obje yok.


> **GÜNCEL DEVİR — P1.5.3b B4 (24 Kasım 2026):** Kod 0ba10c27a66117eadf63e01e3563a7cb48bcf037, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45434699275). [P1_5_3B4_PROFILE_TR.md](P1_5_3B4_PROFILE_TR.md) as-built. B4 profil altyapısı DONE: dual format matched fixture, 81 byte-identical TFR1 pages, four strict/lazy runs, TF_PROFILE_3, 4096/8192 V2 generation options and storage gate. Actual large-world and Android benchmarks OPEN. **Sıradaki P1.5.4a:** profile-driven CPU sampling audit, bounded tile read views, no per-sample LRU touches, exact geometry parity. P1.4 parked; boya/obje yok.

TF_PROFILE_3 dual format matched profile, same sample recipe and bounded telemetry.


> **GÜNCEL DEVİR — P1.5.3b B3b (24 Kasım 2026):** Kod de0c6f1672b989ab5fd14169d7a54040962b98a0, [34/34 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45433789697). [P1_5_3B3B_PREVIEW_TR.md](P1_5_3B3B_PREVIEW_TR.md) as-built. B3b DONE: explicit TFM2 preview, real ArrayMesh/HeightMapShape3D, 576² four interior shard intersection, LOD0/1/2 and mixed seam parity, last-good failure retention, camera recovery. **Sıradaki B4:** reproducible dual-format profile scene, explicit fixture format/size, bounded worker, disk estimate and cancel, root/shard and frame/collision telemetry, actual device profiling remains open. TFM1 default; P1.4 parked; boya/obje yok.

Preview explicit format selection and shard cap; same geometry pipeline, readonly editor stats.


> **GÜNCEL DEVİR — P1.5.3b B3a (24 Kasım 2026):** Kod 03b37b1656616e442ec015d01433517e51700cb9, [33/33 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45432431156). [P1_5_3B3A_ASYNC_TR.md](P1_5_3B3A_ASYNC_TR.md) as-built. B3a DONE: explicit open_v2, pinned root, worker-owned bounded shard LRU, exact compact verification/error telemetry, cross-shard async tests. **Sıradaki B3b:** opt-in TFM2 paged preview mesh/LOD/normal/collision integration, actual cross-shard geometry parity and failure isolation; default TFM1 preserved. B4 device profiling after B3b. P1.4 parked; Android GPU/RSS/FPS proof open, boya/obje yok.

Pinned root, worker-owned shard LRU, exact bitset and lazy error bytes; TFM1 unchanged; scene integration pending.


> **GÜNCEL DEVİR — P1.5.3b B2 (24 Kasım 2026):** Kod 90147bcff4bd530e6d12aac58595c0746e7b4c9c, [32/32 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45431373950). [P1_5_3B2_FIXTURE_TR.md](P1_5_3B2_FIXTURE_TR.md) as-built. B2 DONE: staged TFM2 fixture, shared TFR1 immutable page codec, strict/lazy read helpers, 512² actual 289 pages/4 shards. **Sıradaki B3:** explicit opt-in TFM2 async source integration, pinned root, worker-owned bounded shard LRU, compact verification telemetry, cross-shard preview mesh/collision parity. B4 profiling after B3. TFM1 format unchanged; P1.4 parked; phone GPU/RSS/FPS proof open, boya/obje yok.

Shared TFR1 page codec, TFM2 strict/lazy synchronous helpers, independent fixture worker; existing async format TFM1 only.


> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

TFM2/TFS2 v1 compact binary root/shard buffers, raw SHA, fixed offsets, exact bounds. TFR1 and readers unchanged.


> **GÜNCEL DEVİR — P1.5.3a (24 Kasım 2026):** Kod 2c3227c4a1131b7757f95778967f1c2a38f7e253, [30/30 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45426537117). [P1_5_3A_FIXTURE_TR.md](P1_5_3A_FIXTURE_TR.md) güncel uygulama ve [P1_5_3B_INDEX_DESIGN_TR.md](P1_5_3B_INDEX_DESIGN_TR.md) sıradaki ayrıntılı tasarım. P1.5.3a 256–2048 selectable bounded scratch fixture, gerçek TFH1 provenance, cancel ve isolated publish. 2048 üretim performansı henüz ölçülmedi. Sıradaki P1.5.3b: opt-in TFM2 root/shard binary codec, bounded validation ve corruption tests; TFM1 değişmez, ardından async reader integration. P1.4 beklemede; gerçek Android GPU/RAM/FPS onayı açık. Boya/obje yok.

New builder one source row + page buffer/cache, manifest metadata bounded by TFH1, worker explicit cancel/join; unchanged TFM1/TFR1.


> **GÜNCEL DEVİR — P1.5.2 (24 Kasım 2026):** Kullanıcı P1.4 yerine P1.5'i derinleştirmeyi seçti. Kod 13d5019db609962b9e1d634f5c2644b80f209ced, [29/29 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). Önce [P1_5_MASTER_PLAN_TR.md](P1_5_MASTER_PLAN_TR.md) ve [P1_5_2_IO_PIPELINE_TR.md](P1_5_2_IO_PIPELINE_TR.md) oku. Sıradaki P1.5.3a: TFM1 kapasite/byte sınırı, doğrudan bounded scratch page generator, manifest shard tasarımı ve regression; mevcut TFM1 değişmeyecek. P1.4 beklemede. Telefon ölçümü ve gerçek Mobile Renderer/GPU onayı hâlâ açık. Boya/obje yok.

Async worker binary wake + conservation counters + pipeline histograms; preview pass-through, TF_PROFILE_2. Existing TFM1 limits unchanged.


> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

core/profile_histogram.gd sabit 26 bucket; async_region_source collect_io_profile opt-in, accepted results histogram; preview diagnostic world_extent/has_collision_at/io_profile; profiling/profile_scene.tscn bağımsız, manuel start, kamera trace ve JSON.


> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

paged_terrain_preview.gd: _blocked_tiles map, _block_tile(), blocked_tiles/retained_failed_tiles stats; terminal error olan tile yeni IO almadan atlanır; generation/LOD/neighbor değişimi yeniden değerlendirebilir. Kaynak hata cache'i generation-local. Stop temizler. Eski editable node değişmedi.


**Kod tabanı:** v0.4.4-dev.1, `73603a15361766397854d11bad44ecb41e9bd53e`. **Hedef:** Godot 4.7.2 / Android 11 Mobile. **Kural:** Bu belgeyi kod değiştikçe güncelle; doğrulanmamış bileşenleri CANLI diye sunma.

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
| `core/paged_height_source.gd` | TFM1/TFR1 read-only verified Float32 cache, cross-page bilinear, 1–64 LRU | İZOLE / CI PASS |
| `core/camera_page_prefetch.gd` | Kamera yakın/yön priority, opsiyonel configure_async ile worker scheduler | İZOLE / CI PASS |
| `core/async_region_source.gd` | Thread/Mutex/Semaphore bounded TFR1 IO, tek-buffer SHA, ana-thread Float32 cache | İZOLE / CI PASS |
| `core/paged_tile_geometry.gd` | Read-only Float32 TFR1 get_height, 32-cell ArrayMesh vertex/normal/color/LOD0 collision arrays, region halo | İZOLE / CI PASS |
| `terrain/paged_terrain_preview.gd` | Opt-in @tool Node3D: kamera streaming ile ArrayMesh ve HeightMapShape3D collision; no full height array, no writes | **İSTEĞE BAĞLI PREVIEW / CI PASS** |
| `tests/*.gd` | 20 Godot headless regresyon | CI PASS |
| `tests/run_all.sh` | 4.7.2 version, PASS çıktısı, exit code, engine log kontrolleri | CI PASS |
| `.github/workflows/terraforge-ci.yml` | Ubuntu, geçici Godot projesi, 26 test, log artifacts | CI PASS |

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

## 5. P1.2 — Uygulanan salt okunur data source ve sınırları

**Kodlandı / 22/22 CI PASS:** `paged_height_source.gd` `open,get_height,sample_local,prefetch_rect,release_outside,stats,close` API'lerini sunar. TFM1 full verification, cold TFR1 tam dosya hash ve internal checksum, 1–64 LRU Float32 sayfa cache, cross-page bilinear. `get_height` hata durumunda sahte `height=0` dönmez; `sample_local` dünya dışını explicit hata ile reddeder (**legacy TFH clamp ile farklı**).

**Kodlandı / 22/22 CI PASS:** `camera_page_prefetch.gd` `configure,request_focus,tick,release_distant,stats` API'lerini sunar. En yakın sayfaya, sonra hareket yönüne öncelik verir; 1–8 **senkron** cold read/tick, eski bekleyen sıraları generation ile iptal. Her page'nin tek IO okuması kare süresini aşabilir.

**PLAN:** worker-thread async IO, bounded inflight, generation-id ile **geç sonuçları** atma, startup full world sync SHA optimizasyonu, `HeightSource` ile gerçek `TerraForgeTerrain` mesh/normal/physics bağlama ve multi-page writable transaction. Canlı terrain hâlâ bütün Float32 height array'i tutar. Teknik API kaydı: [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md).

## 5.1 P1.2b — Asenkron disk IO (UYGULANDI / 23 test)

- `async_region_source.gd`: `Thread`, `Mutex`, `Semaphore`; tek düşük öncelikli worker yalnız TFR1 dosya byte'ını alır, aynı buffer'da tam dosya ve internal SHA'yı doğrular, Float32 finite/metadata kontrolünü gerçekleştirir.
- `open(dir,resident_limit,max_jobs, verify_all_pages=true)` varsayılan strict modda bütün TFR1 dosyalarını açılışta doğrular; isteğe bağlı `false` modda yalnız checksummed TFM1 manifestini açar ve her TFR1'i ihtiyaç duyulunca worker içinde doğrular. `request_page` main thread'de bounded queue'ya ekler; `poll_results` main thread cache'e kabul eder. `get_height/sample_local` hazır değilse `ERR_BUSY` veya gerçek veri hatası verir, sıfır yer üretmez.
- `camera_page_prefetch.configure_async(reader)` opt-in background IO scheduler; eski senkron API korunur. Kamera generation değiştirince eski pending/late worker sonuçları kabul edilmez.
- `close()` worker shutdown ve `Thread.wait_to_finish()` ile explicit join yapar; aktif IO bitene kadar bloklayabilir. Android GPU/RAM/FPS ölçümü henüz yapılmadı.
- Güncel kanıt: [Godot 4.7.2 CI 23/23 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313). **Canlı `TerraForgeTerrain` hâlâ global `height_data.heights` kullanıyor**; RAM/FPS artışı iddia edilmez.
- Tüm teknik sözleşme ve sıradaki P1.3 işleri: [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md).

## 5.2 P1.3 — Opt-in paged ArrayMesh + HeightMapShape3D

- **UYGULANDI:** `paged_tile_geometry.gd` `TFR1` resident Float32 sayfalarını, 3×3'e kadar komşu page halo ile 32-cell tile'lara çevirir. LOD stride 1/2/4, aynı LOD komşu merkezî normal ve mixed LOD kenar interpolasyonu, legacy'nin collision sample ölçekleme semantiği.
- **UYGULANDI:** `paged_terrain_preview.gd` `@tool Node3D` varsayılan `preview_enabled=false`; `start_preview` varsayılan lazy modda checksummed TFM1 manifestini doğrular, TFR1 full SHA'yı sayfa ihtiyaç duyulduğunda worker'a bırakır, camera-nearest tile için async sayfaları ister; `pump_stream()` main thread mesh/shape yaratır. Cache limit 9–64 page (varsayılan 16), background job 1–8.
- **UYGULANDI:** `plugin.gd` seçilmiş preview scene düğümüne editör camera global_position forward eder, küçük popup read-only sayfa/mesh/IO sayacı gösterir; brush disabled. Legacy sculpt UI yolunu değiştirmez.
- **CI:** `test_paged_terrain_preview.gd` legacy LOD0/1/2 vertices/normals/collision ve mixed LOD0↔LOD2 seam numerical parity, fail-closed corruption ve source immutability; [Godot 4.7.2 CI 24/24 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421).
- **AÇIK:** eski `TerraForgeTerrain` hâlâ full-grid Float32, gerçek Android GPU/RSS/p95/p99 yok; strict modda sync full-page `open()` ve blocking `close()`, fast camera gaps test edilmeli; çok-region writable transaction olmadan terrain brush kapalı.
- Ayrıntılı kurulum, API ve riskler [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## 5.3 P1.3b — Kamera generation ve minimum-cache LRU (DONE / CI)

- `async_region_source.prioritize_resident(Array[Vector2i])` source-cache'deki doğrulanmış sayfaları sıranın sonuna, yani LRU MRU ucuna taşır. **Gerçek sayfa kilidi değil**, kapasite aşılmaz; yeni IO sonucu daha önce sıcak bir sayfayı yine çıkarabilir. `is_requested` yalnız ana thread'de rezervasyonu kontrol ederek aynı pending işin tekrar submit bütçesini doldurmasını engeller.
- `paged_terrain_preview._sync_tiles`: dünya coordinate ile 32-cell focus sayfasını hesaplar; odak son queue focus'dan >=2 page taşınırsa `source.set_generation(next)` ile henüz başlamayan işleri ve geç tamamlanan eski sonuçları iptal eder. Kamera küçük hareketinde iş iptalinden kaçınır. `stats` camera_cancellations, focus_page, waiting_tile_frames içerir.
- `test_paged_camera_stress.gd` 25. test: 128×128 test haritası, minimum 9 resident page, 2 outstanding worker, 3 uzun kamera geçişi, LOD0 gerçek collision, TFH checksum. [25/25 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507).
- **Kalan:** Android GPU/FPS/RSS onayı yok, çok büyük harita açılış `open()` tüm sayfaları senkron hashler; legacy `TerraForgeTerrain` hâlâ tam global Float32 array kullanıyor.

## 5.4 P1.5 — Manifest-first fast open (UYGULANDI / 26/26 CI)

- `async_region_source.open(directory,resident_limit,max_jobs,verify_all_pages=true)`: **strict default** legacy behavior korunur; `false` ise yalnız TFM1 checksum/schema kontrolü yapar ve worker Thread'i başlatır. TFR1 dosyası ilk kez istenene kadar **varlık/bütünlük doğrulanmış sayılmaz**. TFR1 full-file + internal SHA, world/coord/Float32 on-demand cold load'da geçmeden mesh verisi üretilmez.
- `paged_terrain_preview.verify_pages_on_demand=true` yalnız yeni opt-in readonly Node'da varsayılandır. Editor popup `READ-ONLY ON-DEMAND` veya `FULL` ve `Checked n/total` kapsamını gösterebilir; bu global dünya sağlığı metriği değildir.
- `stats` `verified_at_open,verification_mode,manifest_entries,pages_verified_on_demand,open_verify_ms` içerir. Cache'de doğrulanmış bir sayfa sonradan değişirse yeni cold read'de yeniden SHA yapılır; cache içindeki kopya kendiliğinden tekrar kontrol edilmez.
- `test_lazy_world_open.gd` strict missing/corrupt startup, manifest-only lazy open, verify-on-demand fail-closed, corrupt TFM1 immediate fail, gerçek nearby ArrayMesh/collision ve off-tree explicit `stop_preview` kontrol eder. [26/26 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664).
- **Kalan:** Android 11 p95/RSS/startup doğrulanmadı, TFM1 JSON açılışı hâlâ senkron ve 2MiB sınırda; `close()` tek IO'yu join etmek için bloklayabilir; eski editable `TerraForgeTerrain` global height Float32 kullanır.
- Kaynak: [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).

## 6. Bilinen operasyonel sınırlar

- Disk okuma, SHA, manifest tüm sayfa doğrulaması, stage export **senkron**; Android frame sırasında uzun işlem = takılma. Önce bütçe/IO ölçümü gerekir.
- `res://` ile `user://` Android izin/yazma farkları, data-file path ve direct editor mode gerçek telefonda test edilmeli.
- Terrain create/save ve .tscn sahnesi iki farklı kayıt; kullanıcıya ikisini kaydettir.
- CPU/memory hesapları sadece raw data; draw call, GPU upload, collision, engine overhead ayrıca ölçülür.
- En güncel uygulama ayrıntıları: `REGION_STREAMING_PLAN_TR.md`, `README.md`; ilk yeni görev: `NEXT_SESSION_IMPLEMENTATION_TR.md`.
