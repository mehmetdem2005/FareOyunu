# TerraForge P1.5 — Manifest-First Açılış ve Sayfa Bazında Float32 Doğrulama

**Tarih:** 24 Kasım 2026 · **Hedef sürüm:** `v0.4.4-dev.1` · **Dal:** `feat/terraforge-mobile-addon`  
**Kod commit'leri:** `a582c8625b1c3ba8074ee4bff15f0ab8ed857830`, `73603a15361766397854d11bad44ecb41e9bd53e`.  
**Başarılı 26/26 Godot CI:** https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664

## 1. Kullanıcı açısından ne değişti?

Önceki opt-in TFR1 önizlemesi, `async_region_source.open()` çağrısında bütün harita bölgelerini senkron okuyup SHA ile doğruluyordu; küçük bir haritada sorun değildi fakat 10.000 parçalı dünyada **kamera daha tek tile göstermeden her dosya baştan sona okunuyordu**.

Yeni modda `manifest.tfm` dosyasının **checksum'u, TFM1 şeması, boyutları ve sayfa SHA listesi** açılışta doğrulanıyor. Dünya manifestinin kendisi 2 MiB üst sınırına tabi. Ama her TFR1 dosyasını bu aşamada açmak gerekmez. Kamera hangi sayfayı isterse mevcut düşük öncelikli worker Thread onu **tek byte snapshot** üzerinden full-file SHA, internal TFR1 checksum, page koordinatları, Float32 finite değerler ve spacing ile doğrular. Doğrulanmadan mesh veya çarpışma yapılamaz.

Bu, mevcut editable `TerraForgeTerrain` yerine geçirilmedi. **Yalnız ayrı ve açıkça seçilmiş READ-ONLY preview** bu modun varsayılan tüketicisidir.

## 2. Eski sözleşme aynen korunur

`core/async_region_source.gd`:

- `open(directory, resident_limit=4, max_jobs=3, verify_all_pages=true)` — **Varsayılan STRICT**. Eski tüm çağrılar eskisi gibi her TFR1 dosyasının SHA'sını ve internal verisini açılışta kontrol eder; silik/bozuk dosya yüzünden açılmaz.
- `open(directory, resident_limit, max_jobs, false)` — **Yeni ON-DEMAND**. İlk açılışta yalnız TFM1 checksum + şema doğrulanır. Dünyanın uzak eksik/bozuk bir sayfası başlangıçta anlaşılmayabilir; sadece oraya gidildiğinde dosya hatası görünür.
- Worker `request_page(key)`, `poll_results()`, `get_height()` ve `sample_local()` — yalnız doğrulanmış resident Float32 değer sunar. Hazır olmayan sayfa `ERR_BUSY`, silik sayfa `ERR_FILE_NOT_FOUND`, değiştirilmiş sayfa `ERR_FILE_CORRUPT`. **Hiçbir hatada `height=0` uydurulmaz.**
- `stats()`: `verification_mode: strict/on_demand`, `verified_at_open`, `manifest_entries`, `pages_verified_on_demand`, `open_verify_ms`, bunlara ek eski cache/io/thread sayaçları. `pages_verified_on_demand`, bir kez başarıyla soğuk okunan farklı sayfa sayısıdır; **şu anda hâlâ sağlam olduğunu sürekli yeniden kanıtlamaz**. Cache'den çıktıktan sonraki yüklemede SHA kontrolü yeniden yapılır.
- Kamera generation değişiminde eski kuyruğa alınmış veya geç tamamlanmış sayfa sonuçları iptal edilir. RAM sayfa sınırları, 1–8 job limiti, immutable snapshot ve explicit worker `close()` değişmedi.

`terrain/paged_terrain_preview.gd`:

- Inspector'da **`verify_pages_on_demand = true` varsayılan**. Yalnız bu ayrı salt okunur preview'da dev dünya açılışı için kullanılır.
- `false` yaparsan eski açılış davranışına dönülür; uzak bozuk/missing sayfa yüzünden preview hiç başlamaz.
- Bu ayar, mevcut kaynak TFH/TFL dosyalarını veya `main` branch'ini değiştirmez.
- `plugin.gd` kompakt popup doğrulama durumunu **READ-ONLY ON-DEMAND / FULL** gösterir; kaç farklı sayfanın doğrulandığını ve toplam manifest sayfasını bildirir.

## 3. Güvenlikte ince ama önemli fark

