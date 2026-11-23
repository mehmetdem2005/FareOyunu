# FareOyunu — SE çam biyomu / Part 0 görev ve kabul listesi
Tarih: 2026-11-24 · Durum: **yalnız plan, çalıştırılmadı**

**Tek teknik kaynak:** [PINE_SE_PAINT_PLAN.json](PINE_SE_PAINT_PLAN.json); yapısal sözleşme [PINE_SE_PAINT_PLAN.schema.json](PINE_SE_PAINT_PLAN.schema.json). Bu dosya JSON kararlarını kopyalayıp değiştirmez; yalnız icra sırasını ve kanıt gereksinimini okunabilir kılar.

## Part 0 hedefi
Sağ alt adaya 1K Poly Haven PBR materyallerini sonradan güvenli biçimde uygulamak için **dosyaları/sürümü, materyal envanterini, mask data sözleşmelerini, mobil bütçeyi ve sabit kuşbakışı PNG render profilini** doğrulamak. **Bu partta boyama, orijinal heightmap değişikliği, yeniden heightmap üretimi, doku indirimi veya diğer üç adaya müdahale YOK.**

## Kesin teknik bağlam
- Repo: `mehmetdem2005/FareOyunu`; taban dalı `fix/terrain-direct-source-no-reconstruction`; yalnız plan dalı `docs/se-pine-biome-paint-plan`.
- Ada: `island_se_01`; dosyası `assets/terrain/heightmaps/island_se_01_original.jpg`; gerçek codec **JPEG**, boyut 1536×1536; SHA256 `12e0868d2ab57f5d7840747a31222fbb5b6561f1d00e94103ed0834d7c781691`.
- Yatay preview ölçeği `660`, dikey preview ölçeği `32` Godot birimi; **gerçek metre olarak kabul edilmedi**.
- Fare uzunluğu **10 cm**; doku ölçeği birimleri onaylanmadan UV/texel yoğunluğu ve slope dereceleri kesinleşmeyecek.
- Diğer adalar (`island_nw_01`, `island_sw_01`, `island_north_01`) salt okunur. Kaynak yüksekliği, world state ve server/physics değiştirilmeyecek.

## P0 yapılacaklar — sırayı bozma
- [ ] **P0-01 — Kaynak ve dal:** Bütünlük ve bağımlılık kontrolü; SHA, JPEG gerçek formatı, SE GLB, doğru branch, diğer adaların hash farkı; GitHub'da ikili kaynaklar yoksa `BLOCKED`.
- [ ] **P0-02 — Godot:** Yalnız Part 0 yürütülürken Godot **4.7.2 stable** binary/export templates sürüm+checksum doğrulaması; **Mobile renderer** içe aktarım smoke test; kuruldu varsayılmayacak.
- [ ] **P0-03 — Poly Haven 1K:** 18 adet materyalin URL, lisans, gerçek **1K** diffuse ve `nor_gl` (OpenGL normal) dosyası; gerekli ise rough/ao/height varyantları, vendor fiziksel kaplama genişliği, toplam dosya boyutu ve ayrı hash kayıtları. 2K ile sessiz ikame YASAK.
- [ ] **P0-04 — Klasör:** Planlanan yolları ve sahiplik sınırlarını onayla; kaynaklar ayrı, maskeler ayrı, .tscn yalnız dış kaynak referansı; boş dizinler oluşturma.
- [ ] **P0-05 — Fiziksel ölçek:** Bir Godot biriminin metre karşılığı, gerçek ada boyutu ve fiziksel doku ebatı için ADR. 10 cm referans faresinin yanında en az 1 metrelik örnek yüzey için UV/texel yoğunluğu planı.
- [ ] **P0-06 — İçe aktarma:** Albedo sRGB; normal GL/roughness/AO/height **veri haritası** (lineer); mipmap+repeat; per-map import ayarları ve mobil sıkıştırma seçeneklerinin deney tasarımı. Metallic zeminde 0.
- [ ] **P0-07 — Maske sırası:** Kaynak hash → geçici kara/deniz referansı → göreli height → onaylı metre ölçeği sonrası slope → curvature → elle teyit edilen beach/cliff kıyısı → doğrulanmış lake/river → wetness/distance → biyom/rota/kök maskeleri → normalizasyon/edge test. Kaynağı değiştirme.
- [ ] **P0-08 — Boya kararı:** 7 zone, 18 malzeme; kuru toprakta roughness sabit, gerekçeli yerlerde rough map; AO opsiyonel, GL normal; öncelikli 6 malzeme, diğerleri bölgesel. İleri GPU kararı olmadan 18-way shader yok.
- [ ] **P0-09 — Mobil maliyet:** Eşzamanlı 3 katman/piksel **ölçülmemiş tasarım hipotezi**; özel cihazda p50/p95/p99 kare süresi, bellek/VRAM, shader cost, termal ve texture residency deneyi planla; kesin limit olarak sunma.
- [ ] **P0-10 — PNG standardı:** Yalnız SE ada; Godot 4.7.2 Mobile **gerçek** görüntü; sabit orthographic top-down kamera, %10 kadraj payı, sabit ışık/pozlama/arka plan, 1536×1536 PNG, metadata+hash. Kamera profili harici resource; oyun başlatılması şart olmadan editörde önizleme hedefi.
- [ ] **P0-11 — Negatif denetim:** Diğer adalar değişmedi, orijinal heightmap byte hash değişmedi, yeni EXR/yapay terrain yaratılmadı, sahneye geometri gömülmedi, materyal kodu multiplayer/chunk/collision/state'e dokunmuyor.
- [ ] **P0-12 — Kapatma:** Gerçek Godot render sistemi ve gerekli binary'ler varsa `part_00_overhead.png` **boyasız baseline** oluştur; yoksa açıkça BLOCKED yaz. Part 1'e kullanıcı onayı olmadan geçme.

