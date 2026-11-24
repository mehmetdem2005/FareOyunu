# P1.4R — Ertelenen yazılabilir bölgesel veri mimarisine dönüş kapısı
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
