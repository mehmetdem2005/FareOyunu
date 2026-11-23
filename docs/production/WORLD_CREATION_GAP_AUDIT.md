# FareOyunu — Dünya Oluşturma ve Modüler Üretim Açığı Analizi v1.0
Tarih: 2026-11-24 · Durum: **PLAN / KEŞİF; HENÜZ UYGULAMA YOK** · Hedef Godot 4.7.2 Mobile, Android, authoritative multiplayer, en az 4 ada ve deniz.

## 0. Kaynak, karar ve kapsam
Bu belge [WORLD_ARCHITECTURE.md](../architecture/WORLD_ARCHITECTURE.md), [TERRAIN_ARCHITECTURE.md](../architecture/TERRAIN_ARCHITECTURE.md), [CHUNK_STREAMING_ARCHITECTURE.md](../architecture/CHUNK_STREAMING_ARCHITECTURE.md), [MULTIPLAYER_ARCHITECTURE.md](../architecture/MULTIPLAYER_ARCHITECTURE.md), [PIPELINE.md](PIPELINE.md), [ROADMAP.md](ROADMAP.md), [QUALITY.md](../policies/QUALITY.md) ve [AGENTS.md](../../AGENTS.md) incelendikten sonra oluşturuldu.

**Var olan planların kapsadığı alanlar:** source heightmap ve canonical sample, görsel chunk/LOD/cache, server authority/AOI/replication, temel CI ve çapraz test. **Eksik/kısmi olanlar:** topografya dışındaki dünya üretimi, su altı, tutarlı coğrafya, biyomlar, yollar/AI navigation, araçlar, dünya kayıtları, içerik planlama, yaratıcı kalite kapıları, üretim determinism ve mobil özel maliyetler. Planlanmış olmak uygulanmış olmak değildir.

**Kırmızı çizgi:** Terrain doğruluğu ≠ görsel chunk görünürlüğü ≠ oyun/sunucu simulation doğruluğu ≠ network interest. Ayrı modül sahiplikleri; ortak veri yalnız açık, immutable, sürümlü arayüzlerden okunur. `.tscn` veri ambarı değildir. İzin verilmedikçe sonraki parçada kod/ada/deniz uygulanmaz.

## 1. P0 — Dünya kurulmadan önce çözülmesi gereken mimari kararlar

### W01 — World topology & atlas (WorldLayout / IslandGraph)
**Açık:** Dört+ adanın aralarındaki coğrafi ilişki, gerçek dünya boyutları, geçitler, görüş koridorları, geçilebilir deniz rotaları, yer adları, kimlikler, ölçek ve oyunun harita tasarımı bulunmuyor.
**Sahip:** world design + world data; `WorldManifest` her adanın ext-resource kimliği ve transform'unun tek kaynağı. Terrain/chunk yerleşime karar vermez.
**Çıktı:** island polygons/transforms, water connections, `world_id`, `island_id`, authored layout ve world map preview; **henüz üretme**.
**Kabul:** Ada sınırları çakışmaz, intended geçit kapanmaz, kayıp/mismatch manifest reddedilir; tüm client/server aynı island transforms ile örnekler.

### W02 — Koordinat/origin/ölçü standardı
**Açık:** world unit metre/piksel, height scale, sign/axis, kaynak image Y invert, global vs local position, deniz seviyesi datum, navigasyon/physics/render alignment, dünya uzayınca floating point precision politikası.
**Sahip:** SpatialCoordinateService + world manifest; server global authoritative frame; client render-local optional origin shift, ayrı.
**Karar:** Godot double-precision büyük dünya desteği mobil maliyet yaratabilir. Dünya boyutu ölçülmeden bu özelliği açma veya origin shifting'i zorunlu sayma.
**Kabul:** Aynı world coordinate, editör/standalone/headless/client/server height-ground uyuşması; 4 ada en uzak noktasında fare hassasiyetli step ve drift testleri.

