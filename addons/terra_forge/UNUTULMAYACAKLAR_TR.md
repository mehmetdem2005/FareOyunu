# TerraForge — UNUTULMAYACAKLAR / Deney, karar ve doğrulama defteri

> **GÜNCEL DEVİR — P1.5.4c (24 Kasım 2026):** Kod 94beaeb2cd068e7bf5a09fc9b23b97b98a44d92d, [37/37 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45440552536). [P1_5_4C_STREAM_TRACE_TR.md](P1_5_4C_STREAM_TRACE_TR.md), [ham JSON](P1_5_4C_STREAM_TRACE_CI.json). 12 fixed 144-pump traces (TFM1/2 × cache9/16 × A/B/C); B lower mean pump in all four groups, equal-weight means A 0.722, B 0.568, C 0.676 ms; 21.26% lower B vs A on one runner, work differs at cap16. Shape-missing steps 34/144 cap9,29/144 cap16 for all methods; no raycast or actual render frames. A default, B/C explicit experiments. **NEXT P1.5.4d:** isolate allocation/topology optimization via fixed resident benchmark; preserve exact geometry and opt-in. Device/long soak and real trace repeats open. P1.4 parked; no painting/objects. Read UNUTULMAYACAKLAR_TR.md.


> **GÜNCEL DEVİR — P1.5.4b (24 Kasım 2026):** Kod da123dca5be609cc67c6b18f181b91abdc962404, [36/36 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45439854530). [P1_5_4B_SAMPLING_BENCH_TR.md](P1_5_4B_SAMPLING_BENCH_TR.md), [ham ölçüm](P1_5_4B_SAMPLING_CI.json). A/B/C exact array parity, 14 warm-resident cases × 24 rounds × 3 methods = 1008 timed builds. Equal-weight mean A 1869.22 us, B 1390.05 us, C 1791.09 us; B 25.63% lower than A, wins 14/14 means on one Linux runner. Not mobile FPS or isolated CPU time. A default, B opt-in, C benchmark-only. **NEXT P1.5.4c:** fixed camera trace A/B/C, page/job/cache/RSS/reload and frame/pump comparison; device gates still open. [UNUTULMAYACAKLAR_TR.md](UNUTULMAYACAKLAR_TR.md) mandatory every turn. No painting/objects or P1.4 writes.


**24 Kasım 2026 | Zorunlu ilk okuma | Sahibi: sonraki oturumda projeyi sürdüren geliştirici/AI.**

Repo: `mehmetdem2005/FareOyunu`, dal: `feat/terraforge-mobile-addon`. Bu kayıt oluşturulurken son doğrulanmış kod commit'i `285122ecc826616f3c3840a41ad4e34223afc0fa`, [35/35 Godot 4.7.2 Linux headless CI](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45436882446); önceki doküman HEAD `7496246e71469adfb9f54e4f3e3588c8d5afb832`. Yeni oturumda gerçek HEAD'i tekrar sorgula. Bu dosya tek başına as-built teknik belgelerin yerine geçmez; açık borçların unutulmasını önler. Eski planların tarihsel ifadeleriyle çelişirse en yeni doğrulanmış kanıtı kullan.

## 0 — Kullanıcının bağlayıcı kararı
24 Kasım: P1.5.4a ve önceki deneysel geliştirmeleri unutma. Henüz ölçülmemiş yöntemleri deneysel bırak; performansını varsayma, otomatik varsayılan yapma, sebepsiz silme. Yalnız son eklenen özelliği değil, geçmişten kalan bütün ölçüm ve kabul kapılarını takip et. Bu dosyayı her turda güncelle. Kullanıcının telefonu Android 11 / Redmi Note 8 Pro; testler GitHub CI üzerinden, gerçek cihaz sonuçları ayrıca. Şimdilik sadece arazi geometrisi, veri, LOD, streaming, fizik ve performans; boya/materyal boyama ve obje yerleştirme yok. P1.4 yazılabilir disk transaction bilinçli ertelendi. Main/game dalı ve gerçek TFH/TFL/terraforge_data değişmeyecek; scratch fixture ayrı.

