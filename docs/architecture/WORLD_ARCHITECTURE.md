# Dünya mimarisi — uygulamaya başlanmadan önceki sözleşme v1.0

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
