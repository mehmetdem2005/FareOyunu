# TerraForge — CI, Test Matrisi, Android Performans ve Kalite Kapısı

**Tarih:** 2026-11-24. **Baz kod:** v0.4.3-dev.2, `bf5c1dde57cf4f56a08b606b03c89270d09599c2`. **Son doğrulanmış run:** [GitHub Actions 45415690507, 25/25 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507).

## A. GitHub CI gerçek kapsamı

Workflow: `.github/workflows/terraforge-ci.yml`. Sadece `feat/terraforge-mobile-addon` dalında `addons/terra_forge/**` değişince otomatik; `workflow_dispatch` da var. Ubuntu 24.04 runner, Godot **4.7.2-stable**, geçici isolated `project.godot`, script import/parse, headless EditorPlugin startup, sonra her script.

Test çalıştırıcı: `addons/terra_forge/tests/run_all.sh`. Her test logu, exit code + explicit `PASS:` + Godot engine Error/Parse Error analizi; beklenen özel veri koruma hata satırları kontrollü olarak filtrelenir. Özet ve log artifact Actions içinde. Bu **Android build, Vulkan/OpenGL sürücü testi, gerçek GPU p95 FPS testi** değildir.

### Mevcut 25 test ve neyi kanıtladıkları

| # | Dosya | Kapsanan davranış |
|---:|---|---|
| 1 | `test_height_store.gd` | TFH1 Float32 initialize, serialize/deserialize ve height invariants |
| 2 | `test_data_safety.gd` | Eksik bağlı TFH read-only; yeni sahne explicit create ve dosyanın tekrar açılması |
| 3 | `test_height_layers.gd` | Sparse additive Float32 layers, görünürlük, opacity, kaydet/aç ve bozuk veri reddi |
| 4 | `test_live_layers.gd` | Katmanlar canlı brush, per-layer Undo/Redo, visible composite, TFH byte dokunulmazlığı |
| 5 | `test_layer_scene_roundtrip.gd` | Godot PackedScene içinde layer_mode + layer_file ve yeniden açma |
| 6 | `test_layer_integrity.gd` | TFL2 SHA, önceki sağlam .bak, manuel Restore, TFL1 geriye uyum, bozuk primary koruması |
| 7 | `test_region_store.gd` | TFR1 32×32 tek sahip örnek, LRU, dirty writeback, SHA, restart, eksik/bozuk page |
| 8 | `test_region_export.gd` | TFH/TFL1/TFL2 staged export, Float32 seam equivalence, TFM1 SHA, bozuk/eksik region, kaynağa dokunmama |
| 9 | `test_lod_policy.gd` | LOD policy, tile candidate seçimi ve sınırlar |
| 10 | `test_surface_faces.gd` | Triangle face/winding ve görünür yüzey geometrisi |
| 11 | `test_lod_normals.gd` | LOD0/1/2 analitik eğim normali |
| 12 | `test_lod_seams.gd` | Komşu LOD yükseklik seam davranışı |
| 13 | `test_edge_normals.gd` | Aynı LOD komşu tile için kenar normal eşitliği |
| 14 | `test_stream_budget.gd` | Tile hazırlama queue, tile sayısı ve budget |
| 15 | `test_brush_sampling.gd` | Seyrek/sık stroke inputta benzer yükseklik etkisi, Undo/Redo |
| 16 | `test_offtree_transform.gd` | Headless off-tree brush koordinat dönüşümü hatası üretmeme |
| 17 | `test_advanced_brushes.gd` | Ridge/Valley/Ramp/Stamp şekillendirme ve Undo/Redo |
| 18 | `test_geomorphology.gd` | Ridge/Valley süreklilik, Weather kütle aktarımı ve sabit miktar |
| 19 | `test_shape_quality.gd` | Organic Stamp, scan-independent Smooth, LOD hysteresis, dirty tile halo |
| 20 | `test_drainage_analysis.gd` | Priority-flood depression fill, MFD, flat/downhill flow, rainfall mass balance |
| 21 | `test_paged_height_source.gd` | TFM1/TFR1 SHA, Float32 sınır/bilinear, LRU, bozulmuş/eksik source, TFL2 immutable composite |
| 22 | `test_camera_page_prefetch.gd` | Kamera öncelik, read/tick, generation cancel, 80 konumlu trace, fail-closed corruption |

| 23 | `test_async_page_io.gd` | Gerçek Thread/Mutex/Semaphore, bounded jobs, Float32 cross-page, stale generation drop, missing/corrupt page, close/join ve source immutability |

| 24 | `test_paged_terrain_preview.gd` | Gerçek opt-in TFR1 → ArrayMesh + HeightMapShape3D; legacy LOD0/1/2 vertices/normals/collision parity, mixed LOD seam, bozuk sayfa fail-closed, kaynak dokunulmazlığı |

