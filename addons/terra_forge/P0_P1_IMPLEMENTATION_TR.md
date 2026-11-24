# TerraForge — P0 doğrulama ve P1 veri katmanları, ilk uygulama
Sürüm: 0.4.3-dev.1
Durum: **Godot 4.7.2 Linux GitHub CI üzerinden test ediliyor; Android 11 GPU ve dokunmatik testleri henüz yapılmadı.**

## P0 — Güvenlik ve regresyon kapısı

- Mevcut `.tfh` dosyaları değiştirilmedi veya başka formata taşınmadı.
- Kalıcı `plugin.cfg` yolu göreli kalır (`script="plugin.gd"`).
- Eklentiye `tests/run_all.sh` eklendi; mevcut testlere ek olarak `test_height_layers.gd` çalıştırır.
- Editörün **Terrain > Check** menüsünde test, kullanıcının gerçek haritasını değiştirmeden geçici `user://` dosyalarıyla Float32 katman kaydetme, tekrar açma, görünürlüğü ve bileşimi sınar.
- `Check: PASS`, sadece küçük algoritma ve I/O doğrulamasıdır. LOD, FPS, gerçek GPU maliyeti, sahne çarpışması ve veri dayanıklılığı için **yeterli değildir**.

### Godot 4.7.2 bulunan bilgisayarda tüm regresyon testleri
Proje dizininde `project.godot` ve `addons/terra_forge/` olmalı.

```bash
bash addons/terra_forge/tests/run_all.sh /projenin/tam/yolu /godot/bin/yolu
```

Çıktıda her test PASS/FAIL ve son satırda toplam başarısızlık sayısı görülür. Godot testleri burada **çalıştırılamadı**; çalışmış gibi raporlanmamalıdır.

## P1 — İşleyen ama henüz sahneye bağlanmamış katman çekirdeği

Yeni modül: `core/height_layers.gd` (`TFL1` sidecar formatı).

- Temel Float32 yükseklik verisi `duplicate()` ile ayrı korunur; katman eklemek ilk veriyi değiştirmez.
- Her katman yalnız değişen 32×32 örneklerin Float32 **delta** değerlerini tutar. Ortak tile kenarlarındaki örneklerin **tek sahibi** vardır.
- `add_layer`, `put_delta`, `read_delta`, `set_enabled`, `set_opacity`, `move_layer`, `composite_height`, `compose` API'leri var.
- `save_file(.tfl)` ve `load_file(.tfl)` sürümlü yan dosya formatıyla çalışır. Maksimum 8 katman, en fazla 2048×2048 cell. Dosya önce `.tmp` olarak yazılıp boyutu kontrol edildikten sonra yeniden adlandırılır.
- Yükleme sırasında boyut, sürüm, isim, tile sayısı, negatif/taşan indisler ve non-finite yükseklikler kontrol edilir. Bozuk dosya mevcut bellekteki katmanları değiştirmez.
- Katmanlar **additive height deltas** olarak birleştirilir. Katman sırası metadata açısından anlamlıdır; bu ilk çekirdekte toplama işlemi değişmeli olduğundan, sırayı değiştirmek çıktıyı değiştirmez.
- **Kritik sınır:** Katmanlar henüz TerraForgeTerrain'in canlı fırça, Undo/Redo ve sahne kaydetme akışına bağlanmadı. Bu aşamada `.tfh` asıl oyun yüksekliğidir ve eski davranış korunur. Layer çekirdeği deneysel, izole bir P1 kilometre taşıdır.
- Katmanlar aynı anda birden fazla dosyaya otomatik yazılmıyor; `.tfh` ve `.tfl` arasında çökme sırasında oluşabilecek senkronizasyon uyuşmazlıkları çözülmeden canlı otomatik kayda geçilmeyecek.

## P1'in sonraki zorunlu işleri

1. Godot CLI üzerinde tüm 14 testi çalıştırıp API/parse hatalarını düzelt.
2. Katman ve `.tfh` arasında atomik bir **kaydetme sözleşmesi** tasarla: tek dosyada base+layers veya açıkça sürümlü manifest, checksum ve geri dönüş.
3. Test edilen katman çekirdeğini canlı Edit/Undo/Redo'ya **opt-in** bağla; kapat/aç ve çoklu düzenleme katmanlarına tam regresyon ekle.
4. 2048² yükseklik, sekiz katman, bellek/kare süresi üst sınırlarını Android üzerinde ölç.
5. Sonra yalnız terrain geometrisi için quadtree/clipmap, gerçek diskten stream ve ekran-hatası LOD prototiplerini değerlendirmeye başla.

Malzeme boyama, bitki, taş ve obje yerleştirme bu fazın dışındadır.

## P1 canlı katman entegrasyonu (0.4.0-dev.2)

**Not:** Yukarıdaki 'katmanlar henüz canlı bağlanmadı' ifadeleri v0.4.0-dev.1'in tarihsel durumudur; v0.4.0-dev.2 canlı katman entegrasyonunu içerir.

