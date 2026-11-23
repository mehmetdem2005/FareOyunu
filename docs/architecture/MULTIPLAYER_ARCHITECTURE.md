# Multiplayer / otorite / replikasyon mimarisi — ayrı uzmanlık planı v1.0
Durum: **PLANLANDI, UYGULANMADI** · Godot 4.7.2 · Mobil istemci + headless dedicated server hedefi.

> Üst sözleşme: [WORLD_ARCHITECTURE.md](WORLD_ARCHITECTURE.md). Bu belge protokol, authority, entity kimliği ve network interest sorumluluğunun detaylı kaynağıdır; terrain source veya görsel chunk işini sahiplenmez.

## Temel ilke ve tehdit modeli
**Dedicated authoritative server** başlangıç mimari tercihidir (test/hosting maliyeti ADR ile kesinleştirilir). Client input/intent gönderir; nihai pozisyon, çarpışma, hız, hasar, loot, world change, spawn/despawn, sahiplik ve save state sunucuda hesaplanır. İstemciden gelen state niyet değil gerçek kabul edilmez. Sıfır bug garantisi yok; kritik state invariant'ı test edilmeden merge edilmez.

## Ayrı modüller
- **NetworkTransport:** ENet/WebSocket/diğer seçimi, channel/reliability, bağlantı; uygulama semantic kararlarından ayrı. Seçim mobil gerçek ağ testinden sonra yapılır.
- **Authentication/Session:** peer kimlik doğrulama, izin, tekrar bağlanma, hız limiti ve oturum ömrü. Network client input'u doğrulanmadan yürütülmez.
- **InputCommandValidation:** peer_id, tick/sequence, replay/rate limit, yetki, ölçü/pozisyon/eylem sınırları; abuse detection.
- **SimulationAuthority:** tick bazlı gameplay, deterministic/uyumlu collision queries; yalnız immutable manifest/TerrainSampler canonical veri ile.
- **NetworkInterest/AOI:** sunucu authoritative spatial index ve gameplay relevance ile hangi peer'in hangi entity state'ini alacağına karar verir. **İstemci render chunk/draw distance asla input değildir.**
- **Replication:** snapshot/delta/event türlerinin versioned schema, delta baseline, sequence/ack, ordering, duplicate ve idempotence. Entity spawn/despawn authoritative ve kararlı entity_id ile.
- **ClientPresentation:** client-side prediction, interpolation ve reconciliation. Yalnız algılanan akıcılığı iyileştirir; yetkiyi ele geçirmez.
- **WorldPersistence:** world-event/save migration (uygulandığında) kalıcı ID ve server sürümü üzerinden işler; render tile ID üzerinden değil.

## Değişmez sözleşmeler
- `world_id, island_id, world_revision/content hash, entity_id` ile `ChunkKey` ayrı identifier'lar. NodePath veya render scene lifecycle persistent game identity olamaz.
- Network payload kanonik dünya koordinatı taşır; client floating origin yerel render transformudur. Origin shift, başka oyuncuya teleport değildir.
- World asset değişikliğinde client/server protocol ve source revision handshake gerekir; uyumsuz asset “oynayabilir” diye sessizce kabul edilmez.
- Server rendering, editor tool, client visual tile mesh veya GPU olmadan headless çalışabilmeli.
- Client A'nın sahnede chunk'ı unload etmesi server'ın B oyuncusunu, ağdaki nesneyi veya physics actor'ünü silmez.
- Server AOI nedeniyle replication durması entity'nin sunucudan silinmesi değildir: `temporarily not replicated` ve `authoritatively despawned` ayrı olaylar olarak tasarlanacak.
- Dinamik terrain değişimi istenirse immutable source üzerine authoritative terrain delta/revision + collision invalidation/reconciliation protokolü **ayrı ADR** olmadan eklenmez.

## Bağlanma/yeniden bağlanma durumları
`Disconnected -> Connecting -> Authenticated -> WorldVersionVerified -> InitialSnapshot -> Active -> Reconnecting/Failed`. Late join; packet loss/reorder/duplicate; input gecikmesi; iki peer aynı nesneye eşzamanlı etkileşim; reconnect'te phantom duplication; owner changes ve object lifetime ayrı testlere tabi.

## Planlanan uygulama sırası
1. World + protocol revision/ID contracts ve dedicated-vs-listen, tick, max player, transport karar ADR'leri.
2. Headless SimulationAuthority mock/fixture + TerrainData read-only adapter ve collision consistency.
3. Auth/input validation + authoritative entity lifecycle.
4. InterestManager, snapshot/delta ve prediction/reconciliation; ayrı sorumluluk.
5. Bir sunucu, iki veya daha fazla istemci ile deterministic network tests; sonra gerçek ağ/Android perf.
6. Reconnect, persistence, abuse/operational monitoring; ancak önceki kapılar geçtiğinde.

## Güvenlik ve kabul
- Client RPC ile başka peer'in koordinatını/nesnesini değiştiremez; geçersiz/sahte input güvenle reddedilir.
- Farklı grafik kalitesi, chunk LOD ve cihaz frame time'ı authoritative simulation sonucunu değiştirmez.
- Server farklı world revision ile bağlanan istemciyi tanımlı hata/migration prosedürüyle yönetir.
- Peer görünmez olduğunda bile authoritative world state tutarlıdır; AOI yalnız gönderim optimizasyonudur.
- Kritik desync, yetkisiz RPC, kalıcı veri bozulması, duplicate ownership veya game-breaking rollback açıkken yayın yok.

## Bağlı kalite planı
[Multiplayer entegrasyon testleri](../testing/MULTIPLAYER_INTEGRATION_TEST_PLAN.md). Ayrıntılı performans/sunum planı [CHUNK_STREAMING_ARCHITECTURE.md](CHUNK_STREAMING_ARCHITECTURE.md) içindedir.

Resmi Godot başvuru: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