## Gelecekteki dizin düzeni (şimdi otomatik oluşturulmayacak)
```text
assets/materials/polyhaven/1k/<id>/<diffuse|nor_gl|rough|ao|disp>.<ext>
data/biomes/pine_se/material_catalog.json
data/biomes/pine_se/paint_rules.json
data/biomes/pine_se/masks/<mask>_v###.png
data/biomes/pine_se/render_profile.tres
materials/terrain/pine_se/<external_material>.tres
tools/paint/pine_se/<pipeline>
tests/paint/pine_se/<validation>
artifacts/reviews/pine_se/part_<NN>_overhead.png
artifacts/reviews/pine_se/part_<NN>_metrics.json
```

## Materyal ve map karar özeti

| Tip | Kaynaklar | Boyama rolü / map |
| --- | --- | --- |
| Ana 6 | Forest Ground 03, Forest Floor, Mud Forest, Roots, Rock Ground 02, Mossy Rock | Albedo 1K + OpenGL Normal 1K zorunlu; ıslak/kaya/yosun için gerekçeli roughness |
| Geçiş 12 | Forest Ground 05/01/04, Forest Leaves 02, Brown Mud Leaves/Rocks 01, Coast Sand 01/05, Stony Dirt Path, Pine Bark, Wood Chips, Rocks Ground 02 | Yalnız uygun coğrafi kesimlerde; bazıları yalnız props; bütçe ve envanter kapısı sonrası |
| Bütün materyaller | AO opsiyonel, displacement kayıt/ref, metallic sabit 0 | Normal/displacement gerçek fiziksel yükseklik değildir; fare ölçeğinde ileri gerçek mesh/geometri ihtiyacı ayrı iş |

## Maskelerin güvenilirlik sınırı
Görüntünün siyah deniz alanı ile beyaz tepe alanı, tek başına gerçek kıyı topolojisi/bathymetry, nehir veya göl verisi sağlamaz. Kıyı dik/yumuşak ayrımı ve su maskesi **elle doğrulanmış dış veri** olmalıdır. Slope derecesi/metre cinsinden eşik ancak ölçek onayından sonra belirlenir. Derived maskeler kaynak heightmap değildir; kaynak hash ve dönüşüm sürümü içerir.

## Tur sırası ve kuşbakışı inceleme
- **Part 0:** boya yok; varsa başlangıç Godot PNG + kaynak testi.
- **Part 1:** çam/orman, çamur, kaya ve uygun kıyı **makro kaplama**; aynı kamera PNG.
- **Part 2:** nemli çukurlar, dik ve yumuşak kıyıların ayrı boyanması; aynı kamera PNG.
- **Part 3:** kök bantları, patika ve 10 cm fare ölçeği; aynı kamera PNG ve yakın yer açısı.
- **Part 4:** anti-repeat, ikinci materyaller ve seçici roughness/AO; aynı kamera PNG + ölçüm.
- **Part 5:** bütünlüğün gözden geçirilmesi, yakın plan geometri borcu ve son boyama değerlendirmesi; aynı kamera PNG.

**Her turda DUR → dosya/ölçüm/PNG kanıtını göster → kullanıcı incelemesi → bir sonraki tura geç**. Yalnız görsel olarak güzel görünmesi, gerçek fare yakınında veya mobilde başarılı olduğu anlamına gelmez.

## Definition of Ready / Done (Part 0)
**Ready:** Doğru source ve base branch, plan ve schema doğrulandı, yanlış kaynak/asset revizyonu kullanılmıyor.  
**Done:** 12 görevin sonucu raporlandı (PASS veya BLOCKED olabilir, fakat tamamlandı diye etiketlenmez); tüm 1K varlıklar dosya düzeyinde doğrulandı; Godot ve 10 cm ölçek doğrulandı; render varsa gerçek Godot PNG ve metadata teslim; kullanıcı Part 1'e izin verdi.

### Henüz açık engeller
1. GitHub'da orijinal JPEG/GLB ikili varlıkları henüz commit'li değil; yalnız ZIP'te olabilir.
2. Bu çalışma ortamında Godot 4.7.2 stable kurulu ve test edilmiş olarak kanıtlanmadı.
3. Fare için world-unit metre dönüşümü ve vendor texture physical size onaylanmadı.
4. Nehir/göl/kıyı tipi için güvenilir ayrı maskeler/annotasyonlar doğrulanmadı.
5. Poly Haven materyallerinin tam **1K dosya adları** henüz tek tek kontrol edilmedi.

**Bu belgeyi kaydetmek Part 0'ın uygulandığı anlamına gelmez.**
