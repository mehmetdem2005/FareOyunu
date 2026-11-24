# TerraForge Mobile 0.3.1 — Türkçe kullanım

## Kurulum (telefon / Godot 4.7.2)

1. ZIP arşivinden yalnızca `addons/terra_forge/` klasörünü çıkar.
2. Mevcut Godot projenin köküne, yani `project.godot` ile aynı dizinin altına `addons/terra_forge/` olarak kopyala. Eski eklentiyi önce yedekle veya kapat.
3. Godot'ta **Project → Project Settings → Plugins** menüsünden **TerraForge Mobile**'ı etkinleştir.
4. Bir 3D sahne aç; kök düğüm `Node3D` olsun.
5. Üst 3D araç çubuğundaki **Terrain** butonuna dokun. Açılan küçük menüden **+ New** ile arazi oluştur.
6. İlk arazi *bilerek düzdür*. Bu bir hata değildir: **Raise** ile yükselt, **Lower** ile alçalt, **Smooth** ile yumuşat, **Flatten** ile düzleştir.
7. **Terrain** menüsünden araç ve **Size / Power** değerlerini ayarla. Menüyü kapat. Üst çubuktaki **Brush** anahtarını açıp araziyi tek parmakla şekillendir. Kamerayı hareket ettirmek için **Brush** anahtarını kapat.
8. **Quality → Mobile** profilinde başla. Daha fazla ayrıntı gerektiğinde Balanced/High dene.
9. **Terrain → Save**, Float32 yükseklik verisini kaydeder. Ayrıca Godot'un normal **Scene → Save** seçeneğiyle sahneyi kaydet. *İkisi de gereklidir*.

## Yeni şekillendirme araçları (v0.3)

- **Ridge (Dağ sırtı):** Parmağı sürükleyerek bir hat çiz, **parmağını kaldırınca** arazinin üzerinde tek parça, organik sapmalı bir sırt oluşturulur. Art arda dairesel tepecik basılmaz.
- **Valley (Vadi):** Parmağını sürükleyip kaldırınca kesintisiz bir vadi oyar. Gerçek su havzası hesabı henüz yok.
- **Ramp (Eğimli yol):** Başlangıç noktasına dokun, bitiş noktasına sürükle, **parmağını kaldır**. O zaman eğimli koridor uygulanır. Seçince çıkan **Rise** ayarı başlangıçta **+5 m**; negatif değer iniş oluşturur. Tek seferde en fazla 256 m uzunluğunda ramp yapılır.
- **Stamp (Hazır şekil):** Tek dokunuşla **Hill** (tepe), **Crater** (krater) veya **Mesa** (plato) bas. Parmağı sürüklemek aynı dokunuşta ikinci stamp üretmez.
- **Weather (Termal aşınma):** Çok dik yamaçta tek dokunuşla aşınma işlemi başlat. **Steps** (1–6) işlem sayısını ayarlar; yukarıdaki gevşek malzeme aşağıya aktarılır. Su erozyonu veya tortu simülasyonu değildir.

Hepsinde **Size** etki alanını, **Power** etki şiddetini belirler. Ramp, Stamp ve Weather seçenekleri yalnız ilgili araç seçildiğinde açılır; kalıcı geniş panel yoktur. Undo ve Redo her fırça hareketinde kullanılabilir.

## Telefon üzerinde kalite kontrol

1. **Terrain > Quality: Mobile** seç.
2. Aynı küçük menüdeki **Check** düğmesine bas. Kod kendi geçici test verilerini kullanır; haritanı değiştirmez.
3. Ekranda `PASS` veya `FAIL` sonucunu, Float32, Path ve Weather işlem sürelerini gör.
4. `Mesh last/max ms` ve `Sculpt last/max ms` CPU süreleridir, toplam GPU maliyeti değildir.
5. Ardından 30 dakika çizim, LOD, dosya aç-kapat, belleğin artışı ve sahnenin kare süresini gerçek telefonda kontrol et.

**Önemli:** Bu sürüm henüz tam optimize edildi veya profesyonel doğallık kesinleşti diye işaretlenmedi. [QUALITY_GATE.md](QUALITY_GATE.md) geçilmeden malzeme ve obje yerleştirmeye başlanmayacak.

## Değişiklikler

- Tile'lar, 64/96/160 adetlik mobil kalite bütçesiyle aşamalı yüklenir; ilk açılışta bütün mesh düğümleri aynı anda oluşturulmaz.
- Üç LOD seviyesinin kenarları yükseklik örneklerini eşleştirir. Yüzey boyunca gri kare duvarlar görünmemelidir.
- Yeni arazi sahne merkezinde açılır. Yeni veri dosyası ilk fırça darbesinden önce oluşturulur.
- Küçük ekranlarda açılır menü pencere sınırları içinde tutulmaya çalışılır; alt panel açılmaz.
- Android'in dokunmatik olaylardan türetebildiği sahte fare tıklamaları bir süre yok sayılır.
- **Yeni:** Fırça artık her dokunma olayı için değil, parmağın katettiği mesafe boyunca sabit aralıklarla etki uygular. Hızlı ve yavaş sürüklemede güç farkı azalır. Parmağı sabit tutmak devamlı kazma/yükseltme yapmaz.

## Dosyalar ve güvenlik

`res://terraforge_data/*.tfh`, 32-bit float yüksekliği içeren projene özel veri dosyasıdır. Bir araziyi başka projeye taşırken sahne dosyasıyla beraber bağlı `.tfh` dosyasını da taşı. Bu sürüm oyun dosyalarını değiştirmez; yalnızca `addons/terra_forge/` eklentisi dağıtılır.

**Test durumu:** v0.3.1 için Godot 4.7.2 Android testleri henüz yapılmadı; yeni Check düğmesinin sonucu da telefonla doğrulanmalı. Arayüz açılmıyorsa veya harita boş kalıyorsa Godot'un **Debugger → Errors** bölümündeki ilk kırmızı hata satırını paylaş.

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
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_advanced_brushes.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_geomorphology.gd
godot --headless --path /proje/yolu --script res://addons/terra_forge/tests/test_lod_normals.gd
```
