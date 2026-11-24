# TerraForge v0.4.2-dev.2 — Asenkron TFR1 sayfa okuma (P1.2b)

**Durum:** UYGULANDI / Godot 4.7.2 GitHub CI **23/23 PASS**.  
**Kod commitleri:** `f7b3413da2d571ce5bb3d0f7c0eabdc971e8a337`, `4d5ed1bdce11727f5bc129087432198956ff2ce5`.  
**Son doğrulanmış run:** https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313  
**Korunan dal:** `feat/terraforge-mobile-addon` — `main`, oyun sahneleri, `terraforge_data/`, TFH/TFL/TFL.bak dosyaları değiştirilmedi.

## Ne yaptık? Kullanıcının anlayacağı açıklama

Eski P1.2 prototipinde kamera her yeni arazi parçasını diskten **ana thread'de** okuyordu. Okuma maliyeti tek kareyi aşabilirdi. Yeni tasarım, veri işini **ayrı bir Godot Thread** üzerine alır; o thread yalnız TFR1 dosyasını okur ve doğrular. Oyun/editor ana thread'i yalnız bitmiş küçük Float32 sayfaları kabul eder. Kamera başka bir yere sıçradığında önceki nesilden gelen sonuçlar cache'e sokulmaz. Bu, oyunun kameraya bağlandığı anlamına **gelmez**; altyapının izole testi tamamlandı.

## Yeni / değişen dosyalar

- `core/async_region_source.gd`: `Thread`, `Mutex`, `Semaphore` ile **bir** disk okuyucu işçi; main-owned Float32 cache, bounded pending/inflight/finished job list, generation ID.
- `core/camera_page_prefetch.gd`: eski `configure(reader)` senkron yolunu aynen korur. Yeni opt-in `configure_async(async_reader)` ve `_tick_async` branch'i sayesinde `tick()` diskten doğrudan sayfa okumaz; yalnız worker sonuçlarını kabul edip yeni işleri sıraya koyar.
- `tests/test_async_page_io.gd`: worker thread gerçekten başlar, çok bölge Float32 ve bilinear eşitlik, 1–2 job limit, ana thread poll, kamera generation iptali, eski sonuç reddi, 96×96 dış köşe, bozulmuş/eksik sayfa, kapanış ve reopen fail-closed; test kaynaklarının değişmemesi.
- `tests/run_all.sh`: 23. test eklendi. Linux Godot 4.7.2 GitHub CI 23/23 PASS.

## Worker API ve sözleşmeler

`ASYNC = preload("res://addons/terra_forge/core/async_region_source.gd")`

1. `open(directory, resident_limit=4, max_jobs=3) -> Error`: **tam TFM1 manifest + tüm TFR1 dosya doğrulaması ana thread'de SENKRON** yapılır, sonra bir düşük öncelikli worker başlar. Bu başlangıç süresini hâlâ kısaltmaz.
2. `request_page(key) -> Error`: main thread; cache hit OK, önceden kuyruğa alınan OK, yeni bounded istek OK, dolu kuyruk **ERR_BUSY**, bozuk page için kaydedilen gerçek hata. Worker'a iletilen job tamamen değerlerden oluşur: path, SHA, dünya boyutu, spacing, koordinat ve generation.
3. `_worker_loop()`: yalnız `Semaphore.wait()`, `Mutex` ile korunmuş queue ve `_read_page_file(job)` çağırır; main terrain objelerine dokunmaz.
4. `_read_page_file(job)`: TFR1 dosyasını tek FileAccess handle'dan **tek buffer snapshot** olarak okur; aynı `PackedByteArray` üzerinde dosyanın tamamının manifest SHA-256'sı ve internal TFR1 SHA-256'sı doğrulanır; world cells, key, spacing, finite Float32 doğrulanır; immutable sonuç paketi ana thread'e teslim edilir. Böylece üç ayrı diski okuma/yeniden hashleme arasındaki TOCTOU boşluğu azaltılır.
5. `poll_results(max_results=3)`: yalnız ana thread; geçerli generation sonucunu bounded cache'e yerleştirir. Eski nesilden gelen sonuç bırakılır. Hatalar `_errors` içinde hatayla tutulur; aynı generation içinde sonsuz tekrar denemesi yapılmaz.
6. `get_height(x,z)`, `sample_local(wx,wz)`: **disk okumaz**. İstenen sayfa henüz bitmediyse `ERR_BUSY`; başka hata varsa `ERR_FILE_CORRUPT / ERR_FILE_NOT_FOUND`. Başarısızlık sözlüklerinde hiçbir sahte `height:0` alanı bulunmaz. Bilinear için dört komşu sayfa resident olmak zorundadır.
7. `set_generation(next_id)`: pending ve bitmiş (ama henüz kabul edilmemiş) eski nesil işlerini atar. O anda worker içinde başlamış IO bitene kadar sürebilir; ama sonucu yeni nesil için **kabul edilmez**.
8. `release_outside(first,last)`: yalnız ana thread cache'i bırakır, dosyaya yazmaz.
9. `stats()`: resident, ham Float32 byte, pending/inflight/finished, max_jobs, generation, disk_reads, stale result, cache hit/evict, worker errors, io last/max ms ve open_verify_ms.
10. `close()`: kapanış sinyali + `Semaphore.post()` + `Thread.wait_to_finish()` ile join. **Bir in-flight dosya okuması bitene kadar close() engelleyebilir.** Her karede çağırma; adaptör nesne kullanım sonu explicit kapatmalıdır.

