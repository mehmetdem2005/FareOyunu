# TerraForge M10 Android test projesi

ZIP’i tek klasöre çıkar, `project.godot` dosyasını Godot 4.7.2 ile içe aktar ve Play’e bas. Başlat düğmesi yeni bir oturum açar. Bitince özet ve ayrıntılı JSON kayıtlarını kaydedebilirsin.

| Seçim | Çalışma |
|---|---|
| Hedefli | 4 fizik ve akış regresyonu, ardından 12 eşleştirilmiş Mobile Renderer profili |
| Tam | 147 regresyon, 56 eşleştirilmiş performans profili ve ayrıca 4 mikro gözlem profili |
| Dayanıklılık | TFM2, F motoru, 32 sayfa, aynı arazi oturumunda kesintisiz 30 dakika kamera hareketi |
| Yalnız profiller | 56 eşleştirilmiş performans profili ve 4 mikro gözlem profili |

Yalnız profiller, tamamlanmış regresyon raporunu ayrı tutarak yeni bir performans oturumu açar. Hedefli, tam ve yalnız profil ölçümleri aynı TFM2 haritasında, aynı görüntü ayarlarıyla kol başına 20 saniye çalışır. 16/32 sayfa veya F/I-G/I-H seçimi önceden belirlenmiş ABBA/BAAB sıralarına göre değişir. JSON her kolun tamamladığı işi ve kare sürelerini içerir. Dayanıklılık aynı kamera rotasını daha yavaş tarar ve ayrı raporlanır.

Rapor uygulamanın arka plana geçiş ve geri dönüş bildirimlerini, Godot çalıştırma özelliklerini ve varsa süreç RSS ölçümünü içerir. Aktif profil sırasında arka plana geçiş o profili keser ve oturum eksik olarak kaydedilir. Termal durum ve gerçek GPU kare süresi `null` olarak kalır. Kamera altındaki şekil kapsaması ile kapsül hareketi testleri ayrı ölçümlerdir.

Paket ve profil akışı Linux CI’da doğrulanır. Redmi Note 8 Pro üzerindeki süreler, 30 dakikalık ölçüm ve gerçek Android arka plan/geri dönüş doğrulaması cihaz raporu gerektirir.
