# TerraForge Mobile 0.2.3 — Türkçe kullanım

## Kurulum (telefon / Godot 4.7.2)

1. ZIP arşivinden yalnızca `addons/terra_forge/` klasörünü çıkar.
2. Mevcut Godot projenin köküne, yani `project.godot` ile aynı dizinin altına `addons/terra_forge/` olarak kopyala. Eski eklentiyi önce yedekle veya kapat.
3. Godot'ta **Project → Project Settings → Plugins** menüsünden **TerraForge Mobile**'ı etkinleştir.
4. Bir 3D sahne aç; kök düğüm `Node3D` olsun.
5. Üst 3D araç çubuğundaki **Terrain** butonuna dokun. Açılan küçük menüden **+ New** ile arazi oluştur.
6. İlk arazi *bilerek düzdür*. Bu bir hata değildir: **Raise** ile dağ, **Lower** ile vadi/çukur, **Smooth** ile geçiş, **Flatten** ile düz alan oluştur.
7. **Terrain** menüsünden araç ve **Size / Power** değerlerini ayarla. Menüyü kapat. Üst çubuktaki **Brush** anahtarını açıp araziyi tek parmakla şekillendir. Kamerayı hareket ettirmek için **Brush** anahtarını kapat.
8. **Quality → Mobile** profilinde başla. Daha fazla ayrıntı gerektiğinde Balanced/High dene.
9. **Terrain → Save**, Float32 yükseklik verisini kaydeder. Ayrıca Godot'un normal **Scene → Save** seçeneğiyle sahneyi kaydet. *İkisi de gereklidir*.

## Değişiklikler

- Tile'lar, 64/96/160 adetlik mobil kalite bütçesiyle aşamalı yüklenir; ilk açılışta bütün mesh düğümleri aynı anda oluşturulmaz.
- Üç LOD seviyesinin kenarları yükseklik örneklerini eşleştirir. Yüzey boyunca gri kare duvarlar görünmemelidir.
- Yeni arazi sahne merkezinde açılır. Yeni veri dosyası ilk fırça darbesinden önce oluşturulur.
- Küçük ekranlarda açılır menü pencere sınırları içinde tutulmaya çalışılır; alt panel açılmaz.
- Android'in dokunmatik olaylardan türetebildiği sahte fare tıklamaları bir süre yok sayılır.
- **Yeni:** Fırça artık her dokunma olayı için değil, parmağın katettiği mesafe boyunca sabit aralıklarla etki uygular. Hızlı ve yavaş sürüklemede güç farkı azalır. Parmağı sabit tutmak devamlı kazma/yükseltme yapmaz.

## Dosyalar ve güvenlik

`res://terraforge_data/*.tfh`, 32-bit float yüksekliği içeren projene özel veri dosyasıdır. Bir araziyi başka projeye taşırken sahne dosyasıyla beraber bağlı `.tfh` dosyasını da taşı. Bu sürüm oyun dosyalarını değiştirmez; yalnızca `addons/terra_forge/` eklentisi dağıtılır.

**Önemli:** v0.2.2 kodu inceleme ve algoritma denetiminden geçti ama bu ortamda Godot 4.7.2 çalıştırılamadığı için Android editöründe henüz test edilmedi. Arayüz açılmıyorsa veya harita boş kalıyorsa Godot'un **Debugger → Errors** bölümündeki ilk kırmızı hata satırını paylaş.

## İlk denemede ne görmelisin?

Ortada tek parça gibi görünen düz yeşilimsi bir zemin. Başlangıçta otomatik dağ/çimen dokuları yok; bu sürüm yalnızca şekillendirme ve LOD altyapısını içerir. Arazi 3D editörde parmakla yükselirken kare çizgileri yerine sürekli bir zemin oluşmalıdır. Eğer karo sınırları fark ediliyorsa ekran görüntüsüyle beraber kamera açısını belirt.

## Testler

Bilgisayarda Godot CLI mevcutsa:

```sh
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_height_store.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_lod_policy.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_surface_faces.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_lod_seams.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_stream_budget.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_brush_sampling.gd
```