### W03 — Dünya veri sözleşmeleri, asset provenance ve build graph
**Açık:** resource schemas, revision lineage, source/output SHA, height pixels->meters mapping, dependency invalidation, import cache IDs, cross-version compatibility, island/world ID ile render tile ID ayrımı.
**Sahip:** WorldDataRegistry/AssetPipeline; asla scene embed ve runtime global state yerine.
**Somut durum:** ilk SE-01 kaynak 1536×1536, sonraki yumuşak kıyı 1254×1254 f32 EXR; bu sürümler karıştırılamaz. EXR sadece storage precision; kaynağın gerçek DEM doğruluğunu garanti etmez.
**Kabul:** Version mismatch açık hata; importer/validator doğru pixel type, NaN, dimension, orientation, range ve checksum doğrular; hiçbir sessiz overwrite yok.

### W04 — Kıyı çizgisi / bathymetry / su basma standardı
**Açık:** Hill heightmap siyah deniz alanından otomatik doğru deniz tabanı çıkarılamaz. Kıyı genişliği, kum/taş eğimi, med-cezir olup olmayacağı, ada çevresinde negatif irtifa/bathymetry, su altı collision, shoreline wetness ve kıyı geçişi ayrı tasarlanmalı.
**Sahip:** CoastlineModel + BathymetrySource + WaterSurface/WaterPhysics/WaterRendering **ayrı**.
**Kabul:** Kıyıda basamak/boşluk yok, plaj walking slope onaylı, deniz tabanı sürekliliği, yüzme/boğulma kararları shader'dan bağımsız authoritative simülasyona uygun.

### W05 — 2.5D heightfield sınırları / overhang / yer altı
**Açık:** Heightmap tek `x,z` için tek yükseklik saklar; tünel, fare yuvası, uçurum altı, mağara, köprü altı ve devrilmiş gövde altında passage için tek başına yetmez.
**Sahip:** Terrain base heightfield + ayrı 3D setpiece/mesh/collision/entrance data; cave graph ve occlusion.
**Kabul:** Overlap mesh ile collider/neighbour cells uyumlu; yuvaya girerken görsel chunk unloading canonical underground simulation'ı etkilemez.

### W06 — Editör dünya oluşturma araçları
**Açık:** Play gerektirmeyen terrain preview yeterli değil; dış veri üzerinden adayı sürükle/yerleştir, kıyı konturlarını çiz, path spline/river spline, biome paint, stamp/scatter, zone/POI annotation, dependency rebuild, undo/redo, world atlas debug.
**Sahip:** `@tool WorldAuthoringPlugin` ve disiplin bazlı alt araçlar; editor cache ayrı; source data dışarıda, tool'un ürettiği mesh asla scene içine yüzbinlerce vertex gömmez.
**Kabul:** editörde anında görülebilir, bounded rebuild, undo/redo, reload, source hash, file-lock/reimport loops, crash-safe save ve ölçülmüş editor latency.

## 2. P1 — Dünya inandırıcılığı, ekosistem ve oynanış katmanları

### W07 — Jeomorfoloji ve hidroloji
**Açık:** Tek başına görsel heightmap doğal vadi/akış ağı üretmez. Ridge/valley watershed, flow accumulation, wetness, erosion mask, riverbed slope, spring/lake delta ve yağmur yönü gerekebilir.
**Sahip:** Geomorphology/Hydrology data pipeline; oyuncu oynarken tüm erozyonu simüle etmek zorunlu değildir; offline authoring/baking önce değerlendirilir.
**Kabul:** Su yukarı akmaz; derenin denize bağlantısı, sediment/soil transition ve world polygon crossing açıklanabilir. Nehir/fizik/gameplay ayrı modüller.

### W08 — Biyom, toprak, malzeme ve çevresel zonlama
**Açık:** Rakım tek başına bitki ve zemin dağılımı için yetersiz; slope/aspect, soil type, moisture, coastal exposure, latitude/temperature ve hand-painted mask verisi gerekir.
**Sahip:** BiomeRulebook + SurfaceMaterialResolver; heightmap kaynak verisi değişmez. Texture macro/micro, tiling, normals, roughness, decal, wetness ve vegetation seçimi ayrı.
**Kabul:** Çıplak kayadan ormana rastgele geçiş yok; biyom sınırı fark edilir ama dikiş göstermez; texel density ve mobil shader maliyeti ölçülür.