## 1 — Durum etiketleri ve kapatma kuralı
- IMPLEMENTED: kod var, kabul edilmiş performans veya cihaz uygunluğu demek değil.
- CI_VERIFIED: belirtilen deterministik test geçti, sadece test kapsamını kanıtlar.
- EXPERIMENTAL: açık opt-in; varsayılanlaştırmak için karşılaştırma ve karar gerekli.
- DEVICE_OPEN: gerçek Android kanıtı eksik.
- PARKED: bilinçli ertelenmiş, silinmiş değil.
- PLANNED: uygulanmamış.
- ACCEPTED / REJECTED: ancak karşılaştırmalı kanıt + karar gerekçesi + commit/test/rapor ile yaz. Başarısız deneyi de tarihçe olarak koru.

Her kayıt ID, kaynak, mevcut varsayılan, kanıt, eksik kanıt, sonraki işlem ve yeniden ele alınacağı faz içerir. CI yeşil diye DEVICE_OPEN veya EXPERIMENTAL kapatılmaz. Bir özellik ileride başka fazda değişirse eski kayıt ve geri dönüş yolu korunur.

## 2 — Aktif deneyler / karar bekleyenler

### EXP-01 — P1.5.4a tile read view (EN ÖNCELİKLİ)
Durum EXPERIMENTAL + CI_VERIFIED + DEVICE_OPEN. `use_tile_read_view=false` (preview ve profile varsayılanı). [Teknik kayıt](P1_5_4A_TILE_VIEW_TR.md). `core/tile_read_view.gd`, `core/async_region_source.gd`, `core/paged_tile_geometry.gd`.
A: mevcut get_height + her örnekte LRU; B: 3x3, en fazla 9 resident sayfa referansı, tek senkron main-thread lease; C: açık deneysel runtime seçeneği olan bitişik Float32 karo + halo tamponu (LOD0 35x35 = 1225 örnek, 4900 bayt; world edge clamp/stride ve mixed seam için doğru kapsam kanıtlanmalı). C gerçek veriyi kopyalar; daha hızlı olduğu varsayılmayacak. Tüm yöntemler aynı Float32 yükseklik/normal/UV/renk/index/collision sonucu vermeli.
Kanıt: [35/35 CI](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45436882446), her formatta 4 LOD senaryosu, A 2944 sample LRU touch, B 36 lease page touch (%98,78 yalnız bu işlem türünde). Testler eksik, duplicate, exclusive, out-of-view, generation/poll/eviction/close revocation ve gerçek mesh/shape. Bu FPS veya CPU yüzdesi değil. B 9x4096=36864 bayt mevcut resident payload'a referans; yeni tam dünya buffer yok, toplam RSS kazancı kanıtlanmadı.
Denetim borçları: B hala her sample Dictionary oluşturuyor; required_pages tekrar hesaplanıyor; A/B LRU sırası farklı, sonraki cold reads/eviction davranışı değişebilir. Lease sadece main thread; worker ile paylaşma, cache mutation öncesi revoke. Internal mutability convention güvenlik sınırı değil. P1.5.4b resident ölçüm tamamlandı; tarihsel kabul planı: önce A/B/C aynı resident veri, LOD0/1/2/mixed, world edge ve TFM2 interior shard seam, prewarm, ABBA veya dengeli rotasyon, sabit iterasyon, p50/p95/p99 CPU, sample/alloc/bytes/eviction/reload counts. Sonra gerçek kamera trace ve cihaz. C kopya maliyeti dahil; IO, array generation ve GPU upload ayrı. No flaky CI wall-time gate. Gerekirse scalar access/preallocation/topology ancak parity sonrası. Sonuç çıkmadan varsayılanı değiştirme. P1.5.5'te worker-owned immutable input ayrı tasarlanacak.

**24 Kasım B4b ölçüm güncellemesi:** [P1_5_4B_SAMPLING_BENCH_TR.md](P1_5_4B_SAMPLING_BENCH_TR.md), [ham JSON](P1_5_4B_SAMPLING_CI.json), 36/36 CI. B 25.63% daha düşük equal-weight resident build elapsed vs A, 14/14 mean wins; C copy included slower than B. A default/B opt-in/C benchmark-only. No device acceptance. NEXT P1.5.4c trace; see detail. Other EXP records remain OPEN.

