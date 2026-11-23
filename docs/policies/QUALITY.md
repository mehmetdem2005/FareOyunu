# Kalite, saldırgan test ve kabul prosedürü v1.0

## Test matrisi
- Asset doğruluğu: magic bytes; dosya uzantısı; hash; yüksek hassasiyet algısı; kanal sayısı; gamma; orientation; NaN/Inf; uç değerler; boyut; yanlış ada ID.
- Heightmap: siyah deniz seviyesi varsayımı yok; tam 0/255; clipped pixel; lossy ring; dosya bit derinliği; örnek eşleme; converter determinism; metadata drift.
- Chunk/LOD (ileriki faz): seam çatlakları, ortak köşe, normal continuity, 1536'nın 2^n+1 olmaması, asimetri, negatif koordinat, teleport spam, kamera hızlı dönme, horizon, yanlış LOD kararı.
- Streaming/cache (ileriki faz): tekrar tekrar yükleme, iptal yarışları, out-of-memory, cache eviction sırası, disk yavaşlığı, background/resume, editor reimport, corrupt asset.
- Rendering (ileriki faz): farklı GPU, Mobile fallback, z-fighting, deniz/terrain kesişim, lod popping, under/overwater, specular aliasing, hızlı hareket, termal kısıtlama.
- Oyuncu deneyimi (ileriki faz): fare perspektifi, erişim, kontrol gecikmesi, geri bildirim, kamera, görsel gürültü, oyuncunun ilk 5 dakikası, navigasyon ve keşif ödülü.

## Kanıt ve raporlama
Her test: amaç, araç sürümü, cihaz, beklenen, gerçek, seed, tekrar, grafik/screenshot, başarısızlık nedeni. Başarısız test açık issue olarak kalır; başarı diye raporlanmaz. Farklı hipotezle ikinci tekrar zorunlu: sadece mutlu yol değil.
Bir test aynı modülde arka arkaya kırılırsa prosedür/CI ek denetimi güncellenir. AAA etiket değil, kalite disiplini ve ölçümlü sonuçtur.

## Bu aşamadaki sınırlar
EXR dosyası yerelde doğrulandı; Godot editörü, gerçek Android GPU, Github Actions run henüz doğrulanmadı. Bu üçüne ilişkin kabul kriterleri AÇIK.