| 25 | `test_paged_camera_stress.gd` | 9-page cache + 2 outstanding IO, büyük kamera teleport generation cancellation, origin stale mesh unload, LOD0 HeightMapShape3D oluşturma, TFH SHA değişmezlik |

**Doğrulanmış:** 25 testin tümü `bf5c1dde` commit'i için geçti. [GitHub Actions](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507). Yeni dokümantasyon commit'i kod değişikliği yapmazsa 25 testlik kod sonucu aynı referans kalır; Actions otomatik yeni run başlatmışsa ayrı kaydedilmelidir.

**CI'da YOK / GERÇEK CİHAZ BEKLİYOR:** 3D editörde gerçek Android finger/tap, Mobile renderer görüntüsü, telefon GPU driver, shader upload, uzun süreli RAM/VRAM leak, fizik adımı, termal throttling, kalıcı depolama izinleri ve kullanıcı ekranı.

## B. Yeni test ekleme standardı

- Yeni özelliği izole modülde uygula; `tests/test_*.gd` dosyasında başarılı olunca `print("PASS: ...")`, hata olunca push_error + nonzero quit.
- `tests/run_all.sh` içine ekle; runner suite sayısı gerçek test sayısına eşit olsun.
- `.github/workflows/terraforge-ci.yml` script import/EditorPlugin startup testini kaldırma.
- CI run job logunu aç, **total fails 0** görmeden başarılı deme. Beklenen hata mesajını sadece ilgili testte filtrele; bütün `ERROR:` satırlarını globally gizleme.
- SHA, run URL, test sayısı, yeni risk ve rollback'i `STATUS_AND_CHANGELOG_TR.md` dosyasına kaydet.
- P1.3b kamera/cache stres regresyonu ile toplam **25 test**. Android gerçek render/performans ayrı zorunlu doğrulama; sonraki kod değişikliği 24 testin hepsini koruyacak.

## C. Teknik doğruluk kabul kapıları

| Alan | Asgari kabul | Son durum |
|---|---|---|
| TFH/TFL veri doğruluğu | Byte-özdeş eski kaynak, Float32 roundtrip, eksik dosya locked | CI PASS / Android bekliyor |
| Katmanlar | Görünürlük, Undo/Redo, scene reopen, max layer sınırı, backup | CI PASS / Android bekliyor |
| TFR1 world snapshot | Sınır örneği = tek sahip, tüm dosya/manifest SHA, output-overwrite reddi | CI PASS / canlı yok |
| Paged sampler | Bilinear cross-page, cache limit, bozuk page fail closed, 1–64 limit | **İZOLE CI PASS** / canlıya bağlı değil |
| Worker-thread IO | Mutex/Semaphore, job cap 1–8, stale generation, SHA buffer, join/close | **İZOLE CI PASS** / Android profili yok |
| Opt-in ayrı regional mesh + collision preview | Legacy parity LOD0/1/2, mixed LOD, fail-closed corruption | **İZOLE CI PASS** / Android onayı yok |
| Legacy live node'un gerçek regional HeightSource'a geçirilmesi | Varsayılan eski yol, opt-in migration, page halo, main-thread mesh commit | **PLAN** |
| Live collision | Görsel height ile yüzey hata toleransı altında eşit, boş collision yok | **PLAN** |
| LOD0↔LOD1↔LOD2 | Görünür yarık, gap, checkerboard skirt, yanlış normal, popping yok | Headless kısmi / Android QA bekliyor |
| Sculpt sampling | Slow vs fast drag aynı fiziksel yol üzerinde tutarlı derinlik, crash/undo yok | Headless kısmi / Android QA bekliyor |
| Hidrolojik süreç | NaN yok, kütle dengesi ve gerçek drenaj bağlantıları | Yalnız lokal analiz CI PASS |
| Ekran ergonomisi | Terrain popup kapalıyken 3D viewport kullanılabilir, dev dock yok | Telefon son sürüm QA bekliyor |
| 30 dk dayanıklılık | Memory monotonic growth yok, crash yok, veri geri açılıyor | DEVICE PENDING |

## D. Android 11 sahasında standart test senaryosu

**Aynı test koşulları:** telefonda aynı pil/ısınma başlangıcı; aynı world, quality profile, camera rota, viewport ölçeği, renderer ve sensör/kayıt yöntemi. Warm-up ile ölçüm ayrı. Önerilen kayıt: minimum 5 dakika baseline, 30 dakika stability.

