# Dünya mimarisi — uygulamaya başlanmadan önceki sözleşme v1.1

## Sabit gereksinimler
- Hedef: Godot 4.7.2 stable, Mobile renderer, Android odaklı.
- Coğrafya: en az dört ada, onları saran deniz, dar su geçitleri/boğazlar; yalnızca SE-01 heightmap sağlanmış durumda.
- Sahne sadece harici kaynağa referans verir; heightmap binary, mesh vertex arrays, chunk iç durumu .tscn içine yazılmaz.
- Editörde 3D terrain Play demeden görünür ve inspector'dan kontrol edilebilir. Bu bir sonraki fazın kabul koşuludur.
- Veriler ve dönüşümler deterministik sürümlenir. Harita kaynak koordinatları, dünya metre ölçeği, deniz seviyesi henüz kararlaştırılmadı; uydurulmaz.

## Önerilen gelecek modül sınırları (henüz dosyaları yok)
WorldManifest / WorldLayout: ada kimlikleri, dünya dönüşümleri, bölge komşulukları, reference IDs.
TerrainSource: EXR ve metadata okuyucu, aralık/NaN/sınır kontrolü.
TerrainTileProvider: world-to-heightmap örnekleme, tile border=shared vertices, immutable tile DTO.
TerrainStreaming: önceliklendirme, bütçe, iptal, scene interest, cache eviction.
TerrainLOD: geometri hedefi, screen-space hata metriği, stitching ve normal continuity.
TerrainRendering: mesh/material lifecycle, GPU staging, batched updates.
TerrainPhysics: fare ölçeğinde collision aktivasyonu ayrı bütçe ile.
TerrainEditorPreview: @tool, bounded preview LOD, editor-only cache ve kontrollü invalidation.
Ocean/Bathymetry: deniz seviyesi, kıyı, su derinliği, fizik/görüntü ayrı.
Gameplay/Narrative: dünya sistemlerine yalnız arayüz üzerinden bağlanır.
QA/Telemetry: CPU/GPU frame breakdown, memory, event, reproducible seed.

## Bağımlılık yönü
Manifest -> TerrainSource -> TileProvider -> (Streaming, LOD) -> (Rendering, Physics).
EditorPreview, runtime Rendering/TileProvider API'lerini yeniden kullanır; çalışma zamanı sistemlerini doğrudan tetiklemez. Ocean world layout ve height sample servislerinden beslenir; rendering bağımsızdır.

## Risk ve tasarım kararları
- 1536 x 1536 tek adanın sahaya dağılımı, gerçek metre ölçeği ve deniz seviyesini kullanıcı tanımlamalı; otomatik ölçekle kaliteli sonuç varsayma.
- 1536 boyutunun 2^n+1 olmaması tile sınırları/LOD için özel ele alınacak; bir piksel atlayarak veya sessiz resize ederek çözme.
- GPU'dan RAM'e geçiş GPU işini yok etmez; residency/transfer/cache maliyetleri ölçülmeli.
- Material/lighting high fidelity, low thermal budget ile çatışabilir; önce profilleme ve kalite seviyeleri.
- Küçük fare kamerası mikro-geometri, bitki/çarpışma ölçeği, gölgeleme ve clipping açısından farklı kalite metrikleri gerektirir.
- Editor tool scriptleri güvenlik, recursion ve sahne kirlenmesi riskleri yaratır; kapsamlı test gerekir.

## Multiplayer uyumlu ayrım — bağlayıcı mimari sözleşmesi v1.1

**İlkeler:** Dört ada ve deniz için dünya konumu/ada kimliği ayrı bir kaynak tarafından tanımlanır. Texture, ışık, görünür tile ve LOD sıfır oyuncu/nesne otoritesine sahiptir. Daha ayrıntılı render, farklı hareket/çarpışma sonucu üretmez. Sıfır hata garanti edilemez; hata etkisini sınırlama ve regresyon testi zorunludur.