### W09 — Doğal nesne dağıtımı ve persistent props
**Açık:** Çimen/ağaç/taş/kütük, eğim/yükseklik ve kıyıdan uzaklık kuralları, elle düzenlenen istisnalar, seed determinism, density/culling, mekanik olarak etkileşilebilir nesne kimliği.
**Sahip:** ScatteringAuthoring (offline), VisualFoliage (client only), InteractableWorldObjects (server authority) **ayrı**.
**Kabul:** Aynı seed/revision aynı spawn layout; MultiMesh/LOD yalnız görsel; topladığın/kırdığın nesne başka oyuncuda geri doğmaz. Instance density/per-chunk culling maliyetleri ölçülür.

### W10 — Navigation graphs / yol geçilebilirliği
**Açık:** Fare rotaları, dağ geçitleri, kıyılar, deniz, yuvalar, fox/owl gibi farklı boyut/ajan hareket türleri; karada navmesh, su/air graph, dinamik engel, farenin micro-scale traversability.
**Sahip:** NavigationData + AgentMovementRules + NavigationStreaming/ServerQueries; render chunk ile aynı owner değildir.
**Kabul:** Navmesh agent radius/step/slope'a uygun; komşu region bağlantısı seamless; server ve client'ın doğruladığı hareket kuralları çelişmez. Yol yoksa graceful fallback.

### W11 — Oynanabilir dünya / keşif geometrisi
**Açık:** Büyük alanın neden var olduğu: spawn, first-play path, shoreline-to-hill loop, landmark silhouettes, fırsat/tehdit yoğunluğu, line of sight, güvenli dinlenme, geri dönme ve ada değişimi.
**Sahip:** LevelDesign/WorldExperience; world space/POI annotations external data; gameplay quest/story sistemleri ayrı.
**Kabul:** İlk 5 dakika kör playtest; bir ada içinde anlamlı seçenekli rota; oyuncu kaybolursa affordance/landmark; kaliteli landmark farklı LOD ve sis koşullarında seçilebilir.

### W12 — Dünya canlılığı / ekoloji / AI
**Açık:** Yırtıcı alanları, av yolu, yuva, günlük ritim, AI spawn/hibernation, crowd, LOD AI ve uzaktaki canlıların yaşam durumu.
**Sahip:** EcosystemSpawnRules + server authoritative WorldSimulation + AI Agents; visual fauna render on-demand.
**Kabul:** İstemci uzaklaşınca yaşayan canlı sunucuda anlamsız şekilde yok olmaz; offline/online sim update stratejisi belirlenir; dünyada iz ve tehditler tutarlı.

### W13 — Geçiş ve ulaşım
**Açık:** Adalar arasında yürünebilir sığlık, su geçitleri, yüzme/tekne/alternatif yol, akıntı, teleport? Çok oyuncuda hangi yolun mümkün olduğu ve istemcinin streaming budget'ı.
**Sahip:** WorldTraversalGraph + Surface/WaterMovementRules + UX navigation. Ocean shader sadece görsel.
**Kabul:** Boğazda sahil/deniz sınırı tutarlı, su akıntısı sunucu tarafında uygulanır, streaming yüzünden oyuncu "boşluğa" düşmez.

### W14 — Dünya atmosferi (zaman/hava/aydınlatma/ses)
**Açık:** Gün döngüsü, hava değişimi, rüzgâr, yağış, sis, çevresel ses bölgeleri, su altı sesleri, görünürlük ve performans ile senkron.
**Sahip:** EnvironmentState server (oyunu etkileyen), EnvironmentRendering client (ışık/fog/VFX), AudioZones, TimeOfDay ayrı.
**Kabul:** Farklı grafik preset'leri mekanik avantaj/disadvantage üretmez; cihaz bağımlı olmayan authoritative visibility ve ses kaynakları; frame pacing bütçesi.

### W15 — Dünya durumu ve kalıcılık
**Açık:** Oyuncuların bıraktığı nesneler, harcanan kaynaklar, kırık objeler, büyüme, save checkpoint, world revision/migration ve server event logs.
**Sahip:** PersistenceService/WorldState, multiplayer docs sözleşmesine göre; visual chunk cache authoritative store değildir.
**Kabul:** Aynı nesnenin iki kez spawn olması/loot alınması, reconnect sırasında geri alma veya world revision uyumsuzluğu kontrollü; corrupt save restore.