1. **Başlatma / UI:** Godot 4.7.2 Android projesini aç, plugin etkin, yanlış `res://addons/.../res://...` path hatası yok, kompakt Terrain popup alt dock yerine görünüyor. Popup telefon ekranına sığıyor.
2. **Terrain geometri:** 256×256 flat yeni test world; editörde yüzey solid ve üstten/alttan doğru; kamera dış köşelere; LOD tile resident/pending değişiyor.
3. **Fırçalar:** 9 aracı test et. Ridge/Valley şekil aralıkları, Ramp rise pozitif/negatif, Organic Hill/Crater/Mesa, Weather dik vs düz alan.
4. **Touch:** bir dokunuş iki kere sculpt yapmamalı, mouse-synth guard; hızlı sürükleme vs yavaş sürükleme; bir pinch/kamera hareketi yanlış sculpt başlatmamalı.
5. **LOD seam:** yakın-orta-uzak geçiş, kamerayla ~72/144m sınır geçişi; zorlu sırt/çukur/kenar ve LOD0/1/2 karışımlarında gri dik duvar/gap/normal şerit yok.
6. **Mesh/collision:** fare karakter kapsülünün/yer testinin zemine batmaması, LOD değişiminde collision tutarlı; görünür mesh collision arasındaki height farkını ölç.
7. **Layer:** TFH yedeğini koru; Enable Layers, farklı iki layer, On toggle, Undo/Redo, Save, scene Save, kapanıp açma.
8. **Recovery:** yalnız kopya test dünyasında sahte bozuk TFL; read-only; Restore önceki bak; .corrupt_* korunuyor. Kullanıcının asıl haritasını bozma.
9. **Disk streaming (gelecek):** 10× hızlı uzun kamera rota, 200–1000 page load, resident count limite uyma, bozuk page fail closed, cancellation ve no UI freeze.
10. **Stres:** 30 dk farklı quality profil, hızlı kamera, üst üste brush; kullanıcı veri yeniden açınca kayıt kaybı yok; RAM ve GPU reset/driver crash yok.

## E. Ölçümler ve gerçekçi başlangıç hedefleri

**Bunlar ölçülmüş sonuç değil, hedef/karşılaştırma noktalarıdır.**

| Metri̇k | Hedef / ölçüm şekli |
|---|---|
| FPS/frame time | 30 FPS sınıfında frame 33.33ms; önceki kriter p95 ≤33.3ms, p99 ≤50ms. Bu salt hedef ve sahneye göre yeniden ele alınır |
| 60 FPS sınıfı | 16.67ms frame; hedefe ulaşma garantisi yok |
| RAM | Resident height page sayısı ×4096 byte **ham veri**; gerçek RSS/peak ve Godot Node/Dictionary overhead ayrı |
| CPU build | `Mesh last/max ms`; tek tile CPU budget aşabilir; p95 frame farklı metriktir |
| Sculpt/Drain | `Sculpt last/max ms`, `Terrain > Check` Float32/Path/Weather/Shape/Drain/Layers CPU süreleri |
| GPU | Renderer GPU frame time, drawcalls, vertex sayısı, upload/reallocation ve VRAM; CI headless bunu ölçmez |
| IO | Cached vs cold page load latency, hash verify latency, page read/write totals, flush spike |
| Paged streaming | 4/8/16/32 cache limit kıyası, hit ratio, resident sample bytes ve gerçek RSS |
| Dayanıklılık | 30 dk boyunca RAM sürekli artış eğimi, telefon aşırı ısınma/thermal throttle, scene reload ve CRC |
| Visual | Ground-level before/after, saçma dairesel tekrar, soluk düz relief, LOD seam parlaması yok |

**En önemli karar:** “Performans arttı” demek için aynı sahne ve rota üzerinde karşılaştırmalı gerçek ölçüm veya en azından ayrıntılı CPU/GPU profili gerekir. Tile sayısını azaltmak otomatik toplam GPU performans iyileşmesi değildir.

## F. Başarı/başarısızlık kayıt şablonu

Her GitHub PR/commit sonrası burada veya STATUS belgesinde:
- Commit SHA / version / çalıştırılmış run URL ve sonucu.
- 23 + yeni test adı ve PASS/FAIL; CI raw logs varsa nerede.
- Dönüşümde kaynak SHA değişti mi, yeni dosyalar doğrulandı mı?
- Test platformu: Linux headless mı Android gerçek mi?
- Görsel/kare süreleri varsa cihaz modeli, Android sürümü, renderer, quality profile, kamera ve test world.
- Açık regresyonlar, known limit, önceki çalışan commit'e rollback.
- **Bu bilgiler olmadan “profesyonel / optimize / tam kararlı” ibaresi kullanılmaz.**

İlgili belgeler: [QUALITY_GATE.md](QUALITY_GATE.md), [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md), [RISKS_AND_DECISIONS_TR.md](RISKS_AND_DECISIONS_TR.md).
