# Native Terrain3D — Mühendislik karar protokolü

Kullanıcının 27 Kasım 2026 talimatı: Her görevde önce yöntemin gerçekten en iyi seçenek olup olmadığını düşün. CI sonucunu beklemeden kaynak kod, mevcut ölçüm ve alternatifler üzerinden mühendislik kararı ver. Test kararı doğrular; kararın yerine geçmez.

Her görev öncesinde:
1. Hedef, kök neden, değişmeyecek kalite ve mevcut ölçüm sınırlarını belirle.
2. Upstream native özellikleri, mevcut yöntem, en az karmaşık alternatif ve gerekirse özel çözümü karşılaştır. Hiç değişiklik yapmamak da adaydır.
3. CPU/GPU, I/O, RAM, gecikme, doğruluk, mobil uyumluluk, bakım ve gelecekteki fazlara etkileri değerlendir. Tahmin ile ölçümü ayrı tut.
4. Gerekçeli karar: kabul, reddet, ertele veya yalnız deneysel tut. Öngörülen risk ve geri dönüş yolunu yaz. Sırf plan maddesi var diye gereksiz sistem kurma.
5. Birbirinden bağımsız işler mevcut işin sonucuna bağlı değilse ilerleyebilir; bağımlı işleri doğrulanmamış varsayımla başlatma. Kullanıcının otomatik benchmark istemediği politika korunur.
6. Sonuç geldiğinde yalnız PASS değil, gerçek ölçüm, beklenmeyen çıktı, kalite ve maliyetleri incele. Başarılı paket üretimi telefon performansının ispatı değildir.
7. Yeni bilgiler ilk kararı yanlışlıyorsa düzelt veya geri al. Kararlı referans dalını değiştirme. Eski CPU runtime'a dönme.

## P1.6.2 karar kaydı — 27 Kasım 2026
Seçenekler:
- Ham 64 MiB Float32 dosyası ve açılışta import: referans çalışan yöntem, fakat tam harita GDScript örnek taraması, ham görüntü ve bölge kopyaları, başlangıç dönüşümü. Avantaj basit taşınabilir kaynak.
- Önceden native .res: upstream serializer/loader kullanır, her bölge ayrı dosya, Float32 doğrulanabilir; Android'de açık dosya adıyla load_region, tek toplu update_maps. Bedel sıkıştırılmış dosya açma/çözme, 64 ayrı SHA256 okuması ve resource yüklemesi, tüm region'ların hâlâ resident olması.
- Özel ham chunk formatı: I/O üzerinde daha fazla kontrol sağlayabilir; fakat ekstra codec, native resource oluşturma ve entegrasyon yükü. Şimdilik reddedildi.
- Tek monolit GPU kaynak: küçük dünya için basit; büyük dünya için streaming/memory sınırlaması. Nihai mimari olarak reddedildi.

Karar: native .res paket üretimi kabul. 1.6.2'nin paket üretim hedefi doğrulandı: CI 46011507225, NATIVE_BAKE_OK regions=64 exact_height_samples=16777216 elapsed_ms=2002. Bu sunucu dönüşüm süresi; telefon açılış süresi değil. ZIP önce 82.758.137 bayt, yeni 80.989.685 bayt. Import ortamı logunda Vulkan VK_KHR_surface ve ERR_CANT_OPEN uyarıları/hataları görüldü; GL bake başarılı. Bunlar cihaz sonucu değildir, nedenleri kesinleştirilmedi. Yeni native yükleme yolunun gerçek cihaz doğrulaması açık.
1.6.3 ön karar: önce açılış aşamalarını ayrı ölç (manifest/hash, native resource açma, map upload, ilk fizik, ilk kare). SHA kontrolünü sessizce kaldırma; bütünlük politikası korunur. Cache veya çoklu iş parçacığı gibi çözümleri ancak ölçülen maliyet ve upstream thread güvenliği destekliyorsa seç. Tüm texture array güncellemesi maliyetini P1.7 öncesi ayrıca incele. Şimdilik yeni runtime değişikliği yok.
