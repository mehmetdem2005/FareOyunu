# Visual chunk / LOD / streaming mimarisi — ayrı uzmanlık planı v1.0
Durum: **PLANLANDI, UYGULANMADI** · Hedef: Godot 4.7.2 Mobile / Android.

> Üst sözleşme: [WORLD_ARCHITECTURE.md](WORLD_ARCHITECTURE.md). Chunk yalnız **görsel sunum ve yerel cache/streaming** yönetimidir. Terrain truth veya server object lifetime değildir.

## Amaç
Büyük denizli ada dünyasını RAM/VRAM, CPU, GPU, depolama aktarımı ve termal sınırları gözeterek kesintisiz göstermek; yükleme/görsel kalite kararlarının başka oyuncuyu veya authoritative simulation'ı etkilemesine izin vermemek.

## Sorumluluk ve sınır
- **ChunkKey:** world_id + island_id + source_revision + geometric tile coordinate + LOD. ChunkKey yalnız görsel/asset cache kimliğidir; **entity_id** ya da network owner değildir.
- **ChunkPlanner:** kamera konumu, screen-space error, görünürlük ve ölçülmüş kalite bütçesiyle istenen görsel tile setini hesaplar.
- **ChunkScheduler:** istek önceliği, concurrency, cancellation, generation token, stale result eleme; double load veya unbounded queue yasak.
- **MeshBuilder / TerrainRenderer:** TerrainSampler'dan veri okuyup mesh/material/normal üretir; LOD seam stitching/morph planı, instancing ve render fallback uygular.
- **CachePolicy:** CPU/GPU asset residence, memory limit, LRU/priority; resource invalidation version-aware.
- **ChunkTelemetry:** frame pacing (p50/p95/p99), upload spike, CPU/GPU VRAM, pop-in, cache hit, cancellations ve thermal profile.

**Yasak:** VisualChunkManager terrain source'ı değiştiremez; server collision, oyuncu durumları, network AOI, nesne despawn, envanter veya diğer peer'lere RPC gönderemez. LOD **asla** authoritative physics doğruluğunu değiştiremez.

## Örnek state machine (plan)
`Unrequested -> Requested -> Loading -> CPUReady -> GPUReady -> Visible -> Cooling -> Evicted`; `Cancelled / Failed / Retry` yan durumları. Async sonucu yalnız güncel source_revision + generation token eşleşirse kabul edilir. Görsel tile unload sadece görüntüdeki kaynakları siler.

## Açık teknik kararlar
- Tile boyutu, 1254² source alanının bölünmesi, quadtree vs clipmap vs sabit grid, LOD seviye sayısı, overlap/kenar vertex, collision ile dünya koordinatlarının eşlemesi ölçüm/ADR öncesi kesin değildir.
- Chunk sınırları adanın gerçek kıyısına eşit değildir. Su, foliage ve etkileşilebilir objeler ayrı sunum sistemlerine bağlanabilir, lifecycle sözleşmesi bozulmaz.
- Çok yüksek görünür mesafe çok oyunculu AOI ve network bandwidth parametresi olarak kullanılmaz.

## Gelecekteki parçalar
1. Sampler arayüzü + ChunkKey sözleşmesi ve deterministik partition testleri.
2. Scheduler/cancellation/cache mock ve worst-case bellek testleri.
3. Seams, normals, morphing/LOD ve terrain materyal renderer.
4. Editor preview ile runtime streamer'ın aynı sampler'ı **ayrı yaşam döngüsüyle** kullanması.
5. Headless simulation / multi-peer contract testi ve gerçek Android cihaz profillemesi.

## Hata arama/test kapıları
- Kamerayı hızla hareket ettirme, teleport, chunk sınırında titreme, ani 180° dönüş ve arka plandan geri dönme.
- Eski async isteğin yeni revizyonu overwrite etmesi, double allocation, cache eviction sırası ve memory pressure.
- Bitişik LOD'larda çatlak, normal/texture sürekliliği ve deniz-kıyı kesişimi.
- Görsel chunk'lar sıfırken server doğru world-state ve collider ile çalışıyor.
- Farklı cihazlarda farklı LOD/draw distance ile iki oyuncunun authoritative state'leri aynı.
- GPU context loss, slow I/O ve uzun termal testlerde recover/fallback; kanıtsız “optimize edildi” etiketi yok.

## İlgili planlar
Terrain doğruluğu: [TERRAIN_ARCHITECTURE.md](TERRAIN_ARCHITECTURE.md).
Authority/AOI/replication: [MULTIPLAYER_ARCHITECTURE.md](MULTIPLAYER_ARCHITECTURE.md).
Ağlı karma testler: [../testing/MULTIPLAYER_INTEGRATION_TEST_PLAN.md](../testing/MULTIPLAYER_INTEGRATION_TEST_PLAN.md).
