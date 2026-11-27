# Native Terrain3D — İlerleme Defteri

## 27 Kasım 2026 — Plan onaylandı
- P1.5 native temel: kullanıcı cihazında Dört Havza V2 açıldı, dokulu arazide gezildi ve JSON alındı. Kalan riskler ana planda.
- P1.6–P2.0: 0/43 plan adımı tamamlandı (bu sayım yalnız yeni plan içindir).
- P3.0/P4.0: plan başlıkları, alt adımlar açık.
- Sıradaki: 1.6.1 çalışan referansı ayrı güvenli dalda koruma.
- Bu commit yalnız belge kaydı; çalışma kodu, eski dallar, paket ve benchmark politikası değiştirilmedi.
- Referans commit: `fdbf49b2b5c1e0133a050e2a5f5592011f1fbf2c`.

Her sonraki geliştirmede tarih, adım numarası, commit, durum, ölçüm/kanıt, karar, risk ve sıradaki adım kaydedilir.

## P1.6.1–1.6.2 — 27 Kasım 2026
- 1.6.1 tamamlandı: stable/native-terrain3d-dort-havza-v2 dalı, fdbf49b2b5c1e0133a050e2a5f5592011f1fbf2c commit'ine sabitlendi.
- 1.6.2 aday uygulama: paket sırasında aynı Float32 dünya native 64 .res bölgesine dönüştürülür; 16.777.216 örneğin kayıpsız serileştirilmesi bit düzeyinde kontrol edilir. SHA256 manifesti; Android'de açık dosya isimleri ile native yükleme; tek toplu update_maps. Ham heightmap paketten çıkar. Eksik/bozuk bölge fail-closed. Dünya, materyal, LOD, fizik ayarları aynı. Yeni benchmark yok; paket üretim doğrulaması açık. Gerçek cihaz başlangıç hızlanması henüz ölçülmedi.
- 1/43 tamamlandı; 1.6.2 doğrulama bekliyor. Sonraki: 1.6.2 paket sonucu ve 1.6.3 kopyalar/maliyet.

## 27 Kasım 2026 — P1.6.2 karar ve paket sonucu
- CI 46011507225 başarıyla tamamlandı; 64 native bölge ve 16.777.216 Float32 örneğin tamamı bit düzeyinde eşleşti. Sunucu bake 2002 ms; telefon açılışı ölçülmedi. ZIP 80.989.685 bayt. Import logunda Vulkan VK_KHR_surface ve ERR_CANT_OPEN kayıtları mevcut; GL bake tamamlandı.
- Paket üretim hedefi tamamlandı: 2/43 (P1.6 2/7). Yeni native yükleyicinin gerçek cihaz doğrulaması açık; stabil referans önceki sürüm.
- Kullanıcı talimatıyla mühendislik karar protokolü ve P1.6.2 alternatif karşılaştırması kaydedildi. Sıradaki 1.6.3: ölçüm ayrımı ve kopya maliyeti. Yeni benchmark/paket başlatılmadı.

## 27 Kasım 2026 — Kullanıcı performans önceliğini kesinleştirdi
- ZIP boyutu hedef olmaktan çıkarıldı. Takılma, uzun kare, açılış ve sürdürülebilir FPS öncelikli. Disk boyutu yalnız cihaz kapasitesi açısından sınır. Karar protokolü ve ana plan güncellendi. 2/43; sıradaki P1.6.3. Bu commit belge değişikliği; runtime ve CI değişmedi.

## 27 Kasım 2026 — Yakın alan kalite şartı
- Yakın grafik, geometri, doku ve fizik kalite koruması zorunlu kabul kriteri oldu. Global dinamik çözünürlük varsayılan optimizasyon değil. Önce gereksiz iş ve uzak maliyetler. 2/43; P1.6.3 sırada. Yalnız belge değişikliği.

## P1.6.3 — 27 Kasım 2026
- Kullanıcı: arka plan optimizasyonu kendisi gecikme yaratmamalı. Zorunlu karar protokolüne worker bütçesi, iptal/dedup/backpressure ve kaynak rekabeti eklendi.
- Aday kod: baked başlangıçta gereksiz boş region resize kaldırıldı (upstream load_region boyutu kendisi ayarlar); raw import korunur. Dört doku aynı format ve mip byte'larıyla paket sırasında Image .res olarak hazırlanır. Telefonda PNG decode ve mip üretimi yerine hazır zincir, GPU upload aynıdır. Bir defalık startup faz süreleri JSON'a eklenir. Yeni worker yok; SHA256 ve yakın grafik ayarları aynı. Paket üretim doğrulaması açık, cihaz hızı henüz ölçülmedi.
- 2/43; P1.6.3 doğrulama açık. Sıradaki P1.6.4 ve 1.6.7 ölçüm/IO kararları.