### A. Birbirine karışmayacak domain'ler
1. **WorldManifest (salt okunur):** world_id, island_id, veri_revision/hash, world origin/coordinate frame, unit scale, sea datum ve ada yerleşimi. İstemci/sunucu aynı mantıksal dünya sürümünü kontrol eder; sürüm uyuşmazlığı sessizce kabul edilmez.
2. **TerrainData (salt okunur):** heightmap, kaynak dönüşümü, world-to-height sample, sabit collider/geometry veri erişim sözleşmesi. TerrainData hiçbir RPC açmaz; peer, kamera, görünürlük, chunk create/destroy veya oyuncu otoritesi bilmez.
3. **VisualChunkManager (istemci/görüntü):** ekrana çizilen mesh, görsel LOD, cache, instancing, GPU upload ve draw distance yönetir. Kameraya göre yükler/boşaltır; kendi tile ID'si, bir adanın kalıcı kimliği veya gameplay nesne kimliği değildir. Sunucunun simulation state'ini yükleyip silemez.
4. **SimulationWorld/PhysicsAuthority (headless uyumlu):** authoritative collision query, hareket, envanter ve değişen dünya olayları. Gerekirse kendine ait fizik/bölge bölümlemesi kullanır; buna VisualChunkManager karar vermez. Server collision, istemcinin düşük LOD mesh'ine dayanamaz.
5. **NetworkAuthority + Replication:** kimliği doğrulanan peer'lerin input/intent mesajlarını kontrol eder, server tick'inde simülasyonu günceller ve state snapshot/event gönderir. Replication; terrain asset üretmez, visual chunk yükleyemez, EXR'yi/mesh'i her tick göndermeye kalkmaz.
6. **NetworkInterest (AOI):** sunucunun relevancy kararları ve peer subscription; oyuncu/nesne konumu, visibility/culling, occlusion gibi kurallar. Görsel chunk radius veya cihaz ayarından BAĞIMSIZ; SpatialIndex gibi ortak salt-okunur konum/region ID'lerini kullanabilir.
7. **EditorTerrainPreview:** yalnız editor @tool layer, TerrainData'nın okuma arayüzünü kullanır; runtime server/network koduna bağlı değildir.

### B. Sınır ve bağımlılık kuralları
- `WorldManifest -> TerrainData -> HeightSample/CollisionSource` veri çekirdeğidir; `VisualChunkManager`, `EditorPreview`, `SimulationAuthority` yalnız interface üzerinden okur.
- `NetworkAuthority -> SimulationAuthority -> authoritative world state`. `Replication` ve `NetworkInterest` yalnız simulation state + authoritative spatial index üzerinden çalışır.
- `VisualChunkManager -> NetworkAuthority` doğrudan komut veya `NetworkInterest -> VisualChunkManager` doğrudan karar YASAK. İletişim yalnız client gameplay presentation adapter'ın subscription/snapshot arayüzü üzerinden, tek yönlüdür.
- Server visual mesh, material, GPU ve client camera olmadan headless başlatılabilir olmalıdır; client visual chunk sıfır iken server oyuncunun collision ve etkileşimlerini doğru işlemelidir.
- Client'ta chunk unload/degrade/LOD change yalnız render/yerel önbellek değişikliğidir; network entity despawn, authoritative collider remove veya envanter reset asla tetikleyemez.
- Kalıcı `entity_id` + `world_id` + `island_id` + veri revision, geçici `tile/chunk_id` veya NodePath ile aynı şey DEĞİLDİR. Replication kimliği/otoritesi ile render tile kimliği birbirine dönüştürülmez.
- Godot scene NodePath/RPC eşleşmesi ve multiplayer authority kısıtları ayrı bir protocol contract ile sürümlenecek; runtime visual node lifecycle RPC endpoint'lerini kaydırmayacak.

