# TerraForge — P0 doğrulama ve P1 veri katmanları, ilk uygulama
Sürüm: 0.4.0-dev.1
Durum: **Yapılandırıldı ve kodlandı; Godot 4.7.2 / Android 11 üzerinde henüz çalıştırılmadı.**

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
