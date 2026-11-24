# TerraForge Mobile — Geometri & Performans Kalite Kapısı (v0.3.1)

**Durum: AÇIK / HENÜZ ONAYLANMADI.** Bu belge malzeme boyama ve obje yerleştirmeden **önce** geçilecek kontrolleri tanımlar. Kod eklenmesi başarılı test yerine geçmez.

## Profesyonel arazi şekillendirmenin temelleri

1. **Makro jeomorfoloji:** Dağ sırtı, havza, eğim ve drenaj birbiriyle uyumlu olmalı. Güncel Ridge/Valley uzun, tutarlı, asimetrik ve hafif domain-warp uygulanmış koridorlar üretir; **gerçek su havzası çözümü yapmaz**.
2. **Süreç tabanlı detay:** Weather, fazla eğimli komşular arasında 4-yönlü, iki aşamalı tampon üzerinde sınırlı malzeme aktarır. Yaklaşık kütle korur. **Hidrolik erozyon, sediment taşınımı, stratigrafi ve kaya türü modellemesi yoktur**.
3. **Kesintisiz yüzey:** Dikiş çatlağı, T-junction, keskin LOD parlaması, gövdesi görünmeyen yamaç ve aşırı düzenli dairesel desen bulunmamalı. 0.3.2 LOD histerezisi ve görünen mesh'ten normal hesabını ekler, ancak tam geomorph/edge stitch yerine geçmez.
4. **Gerçek fizik:** Görsel mesh ile HeightMapShape3D çarpışmasının uyuştuğu, yakın LOD dışı fizik kapsamının bilinçli olduğu doğrulanmalı.
5. **Tekrarlanabilir iş akışı:** Same seed / same geometry / same stroke inputs → aynı yükseklik. Üretim önce Float32 veri olarak kalmalı; görüntüleme LOD'u ana veriyi değiştirmemeli.

## Teknik kabul ölçütleri

| Kontrol | Kabul şartı | Şu an |
| --- | --- | --- |
| Plugin yükleme | Godot 4.7.2 Android editörde temiz açılır | Telefon testi bekliyor |
| Touch | Tek dokunuş tek işlem, çoklu dokunma kamerayı bozmaz | Test bekliyor |
| Float32 | Kaydet/aç değerleri bit hassasiyetini korur | Test kodu var, çalıştırılmadı |
| Jeoloji | Ridge/Valley kararlılığı, Weather dengesi; Priority-flood/MFD yerel drenaj analizi su dengesini korur | Test kodu var, çalıştırılmadı |
| LOD topoloji | Dikiş yarıkları ve kırmızı/gri dikey duvar görülmez | Cihaz görsel testi bekliyor |
| Mesh normals | LOD0/1/2 eğim normalleri analitik referansla uyumlu | Test kodu var, çalıştırılmadı |
| Ekran alanı | Açılır menü kapalıyken alt panel ekranı daraltmaz | Cihaz testi bekliyor |
| Dayanıklılık | 30 dk editörde gezinme/şekillendirme; veri kaybı/çökme yok | Test bekliyor |
| Kare süresi | Temsili sahnede hedef p95 ≤ 33.3ms ve p99 ≤ 50ms (30 FPS sınıfı) | Ölçüm yok |
| Bellek | 30 dk boyunca yükle/boşalt işlemlerinde sürekli artış yok | Ölçüm yok |
| GPU | Mobile Renderer ile render hatası ve sürekli GPU yüklenme tepe noktaları yok | Ölçüm yok |

## Profiling: ne ölçülüyor?

- Compact **Terrain** popup içinde `Mesh last/max ms`: mesh üretilirken harcanan **CPU tarafı süre**; GPU toplam maliyeti değildir.
- `Sculpt last/max ms`: koridor veya Weather işleminin **CPU süresi**; fırça sırasında render gecikmesini tek başına açıklamaz.
- `Vertices`: anda resident olan tile mesh vertex sayısı; GPU tahsisinin tümünü temsil etmez.
- Quality profilleri CPU yeniden kurulumunu hem adet hem süre bütçesiyle sınırlar. Bir tek pahalı tile yine süre bütçesini aşabilir.
- Sağlıklı performans karşılaştırması için aynı cihaz, aynı render profili, aynı kamera rotası ve aynı harita kullanılmalı.

## Manuel test senaryosu

1. Proje ve `terraforge_data` klasörünü yedekle. Yeni bağımsız 256x256 m test haritası oluştur.
2. Godot Android editörü: **Terrain > Quality: Mobile** ve ardından **Check**. PASS/FAIL ve süreleri kaydet.
3. Uzun bir Ridge ve yanına uzun Valley çiz. Parmağı kaldırınca koridor uygulanmalı. Aynı yolu üç farklı hızda tekrarla.
4. Dik yamaçlara **Weather**, 3 Steps uygula. Sert piklerin gevşemesi gerekir; düz alana bir değişiklik gelmemeli.
5. Ramp ve Stamp, Undo, Redo, Save; yeniden açınca Float32 yükseklik değişmemiş olmalı.
6. Kamerayı arazinin kenarlarına götür, LOD sınırlarını düşük ışıkta ve farklı açılarda kontrol et. Sürüş ve kamera hareketinde görünür yarık veya belirgin kare desen olmamalı.
7. Her kalite profilinde 5 dakika gezin, en yüksek Mesh/Sculpt sürelerini kaydet. Godot Debugger / Monitor bölümünde kare sürelerini ve VRAM/CPU kullanımı uygun olduğunda karşılaştır.
8. Sahneyi kapat/aç. 30 dk sonunda bellek sürekli artıyorsa kararlı etiketi verilmez.
9. 0.3.2 için Smooth ve Stamp simetrisini, LOD eşik histerezisini ve yükseklik sınırlarının dikiş gölgelerini ayrı test et.

## Sınırların dürüst dökümü

- 0.3.3'te yerel ve salt-okunur priority-flood + MFD akış birikimi analizi bulunuyor. **Bu henüz hidrolik erozyon değildir.** Geniş havza, kaya ve tortu sistemleri sonraki aşamalardadır.
- Yeraltı mağaraları/overhang heightfield ile oluşturulamaz; ayrı mesh/voxel sistemi gerekir.
- Bütün Float32 yükseklik verisi hâlâ RAM'de. Meshe ait resident tile sayısı yönetiliyor, gerçek diskten tile streaming henüz yok.
- Mevcut sahneye ait eksik `.tfh` verisinin üstüne boş yükseklik yazmayı engelleyen salt-okunur koruma var. Ayrıca LOD komşularının normalleri için sayısal test eklendi; Godot/Android doğrulaması bekliyor.
- Birden fazla düzenleme katmanı / ayrı dokular / taş fiziği / GPU profiler / nonblocking worker sürümü yapılmadı.
- **Daha optimize** olduğuna ancak Terrain3D ile aynı harita, aynı materyal, aynı kamera ve gerçek telefonda adil karşılaştırmayla karar verilebilir.

**Boyama ve obje yerleştirme, bu kontrol listesi geçilene kadar sonraki geliştirme aşaması değildir.**
