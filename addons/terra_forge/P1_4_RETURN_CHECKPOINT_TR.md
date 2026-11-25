# P1.4R — Ertelenen yazılabilir bölgesel veri mimarisine dönüş kapısı

## 25 Kasım — P1.4R ilk karar ve uygulama sırası

`region_store.write_height` / `flush_all` ve tahliyedeki `_save_page` tek sayfayı kaydeder. `region_index_v2.decode_shard` ise köke bağlı shard verisini doğrular. Canlı bir sayfanın üzerine yazmak eski okuyucunun doğrulamasını bozabilir. `region_export.export_file` ayrı bir dışa aktarma yoludur. `terra_forge_terrain.end_stroke` birden çok örneği tek kullanıcı işleminde toplar. `height_layers.move_layer` katman sırasını değiştirebildiğinden uzun ömürlü geçmiş için tek başına liste indeksi yetersizdir.

İlk izole prototip için tercih: küçük test dünyasında iki tam nesil dizini ve açıkça seçilen kök. İlk adımda tüm dünyayı çoğaltma maliyetini ölç; büyük haritaya taşımadan önce içerik adresli değişmez sayfa/shard paylaşımı ile karşılaştır. Mevcut okuyucunun düz dizin biçimini ilk deneyde kullanabiliriz. Kamera epoch değeri veri nesli olarak kullanılmayacak.

P1.4a ilk kabul örneği: 31 ve 32 numaralı bitişik x örneklerini aynı fırça işleminde değiştir. Eski köke bağlı okuyucuda iki eski yüksekliği, yeni köke bağlı okuyucuda iki yeni yüksekliği doğrula. Yayın öncesi her kesinti noktasında önceki kök okunabilmeli. Bozuk veya eksik sayfada yeni kök seçilmemeli. Kalıcı kök değiştirme, disk dolması ve yeniden başlatma kurtarması sonraki prototip kontrolleridir. Bu tasarımın gerçek cihazda güç kesintisine dayanıklılığı henüz ölçülmedi.

> **GÜNCEL DEVİR — P1.5.5d (24 Kasım 2026):** Kod 161346b356abe59a38876fc243ff950b21d0c4a1, [42/42 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45449446366). [P1_5_5D_PRIORITY_WORKER_TR.md](P1_5_5D_PRIORITY_WORKER_TR.md), [ham JSON](P1_5_5D_PRIORITY_WORKER_CI.json). F=explicit experimental priority worker mode4; A default, E unchanged. 24 C/E/F traces, two cadences, two page caps, both formats. F reduces missing shape steps vs E in all measured groups; cap16 still behind C, modest pump overhead. 8ms target no full-period deadline misses in this run. No actual physics raycast/rendered FPS/Android proof. **USER DECISION: P1.5 first; P1.4/P1.4R PARKED until P1.5 work complete or user changes order.** NEXT P1.5.5e: isolate dense scalar worker compute latency, preserve exact output and compare E/F vs candidate; then P1.5.6. Keep all experiments, no painting/objects.

24 Kasım 2026 — Kullanıcı P1.4'ün unutulup unutulmadığını sordu. P1.4 PARKED; P1.5.5c sonrasında **NEXT tasarım değerlendirmesi**, sonsuza dek P1.5.10 bekleme yok. Bu belge plan ve dönüş koşulu, kod uygulanmış veya kullanıcı gerçek veri yazımını onaylamış değildir.

## Mevcut kök sorun
- core/region_store.gd create/write/flush ve sayfa tahliye sırasında kaydetme yapabilir, fakat immutable manifest ile bir transaction değildir. TFR1 tek başına yazılırsa TFM1/2 SHA pinleri eski kalır. Mevcut writer'ı doğrudan preview'a bağlama.
- core/region_export.gd benzersiz dizin staging, export; edit transaction değildir.
- core/region_index_v2.gd TFM2 root/shard checksummed immutable kimlik; değişen page hash -> değişen shard -> yeni root. TFM1/2 flat directory reader mevcut; COW object-addressed storage veya generation directory sharing için yeni okuma adaptörü gerekir, otomatik uyumluluk iddiası yok.
- terrain/terra_forge_terrain.gd legacy height_data/layers/brush/Undo/Redo hâlâ tam Float32 alanı. Gerçek TFH/TFL/terraforge_data ve main dalı korunur.
- async_region_source + geometry_worker source session/epoch/snapshot pinning mevcut; kamera epoch veri generation değildir. Yeni root yayınlanınca eski reader/worker kendi immutable snapshot'ını tutmalı, in-place data mutasyonu yasak.

## P1.4R inceleme sırası (yazmadan)
1. Read existing format docs, region_store/export/manifest/index_v2, height_store/height_layers, terrain brush history/save, async reader and worker lifetime. Inventory exact read/write boundary, dirty rectangle and layer/undo semantics. Identify stable source/layer IDs.
2. Compare generation directories (portable, possible duplication), immutable content-addressed pages/shards + root pointer (COW reuse, new loader/GC complexity), journal/recovery alternatives. Hardlinks not assume Android availability; no whole-world copying per stroke without measurement. Choose format/protocol only after tradeoff; avoid modifying existing TFM1/2 wire formats in place.
3. Specify pointer/root verification, bounded transaction dirty pages, multi-page write, immutable staging, durable commit point, reader pin and reclaim policy, disk-full/rename/kill recovery. Atomic rename process-crash vs actual power-loss guarantee separate; Godot FileAccess.flush != guaranteed fsync. No arbitrary recursive cleanup or delete live generations. Old/new complete only, no mixed.
4. Plan scratch-only P1.4a prototype (single writer + two page cross-boundary stroke + old reader/new reader), fault injection each commit boundary, corrupted pointer/manifest fail closed, rollback, stale worker output, read-only compatibility. No real data write until explicit decision. Later P1.4b layers/Undo/Redo stable IDs and COW sparse deltas; P1.4c integration, Android storage & recovery; plan names provisional.
5. Return a written decision and exact next small test; user can authorize implementation. P1.5.5d coverage correction remains open in EXP-08, then P1.5.6–10, no silent phase loss.

## Acceptance gates
Immutable authoritative data and checksums, no invented flat heights, bounded RAM and disk, old/new atomic publication and rollback, crash injection, mixed generation isolation, correct brush/undo/layer semantics, real Android permissions/storage and performance. Do not claim P1.4 completed until actual tests and user acceptance.
