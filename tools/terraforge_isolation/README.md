# TerraForge darboğaz izolasyonu

Release APK'yı açıp **Ölçümü başlat** düğmesine basın. Kamera otomatik hareket eder. Her koşul normal ve ters sırada birer kez çalışır. 24 bölümün her biri 10 saniye ölçülür. Hazırlık ayrıca süre alır. **JSON kaydet** bütün sonuçları tek dosyaya aktarır. Pencere değişirse uygulama tamamlanan bölümleri kesinti bilgisiyle kaydeder. Aynı projeyi Godot Android editöründe çalıştırarak uygulama türlerinin toplam farkını ölçebilirsiniz. Önce hangi uygulamayı açtığınızı ikinci karşılaştırmada tersine çevirin.

Aynı TFM2 kaynağı, Mobile Renderer, gölgesiz bir yönlü ışık ve sabit kamera yüksekliği kullanılır. Hareketli bölümlerde kamera 24 metre gider ve 24 metre geri döner. Gerçek zaman kameranın konumunu belirler. Çizilen kare sayısı ve worker'ın tamamlayabildiği iş miktarı cihaza bağlıdır. Oyuncu kapsülü bu kamera deneyinin dışında kalır.

| Karşılaştırma | Ölçülen fark |
|---|---|
| empty → frozen_still | Ortak arayüz ve arka plana yerleşik arazinin statik çizim maliyetini ekler. |
| frozen_still → frozen_move | Aynı yerleşik parçaların üzerinde kamerayı hareket ettirir. |
| frozen_move → live | F/32 akışını ve hareketle değişen yerleşik parçaları ekler. |
| live → stats | Her karede ayrıntılı preview.stats() çağrısını ekler. Temel kare zamanlayıcısı ve düşük frekanslı GPU örneklemesi bütün koşullarda ortaktır. |
| live → half_scale | 3B hedefin her eksenini %50'ye, piksel sayısını %25'e indirir. Arayüz doğal çözünürlüktedir. |
| live → unshaded | Aynı geometriyi aydınlatmasız materyalle çizer. |
| live → mesh_only | Akış devam ederken fizik düğümü ve heightmap şekli yayınını kaldırır. Bu karşılaştırma oynanış fiziğinin toplam süresini ölçmez. |
| mesh_only → hidden_mesh | Mesh üretimi ve sunucuya atama sürerken arazinin ekrana çizimini kaldırır. |
| hidden_mesh → receipt | Her iki koşulda arazi görünmez. İkinci koşul CPU worker sonuçlarını tüketip LOD ve komşuluk kaydını tutar, mesh veya fizik kaynağı yayınlamaz. |
| baked_patch ↔ gpu_patch | 36 chunk, 73.728 üçgen, aynı yükseklikler, ışık, rota ve görünürlük sınırları. Birinde çevrimdışı üretilmiş mesh'ler, diğerinde ortak bir grid ve vertex shader'ın okuduğu RF yükseklik dokusu kullanılır. İki koşulda da fizik ve streaming kapalıdır. |

Son iki koşul sabit bir 192 × 192 hücrelik alanı kapsar. Clipmap halkaları, sınır dikişleri, yeni yükseklik sayfalarının GPU'ya yüklenmesi, düzenleme ve hareketli çarpışma ayrı bir aday gerektirir. Canlı F/32 görünür alanı ve LOD seçimi farklıdır. Önce iki sabit alan yöntemini birbirleriyle karşılaştırın.

Her bölüm kendi preview oturumunu açar ve başlangıç konumunu doldurur. JSON'daki **setup** bu ilk dolumun karelerini ve **open_ms** açılış çağrısını verir. Dosya sistemi ve sürücü önbellekleri oturumlar arasında yaşayabilir. Bir saniyelik bekleme ardından ölçülen ana bölümde **frame_ms** kare aralığıdır. Ortalama FPS toplam kare sayısının toplam süreye oranıdır. p95 ve p99 en yakın üst sıra istatistikleridir. **publish_ms** ve **sync_and_eviction_ms**, **pump_ms** içindedir. İkinci süre seçim ve silmeyi birlikte kapsar. **stats_ms** pompa dışındadır. **slowest_frames** önceki process çağrısındaki CPU işini sonraki kare aralığıyla eşler. **viewport_gpu_ms** gecikmeli GPU örnekleri sunar. Sayaç mevcut değilse değer null olur. **delivered**, **mesh_uploads**, **height_shapes_assigned** ve **pending_end** aynı yolu ne kadar farklı iş yaparak tamamladığınızı gösterir.

## Projeyi üretme

Godot 4.7.2 ve Python ile depo kökünde çalıştırın. Çıkış klasörü ve ZIP yeni olmalıdır.

```sh
python3 tools/terraforge_isolation/build.py --output /tmp/tf-isolation --zip /tmp/tf-isolation.zip
godot --path /tmp/tf-isolation
```

Baker, yükseklikleri mevcut TFM2 örnekleyicisinden üretir. Görüntülü bir Mobile Renderer ortamında aşağıdaki iki komut prototip görüntü eşleşmesini ve kısa deney akışını doğrular.

```sh
godot --path /tmp/tf-isolation --script "$PWD/tools/terraforge_isolation/verify_patch.gd"
godot --path /tmp/tf-isolation -- --verify-isolation
```

## Cihaz izi

Dağıtılan arm64 ölçüm APK'sı Godot 4.7.2'nin resmi Perfetto release şablonuyla hazırlanmıştır. Normal FPS koşusu iz toplayıcıyı başlatmaz. Ayrı bir koşuda ADB ile bağlı cihazda özellikle yavaş bölümü 15 saniye kaydedebilirsiniz. Motor olayları, iş parçacığı zamanlaması, desteklenen CPU frekans olayları ve Godot bölüm işaretleri yapılandırmaya dahildir.

```sh
adb shell perfetto --txt -c - -o /data/misc/perfetto-traces/terraforge.pftrace < tools/terraforge_isolation/godot-perfetto.config
adb pull /data/misc/perfetto-traces/terraforge.pftrace
```

Yeni APK üretirken Android release dışa aktarma şablonu olarak resmi android_release.perfetto.apk dosyasını seçin, çıktıyı zipalign ve apksigner ile hazırlayın. Godot Visual Profiler ile ayrıntılı çizim incelemesini ayrıca çalıştırın. [Godot Perfetto belgeleri](https://docs.godotengine.org/en/latest/engine_details/development/profiling/perfetto.html)
