# Kalite, saldırgan test ve kabul prosedürü v1.1

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
İlk sentetik heightmap unit testleri ve ilk GitHub Actions phase-0 run başarılı olarak raporlandı (ROADMAP'de run ID var); yeni commit'lerin CI'si ayrı doğrulanır. Gerçek EXR'nin repo entegrasyonu, Godot editör görünümü, gerçek Android GPU ve player testleri hâlâ AÇIK.

## Genişletilmiş test tasarımı: rakip hipotezle sınama
1. **Test türü denge:** unit / property-based ve metamorphic / fuzz / contract / integration / editor / visual regression / GPU-specific / device / load, soak ve recovery / human playtest. Uygulanan tür için seed, fixture, expected oracle ve rapor gerekir; “her şey test edildi” denmez.
2. **Arazi asset karşılaştırma:** eski 1536x1536 görsel ve yeni yumuşak kıyı 1254x1254 kaynak **farklı sürümlerdir**. Checksum ve bit depth yanında elevation histogram, shoreline slope percentile, smoothness, islands/holes, rotation/coordinate mapping, bathymetry seam, beach walkable gradient, yanlış color-profile/gamma ve değişen peak konumları test edilir. Heightmap fotogerçekçi kabartma çizimi ile doğrusal yükseklik verisi birbirine karıştırılmaz.
3. **Sınır/stres denemesi:** 0/1 height, NaN/Inf, çok büyük/bozuk EXR, kesik dosya, eksik resource, yanlış compression, farklı endianness; tile edge, negative world coords, origin shift, teleport spam, chunk sınırında ileri-geri, delete/reload cache, asset revision drift.
4. **Eşzamanlı durum saldırıları:** iki chunk aynı anda istenir; kamera giderken görev iptali; arka plana atma/tam geri dönme; disk düşük; import devam ederken scene değişimi; kaybolan GPU context; açılışta bellek baskısı; shader derleme sıçraması; yavaş I/O. Race/stale-state/duplicate allocation fail kabul edilir.
5. **Editör güvenliği:** @tool script loop, recursive notifications, runaway regeneration, inspector parameter change, undo/redo, reload/cache reset, scene dirty flag; preview yanlışlıkla editable source'u veya .tscn'i değiştirmeyecek. Play basmadan gösterim görüntü kanıtı.
6. **Kullanıcı deneyimi falsification:** en az bir ilk-kez oyuncu ve uzman olmayan kullanıcıyla görev bazlı ölçüm; yönünü bulma, fare ölçeğinde yol/engel görünürlüğü, kamera sıkışması, kontroller, haptic/duyusal yük, görev anlaşılabilirliği, oyun başı 5 dakika; başarısızlık dahil geri bildirim. “Güzel görünüyor” kabul değildir.
7. **Ergonomi/erişilebilirlik:** dokunmatik hedefler, el tercihi, kamera hassasiyeti, yazı boyutu, yüksek kontrast, renk dışında bilgi, hareket hassasiyeti, ses altyazısı ve sadeleştirme seçenekleri ihtiyaç analiziyle ele alınır.
8. **Save/migration (uygulanacağı fazda):** atomik yazma + backup, sürüm ve schema migration, yarıda kesilme, boş depolama, eski sürümden yükleme, bozuk dosyadan kurtarma, save restore ve uninstall senaryoları. Oyun dünyası/ada yerleşimi değişirse eski save doğru konuma eşlenmeli.
9. **Performans ve uzun oturum:** farklı Android GPU, ekran yenileme hızı, thermal conditions, cold/warm start, frame pacing variance, shader/cache warmup, disk/VRAM residency, doze/background/resume, crash ve ANR, enerji tüketimi. Aynı rotada 30+ dk ve uzun soak testleri ayrı koşulur; hedef ve süre CI/cihaz aşamasında onaylanır.
10. **Hata yönetimi:** severity S0 (veri kaybı/çalışmaz), S1 (oyun durur), S2 (önemli kalite bozulması), S3 (kozmetik); severity/priority aynı şey değildir. Her S0/S1 için repro seed, cihaz, build hash, minimum reproducer, root cause, prevention test, regresyon kanıtı ve resolved durumuna geçmeden tekrar test.

## Birleşik sistem senaryoları (gelecek fazlar)
- Fare dar kıyıda koşarken LOD sınırı değişiyor, yağmur/deniz shader açık, collision tile yenileniyor, kamera suya yaklaşıyor.
- Yüksek noktadan dört ada ufku görülürken deniz yansıması, uzak vegetation ve draw distance birlikte test ediliyor.
- Save yazılırken uygulama kapanıyor, geri açılınca actor/world version değişmiş: kayıt bozulmuyor veya geri alma yolu var.
- GPU yoğun anda termal kısılma başlıyor, streaming priority değişiyor; görünür pop-in, oyuncu kontrolünde gecikme ve kare süresi ölçülüyor.

## Kabul/ret kanıtı
Tüm test çıktılarında test edilen build SHA, cihaz modeli/GPU/sürücü, Godot sürümü, kaynak manifest hash, amaç, ölçüm profili, başarısızlık, screenshot/capture ve rerun tarihi kaydedilir. Sayısal eşikler ADR ile onaylanmadan rastgele “geçti” etiketi verilemez. S0/S1 açıkken release/merge kapısı kilitli kalır. Gereksinimin olmadığı yerde test gereksizdir; ama test eksikliği açık yazılır.
