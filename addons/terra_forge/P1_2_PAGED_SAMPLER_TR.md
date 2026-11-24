# P1.2 — Doğrulanmış Sayfalı Float32 Kaynak ve Kamera Ön Yükleme Tasarımı

**24.11.2026** | İlk iki çekirdek görev **DONE / GitHub CI PASS 22/22** | Kod: `d51614777e37107dffd276593d12e55b134934c2`, `a214c907b6fba2d3cd7dba32f883ee5fad7ed446` | CI: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825

## 1. Ne gerçekten uygulandı?

- `core/paged_height_source.gd` — yalnız okuma için `TFM1` + `TFR1` Float32 yükseklik örnekleyicisi. `open(directory,cache_pages)` tüm dünya manifestini ve listedeki her sayfayı açılışta doğrular. Başarısızsa eski cache üzerinden veri sunmaz.
- `get_height(x,z)` tek örnek sahibi olan 32×32 region sayfasına gider. Dönen sözlük `{error:OK,height:value}`; hatada `height` anahtarı **yoktur**, sahte 0 döndürülmez.
- `sample_local(wx,wz)` noktanın etrafındaki dört örneği (sayfa sınırı geçebilir) alır, TFH1 ile aynı bilinear değerini hesaplar. Dünya dışı koordinatları **ERR_INVALID_PARAMETER** ile reddeder; legacy HeightStore bu durumda clamp yapıyordu. Bu fark ileride adaptörde açıkça ele alınmalı.
- `prefetch_rect(first,last,max_new_reads)` mevcut dikdörtgen işini cursor ile sürdürür; aynı çağrı tekrarlandığında başa dönmez, yeni dikdörtgende eski bekleyen sırasını bırakır.
- `release_outside(first,last)` yalnız RAM cache'i bırakır; dünya sayfalarını veya TFH/TFL'yi yazmaz. LRU ham Float32 cache limiti 1–64 sayfadır; metadata ve geçici yüklemeler bu rakamın dışında kalır.
- Cold page: manifestteki **tam dosya SHA-256**, TFR1 iç checksum/koordinat/dünya bilgisi ve yükleme sonrasında tekrar tam dosya SHA kontrol edilir. Hata olursa sağlam RAM cache'i yeni bozuk veriyle değiştirilmez.
- `stats()`: resident, limit, raw resident bytes, manifest entries, disk_reads, hits/misses, evictions, io_last/max_ms, manifest open verify süresi, prefetch generation.
- `core/camera_page_prefetch.gd` — `configure(reader,max_reads_per_tick)`, `request_focus(world_x,world_z,radius_pages,travel_direction)`, `tick()`, `release_distant()` ve `stats()`.
- Kamera planner en yakın bölgeye öncelik verir; aynı uzaklıktakilerde hareket yönünü ağırlıklar. Plan listesini cache kapasitesiyle sınırlar; her `tick` çağrısında en fazla 1–8 yeni sayfa okur. Kamera başka konuma sıçrarsa başlamamış sayfa istekleri yeni generation ile değiştirilir.

## 2. Gerçekte yapılmayanlar

- **Asenkron IO / background thread yok.** `tick()` senkron dosya okur. Bir TFR1 sayfasının doğrulanması bile yavaş flash depolamada kare süresini aşabilir. “2 sayfa/frame” bir süre garantisi değildir.
- **Canlı kamera Node / MeshInstance / collision bağlantısı yok.** `request_focus()` çağrısı bir test veya daha sonra yazılacak adaptör tarafından verilir, mevcut oyun kamera hareketine otomatik bağlanmaz.
- **Canlı RAM tasarrufu yok.** `terra_forge_terrain.gd` hâlâ `height_data.heights` ile tüm dünyayı belleğe alır. Yalnız izole sampler kendi sayfalarını sınırlı tutar.
- **Mutable regional sculpt, layer journal, çok-bölge manifest transaction yok.** TFM1 snapshot read-only olarak korunur.
- Full manifest açılışında **tüm sayfalar** sırayla SHA/doğrulama için diskten okunur. Tam world grid RAM'de tutulmasa da büyük dünyada startup süresi maliyeti olabilir.
- `get_height()` cache hit sonrası dosyanın her erişimde tekrar hashlenmesi yerine bellekte önceden doğrulanmış height sunar. Ancak sayfa cache'den çıkarılıp tekrar okunduğunda disk bütünlüğü yeniden kontrol edilir.
- Resident raw height bytes = sayfa sayısı ×4096; `Dictionary`, manifest SHA listesi, GDScript, Godot, dosya hash ve IO tamponları bu sayının dışında. `P1.2` sonunda Android gerçek RAM ölçümü halen gereklidir.