**Manifest-only open, “bütün harita doğrulandı” anlamına GELMEZ.** Tam world kapsamlı kontrolü hız uğruna erteliyoruz; bir sayfa istenene kadar varlığı/sağlamlığı bilinmez. Ancak istenen veri işçi thread'de hash doğrulanmadan mesh/collision'a sokulmaz. Yakın sağlıklı arazi, uzaktaki hasarlı parça yüzünden başlangıçta kilitlenmez. Hasarlı parça kendi konumunda hata durumuna geçer; sahte y=0 arazi yok.

Manifest dosyasındaki SHA-256 **bozulma bütünlüğü kontrolüdür, kriptografik imza/kimlik doğrulaması değildir**. Bir saldırgan manifest ve tüm veriyi birlikte değiştirebiliyorsa bu sistem bunu şifreli bir imza gibi engellemez. Bu sürüm yalnız immutable lokal snapshot için tasarlanmıştır.

## 4. Kanıtlanan testler ve bilinen kaynak sızıntısı düzeltmesi

Yeni `tests/test_lazy_world_open.gd` ile toplam **26/26 PASS**:

- [x] Varsayılan `open()` ve explicit strict, uzak silik sayfayı *açılışta* reddeder.
- [x] ON-DEMAND manifest doğrulaması uzak silik dosyayı açılışta okumadan başarılıdır; ilk yakındaki Float32 örneği sadece gerçek worker SHA ile hazırdır.
- [x] `pages_verified_on_demand` ve `verification_mode` gerçek kapsamı yansıtır.
- [x] Salt okunur önizleme, uzak bir sayfa silik olsa da yakın sağlıklı bölge için gerçek mesh + LOD0 collision üretir.
- [x] Eksik/bozuk uzak parça cold load'da fail-closed; başarılı `height` uydurulmaz veya hatalı iş sonsuz tekrar edilmez.
- [x] Tam sayfa checksum değişimi strict startup'ta, lazy modda ilgili sayfa istendiğinde yakalanır.
- [x] Bozuk ve olmayan TFM1 manifesti her iki modda da **açılışta reddedilir**.
- [x] TFH authoritative kaynak SHA hiçbir test işlemiyle değişmez.
- [x] Test sahnesine eklenmemiş `@tool Node3D` için `preview.stop_preview()` + `free()` sırası zorunlu. İlk CI yalnız Godot exit resource-leak nedeniyle başarısızdı, testte thread join onarıldı; [son CI 26/26 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664). Başarısız CI: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45419683043.

## 5. Hâlâ yapılmayan işler ve riskler

- **Ölçülmüş Android 11 açılış süresi yok.** Manifest JSON ve metadata işlemesi ana thread'de senkron, üst sınır 2 MiB. TFR1 dosya taraması kaldırıldı; gerçek RSS ve p95/p99 kıyasını telefonda yapmak gerekli.
- Hızlı kamera hareketinde ihtiyaç duyulan TFR1 henüz doğrulanmamış olabilir; o tile **görünmeyebilir**. Çarpışma güvenliği için eski sağlam tile korunması / fallback davranışı ayrı saha testine muhtaç.
- `close()` tek in-flight IO dosyasının bitmesini `wait_to_finish` ile bekler; uzun depolama takılmaları test edilmedi.
- Mevcut **editable** `terrain/terra_forge_terrain.gd` tüm Float32 heightmap'i RAM'de tutar. Bu mod ona otomatik uygulanmadı. Bölgesel Brush/Undo/Redo transaction ve generation-pinned manifest geçişi P1.4 açık iştir.
- Büyük dünyada 10.000 manifest page limiti, 2 MiB manifest sınırı, gerçek telefon depolama throughput/RAM ve 30 dakikalık stress cihazda doğrulanmalı.
- Tam doğrulama strict modun mevcut güvenlik sözleşmesi korunur. Eksik/bozuk sayfa için hiçbir durumda otomatik create_blank_page veya orijinale overwrite yok.

## 6. Bir sonraki uygulanabilir mühendislik işi

**P1.3/P1.5 kalite:** Android gerçek FPS/RSS/ilk-açılış profili ve kamera/LOD seam güvenliği için test sahnesi ve ölçümler; mümkünse kayıpsız **eski sağlam mesh/çarpışmayı koruyan** kamera/sayfa failover politikası, CI regression. Ardından **P1.4** generation-based multi-page/manifest copy-on-write transaction ve salt okunur/kalemli mod ayrımı. Boyama ve obje yerleştirme yok.

Başlangıç rehberi [HANDOFF_START_HERE_TR.md](HANDOFF_START_HERE_TR.md), görev sırası [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md), tüm fazlar [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md), CI matris [QUALITY_TESTS_AND_BENCHMARKS_TR.md](QUALITY_TESTS_AND_BENCHMARKS_TR.md).
