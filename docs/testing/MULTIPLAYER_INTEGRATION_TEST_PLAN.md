# Terrain × Chunk × Multiplayer entegrasyon test planı v1.0
Durum: **PLANLANDI, OTOMASYON HENÜZ KURULMADI** · Önkoşul: ayrı domain sözleşmeleri.

> Genel test standardı: [QUALITY.md](../policies/QUALITY.md). Bu belge çok oyunculu dünya etkileşimi için senaryo ve otomasyon planının ayrıntılı kaynağıdır.

## Giriş ve bağımlılıklar
- [Terrain contract](../architecture/TERRAIN_ARCHITECTURE.md) (canonical source/sample/collider).
- [Chunk contract](../architecture/CHUNK_STREAMING_ARCHITECTURE.md) (client-only visual lifecycle).
- [Multiplayer contract](../architecture/MULTIPLAYER_ARCHITECTURE.md) (server authority, AOI, RPC).
- Doğrulanmış world manifest ve asset hash; Godot sürümü/export template hash; gerçek headless server ve en az iki farklı client test cihazı/emülatör.

## Test setleri / CI düzeni
1. **Static contract lint:** yasak imports/calls, render tile'ın entity_id yerine kullanılması, server'ın visual dependency alması, yanlış `.tscn` gömülü verisi. Henüz kod olmadığı için job eklenmedi.
2. **Terrain unit/property:** source hash/EXR type, dünya koordinat dönüşümü, sampler determinism, ada kenarı, NaN, datum, farklı render LOD'da eşit canonical height.
3. **Client visual chunk mock:** async request cancellation, token/generation, duplicate load, memory eviction, rapid teleport, camera jitter ve crash recovery; hiçbir server side effect yok.
4. **Headless server physics:** render/GPU olmadan actor collision + region loading; client chunk sıfır olduğunda bile doğru ground queries.
5. **Multiplayer contract:** protocol handshake, world revision reject, auth/rate/replay, entity ID lifecycle, AOI bağımsızlığı, snapshot delta ordering, late join ve reconnect.
6. **Multi-peer integration:** aynı seed/world'de en az 2 client + 1 server, sonra 4/8+ test grupları. Peer A boşaltıyor, peer B yürümeye devam ediyor; her ikisinin server kayıtları aynı.
7. **Chaos/adversarial:** loss/jitter/reorder/duplication, timeout, stale snapshots, reconnect storms, malicious RPC/input, yüksek bandwidth pressure, platform background/resume.
8. **On-device UX/perf:** farklı Android CPU/GPU/refresh/display quality; kıyı/dağ/boğaz gezintisi, terrain seam, kontrol gecikmesi, p50/p95/p99, termal, crash/ANR, paket kullanımı ve uzun soak.

## Kritik senaryolar ve geçiş beklentisi
| Senaryo | Beklenen |
| --- | --- |
| A chunk unload, B aynı chunk sınırında hareket ediyor | B'nin server entity ve collision durumu değişmez |
| A düşük LOD, B ultra görünüm | Canonical hareket/oyuncu etkileşim sonuçları sunucuda aynı |
| Sunucu headless, görsel GPU yok | Terrain/collider/network çalışır |
| World revision/hash uyumsuz | Handshake reddeder veya açık migration yolu izler |
| Teleport + AOI enter/leave + chunk eviction | Stale/duplicate ghost entity olmaz |
| Packet duplication/reorder + reconnect | Monotonic snapshot/tick; idempotent entity/event |
| Client başka player'a RPC ile damage/teleport dayatır | Server reddeder, audit kaydı ve fail-safe |
| Uzak adaya origin shift | Client görüntüsü kayabilir; authoritative global location sabit |
| Save sırasında crash/kopma | Veri geri yüklenir veya sürümlü recovery uygulanır |
| Client hafıza dolu, texture yüklenemiyor | Client degrade/fallback; server state bozulmaz |

## Deney düzeneği ve kanıt
- Her deney: test-id, commit/build SHA, Godot sürümü, manifest hash/world_revision, server/client version, peer sayısı, RNG seed, tick/snapshot trace, latency/loss/jitter config, CPU/GPU profile, sonuç, repro script ve artifact bağlantıları.
- Mock/harness sonuçları yalnız harness koşullarını kapsar; gerçek telefon/gerçek kullanıcı ve gerçek network ölçümleri ayrı kapıdır.
- S0: yetkisiz state mutasyonu, veri kaybı, server/world corruption. S1: oyun durması, görünmez collider/critical desync, başka peer'in chunk unload'undan bozulma. S0/S1 açıkken ilgili PR merge/release bloke.
- Eşikler (max ping, jitter toleransı, CPU memory budget, tick, FPS, oyuncu sayısı) başlangıçta bilinmiyor; ölçüm ve ADR olmadan uydurulmaz.

## TO-DO — parçalı, izinsiz ilerleme yok
- [x] Test matrisi ve fail kriterleri belgelendi.
- [ ] Kod bağımlılık lint + contract tests (domain kodu yazıldıktan sonra).
- [ ] Mock server physics + chunk unload/terrain check fixtures.
- [ ] Dedicated server + 2 client deterministic harness.
- [ ] Network loss, replay/spam ve stale-state fuzz suite.
- [ ] Android çoklu cihaz/uzun oturum ve insan testleri.
- [ ] CI required checks + branch protection enforcement denetimi.

## Çıkış kapısı
Bir test gerçekten koşmadıysa **PASS yazılamaz**. Tamamlanan her parçada yalnız o parçanın test kanıtları raporlanır. İstemci rendering doğruluğu server simulation doğruluğunun yerine geçmez.