- İsteğe bağlı **Enable Layers** işlemi mevcut TFH verisinden TFL1 belge yaratır; eski dosya dokunulmadan kalır. Sahne dosyasını ayrıca kaydetmek zorunludur.
- TFL1, base + tüm delta katmanlarının **tek kalıcı otorite dosyasıdır**; TFH'ye çift yazım yapılmaz.
- Fırça/Undo/Redo seçilen katmana uygulanır. Katman görünürlüğü kompoziti yeniden hesaplar ve geçmişi temizler.
- `tests/test_live_layers.gd` opt-in, eski TFH'nin değişmemesi, çoklu katman, Undo/Redo, save/reopen ve eksik TFL1 korumasını denetler.
- **Sınır:** Opaklığı 1 olmayan katmana fırça yapılmaz. Eklenti katman dosyası yokken mevcut TFH'ye sessizce dönmez. CI testleri yeşil olmadan cihaz kullanımında kararlı olduğu iddia edilmez.
- **P0:** Test sayısı artık 17'dir; gerçek Android GPU/ısı ve uzun süreli dokunmatik testleri bekliyor.

- `tests/test_layer_scene_roundtrip.gd`: Godot `.tscn` kaydında katman modu/yolu korunuyor ve `.tfl` ile yeniden açılan sahne aynı yüksekliği geri alıyor (17/17 CI).


## P1 kayıt dayanıklılığı (0.4.0-dev.3)

- TFL2: Float32 temel veri ve katmanların tümü tek dosyada; tam payload SHA-256 kontrolü yüklemede zorunlu.
- Eski TFL1 okunur; kullanıcı Save'e bastığında TFL2 olarak kaydedilir ve eski TFL1'in bir kopyası `.bak` olur.
- `.tmp` staging + doğrulama + atomik rename, yedek için `.bak.tmp` staging + rename kullanılıyor. `.bak` son **önceki** sağlam kaydı tutuyor.
- Eksik/bozuk TFL2 otomatik olarak eski TFH veya yedeğe dönmez; salt okunur. Yalnız `Restore` işlemi, doğrulanmış `.bak` dosyasını geri yükler, bozuk asıl dosyayı ayrı `.corrupt_...` kopyasıyla saklar.
- İlk kayıt sonrası `.bak` yok; iki başarılı kayıt gerekir.
- `test_layer_integrity.gd` bu durumları ve yarım kalan geçici dosyayı denetler. Godot CI tamamlanana kadar yeni değişiklikler kararlı kabul edilmez.
- Kontrol amaçlı SHA-256, yetkisiz değişikliklere karşı kriptografik kimlik doğrulama sağlamaz.
- Performans notu: büyük katman dosyalarının doğrulanması ve yedeklenmesi şimdilik ana thread'de; sonraki optimizasyon adımı kademeli/asenkron güvenli kayıt tasarımıdır.

## P1 bölge store prototipi (0.4.1-dev.1)

- `core/region_store.gd`: 32×32 tek-sahipli sample sayfaları, checksum doğrulaması, .tmp / .bak kayıt ve sabit LRU limit.
- `tests/test_region_store.gd`: 19. regresyon olarak eklenmiştir.
- Bu sürüm **canlı arazi RAM kullanımını azaltmaz**. `terra_forge_terrain.gd` eski bütünü RAM'de tutan API'yi kullanmaya devam eder.
- Sonraki zorunlu adım, dünya manifesti + bağımsız doğrulama + kayıpsız dönüşüm ve katmanlı taşınma için testlerdir. Detay: `REGION_STREAMING_PLAN_TR.md`.

## v0.4.2-dev.1 — P1.2 salt okunur height source + kamera scheduler

- `core/paged_height_source.gd` ve `core/camera_page_prefetch.gd` **uygulandı**; TFM1 ve TFR1 tam SHA, Float32 bilinear, LRU, senkron nearest-first camera prefetch ve pending generation reset.
- İki yeni regresyonla [Godot 4.7.2 CI 22/22 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825).
- **Hâlâ:** gerçek canlı `TerraForgeTerrain` tüm Float32 `height_data.heights` verisini RAM'de tutar. Asenkron işçi IO, canlı mesh/collision/Brush entegrasyonu ve Android GPU/perf ölçümü yok. Sonraki görev [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md).

## v0.4.2-dev.2 — Asenkron page IO ve kamera generation testleri

- `core/async_region_source.gd`: Thread/Mutex/Semaphore, main-thread committed Float32 cache ve bounded 1–8 jobs; file SHA ve TFR1 internal checksum **tek buffer** üzerinde; `close()` explicit join.
- `camera_page_prefetch.gd` opt-in `configure_async`; eski sync yol korunur. Yeni `tests/test_async_page_io.gd` generation cancellation, deleted/corrupt region, 32-cell seam bilinear ve worker shutdown.
- [Godot CI 23/23 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313); **canlı terrain mesh/physics ve Android GPU testi yok**, startup sync. P1.3 sonraki görev: [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md).

## v0.4.3-dev.1 — P1.3 opt-in gerçek terrain preview

- `core/paged_tile_geometry.gd` ve `terrain/paged_terrain_preview.gd`: read-only async TFR1 Float32 pages → gerçek ArrayMesh, LOD0 HeightMapShape3D, LOD0/1/2 normal/kenar/çarpışma eşitliği.
- `plugin.gd`: Godot 3D editor kamera konumunu seçilmiş preview node'a iletir, read-only Brush/status. Önceki editable `TerraForgeTerrain` korunur.
- `test_paged_terrain_preview.gd` ile [Godot CI 24/24 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421); gerçek Android UI/GPU/thermal/RSS ve büyük dünya sync startup riski sürüyor. Ayrıntı: [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).