### W16 — World content packaging/streaming budgets
**Açık:** Map atlas, island tile, texture atlases, mesh LOD/HLOD, grass density, sound streaming, shader variant, GPU upload/spikes, disk compression/download, Android sıcaklık ve güç.
**Sahip:** AssetBuildGraph + Packaging/Performance Budget; render chunk cache ile runtime asset store ayrı.
**Kabul:** Hangi asset'in neden yüklendiği izlenir; p95/p99 spike, RAM/VRAM, FPS ve CPU ölçüleri bilinir. Mobile renderer'ın Forward+-only optimizasyonlarından otomatik fayda beklenmez.

## 3. P2 — Dünya cilası ve üretim olgunluğu
- **W17 Visual storytelling / art direction bible:** fare yüksekliğinde siluet, renk hiyerarşisi, doğal yol işaretleri, tehlike göstergeleri; çevre dekoru görev verisiyle karışmaz.
- **W18 Environmental audio & acoustic occlusion:** kıyı/rüzgâr/suyun altı/mağara tonları; dynamic mix; 3D sound budget.
- **W19 Deterministic procedural authoring:** seed, parametre ve versiyon, elle yazılmış override'lar; generated world ile curated design çakışmasını çözen precedence policy.
- **W20 World map/minimap and discovery state:** adanın kartografik temsili, keşif/fog of war, markalar ve world coordinate dönüşümü, per-player state; renderer değil gameplay data.
- **W21 World debugging / observability:** live overlay for world_id, source revision, terrain samples, coastline, visual tiles, AOI, navigation, entity, perf; editor-only vs client-only ayrımı.
- **W22 Narrative/quests/world gating:** bulduğun içerik ile aktif hikâye tetikleyicilerinin dış veri sözleşmesi; multiplayer yetki, ilerleme ve tekrar oynama.
- **W23 Localization/accessibility:** büyük arazide hedefleri ve tehlikeleri yalnız renk/sese bağlamama; düşük görüş/ışık ve dokunmatik okunurluk.
- **W24 Disaster recovery/content updates:** son kullanıcı dünyasını ve save'lerini güncelleme, manifest migration, eski asset'i güvenli terk etme, build/release rollback.

## 4. Önerilen uzmanlık plan dosyaları — yalnız iş başladığında oluştur
Bu analiz master backlog'dur. Aynı konuyu hemen 20 boş `.md` dosyasına dağıtma. Bir modüle geçildiğinde tek sahiplikli ayrıntılı plan yaz, ilgili üst belgeden link ver.

| Öncelik | Gelecek plan adı (öneri) | Sorumluluk |
| --- | --- | --- |
| P0 | `docs/architecture/WORLD_LAYOUT_COORDINATES.md` | W01-W02 island atlas, global/local coords |
| P0 | `docs/architecture/COASTLINE_BATHYMETRY.md` | W04 coast mask, underwater model |
| P0 | `docs/architecture/WORLD_DATA_PIPELINE.md` | W03 versioned asset graph, validate |
| P0 | `docs/architecture/WORLD_EDITOR_TOOLING.md` | W06 @tool authoring/preview |
| P1 | `docs/architecture/HYDROLOGY_GEOMORPHOLOGY.md` | W07 watershed/erosion/river |
| P1 | `docs/architecture/BIOMES_MATERIALS.md` | W08 layered environment |
| P1 | `docs/architecture/SCATTER_FOLIAGE.md` | W09 visual/object spawn |
| P1 | `docs/architecture/WORLD_NAVIGATION.md` | W10 per-agent nav |
| P1 | `docs/production/WORLD_LEVEL_DESIGN.md` | W11 player journey/POI |
| P1 | `docs/architecture/ECOSYSTEM_SIMULATION.md` | W12 wildlife/hibernation |
| P1 | `docs/architecture/WORLD_TRAVERSAL.md` | W13 island crossings |
| P1 | `docs/architecture/ENVIRONMENT_AUDIO_TIME.md` | W14 weather/time/sound |
| P1 | `docs/architecture/WORLD_PERSISTENCE.md` | W15 persistent state and migration |
| P1 | `docs/production/WORLD_ASSET_BUDGETS.md` | W16 packaging/performance |
| P2 | `docs/production/WORLD_ART_DIRECTION.md` | W17 visual communication |
| P2 | `docs/production/WORLD_CONTENT_STORY.md` | W20/W22 narrative/discovery |
| P2 | `docs/testing/WORLD_STRESS_TEST_PLAN.md` | W21/W24 geo/visual/AI/online QA |

