# TerraForge Mobile — Telefonda Kullanım, GitHub CI ve Güvenli Çalışma Kılavuzu

**24.11.2026.** Kullanıcı telefonu üzerinden Godot editörü kullanıyor; hedef Android 11, Godot 4.7.2, Mobile Renderer; ekran alanı kıt, klavye/konsol zorunlu olmamalı. Kod geliştirme ve script testleri **GitHub Actions CI** üzerinde yapılıyor.

## 1. Repo, dal ve telefon için en önemli dosyalar

- GitHub repo: https://github.com/mehmetdem2005/FareOyunu
- Geliştirme dalı: https://github.com/mehmetdem2005/FareOyunu/tree/feat/terraforge-mobile-addon
- Eklenti klasörü: `addons/terra_forge/`
- Son doğrulanmış kod commit'i: `73603a15361766397854d11bad44ecb41e9bd53e`
- Son PASS CI: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664 (26/26; Linux Godot 4.7.2)
- Son kaynak ZIP örneği: https://github.com/mehmetdem2005/FareOyunu/archive/734c9088d76603279599654d345249b0cc90e321.zip — **tüm repo arşivi**. Kopyalanacak addon yalnız `addons/terra_forge/`.
- Altında çalışılan sahne ve `terraforge_data/`, TFH/TFL/TFL.bak kaynakları ZIP değiştirirken silinmez.
- GitHub Actions ekranı: depo > Actions > TerraForge Godot 4.7.2 CI. Yeşil check Linux headless testi ifade eder.

## 2. Android editör kullanımı — güncel

1. Projeyi ve `terraforge_data/` içeriğini bağımsız yedekle.
2. Repo ZIP'i indirip içinden yalnız `addons/terra_forge/` klasörünü proje içindeki aynı yere kopyala. Eklentiyi çift klasörde `addons/terra_forge/addons/terra_forge/` hâline getirme.
3. Godot > Project > Project Settings > Plugins > `TerraForge Mobile` etkin.
4. Kaydedilmiş 3D sahnede Node3D root; 3D editor araç çubuğundaki küçük `Terrain` popup'ı aç. Eski büyük alt dock geri gelmemeli.
5. `+ New` yeni bağımsız test terrain yaratır; eski yükseklik dosyasını düz sıfır araziyle değiştirmek için kullanılmaz.
6. `Quality: Mobile` seç, `Check` çalıştır. Çıkan PASS/FAIL ve `F32, Path, Weather, Shape, Drain, Layers` işlem sürelerini not et. Check kullanıcının gerçek height data'sını değiştirmeyen scratch testidir.
7. `Brush`'ı aç; Raise/Lower/Smooth/Flatten, Ridge/Valley, Ramp, Stamp, Weather'i kullan. Fırça açıkken dokunmatik kamera ile çakışma olup olmadığını gözle.
8. `Enable Layers` opt-in: mevcut TFH korunur, TFL2 otorite belgesi yaratılır. **Hemen Godot sahnesini kaydet**, layer mode/file path kalıcı olsun.
9. Katmanları `+` ile ekle; seçici ve `On` ile kontrol et. Hidden layer sculpt edilmez; layer toggle sonrası Undo history sıfırlanabilir.
10. `Terrain > Save` TFL2'yi yazar; **sahne Save** ayrıca yapılmalı. Restore varsa önceki .bak kayıt geri döner, son çalışmaların tamamı dönmeyebilir.
11. Eksik TFH/TFL read-only uyarısı: veri dosyasını backups'tan aynı path'e getir, yeni dosyayla üzerine yazma. `Restore` yalnız doğrulanmış .bak varsa görünür.

## 2.1 P1.2 prototip ilerleme durumu (v0.4.2-dev.1)

- `core/paged_height_source.gd` ile `camera_page_prefetch.gd` kodlandı ve 22/22 GitHub CI geçti. Bunlar **henüz telefonun canlı editor sahnesine bağlı değildir**: ekranda yeni kamera streaming butonu arama.
- İşlemci ve depolama yükü hâlâ senkron; bu aşamada gerçek RAM/FPS kazanımı beklenmez.
- Bir sonraki iş P1.2b bounded worker-thread IO, ardından P1.3 opt-in read-only mesh/collision. Bkz. [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md).

## 2.2 P1.2b yeni asenkron IO (v0.4.2-dev.2)

