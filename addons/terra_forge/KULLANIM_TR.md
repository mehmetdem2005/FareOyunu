# TerraForge Mobile 0.4.4-dev.1 — Türkçe kullanım
> **Yeni sohbette unutulmasın:** Önce [DOCS_INDEX_TR.md](DOCS_INDEX_TR.md) ve [HANDOFF_START_HERE_TR.md](HANDOFF_START_HERE_TR.md) oku. Sürüm geçmişi, P0–P7 tüm fazları, profesyonel terrain araştırması, mimari, CI kanıtları, riskler ve sıradaki uygulanabilir işler bu daldaki yeni MD dosyalarında kalıcı olarak kayıtlı.


## Kurulum (telefon / Godot 4.7.2)

1. ZIP arşivinden yalnızca `addons/terra_forge/` klasörünü çıkar.
2. Mevcut Godot projenin köküne, yani `project.godot` ile aynı dizinin altına `addons/terra_forge/` olarak kopyala. Eski eklentiyi önce yedekle veya kapat.
3. Godot'ta **Project → Project Settings → Plugins** menüsünden **TerraForge Mobile**'ı etkinleştir.
4. Bir 3D sahne aç; kök düğüm `Node3D` olsun.
5. Üst 3D araç çubuğundaki **Terrain** butonuna dokun. Açılan küçük menüden **+ New** ile arazi oluştur.
6. İlk arazi *bilerek düzdür*. Bu bir hata değildir: **Raise** ile yükselt, **Lower** ile alçalt, **Smooth** ile yumuşat, **Flatten** ile düzleştir.
7. **Terrain** menüsünden araç ve **Size / Power** değerlerini ayarla. Menüyü kapat. Üst çubuktaki **Brush** anahtarını açıp araziyi tek parmakla şekillendir. Kamerayı hareket ettirmek için **Brush** anahtarını kapat.
8. **Quality → Mobile** profilinde başla. Daha fazla ayrıntı gerektiğinde Balanced/High dene.
9. **Terrain → Save**, Float32 yükseklik verisini kaydeder. Ayrıca Godot'un normal **Scene → Save** seçeneğiyle sahneyi kaydet. *İkisi de gereklidir*.

## Yeni şekillendirme araçları (v0.3)

- **Ridge (Dağ sırtı):** Parmağı sürükleyerek bir hat çiz, **parmağını kaldırınca** arazinin üzerinde tek parça, organik sapmalı bir sırt oluşturulur. Art arda dairesel tepecik basılmaz.
- **Valley (Vadi):** Parmağını sürükleyip kaldırınca kesintisiz bir vadi oyar. Gerçek su havzası hesabı henüz yok.
- **Ramp (Eğimli yol):** Başlangıç noktasına dokun, bitiş noktasına sürükle, **parmağını kaldır**. O zaman eğimli koridor uygulanır. Seçince çıkan **Rise** ayarı başlangıçta **+5 m**; negatif değer iniş oluşturur. Tek seferde en fazla 256 m uzunluğunda ramp yapılır.
- **Stamp (Hazır şekil):** Tek dokunuşla **Hill** (tepe), **Crater** (krater) veya **Mesa** (plato) bas. Parmağı sürüklemek aynı dokunuşta ikinci stamp üretmez.
- **Weather (Termal aşınma):** Çok dik yamaçta tek dokunuşla aşınma işlemi başlat. **Steps** (1–6) işlem sayısını ayarlar; yukarıdaki gevşek malzeme aşağıya aktarılır. Su erozyonu veya tortu simülasyonu değildir.

Hepsinde **Size** etki alanını, **Power** etki şiddetini belirler. Ramp, Stamp ve Weather seçenekleri yalnız ilgili araç seçildiğinde açılır; kalıcı geniş panel yoktur. Undo ve Redo her fırça hareketinde kullanılabilir.

## Telefon üzerinde kalite kontrol

1. **Terrain > Quality: Mobile** seç.
2. Aynı küçük menüdeki **Check** düğmesine bas. Kod kendi geçici test verilerini kullanır; haritanı değiştirmez.
3. Ekranda `PASS` veya `FAIL` sonucunu, Float32, Path ve Weather işlem sürelerini gör.
4. `Mesh last/max ms` ve `Sculpt last/max ms` CPU süreleridir, toplam GPU maliyeti değildir.
5. Ardından 30 dakika çizim, LOD, dosya aç-kapat, belleğin artışı ve sahnenin kare süresini gerçek telefonda kontrol et.

