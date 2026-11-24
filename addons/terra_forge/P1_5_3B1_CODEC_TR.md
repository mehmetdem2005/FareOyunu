# P1.5.3b B1 — TFM2/TFS2 frozen codec v1
> **GÜNCEL DEVİR — P1.5.3b B1 (24 Kasım 2026):** Kod a2793e063381008af133edbb9e3ff21b65c3160a, [31/31 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769). [P1_5_3B1_CODEC_TR.md](P1_5_3B1_CODEC_TR.md) frozen binary layout ve as-built contract. B1 DONE: TFM2/TFS2 codec, bound, SHA, coordinate/edge validation, max root, corruption tests. **Sıradaki B2:** isolated staged TFM2 fixture exporter, gerçek multi-shard world, synthetic provenance, strict scan/lazy verified shard/page read helpers, cancel/cleanup. Sonra B3 async reader, B4 profiling. TFM1 unchanged; Android GPU/RSS/FPS proof open, P1.4 parked, boya/obje yok.

## Files
core/region_index_v2.gd: static encode/decode/load, RootIndex and ShardIndex value-buffer objects; no page writes or production reader integration. tests/test_region_index_v2.gd: test 31.
 
## Frozen binary layout v1
Little endian. SHA-256 digest raw 32 bytes. All-zero digest reserved invalid. No paths from files. Root filename manifest.tfm2; shard filename s_%05d_%05d.tfs. TFR1 existing page layout unchanged.
Root header 80 bytes:
- offset 0 magic ASCII TFM2 (4); 4 version u32=1; 8 cells_x u32; 12 cells_z u32; 16 spacing Float32 (finite positive including after conversion); 20 page_width u16=32; 22 shard_width u16=16.
- 24 pages_x u32; 28 pages_z u32; 32 shards_x u32; 36 shards_z u32; 40 provenance u32 (1 TFH1, 2 TFL1, 3 TFL2, 4 SYNTHETIC_V1); 44 reserved u32=0; 48 source digest 32 bytes.
- offset 80 row-major shard full-file SHA digests, 32 bytes each; terminal 32-byte SHA of all preceding bytes. Exact size 112+32*shards_x*shards_z. Max cap 256KiB, actual theoretical max 135312 bytes.
Shard header 48 bytes:
- offsets 0..23 same except TFS2 magic; 24 shard_x u32; 28 shard_z u32; 32 edge pages_x u32; 36 edge pages_z u32; 40 and 44 reserved u32=0.
- offset 48 row-major TFR1 full-file SHA digests. Terminal 32-byte SHA of preceding bytes. Size 80+32*edge_x*edge_z, maximum 8272 bytes, cap 16KiB.
Coordinates and count derived from dimensions: cells per axis multiples of 32, range 32..32768 inclusive. pages=(cells>>5)+1; shards=(pages+15)>>4; edge=min(16,pages-key*16); page owner shard=page>>4. Each sample boundary has one TFR1 owner. Implicit ordinal means no coordinate fields per digest. Root source identity uses provenance + digest; synthetic descriptor canonicalization MUST be defined in B2, no fake TFH provenance.
RootIndex getters cells, spacing, page_count, shard_count, provenance, source_digest, byte_count, snapshot_digest (trailing internal SHA, not full-file digest), shard_digest, shard_for_page. ShardIndex getters key, extent, byte_count, page_digest. Bounds errors return empty digest or (-1,-1); no fabricated height. Decoders duplicate validated bytes; returned digest slices are independent. Objects follow read-only API convention; GDScript underscore is not access protection. No untrusted code may mutate private raw.
 
## Validation
Disk size cap checked before allocation, one file handle reads buffer and rechecks length. Exact structural length from bounded validated dimensions. Root internal SHA, shard full-file SHA against pinned root plus internal SHA, exact Float32 spacing and world/coordinate/edge match, reserved zero, valid provenance tag, nonzero entries. Corrupt/missing returns error with no index. SHA is integrity not authentication, no protection against deliberate fully re-signed entire root from untrusted source. B1 does not verify TFR1 content or existence; B2/B3 must.
 
## Evidence
31/31 CI PASS https://github.com/mehmetdem2005/FareOyunu/actions/runs/45428622769 . 512x1024 rectangular 17x33 pages/2x3 shards, all 561 digest lookups, edge sizes and bounds; forged re-sealed fields, every root byte bit mutation, zero digest, truncation/trailing, wrong shard, rebound malformed shard, Float32 underflow/overflow, max root with mock hashes, disk read size caps, pinned root buffer independence. These are codec tests, not generated 32768 terrain.
 
## Next B2 checklist
1. Implement separate core/region_fixture_v2.gd or reuse builder through explicit format flag, no TFM1 modification. Fixed versioned synthetic descriptor including dims, spacing bits, generator id/parameters; source digest SHA descriptor. Generate TFR1 by page; write complete TFS2 per shard and retain only compact root digest list. No global heights or global page hashes. Explicit free-space preflight, bounded worker progress/cancel and own stage cleanup; do not enable 4096/8192 UI before reader support.
2. Shared read-only TFR1 page codec verification from one immutable buffer (full digest + internal digest + dims/key/spacing + finite). Reuse async source's validated path or extract common pure helper with full old regressions; TFM2 exact float bits contract. Strict verification walks each shard/page, fail closed, cancellable; lazy root and shard/page helper separate, no claim fully verified. Stage rename only after full verification. No crash durability guarantee.
3. Tests real 512x512 multi-shard snapshot (289 pages, 4 shards), edge sample parity, deterministic provenance, missing/corrupt shard/page, wrong format, cancellation, source protection, strict vs lazy boundaries. 4096/8192 optional benchmark, not forced each CI. Max theoretical preflight includes logical disk bytes and inode overhead separate. 
4. Then B3 opt-in async reader, compact pinned root and bounded shard cache, epoch/snapshot distinction, old strict/lazy unchanged; B4 device profile after integration. No geometry/brush changes until reader parity.