**Var olan belgeler korunur:** TERRAIN_ARCHITECTURE, CHUNK_STREAMING_ARCHITECTURE, MULTIPLAYER_ARCHITECTURE, MULTIPLAYER_INTEGRATION_TEST_PLAN. Büyük modül ayrı planı açıldığında domain ownership'i yeniden kopyalamaz; üst belgeler link verir.

## 5. Faz faz net TO-DO (yalnız plan; otomatik ilerleme yok)

### Phase W0 — Bu tur
- [x] Mevcut mimari/pipeline/QA dosyalarını tarayıp kapsananlarla boşlukları ayrıştır.
- [x] Godot 4.7 precision, navigation, threading ve mobile rendering sınırlamalarını resmi kaynaklarla doğrula.
- [x] P0/P1/P2 world module matrix, owner sınırları ve kabul kapılarını yaz.
- [ ] Uygulama, scene/plugin, heightmap replacement, ada üretimi — **kapsam dışı**.

### Phase W1 — Önce mutabakat; uygulama sonra
- [ ] World scale/units, island placement, world ID/axis/datum ve koordinat ADR'si.
- [ ] 1536² eski SE-01 vs 1254² soft-coast source revision ve gerçek EXR SHA/linear-data audit.
- [ ] Coastline+underwater data model ve editor tool ownership kararı.
- [ ] Bunları P0 modül belgelerine bölecek dar kapsamlı yeni PR.

### Phase W2 — İlk teknik dikey kesit
- [ ] Sadece SE-01'in küçük kıyı→yamaç→tepe bölgesinde editor preview, kıyı sürekliliği, collision query, server headless, visual chunk mock.
- [ ] Render/physics/nav/world placement veri sözleşmelerini test et.
- [ ] En az bir gerçek düşük/hedef Android cihaz profili.

### Phase W3 — İlk oynanabilir deneyim
- [ ] Fare ölçeğinde yol/engel ve ilk 5 dakikalık rota.
- [ ] Geçici vegetation + material + ocean + sound, ama gameplay/net authority testleri ayrı.
- [ ] Human blind playtest ve defekt temelli düzeltmeler.

### Phase W4 — Ada atlasına büyüme
- [ ] Diğer adalara geçmeden P0-P1 quality gates ve deniz/boğaz traversal proof.
- [ ] World layout, biome, objects, navigation, wildlife ve persistence modüllerini ayrı parça ve PR ile aç.
- [ ] Adalar arası seamless geçiş, render-unload/server-world doğruluğu; gerçek cihaz ve multiplayer kaos testi.

## 6. Her yeni dünya modülü için zorunlu karar şablonu
**Problem / oyuncu faydası; owner/domain; input-output schema; immutable vs runtime state; world_id/island_id/revision ilişkisi; client/server/editor hangi katmanda; allowed/forbidden dependencies; data format/provenance; coordinate/units; memory/CPU/GPU/VRAM/network bütçesi; P50/P95/P99; edge cases; adversarial tests; visual & human evidence; rollback; DOR/DOD.** Her başlık kısa ama açık kanıtla kapanır.

## 7. Önemli karşıt bakış / kaynak dayanakları
- Godot 4.7 large world coordinates mobilde ek maliyet getirebilir; oyunun boyutunu ve hassasiyetini ölçmeden double-precision ya da floating origin dayatma: https://docs.godotengine.org/en/4.7/tutorials/physics/large_world_coordinates.html
- Navigation mesh ayrı bir pathfinding verisidir; fizik mesh/visual mesh otomatik kaynak hakikati sayılmaz: https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationmeshes.html
- Godot scene tree aktifken thread-safe değildir; background mesh/asset generation ile main-thread application ayrılmalı: https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html
- Godot Mobile'da otomatik instancing Forward+ ile aynı değildir; MultiMesh, visibility/HLOD ve batch kararları ölçülmeli: https://docs.godotengine.org/en/4.7/tutorials/performance/optimizing_3d_performance.html

**Son karar:** Dünya üretimi, terrain ve chunk sınıfının içine sıkıştırılmaz. Topoloji, coğrafya, su, ekoloji, navigasyon, gameplay, network ve authoring araçları ayrı owners ve versioned data contracts ile planlanır. **Bu belge yalnız planlama ve açığı gösterir; çalışma sistemi iddiası değildir.**