**24 Kasım P1.5.4c:** [stream trace](P1_5_4C_STREAM_TRACE_TR.md), [ham JSON](P1_5_4C_STREAM_TRACE_CI.json), 37/37 CI. A default/B+C explicit experimental choices (legacy bool preserved); B lower mean pump 21.26% across groups, cap16 different work. Cap9 153 reloads/34 missing steps, cap16 73–74 reloads/29 missing steps; sampled RSS same, not memory proof. B/C cold page failure retention and recovery verified, cold shard variant and rendered frames/raycast/device/30min still open. NEXT P1.5.4d isolated allocation/topology experiment, no default change.

### EXP-02 — P1.3b/P1.5.0 strict / lazy açılış
CI_VERIFIED + DEVICE_OPEN. `async_region_source.open()` strict varsayılan; read-only preview lazy varsayılan (verify_pages_on_demand=true); strict seçeneği korunacak. TFM1 lazy manifest-only, TFM2 lazy root-only; cold shard/page SHA doğrulanır. [26/26 CI](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664), [not](P1_5_LAZY_WORLD_OPEN_TR.md). Strict bütün taramayı senkron yapar; büyük dünyada UI bloklanabilir, lazy tam dünya bütünlük onayı değildir. Uzak bozuk sayfa sonradan hata verir. Açık: aynı fixture/route, cold/warm order farkı, first focus, UI hitch, RSS, disk IO, bozuk uzak page. P1.5.10'da tekrar; strict'i kaldırma.

### EXP-03 — TFM2 hiyerarşik indeks / TFM1 kıyaslaması
IMPLEMENTED + CI_VERIFIED + EXPERIMENTAL + DEVICE_OPEN. TFM1 default, TFM2 açık seçim; otomatik fallback yok, mixed folder V2 reddi. B1 binary root/shard schema, B2 genuine fixture, B3a async, B3b preview, B4 profiler tamamlandı. [B1](P1_5_3B1_CODEC_TR.md), [B2](P1_5_3B2_FIXTURE_TR.md), [B3a](P1_5_3B3A_ASYNC_TR.md), [B3b](P1_5_3B3B_PREVIEW_TR.md), [B4](P1_5_3B4_PROFILE_TR.md). 
Kanıt: B1 31, B2 32, B3a 33, B3b 34, B4 34 CI. 512² 289 pages/4 shards; 576² 361 pages, x=z512 interior seam gerçek ArrayMesh/HeightMapShape3D; LOD0/1/2 + mixed arrays. B4 256² TFM1/2 81 byte-identical TFR1, dört strict/lazy profile runs. 4096/8192 seçilebilir, gerçek büyük üretim ve cihaz benchmark henüz YOK; 32768 teorik indeks kapasitesi, üretici 8192 cap. TFM1 fixture cap 2048/axis, TFM1 10k pages/2MiB manifest. TFM2 root pinned, worker shard LRU 1..16 (default4), each cold shard/page verified. Bitset exact unique max131329 bytes, lazy terminal error max1050625 bytes; payload counts not RSS. Cached verified bytes no hot reload. SHA integrity not authenticity.
Açık: 1024/2048 matched A/B strict/lazy on device, shard caps 1/4/8/16 and page caps 9/16/32/64, hit/miss/eviction/cold IO, CPU and RSS. Actual 4096/8192 fixture preflight then generation/strict/lazy/stream traces with storage and inode accounting; optionally separate CI benchmark, not every push. 32768 no practical claim. P1.4 immutable generations compatibility audit before writable deployment.