### C. Çok oyunculu gerçeklik modeli
- Varsayılan güven modeli: **dedicated authoritative server**. İstemci komut/intent gönderir; son pozisyon, hız, hasar, kaynak toplama, dünyayı değiştirme, spawn/despawn ve loot son kararını sunucu verir.
- Client-side prediction/interpolation yalnız görsel tepkiselliği artırır; gerektiğinde sequence+tick ile reconciliation yapılır, server doğruluğu korunur. Transport güvenilir/güvenilmez seçimleri mesaj sınıfına ve maliyetine göre ADR'de netleşir.
- İlk bağlanış: kimlik/oturum onayı -> protocol + world revision handshake -> ilk authoritative snapshot -> interest subscription -> kontrollü görünüm. Sürüm uyuşmazlığı, eksik asset veya snapshot boşluğu açık hata/fallback olmalıdır.
- Join/leave, disconnect/reconnect, late join, snapshot order, packet duplication, ownership transfer, interest enter/leave ve teleport transition için ayrı durum makinesi ve idempotent işlemler.
- Bir sunucuya bağlı oyuncuların farklı render mesafesi/LOD/cihaz kapasitesi olabilir; bunlar gameplay kurallarını değiştiremez.
- Destructible/modifiable terrain ileride istenirse immutable base heightmap'ten **ayrı versioned authoritative terrain delta** ve buna bağlı collider/cache invalidation protokolü tasarlanmadan eklenmez.
- Büyük dünya koordinatları: authoritative global coordinate ile istemciye özgü floating-origin/render-local frame ayrılır; origin-shift networkte fiziksel teleport veya yeni dünya konumu olarak aktarılmaz.
- Sayısal server tick rate, maximum clients, server region, bandwidth, latency/jitter ve simülasyon bölgelemesi henüz karar verilmedi; benchmark + threat model + ADR sonrası sabitlenir.

### D. Örnek kabul sözleşmesi
Oyuncu A uzaktaki adada, oyuncu B kıyıda: A'nın telefonundaki görsel ada chunk'ı boşalır; B yürümeye, etkileşmeye ve sunucuda doğru collision almaya devam eder. A daha sonra yaklaştığında snapshot ile doğru world state gelir; server başka oyuncu görmüyor diye varlığı silmemiştir.

### E. Kaynaklar (Godot 4.7 referansı)
- https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html
- https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html
- https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html

## Uzmanlık planları — kaynak hiyerarşisi (2026-11-24)
Bu dosya genel dünya invariants ve domain sınırlarının üst sözleşmesidir. Aşağıdaki **ayrı Markdown belgeleri** ilgili alt sistemin ayrıntılı tek kaynağıdır. Çelişki halinde uygulamayı durdur, ADR/PR'de uzlaştır; sessizce yorumlama.

| Alt sistem | Ayrı plan dosyası | Sahipliği |
| --- | --- | --- |
| Terrain / collision source | [TERRAIN_ARCHITECTURE.md](TERRAIN_ARCHITECTURE.md) | Immutable heightmap, sampler, canonical collision input ve editör veri önizlemesi |
| Görsel chunk / LOD | [CHUNK_STREAMING_ARCHITECTURE.md](CHUNK_STREAMING_ARCHITECTURE.md) | Client visual tile scheduling, LOD, mesh, GPU/cache |
| Multiplayer | [MULTIPLAYER_ARCHITECTURE.md](MULTIPLAYER_ARCHITECTURE.md) | Dedicated server authority, AOI, replication, protocol ve session |
| Entegrasyon / adversarial QA | [MULTIPLAYER_INTEGRATION_TEST_PLAN.md](../testing/MULTIPLAYER_INTEGRATION_TEST_PLAN.md) | Client/server/terrain/chunk sözleşmelerinin ortak ve kaos testleri |

Bu belgeler kod değildir: görsel chunk sistemi, authoritative sunucu ve editor terrain önizlemesi henüz uygulanmış sayılmaz.

## Dünya üretimi genişleme ve açık listesi (2026-11-24)
Mevcut terrain, chunk, multiplayer ve entegrasyon planlarının DIŞINDA kalan world layout, koordinat, kıyı/bathymetry, su yolları, biyom/ekoloji, navigation, editör authoring, world persistence, content/UX ve görsel bütçe ihtiyaçları [WORLD_CREATION_GAP_AUDIT.md](../production/WORLD_CREATION_GAP_AUDIT.md) içinde P0/P1/P2 olarak kaydedildi. Bunlar uygulanmış modüller değildir. İlgili detay planı, modül başladığında açılır ve buradan linklenir; aynı sorumluluk farklı dosyalarda yeniden tanımlanmaz.