**Önemli:** Bu sürüm henüz tam optimize edildi veya profesyonel doğallık kesinleşti diye işaretlenmedi. [QUALITY_GATE.md](QUALITY_GATE.md) geçilmeden malzeme ve obje yerleştirmeye başlanmayacak.

## 0.3.2 — Geometri ve mobil optimizasyon

- **Stamp:** Hazır şekiller artık kusursuz dairesel değil; hafif asimetrik ve dünya koordinatlarına bağlı gürültüyle doğal görünüme yaklaşıyor. Bu gerçek kaya/erozyon simülasyonu değildir.
- **Smooth:** Sıralı verteks güncellemesinin bir yönde yamulma oluşturmasını engelleyen anlık görüntü kullanıyor; keskin kenarları tamamen yok etmeden yumuşatıyor.
- **LOD:** Yakın/uzak eşiklerinde titreyen geometri geçişlerini azaltan 8 m histerezis ve görünen yüzeyden hesaplanan eğim normalleri eklendi.
- **Performans:** Fırça darbesinde binlerce tekrar yerine kare/dikdörtgen tabanlı kirli tile işaretleme; termal aşınmada daha az geçici bellek tahsisi.
- **Check:** Şekil sınırları ve LOD geçişleri de doğrulama kapsamına eklendi.

## Değişiklikler

- Tile'lar, 64/96/160 adetlik mobil kalite bütçesiyle aşamalı yüklenir; ilk açılışta bütün mesh düğümleri aynı anda oluşturulmaz.
- Üç LOD seviyesinin kenarları yükseklik örneklerini eşleştirir. Yüzey boyunca gri kare duvarlar görünmemelidir.
- Yeni arazi sahne merkezinde açılır. Yeni veri dosyası ilk fırça darbesinden önce oluşturulur.
- Küçük ekranlarda açılır menü pencere sınırları içinde tutulmaya çalışılır; alt panel açılmaz.
- Android'in dokunmatik olaylardan türetebildiği sahte fare tıklamaları bir süre yok sayılır.
- **Yeni:** Fırça artık her dokunma olayı için değil, parmağın katettiği mesafe boyunca sabit aralıklarla etki uygular. Hızlı ve yavaş sürüklemede güç farkı azalır. Parmağı sabit tutmak devamlı kazma/yükseltme yapmaz.

## v0.4.4-dev.1 — Manifest-first hızlı açılış (salt okunur test)

- `paged_terrain_preview.gd` script'li ayrı test sahnesinde `region_directory` geçerli TFM1/TFR1 klasörüne işaret etsin. Inspector'da yeni `verify_pages_on_demand` **varsayılan AÇIK**: öncelikle yalnız `manifest.tfm` checksum/schema açılış kontrolü, ilk istenen bölge ayrı Thread'de SHA ile kontrol edilir.
- **Yapılan önemli güvenlik ayrımı:** Uzak bozuk/missing bölge ilk açılışta bilinmeyebilir. Ona gidildiğinde hata verilir; asla düz zemin uydurulmaz. `verify_pages_on_demand=false` seçersen önceki gibi her bölge dosyası açılışta doğrulanır (**FULL**).
- Seçili Node'da küçük TerraForge paneli `READ-ONLY ON-DEMAND` veya `FULL`, `Checked n/total`, tile/RAM/IO sayacı gösterir. **Fırçalar ve yazma kapalıdır**, TFH/TFL kaynak değişmez.
- [GitHub Godot CI 26/26 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664); gerçek Android 11 kamera, FPS/RSS ve açılış süresi ölçümü henüz yok. Ayrıntı: [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).

## v0.4.3-dev.2 — Hızlı kamera hareketi ve cache düzeltmesi