**Sınırlar:** max resident 1–64 sayfa; max outstanding jobs 1–8; aynı anda **tek** worker. Ana thread cache ve thread queue ayrıdır. Ham cache maksimum `resident_limit × 4096 byte`; in-flight/finished veri, hash buffer, JSON manifest, Godot overhead buna **dahil değildir**.

## CI kapsamı ve kanıt

- `test_async_page_io.gd`: eski 22 regresyon korunarak 23. test eklendi. İkinci test commit'i, cold in-flight job tamamlanmadan generation değiştirme, yeni sayfa önceliği, deleted TFR1 fail-closed, worker join while pending senaryolarını ayrıca kapsar.
- Resmî Godot Thread/Mutex/Semaphore ve thread-safe API ilkeleri doğrulandı: https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html ve https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html .
- **GitHub Actions:** https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313 — **23/23 PASS**, Godot 4.7.2 Linux headless. Bu, Android 11 GPU, touch, zaman sıçraması ve gerçek telefon benchmark'ı değildir.

## v0.4.4-dev.1 geçiş notu — manifest-first hızlı açılış

Bu belge **P1.2b tarihsel implementasyonunu** anlatır. Artık `async_region_source.open(directory,resident_limit,max_jobs,verify_all_pages=true)` şeklinde opsiyonel dördüncü parametre vardır. Varsayılan strict mod bu sayfadaki ilk davranışı korur; yeni `false` mod checksummed TFM1 ile hemen açar, her TFR1 cold IO'da hashlenir. Yeni readonly preview bunu varsayılan seçer. [26/26 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664). Ayrıntı [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).

## Bilinen açık riskler

- `open()` tüm sayfaları senkron doğrular; dev dünya startup latency. Gelecek iş: startup manifest-first ve aşamalı doğrulama **fail-closed** semantiğini bozmadan tasarla (yapılmış değil).
- Bir `poll_results` çağrısı cache ve küçük Float32 kopyalarla çalışır; GPU/NODE işlemez. **Gerçek p95/p99 FPS kazancı ölçülmedi**.
- `close()` in-flight IO'yu kesemez, worker işini bitirir. Android yavaş/buzulmuş depolama durumunda ana thread join stall riskini değerlendirmek gerekir.
- `camera_page_prefetch.gd` eski senkron API halen kullanılabilir. Asenkron yol açıkça `configure_async` ile seçilir.
- **En önemlisi:** Canlı `terrain/terra_forge_terrain.gd` hâlâ `height_data.heights` global Float32 dizisini kullanıyor. Yeni modüller **izole**; oyun sahnesi RAM/FPS hâlâ eski şekilde.
- TFR1/TFM1 immutable snapshot; **çok-sayfalı atomic write transaction henüz YOK**. Region sculpt/Undo/Redo açma. Eksik sayfayı 0 yüksekliğe dönüştürme.

## P1.3 ilerleme güncellemesi (v0.4.3-dev.1, tarihsel planı geçersiz kılar)

Aşağıdaki P1.3 ilk planındaki **izole mesh/normal/collision + editör kamera entegrasyonu UYGULANDI**: `paged_tile_geometry.gd`, `paged_terrain_preview.gd` ve `plugin.gd`; Godot CI [24/24 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421). Eski `TerraForgeTerrain` otomatik değişmedi, P1.3 Android kalite kapısı açık. Güncel kaynak: [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## Sıradaki iş — P1.3 (TARİHSEL PLAN)

1. `terrain/terra_forge_terrain.gd` içinde height_data.heights/read doğrudan erişim envanteri.
2. Varsayılan eski TFH/TFL kaynağını koruyarak yeni `HeightSource` read-only adapter prototipi.
3. Gerçek sahnenin **ayrı opt-in test kipi** için mesh/LOD/normals/HeightMapShape3D collision sayfaları; Brush disable.
4. Kamera world-to-region address, prefetch halo, async completion main-thread mesh commit; eksik page = tile eski geometriyi tutar veya hata, sıfır y terrain yaratmaz.
5. Legacy vs paged Float32 vertex, border normals, collision testlerini GitHub CI'a ekle; Android gerçek test bekleyen olarak işaretle.
6. Sonraki aşama P1.4 atomik multi-page/manifest transaction ve tahribatsız layer entegrasyonu.

Bir sonraki sohbette [HANDOFF_START_HERE_TR.md](HANDOFF_START_HERE_TR.md), [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md), [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md) ve bu dosyayı oku. Hedef hâlâ **yalnız terrain**, boyama ve obje yerleştirme değil.
