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
## P1.6.4 — 27 Kasım 2026
- P1.6.3 paket çalışması 46012663880 son kontrolde aktif; bağımsız materyal kaynağı incelemesi sürdürüldü.
- World profili final Terrain3DMaterial ayarları tree öncesi hazırlanır. Native macro variation her zaman kapalıydı; kullanılmayan noise uniform'u ve branch kaldırıldı. Native otomatik NoiseTexture2D üretim ihtiyacı azalır, görünüm ve yakın kalite korunması hedeflenir. Checker final map update sonrası kapatılır. Baker world shader yolunu kullanır. Yeni worker yok. Karar protokolünde kaynak gerekçeleri ve riskler yazılı. Paket ve telefon doğrulaması açık; 2/43.

## P1.6.3/P1.6.4 — Paket hatası ve düzeltme
- 46012663880 ve 46013072810 başarısız: bake_native.gd texture_path değişkeninde Variant kaynaklı GDScript tür çıkarımı hatası; native bake ve shader çalışma aşamasına geçilmedi. Önceki başarılı paket korunuyor.
- Her iki yüzey döngüsü String olarak tiplendi, texture_path açık String oldu. Import logunda parse hatası görülürse 240 s timeout beklemeden paket kesilir; dört mip zinciri başarı işareti ayrıca zorunlu. Yeni tek birleşik paketleme doğrulaması; benchmark yok. P1.6.3/4 doğrulanmadı, 2/43.

## P1.6.3/P1.6.4 — Birleşik paket sonucu ve temizlik
- CI 46013911229 başarılı: NATIVE_SURFACE_MIPS_OK count=4, NATIVE_BAKE_OK regions=64 exact_height_samples=16777216 elapsed_ms=2892. Önceki parse hatası giderildi. Artifact 15205900568. 4/43 paket/uygulama hedefi; cihaz açılış, shader derleme ve FPS ölçümleri açık.
- Logda sunucu ses aygıtı ve Vulkan VK_KHR_surface hatası, VSync desteği uyarısı, offline PNG yükleme uyarısı mevcut. GL bake ve artifact başarılı. Ses için import komutunda Dummy seçildi. Offline raw PNG okuması açık byte buffer decode ile değiştirildi; Android baked yoluna, geometriye, shader'a veya fizik ayarına dokunulmadı. Vulkan ve VSync uyarıları maskelenmedi; sunucu ortamına özgü olabileceği için mobil renderer değiştirilmedi. Temizlik commit'inin paket sonucu açık. Sıradaki P1.6.5.

## P1.6.5 — 27 Kasım 2026
- P1.6.3/4 temizlik CI 46014546324 başarılı: 64 region, 16.777.216 Float32 örnek, dört mip zinciri. Ses ve PNG log uyarıları yok; Vulkan/VSync ortam kayıtları duruyor. Artifact 15204524992.
- P1.6.5 aday: mevcut spawn/respawn ray kontrolü doğru native collider id + beklenen yükseklik ile güçlendirildi; 3 s hata sınırı ve manuel retry. Geçersiz spawn yüksekliğinde backend aktive edilmez. Normal oynanışta ek ray yok; fizik/LOD ayarları korunur. Gate olayları rapora yazılır. Paket doğrulaması açık, cihaz sonucu yok. 4/43. Sonraki P1.6.6/7: takılma teşhisi ve düşük maliyetli recorder.

## P1.6.6–7 — 27 Kasım 2026
- 46015224588 paket sonucu başarılı; P1.6.5 cihaz gate davranışı açık. 5/43 paket/uygulama hedefi.
- Aday recorder schema 3: normal oyun sırasında disk yazma/flush ve RSS okuma kaldırıldı; RAM sınırları, dropped sayaçları, 50ms+ stall bağlamı ve P99.9, bir saniyelik HUD özetini tekrar kullanma. Manuel export korunur; crash recovery yok, cihaz ölçümü açık. Yeni worker/kalite değişikliği yok. P1.6.6/7 birleşik paket doğrulaması açık.

## P1.6 kapanış — 27 Kasım 2026
- CI 46016265505 başarılı; 64 native region, 16.777.216 Float32 örnek, 4/4 mip zinciri kayıpsız doğrulandı; offline bake 2045 ms. Artifact 15205259073. Vulkan/VSync ortam uyarıları devam ediyor. Bu CI paket üretimi, recorder çalışma davranışı veya FPS benchmark değil.
- 7/43 paket/uygulama hedefi; P1.6 7/7 bu kapsamda kapandı. Gerçek cihaz başlangıç/gate/recorder ve donma analizi açık; önceki donmanın nedeni kanıtlanmadı. P1.7.1 sırada. Kararlı V2 referans değişmedi.

## P1.7.1 — kaynak denetimi tamamlandı
- Native add/remove tüm texture array ve region_map_changed üzerinden fizik rebuild yapabilir; remove_region gerçek RAM eviction değil, save_directory silinmiş disk kaynaklarını silebilir. Ayrıntılı kaynak ve 213.333 MiB teorik harita yükü: NATIVE_RESIDENCY_AUDIT_TR.md. Cihaz GPU/RSS/timing ölçümü yok.
- 64 region resident korunur, naive streaming reddedildi. 8/43, P1.7 1/10. Sıradaki 1.7.2 kararlı koordinat indeksi. Yalnız belge commit, CI tetiklenmez.