## 3. CI testleri

- `tests/test_paged_height_source.gd` (21. test): 96×64 TFH örnekleri ve TFL2 visible composite, 0/31/32/33/63/64 ve outer edge Float32 sample equality, cross-page bilinear, 1–2 page resident limit, incremental prefetch budget, bozulma/eksik sayfa, .tmp, kaynak byte özdeşliği.
- `tests/test_camera_page_prefetch.gd` (22. test): yakın sayfa önceliği, 1 read/tick sınırı, camera teleport generation cancellation, 80 farklı kamera odağı, resident raw bytes üst sınırı, bozuk soğuk sayfanın fail-closed hatası.
- GitHub Actions gerçek sonucu: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825 — **22/22 PASS**, Godot 4.7.2 ubuntu-24.04 headless. Android GPU ve dokunmatik testi değildir.

## Güncelleme 0.4.2-dev.2 — P1.2b asenkron worker artık UYGULANDI

İlk iki modülün 22/22 testlik tarihsel kaydı bu belgede korunmuştur. Daha sonraki asenkron worker geliştirmesi `core/async_region_source.gd` ve `camera_page_prefetch.configure_async()` ile **tamamlandı**; gerçek Thread/Mutex/Semaphore, bounded job queue, generation result cancellation, tek-buffer SHA. `tests/test_async_page_io.gd` ile [Godot CI 23/23 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313). Bu yeni davranışın otorite belgesi: [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md). **Sıradaki aktif iş P1.3 opt-in read-only terrain mesh/collision adaptörü.** Aşağıdaki bölüm artık tarihsel ilk P1.2 planıdır.

## 4. Tarihsel plan — Sıradaki zorunlu teknik iş

**P1.2b: Bounded, thread-safe asynchronous page IO and camera queue.**

1. Veri işi ile UI/scene işini ayır: worker sadece dosya buffer, checksum, Float32 parser; MeshInstance3D/StaticBody3D/SceneTree ana thread.
2. CPU/IO tick budget, en fazla bekleyen job ve resident cache; iş bitse bile önceki generation ise sonucu kullanma.
3. Başarısız/timeout page için fail-closed error ve durum cache'i; aynı bozuk sayfayı her kare yeniden isteme.
4. Startup'ta tüm world'ü senkron doğrulama maliyeti için kontrollü manifest-first / lazy-validation protokolü tasarla; bunu yaparken eksik world'ün yanlış “başarılı” görünmesini engelle.
5. Stres CI: kamera zıplama/restart/race, page header/hash değiştirme, aynı anda dispose/reopen, overload, deterministik öncelik.
6. **Ardından** P1.3 test sahnesinde opt-in read-only mesh + collision sampler adaptasyonu. Fırçalar transaction kurulmadan region mode'da KAPALI.

## 5. Geçiş sözleşmesi

Eski `.tfh`, `.tfl` ve `.bak` kullanıcı verileri aynen tutulur. Branch dışı oyun dosyaları değiştirilmez. Görev tamamlandı sayılabilmesi için kod commit + en az 23/23 CI PASS + gerçek run URL ve belgelere yeni durum kaydı gerekir. Android ölçümü yapılmadan “tam optimize” denmez.

Bkz. [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md), [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md), [ENGINE_ARCHITECTURE_TR.md](ENGINE_ARCHITECTURE_TR.md), [QUALITY_TESTS_AND_BENCHMARKS_TR.md](QUALITY_TESTS_AND_BENCHMARKS_TR.md).