- `async_region_source.gd` gerçek Godot Thread ile arka planda disk sayfa okumayı ve SHA doğrulamasını uygular; kamera scheduler bu modu `configure_async` ile kullanabilir.
- GitHub Linux CI [23/23 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45408761313). Bu **cihazdaki oyuna otomatik bağlanmaz**; ekranda yeni UI yok ve gerçek FPS/RAM artışı iddiası yok. Scene hâlâ eski tam RAM height source'dan çalışır.
- `open()` full-world doğrulamayı senkron yapar, `close()` bitmeyen IO için join bekleyebilir. Bir sonraki iş P1.3 opt-in read-only mesh/collision bağlantısı, kaynak: [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md).

## 2.3 P1.3 ayrı salt okunur bölgesel önizleme

- Godot test sahnesine ayrı Node3D ekle, `res://addons/terra_forge/terrain/paged_terrain_preview.gd` script'ini bağla; geçerli TFM1/TFR1 klasörünü `region_directory` alanına yaz, `preview_enabled=true` işaretle.
- Preview seçilince editör kamera hareketi mesh streaming'e yönlendirilir. Büyük alt panel yok, kompakt popup'ta `READ-ONLY` ve RAM sayfa/IO counters var; Brush kapalı, dosyayı yazma yok.
- TFR1 üzerinden gerçek ArrayMesh + LOD0 HeightMapShape3D oluşması ve eski mesh LOD0/1/2 parity [Godot CI 24/24 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421); gerçek Android 11 GPU/ekran/termal ve RSS benchmark henüz yok.
- **Eski sahneyi otomatik migrate etme.** Orijinal TFH/TFL dosyaları ve game character/scene korunur. Full world startup SHA senkron, hızlı kamera tile-gap ve collision coverage cihazda test bekliyor. [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## 2.4 P1.3b hızlı kamera hareketi testi

- `paged_terrain_preview.gd` kamerası >=2 sayfa uzaklaştığında bekleyen eski disk işlerini bırakır; `async_region_source` geçerli mesh için halo sayfalarını LRU önceliğine alır.
- GitHub [25/25 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507); 9-page limit + 2 worker job + hızlı kamera geçişi + gerçek LOD0 collision test edildi.
- **Gerçek Android'deki FPS/RSS ölçülmedi**. Test sahnesi dışında legacy oyun/editör terrain'i otomatik optimize olmaz. Kalan cihaz kontrol listesi [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## 2.5 P1.5 — Hızlı açılış ve doğrulama modu (v0.4.4-dev.1)

- Ayrı `paged_terrain_preview.gd` test sahnesinde `verify_pages_on_demand=true` varsayılan: checksummed TFM1 manifesti açılışta, istenen TFR1 sayfa ilk cold load'da worker Thread SHA-256 ile doğrulanır. Eski `async_region_source.open()` çağrıları varsayılan **strict** modda kalır.
- Editör popup `READ-ONLY ON-DEMAND` veya `FULL` ve `Checked x/y` gösterir. ON-DEMAND'da henüz istenmemiş bozuk/missing dünya parçası açılışta bulunmayabilir. Hata halinde sahte düz y=0 arazi gösterilmez.
- [26/26 Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45420063664). Gerçek Android başlangıç süresi/termal/GPU/RSS hâlâ kullanıcı cihazında ölçülmeyi bekliyor.
- Tam teknik durum [P1_5_LAZY_WORLD_OPEN_TR.md](P1_5_LAZY_WORLD_OPEN_TR.md).

## 3. Dokuz mevcut şekillendirme aracının kısa kullanımı

| Araç | İşlem | Sınır |
|---|---|---|
| Raise | Basılı/touch drag ile height artır | Event mesafesine bağlı stamp |
| Lower | Height azalt | Aşırı slope ve collision kontrolü |
| Smooth | Snapshot/bilateral smoothing | Gerçek erosion değil |
| Flatten | Seçilen height çevresine düzleme | Sert dik kenar görsel kontrol |
| Ridge | Çiz, parmağı kaldır, continuous crest | Jeomorfolojik ridge graph değil |
| Valley | Çiz ve bırak, continuous valley | Su havzası otomatik çözmüyor |
| Ramp | İki nokta arasında eğim; Rise ± | Süre/uzunluk sınırı |
| Stamp | Hill/Crater/Mesa | Tam simetrik değil ama geolojik değil |
| Weather | Dik yamaca dokun, pass sayısı | Lokal termal, hidrolik erozyon değil |

## 4. GitHub CI nasıl izlenecek (telefonda komut gerekmeden)

- GitHub repo > **Actions** > **TerraForge Godot 4.7.2 CI**.
- Son run'ın branch adı `feat/terraforge-mobile-addon`, head SHA ve status/conclusion'a bak.
- Fail olursa adımlar: `Install official Godot`, `Create isolated CI-only Godot project`, `Import project and parse addon scripts`, `Verify Godot editor plugin loads`, `Run all TerraForge Godot regression tests`, log artifacts.
- Hata türleri: GDScript parse, plugin loading, expected PASS yok, data format/geometry regression. Hata görmeden “başarılı” yazma.
- CI Linux headless olduğu için **Android screen crop, touch, GPU FPS ve depolama izinleri** değerlendirmesi kullanıcı telefonunda ayrıdır. Kullanıcıdan yalnız bu tür gerçek cihaz bulguları istendiğinde ekran görüntüsü ve Godot logs iste; kod testleri için PC talep etme.

## 5. Telefon kalite kontrol ve performans notları

- `Terrain > Quality: Mobile`, sonra Balanced/High ile aynı kamera rotasında kıyas.
- 256×256 test haritası üstten ve yere yakın görünüm; yüzey solid, gri checkerboard wall yok, alt taraf hollow hissi yok.
- LOD sınırları 72/144m çevresinde gez, zorlu dağ sırtta ve zayıf ışıkta normal dikişine bak.
- `Mesh last/max ms`, `Sculpt last/max ms`, `Tiles, Pending, Vertices` not et. Bunlar GPU frame süresi değil.
- Layer Save/scene Save → kapat/aç; TFH orijinal hash değişmemeli; yeni TFL2 verisi aynı olmalı.
- Gerçek 30 dk profil: RAM/VRAM, FPS, p95/p99, CPU/GPU, takılma, termal throttle, GPU driver reset.
- Hayali benchmark yazma; cihazda görünür yan etki olmadıysa bile “garanti” deme.
- Sadece terrain geometri; boyama/obje/bitki menüsü bu fazda önerilmez.

## 6. Kullanıcıdan gelebilecek sık sorular ve güvenli cevaplar

- “ZIP ver”: son **gerçek commit SHA** ile GitHub arşivi linkini oluştur; bütün repo ZIP'i olduğunu söyle, yalnız addon klasörünü değiştir.
- “Neden hâlâ RAM çok?”: TFR1/TFM1 prototip canlı terrain height source'a bağlı değil. P1.2–P1.3 entegrasyonu gerek.
- “CI yeşil, Android neden çöktü?”: Headless Linux farklı platform; oyun/driver/render/thermal test edilmedi. Android log/bugreport ve ilgili 3D görünümle eşleştir.
- “16-bit gerçek mi?”: Native TFH/TFL/TFR verileri Float32; JPEG 8-bit kaynak gerçek yeni sample bit bilgisine dönüşmez.
- “Terrain3D'den iyi mi?”: Ölçümlü eşit scene/renderer/LOD/collision karşılaştırması yoksa bilemeyiz.
- “Eski dosyam kayıp”: Read-only fail closed. `terraforge_data` ve layer .bak yedeklerini kontrol et; kaynak üzerine yazma.
- “Devam”: `HANDOFF_START_HERE_TR.md` ve `NEXT_SESSION_IMPLEMENTATION_TR.md` kaynaklı ilk açık işi kodla/test et, aynı planı tekrar anlatma.

## 7. İş bitirme iletişim formatı

Yanıt kısaca ne değişti, neden, hangi dosyalar, GitHub commit, gerçekten çalıştırılmış CI run, test sayısı, cihazda bilinmeyenler, korunan data, ZIP ve sıradaki **tam görev** içermeli. Uygulama belge dışında kaldıysa açıkça “prototip” de. Kullanıcının telefonu olduğu için terminal kurulum adımları varsayılan çözüm olmamalı.

Bağlı belgeler: [HANDOFF_START_HERE_TR.md](HANDOFF_START_HERE_TR.md), [QUALITY_TESTS_AND_BENCHMARKS_TR.md](QUALITY_TESTS_AND_BENCHMARKS_TR.md), [RISKS_AND_DECISIONS_TR.md](RISKS_AND_DECISIONS_TR.md).
