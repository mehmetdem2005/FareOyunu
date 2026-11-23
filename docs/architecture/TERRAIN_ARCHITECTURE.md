# Terrain mimarisi — ayrı uzmanlık planı v1.0
Durum: **PLANLANDI, UYGULANMADI** · Hedef: Godot 4.7.2 / Mobile renderer · Kapsam: FareOyunu açık dünya, en az dört ada.

> Üst sözleşme: [WORLD_ARCHITECTURE.md](WORLD_ARCHITECTURE.md). Bu belge terrain'in kaynak/örnekleme/collision sözleşmesinin tek ayrıntılı kaynağıdır. Görsel chunk ve ağ protokolünü yönetmez.

## Amaç ve oyuncu deneyimi
Heightmap, sabit dünya koordinatları, kıyılar ve fiziksel yürünebilirlik tüm istemcilerde aynı mantıksal dünyayı temsil etmeli. Editor açıldığında Play'e basmadan arazi görülebilmeli. Dağ, tepe, yamaç ve yumuşak kıyı geçişi fare ölçeğinde inandırıcı ve kontrollü olmalı.

## Sahiplik ve modül sınırı
- **WorldManifest (dış data):** world_id, island_id, geometry_revision, kaynak hash, dünya konumu, koordinat dönüşümü, metre/piksel ölçeği, yükseklik aralığı, deniz seviyesi ve format bilgisi. Gerçek ölçek henüz belirlenmedi.
- **TerrainSource (immutable):** doğrulanmış EXR / height samples, eksik-kırık dosya/NaN kontrolü; 32-bit FLOAT depolamayı varsaymak yerine gerçek EXR kanal/pixel type doğrulaması.
- **TerrainSampler:** `sample_height(world_pos)`, `sample_normal(world_pos)` ve `query_surface(world_pos)` gibi saf arayüzler; kesin imzalar kod başlamadan ADR ile sabitlenir. World→sample dönüşümünü bir yerde uygular.
- **TerrainCollisionSource:** sunucunun kullandığı canonical collision input. Collision region cache olabilir ama onun bölgelemesi client görsel chunk'lara bağımlı olamaz.
- **TerrainEditorPreview:** yalnız `@tool`, TerrainSource'dan okur, düşük maliyetli mesh önizlemesi; `.tscn` yalnız harici resource/script referansı taşır.

**Yasak bağımlılıklar:** Terrain modülü MultiplayerAPI, RPC, network peer, client camera, render LOD veya VisualChunkManager'ın yaşam döngüsünü bilmez. Sahnede height samples/mesh vertex dizileri saklanmaz.

## Bilinen veri kararı / kapanmamış risk
- İlk kaynak SE-01 manifesti **1536×1536**; son hazırlanan yumuşak kıyı EXR **1254×1254**. Bunlar farklı asset revizyonlarıdır; önce source/output SHA, kanal ve range doğrulanır, sonra kullanıcı onayıyla aktif revision seçilir. Sessiz resize, source overwrite ya da 32-bit'e dönüştü diye “gerçek yeni yükseklik ayrıntısı” iddiası yok.
- Kaynak yüksekliğinin gerçek metre cinsinden DEM olmadığı varsayılır; sea level ve metre ölçeği ayrı karardır.
- Kıyı yakınındaki yüksek eğimler, su/zemin kesişimi ve collider/sample farklılığı bağımsız test edilir.
- 1254 ve 1536 boyutları tipik `2^n+1` terrain grid'lerine uymayabilir: pixel discard, resample ya da pad stratejisi ölçülmeden seçilmez.

## Gelecekteki küçük uygulama parçaları
1. Asset envanteri ve world-space contract ADR (format, eksen, normalize aralık, deniz datumu).
2. Immutable source reader ve deterministic sampler + kaynak doğrulama testleri.
3. Server-safe canonical terrain/collision queries; visual tile yaşam döngüsünden bağımsız.
4. Godot `@tool` editor preview; resource invalidation, undo/redo, cache, editor restart testleri.
5. Kanıt: mesh/sampler/collider kıyı ve tepe boyunca tutarlı; Android budget, editor frame ve render farkları ayrı ölçülür.

## Kabul/test kapıları (henüz koşulmadı)
- EXR checksum, pixel type, yön ve aralık doğrulandı; world manifest ile tutarlı.
- Aynı world coordinate için sampler sonucu render LOD ve kamera mesafesinden bağımsız.
- Görsel chunk sıfır olduğunda headless server collision sorusu hâlâ doğru sonuç veriyor.
- Sadece `@tool` sayesinde Godot editörde terrain görünüyor; Play yok ve source dosyası değişmiyor.
- Bozuk kaynak, NaN/Inf, ada sınırı ve komşu tile köşe testleri raporlu.

## Hariç kapsam
Visual chunk scheduling/LOD, entity replication, network interest, server tick, player gameplay ve su efektleri bu belgeden yönetilmez. Ayrıntılar [CHUNK_STREAMING_ARCHITECTURE.md](CHUNK_STREAMING_ARCHITECTURE.md) ve [MULTIPLAYER_ARCHITECTURE.md](MULTIPLAYER_ARCHITECTURE.md) içindedir.