- Yeni opt-in `paged_terrain_preview.gd` test düğümünde kamera uzak bir yere aniden sıçrarsa önceki bölgelere ait henüz bitmemiş **disk taleplerinin sonuçları** iptal edilir; yeni sahnenin önüne geçmez.
- Komşu tile'ın `height` ve `normal` örnekleri oluşturulurken zaten yüklenmiş gerekli sayfalar LRU'da öne alınır. 9 sayfalık cache limiti **artırılmaz**; aynı sayfaya gereksiz tekrar talebi gönderme de önlenir.
- Yeni 25. stres testinde 128×128 dünya, 9 region cache, 2 background job, çoklu kamera teleport ve LOD0 collision doğrulandı. [GitHub Godot 4.7.2 CI 25/25 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507).
- Gerçek telefon FPS, RAM, Android Mobile Renderer görsellik testi henüz **YOK**; mevcut legacy editörün tam-heightarray kaynak yolu değişmedi. Detay: [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## v0.4.3-dev.1 — İlk gerçek bölgesel terrain mesh / collision

- Yeni `terrain/paged_terrain_preview.gd`: ayrı test sahnesinde `Node3D`'ye script bağla, önceden doğrulanmış TFM1 + TFR1 klasörünü `region_directory` alanına yaz, `preview_enabled` işaretle. **Eski TerraForgeTerrain sahnenin yerine otomatik geçmez.**
- Arka planda yüklenen Float32 bölge verileri artık gerçek `ArrayMesh` ve LOD0 `HeightMapShape3D` çarpışması oluşturur. 3 LOD'daki normal/sınır değerleri eski renderer ile karşılaştırıldı.
- Godot editöründe preview düğümünü seçince kompakt TerraForge popup **READ-ONLY** olur, Brush kapanır. Editör kamerası konumu 3D streaming'e aktarılır; sayfa/mesh/IO göstergeleri belirir.
- Eksik/bozuk bölgeden sahte düz arazi oluşmaz. `save_data()`, `paint_at()` ile bölgesel düzenleme kapalı. Kaynak TFH/TFL korunur.
- [Godot 4.7.2 CI 24/24 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421). **Android 11 telefon FPS/GPU/RAM/görsel ekran doğrulaması henüz yapılmadı**. Büyük dünya ilk yükleme SHA senkron ve aktif worker stop işleminde join bekleyebilir.
- Telefon kullanım ve bütün teknik sınırlar: [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## v0.4.2-dev.2 — Gerçek arka plan arazi dosyası yükleme

- Yeni `core/async_region_source.gd` ile disk verisi artık **ayrı Godot Thread** içinde yüklenebiliyor. Ana thread verinin bitmesini beklemek yerine hazır gelen Float32 sayfaları alıyor.
- `Mutex` ve `Semaphore` ile aynı anda bekleyen/çalışan/biten işler 1–8 sınırında, RAM cache'i 1–64 sayfada tutuluyor. Kamera aniden değişince eski generation sonuçları yeni haritaya karışmıyor.
- Her TFR1 dosyası **tek buffer snapshot** üzerinden tam dosya SHA + iç checksum + koordinat ve Float32 doğrulamasına tabi; eksik/bozuk sayfa sıfır yükseklik sayılmaz.
- Yeni 23. GitHub regresyonu dâhil **23/23 PASS:** https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313.
- **Henüz oyun sahnesinin terrain mesh/collision/Brush yollarına bağlı değil**; bu sürümde telefon ekranında yeni tuş, garanti FPS artışı veya RAM düşüşü bekleme. Büyük dünyanın açılış kontrolü hâlâ senkron. Sonraki P1.3 opt-in read-only terrain adaptasyonu: [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md).

## v0.4.2-dev.1 — İzole salt okunur yükseklik ve kamera ön yükleme prototipi

- `core/paged_height_source.gd` TFM1/TFR1 dosyalarını SHA-256 doğrulayarak Float32 örnekleri ve 32 sayfalık sınırda bilinear interpolasyonu destekliyor; en fazla 1–64 bölgeyi RAM cache'de tutuyor.
- `core/camera_page_prefetch.gd` kamera merkezine/yönüne yakın region sayfalarını seçiyor; her çağrıda 1–8 **senkron** disk okumasını aşmıyor ve henüz başlamamış eski istekleri kamera sıçrayınca iptal ediyor.
- GitHub Godot 4.7.2 CI [22/22 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825). **Henüz canlı terrain mesh/physics/Brush sistemine bağlı değil.** Eski haritanın RAM tüketimi otomatik azalmıyor.
- Bir sonraki iş worker-thread-safe async IO ve bounded in-flight jobs; ardından opt-in read-only terrain. Bkz. [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md).

## v0.4.1-dev.2 — Dünya manifesti ve kayıpsız yüksekliğin dışa aktarımı

- Yeni `core/region_manifest.gd` her bölgenin koordinatını, dosya doğrulama değerini, dünya boyutunu ve kaynak SHA-256 kimliğini tutar.
- Yeni `core/region_export.gd` mevcut `.tfh`, `.tfl` dosyasından **yeni bir klasöre** bölgesel Float32 veri çıkarır. Orijinal dosyayı değiştirmez.
- `.tfl` dosyalarında, katmanların o an **görünen birleşik yüksekliği** aktarılır; ayrı ayrı düzenlenebilir katmanlar orijinal `.tfl` içinde kalır.
- Çıktı önce geçici bir klasörde oluşturulur, dosyaların hepsi doğrulanınca son isimli klasöre taşınır. Çıktı klasörü zaten varsa **üzerine yazılmaz**.
- Bu adımda mobil menüye dönüşüm butonu koymadım. Büyük verilerde dosya yazma hâlâ senkron; telefon editörünü kilitlememek için CI'da çalıştırılabilecek izole API ve testler olarak kalıyor.
- `tests/test_region_export.gd` dönüştürme, sınır hassasiyeti, kaynak bütünlüğü ve bozuk manifest senaryolarını sınar.

## v0.4.1-dev.1 — Gerçek diskten bölge yükleme temeli

- Yeni `core/region_store.gd` her biri **32×32 Float32 örnek** içeren ayrı bölge dosyaları tutar. LRU önbellek sayesinde aynı anda bellekte kalan yükseklik bölgesi sayısı sınırlandırılır.
- Sınır örneklerinin yalnız **tek sahibi** olur. Eksik veya bozuk dosya **sıfır yükseklik gibi davranmaz**, hata üretir.
- Bölgeye yazmadan önce `.tmp` ve SHA-256 doğrulaması, önceki sağlam versiyon için `.bak` dosyası kullanılır.
- **Önemli:** Bu aşamada bölge sistemi henüz canlı Godot arazisine bağlı **değil**. Mevcut sahneni kullanırken RAM tüketimi azaldı diye düşünme; bu, CI'da doğrulanacak çekirdek prototipidir.
- `tests/test_region_store.gd` GitHub CI testlerine eklendi. Bölge mimarisi ve sonraki adımlar: [REGION_STREAMING_PLAN_TR.md](REGION_STREAMING_PLAN_TR.md).

## v0.4.0-dev.3 — Kayıt bütünlüğü ve kurtarma

- Yeni katman dosyaları **TFL2** biçimindedir. Dosyanın tamamı için SHA-256 doğrulama değeri tutulur. Eski **TFL1** dosyaları açılabilir; sonraki kayıtta TFL2'ye yükseltilir.
- Her başarılı yeni kayıtta, önceki sağlam `.tfl` sürümü `.tfl.bak` dosyasında korunur. **İlk kayıttan hemen sonra henüz yedek yoktur**; ikinci kayıtta oluşur.
- Yeni veri önce `.tmp` dosyasına yazılır ve doğrulanır; böylece yarım kalan işlem mevcut ana dosyayı değiştirmez.
- Ana `.tfl` kaydı bozulmuşsa arazi **salt okunur** olur. Eklenti boş veriyle üzerine yazmaz.
- Geçerli yedek varsa menüde **Restore** belirir. Dokunduğunda önce bozuk dosya `.corrupt_...` olarak korunur, ardından önceki sağlam kaydı geri getirilir. **Son kayıttan sonraki değişiklikler kaybolabilir.** Kurtarma isteğe bağlıdır; otomatik geri dönüş yapılmaz.
- `.tfh` dosyası katman modunda aynen korunur. Bu bir şifreleme sistemi değildir; yanlışlıkla bozulmayı tespit etmek içindir.
- GitHub CI'ya bütünlük, kurtarma, eski format ve yarım kalan kayıt için regresyon testi eklendi.

## v0.4.0-dev.2 — Gerçek düzenlenebilir katmanlar

1. Mevcut arazini yedekle. Godot'ta TerraForge'un üstteki küçük **Terrain** menüsünü aç.
2. **Enable Layers** düğmesine dokun. Eklenti eski `.tfh` dosyasını koruyarak, içinde temel yükseklik ve katmanlar bulunan yeni `.tfl` dosyası oluşturur. Aynı adlı `.tfl` varsa **üstüne yazmaz**.
3. **Godot sahneni kaydet.** Katman modu ve yeni dosyanın yolu sahneyle beraber saklanmalıdır.
4. Küçük satırdan **Sculpt 1** katmanını seçip Brush ile şekillendir. **+** ile başka katman ekle.
5. **On** anahtarıyla katmanı gizle veya göster. Gizli katmanda Brush kullanamazsın. Katmanı gizlemek Undo geçmişini temizler.
6. **Terrain > Save** katmanları ve temel yüksekliği **tek `.tfl`** dosyasına kaydeder. Artık eski `.tfh` dosyasına yazmaz.
7. Sahneyi yeniden açınca katmanlar geri gelmeli. Eksik/bozuk `.tfl` varsa arazi salt okunur açılır; eski `.tfh` dosyasına otomatik dönülmez.

**Dikkat:** Bu özellik isteğe bağlıdır. Açmadığın bütün eski sahneler yine normal `.tfh` sistemiyle çalışır. Bu sürümde katman opaklığı API'de var, ancak küçük mobil menüde hâlâ yalnız görünürlük kontrolü bulunuyor. Android cihaz testi bekliyor.

## P0/P1 uygulamasının ilk sürümü (0.4.0-dev.1)

- Yeni `core/height_layers.gd` katman çekirdeği **ayrı** kodlandı. 32×32 seyrek bloklarda Float32 yükseklik farkları tutar; temel arazi dosyasını değiştirmez.
- Bu **v0.4.0-dev.1** açıklaması, izole ilk prototipin tarihçesidir. **v0.4.0-dev.2** ile katmanları mobil menüden isteğe bağlı açabiliyorsun.
- **Terrain > Check** düğmesi artık katman kaydet/aç, görünürlük ve birleştirmeyi de kullanıcının arazisinden bağımsız test eder.
- Bilgisayarda Godot 4.7.2 yüklüyse, tüm 20 regresyonu `bash addons/terra_forge/tests/run_all.sh /proje/yolu /godot/yolu` ile çalıştır.
- Ayrıntılı uygulama ve geriye uyumluluk sınırları: [P0_P1_IMPLEMENTATION_TR.md](P0_P1_IMPLEMENTATION_TR.md).

## 0.3.3 — Yeni mühendislik düzeltmeleri

- **LOD kenar aydınlatması:** Aynı ayrıntı seviyesindeki komşu tile'lar ışık hesabında ortak sınırın iki tarafını kullanır. Geometri kapanmış olsa bile göze çarpan gölge çizgilerinin azalması hedefleniyor.
- **Ridge/Valley:** Birbirini tekrar tarayan uzun çizim parçaları için doğal sapma hesabı önbelleğe alındı; geçici önbellek en fazla 65.536 örneğe kadar büyür.
- **Kaybolmuş yükseklik dosyası:** Eski sahnenin bağlı `.tfh` dosyası eksik/bozuksa eklenti araziyi salt okunur yapar. Eksik dosyayı boş araziyle yanlışlıkla ezmez.
- **Drenaj analizi:** Yerel çukurları koşullandıran ve suyu birden çok alt komşuya dağıtan deneysel bir hesap motoru eklendi; **henüz araziyi oymaz**. `Terrain > Check` çıktısında `Drain` işlem süresi görünebilir.

**Eksik .tfh uyarısı alırsan:** Önce `terraforge_data` yedeğinden aynı dosyayı geri yükle. Eski haritanın üstüne `+ New` kullanma.

## Dosyalar ve güvenlik

`res://terraforge_data/*.tfh`, 32-bit float yüksekliği içeren projene özel veri dosyasıdır. Bir araziyi başka projeye taşırken sahne dosyasıyla beraber bağlı `.tfh` dosyasını da taşı. Bu sürüm oyun dosyalarını değiştirmez; yalnızca `addons/terra_forge/` eklentisi dağıtılır.

**Test durumu:** v0.4.0-dev.1 için Godot 4.7.2 Android testleri henüz yapılmadı. Check düğmesi gerçek GPU kare süresi testi değildir. Arayüz açılmıyorsa veya harita boş kalıyorsa Godot'un **Debugger → Errors** bölümündeki ilk kırmızı hata satırını paylaş.

## İlk denemede ne görmelisin?

Ortada tek parça gibi görünen düz yeşilimsi bir zemin. Başlangıçta otomatik dağ/çimen dokuları yok; bu sürüm yalnızca şekillendirme ve LOD altyapısını içerir. Arazi 3D editörde parmakla yükselirken kare çizgileri yerine sürekli bir zemin oluşmalıdır. Eğer karo sınırları fark ediliyorsa ekran görüntüsüyle beraber kamera açısını belirt.

## Testler

Bilgisayarda Godot CLI mevcutsa:

```sh
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_height_store.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_lod_policy.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_surface_faces.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_lod_seams.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_stream_budget.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_brush_sampling.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_advanced_brushes.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_geomorphology.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_lod_normals.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_shape_quality.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_data_safety.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_edge_normals.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_drainage_analysis.gd
```