### EXP-04 — Profil ölçüm altyapısı ve ölçüm hataları
IMPLEMENTED + CI_VERIFIED + DEVICE_OPEN. [B4](P1_5_3B4_PROFILE_TR.md), `profiling/profile_scene.tscn`, TF_PROFILE_3 JSON (bounded 8 reports). Matched fixture recipe session hint not external proof. Identical extent/route/settings only fair A/B; normalized sine route speed changes with extent. Strict/lazy alternate order; no OS cache flush guarantee. Process RSS sampled /proc/self/status, Godot static separate, unavailable null. Frame interval not GPU time; mesh build pump sample not isolated CPU; worker accepted-only histogram excludes strict/canceled work; shard counters include canceled work. First collision / longest sampled gap only shape attachment, not raycast. Report device/OS/Godot/renderer/resolution/commit and actual elapsed. Need separate IO open/read/hash/decode, per-stage CPU, draw calls/triangle count, real raycast, real GPU/thermal where supported. New performance metric needs definition and denominator. P1.5.4b and P1.5.10.

### EXP-05 — Cache & kamera iş kuyruğu / failure isolation
IMPLEMENTED + CI_VERIFIED + DEVICE_OPEN. TFM1/2 page cap 1..64, preview 9..64 default16; jobs 1..8 default4; single IO worker low priority. Epoch cancels pending/completed and drops stale in-flight result; cannot interrupt current read; binary wake fixed 1000 epoch CI [29/29](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45425969111). P1.3c last-good verified mesh/shape only at same coordinate on failed rebuild; never-loaded tile remains absent; independent healthy tiles proceed [27/27](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Camera epoch and snapshot identity separate. Open/close join can block; don't per-frame. Actual teleport, slow/fast route, minimal cache halo thrash, near hole and longest gaps, stale work, retained resource count 30min pending. New tile view LRU order may affect this, retest using real trace before accepting EXP-01. No guarantee collision exists outside loaded LOD0 area.

### EXP-06 — Büyük scratch üreticileri / depolama
IMPLEMENTED + CI_VERIFIED + DEVICE_OPEN. [TFM1 builder](P1_5_3A_FIXTURE_TR.md) and [TFM2 builder](P1_5_3B2_FIXTURE_TR.md); unique exclusive staging, worker cancellation + publication serialization, full verify then rename, no source overwrite. TFG1 descriptor 24 bytes, V2 synthetic provenance no fake TFH. Preflight logical bytes + overhead gate not reservation; actual disk allocation/inode count, Android free space/permissions, kill orphan cleanup, power-loss not guaranteed. Successful fixture stays on disk. 2048/4096/8192 actual device generation stress pending; safe cancel + cleanup measured on device. No automatic deletion of user worlds or previous results.

### EXP-07 — Doğal arazi şekilleri / hassasiyet / görsel kalite
IMPLEMENTED parts + DEVICE_OPEN. [Geomorphology](TERRAIN_GEOMORPHOLOGY_TR.md), [quality tests](QUALITY_TESTS_AND_BENCHMARKS_TR.md), [risk log](RISKS_AND_DECISIONS_TR.md). Existing erosion/drainage/advanced brushes, shape quality, surface normals, seam regression preserved. User wants believable natural terrain especially microforms, not artificial repetitive noise/hills, no fidelity reduction to optimize. Float32 canonical heights; 8-bit source terracing cannot be recovered by bit-depth conversion; no silent quantization. Actual editor and game visual checks (cliffs, channels, ridges, small banks, mixed LOD transitions, corner normals, lighting, camera at mouse scale) pending. Existing seam interpolation parity isn't proof of universal watertight topology, transient mixed-neighbor publication or collision continuity. Before painting/objects, user quality acceptance plus geometry/device gates. Do not confuse diagnostic synthetic ridges with production art.

## 3 — Ertelenen ve sonraki fazlar (sırayı koru)
| ID | Durum | Kapanış şartı / sonraki çalışma |
|---|---|---|
| P1.4 editable disk transactions | PARKED | User decision + immutable generation/COW, atomic manifest publication, layer IDs, rollback/crash recovery, stale reader isolation, no live TFH/TFL overwrite; power-loss separately. Legacy editable terrain still full Float32 RAM. |
| P1.5.4b CPU benchmark | CI_VERIFIED | A/B/C resident comparison DONE, decision still experimental. |
| P1.5.4c streaming trace | CI_VERIFIED | 12 fixed async pump traces; actual frame/Android still open. |
| P1.5.4d allocation/topology experiment | NEXT | Isolate one hot-loop improvement, exact parity and fixed-work benchmark. |
| P1.5.5 geometry worker | PLANNED | One bounded worker, immutable input and generation/LOD/neighbor identity, stale outputs discarded, pure arrays only; no SceneTree/Mesh/Physics on worker. Main-thread publication. |
| P1.5.6 GPU publication | PLANNED | Budgeted upload, reusable topology/material only if measured, near priority, bounded VRAM, draw calls/triangles and GPU separately measured. |
| P1.5.7 physics | PLANNED | Actual physics-tick raycast parity/collision coverage, coherent mesh/shape generation, near priority, last-good, fast crossing/teleport, no flat fallback. |
| P1.5.8 predictive prefetch | PLANNED | EWMA motion, bounded lookahead and work/byte caps, compare fixed trace vs current; avoid pin eviction and wasted IO. |
| P1.5.9 adaptive budgets | PLANNED | User presets, hysteresis/cooldown, near geometry and collision first; frame budget validation, no precision compromise. |
| P1.5.10 device gates | PLANNED / DEVICE_OPEN | Same renderer/resolution/map/trace/settings, ABBA/repeats, 30min soak, frame p95/p99, RSS trend, actual physics, GPU/thermal where available, user visual acceptance. |
| Material painting / objects | PARKED | Explicit user go-ahead after terrain quality and performance readiness; not in this scope. |

## 4 — Her yeni oturumun zorunlu işlemleri
1. GitHub branch HEAD + latest CI sorgula; bu dosyayı, HANDOFF_START_HERE_TR.md ve NEXT_SESSION_IMPLEMENTATION_TR.md oku; eski tarihsel satırları güncel talimat sanma.
2. Açık EXP kayıtlarını kontrol et. Bir fazı ilerletmek diğer açık borçları kapatmaz. Yeni deney için ID, default/opt-in, referans kod, risk, kanıt, ölçüm ve revisit fazı ekle.
3. Önce mevcut kodu oku. Sadece addon branch, atomic commit/CAS, no force, no main/user data writes. Hedefli test + tam Godot 4.7.2 CI; failure varsa düzelt veya açıkça raporla. Headless PASS != Android PASS.
4. Sonuçta hangi metrik gerçekten ölçüldü, hangisi varsayım, test sayısı/commit/run, geri dönüş ve sonraki iş yaz. Bu dosyayı ve ilgili handoff/roadmap/status/quality belgelerini güncelle. Deneyi kabul/reddetmeden önce kanıt ve gerekçe ekle; geçmişi silme.
5. Kullanıcı yeni sohbette sadece “Devam” derse en son NEXT işini yap; EXP kayıtlarını tekrar unutma. Kullanıcı önceki bir deneyi test etmeyi isterse ilgili ID'den devam et.
 
## 5 — Karar tarihçesi (append-only)
- 24 Kasım 2026: Kullanıcı deneysel optimizasyonları ve önceki geliştirmeleri unutmayacak ayrı MD kayıt istedi. EXP-01 opt-in kaldı, A/B/C kıyaslaması next; EXP-02..07 ve P1.4/P1.5.5..10 açık. Bu commit doküman-only; yeni test/benchmark çalıştırılmadı.
 
- 24 Kasım 2026: P1.5.4b A/B/C resident benchmark 36/36 CI, B promising, no acceptance/default change. Next trace P1.5.4c.

- 24 Kasım 2026: P1.5.4c fixed trace 37/37, B promising, C explicit opt-in, no Android acceptance. P1.5.4d next; all older open gates preserved.

### Yeni kayıt şablonu
ID / tarih / faz:
Durum / varsayılan / geri dönüş:
Kod ve test kanıtı (commit + run + cihaz/ortam):
Ölçülen değer ve birim / ölçülmeyen:
Risk / açık borç:
Tekrar ele alınacağı faz ve kabul şartı:
Karar ve gerekçe:
