# TerraForge — Profesyonel Arazi Jeomorfolojisi ve Geometri Araştırma Notları

**24.11.2026.** Bu belge **yalnız terrain geometry** hedefini kapsar. Şu anda ana sistemler yapıldı sanılmamalı: gerçek watershed graph, hidrolik erozyon, sediment, clipmaps, CDLOD, gerçek kaya katmanlaşması ve near-ground adaptive detail **PLAN**. Mevcut continuous Ridge/Valley, Weather, priority-flood/MFD ancak başlangıçtır.

## Kullanıcının kalite hedefi ve neden basit noise yetmez

Fare Martin açık dünyasında fare boyutunda kamera, yere yakın yüzeyi çok görünür kılıyor. Arazi yalnız yukarıdan hoş görünmemeli; yürürken tepeler, kıyılar, vadiler, geçitler ve yamacın yapısı gerçek hissettirmeli. Tekrarlı yuvarlak damgalar, uniform noise, anlamsız vadi sonları, tüm dünyada aynı frekans, 8-bit yüksekliği EXR'e büyütüp kaybolan detayı geri getirdiğini iddia etmek kabul edilemez.

**Asıl hedef:** Makro dağ omurgası, su bölümü/ridge ağı, havza, akarsu bağlantıları, eğim, aşınma direnci ve sediment birikiminden geometrik neden-sonuç üretmek. Noise yalnız süreç kaynaklı mikro sapmayı desteklemeli.

## P2 — Çok ölçekli jeomorfolojik iskelet (PLAN)

### Makro: dünya silüeti (100m–km)
- Ridge graph: ana/ikincil sırt, crest/saddle, dağ arası geçit, plato, basin ve büyük kıyı eğimi.
- Spline kontrollü ve tahribatsız değiştirilebilir kullanıcı kontrol noktaları; ayrı tüm heights dizisine dönüştürülebilen deterministic delta.
- Eğimin iki yanında asimetri; düşük frekanslı relief; dış dünya ölçeği ve uçsuz tekrarlar.
- Referans gerçek topoğrafyanın elevation histogramı/silüeti ile ölçüm.

### Mezo: yamaç ve havza (1–100m)
- Gully/ravine, secondary tributary, terrace, landslide, talus, aşınma kırıkları.
- Nehir kolu başlangıcı, diğer kola kavuşma ve aşağı eğim fiziksel olarak ilişkili; rastgele kanal çizme.
- Eğim/aspect ve kaya direnci jeomorfolojinin sebebi; renderer texture painting değil, height hesap alanı.
- Eşikli slope smoothing yüzey omurgasını silmemeli.

### Mikro: farenin kamerası (cm–metre)
- Gerçek küçük çıkıntı, sığ erozyon izi, ufak çöküntü, akarsu yatağı girintisi; gerçeğe yakın geometri.
- Bütün 8192² veya büyük dünyayı cm resolution tutma: adaptif near-ground detail, uzak LOD ve collision sınırları.
- Shader normal/doku yalnız görüntü verir, gerçek height geometry'nin yerine geçmez. Bu projede boya yok.

## P3 — Hidrolik erozyon ve sediment (PLAN)

**Mevcut:** `drainage_analysis.gd` priority-flood depression conditioning ve MFD accumulation (max 97×97 örnek, salt okunur). `thermal_weathering.gd` dört-neighbor, talus eşikli lokal height transfer (radius ≤32m, max 6 pass). Bunlar **hydraulic erosion değil**.

Geliştirme zinciri:
1. TFM1 paged terrain üzerinden basen/outlet çözümü; priority-flood fill ve gerektiğinde breach alternatiflerini kıyasla.
2. Watershed graph ve drenaj kollarının birleşimi; düz zemin akışı random köşeye bağlama. D8 tek yönlü düz şeritleri engellemek için MFD veya D-infinity alternatifini test et.
3. Yağış/akış hacmi, eğim ve hız; sediment taşıma kapasitesi; erodibility/hardness/geology alanı.
4. İncelme (incision), çökelme (deposition), termal yamaç gevşemesi; Float32 değişim katmanı.
5. Su ve tortu kütle hesabı; negatif/kayıp kütle/NaN/sonsuz height yok; sabit zaman adımı ve stabilite.
6. Çok region su/sediment transferi: sınırda kütle korunumlu halo ve atomic transaction; thread-safe bounded offline hesap.
7. Deterministik seed/snapshot/provenance. Uzun işlem cancel ve Undo; asıl Float32 kaynak kalır.
8. Gerçek topoğrafyada dendritic branching, basin slope ve talus birikimi ile kıyas; yalnız güzel görünen render başarı değil.

**Zorunlu fixture:** flat DEM, tek pit ve spill outlet, iki nehir kolunun birleşmesi, kapalı havza, farklı sampling spacing, slope direction, çok-region boundary, yarım kalan işlem ve aynı seed'in aynı height sonuçları.

## P4 — Profesyonel LOD mimarisi

**Canlı mevcut:** CPU-generated `ArrayMesh`, 32-cell tile, LOD stride 1/2/4, 8m histerezis, edge-conformed heights ve komşu normal hesabı. Full topology stitch ve continuous morph **kanıtlanmadı**.

| Alternatif | Gerekçe | Yapılması gereken kanıt |
|---|---|---|
| Mevcut CPU tile | Bilinen baseline, karşılaştırma referansı | CPU rebuild spikes, drawcall, memory, collision |
| Geometry clipmaps | Kamera merkezli tekrar kullanılan GPU mesh halkaları | Godot Mobile shader/height texture format, VRAM, seam, GPU bandwidth |
| CDLOD / quadtree | Uzaklık ve ekran-hatası temelli seçici LOD | Node traversalı, T-junction, culling, görsel popping |
| Screen-space error | Keskin sırt ile düz ovanın aynı vertex sayısını gerektirmemesi | Pixel error hedefi, LOD sürekliliği |
| Yakın adaptif detay | Farenin yere yakın olduğu yerde gerçek mikro yükseklik | Collision ile render eşleşmesi, yüksek GPU maliyeti |

LOD geçişinde yakın/uzak tile geometrisi ve normals aynı world-height'i temsil etmeli; checkerboard skirt, dik gri duvar, ışık dikişi, T-junction, collision boşluğu, ani vertex sıçraması ve titreşim için ayrı testler.

## P5/P6 — Terrain editörü ve fizik

- Height profile/kesit, izohips, slope/aspect, havza akış haritası gibi **debug/ölçüm** araçları. Texture paint değildir.
- Makro ridge graph spline editörü, road-like ramp (yalnız geometrik eğim), terrace/plateau/coastal transition, kontrollü falloff, provenance.
- Tahribatsız “işlem katmanı” ve yeniden hesaplama; gizle/göster; Undo/Redo; uzun CPU işleminde preview/cancel.
- HeightMapShape3D ile mesh koordinatları ve hareketli farenin çarpışma hassasiyeti; fizik LOD ayrı ölçülebilir.
- Heightfield x/z başına tek y: gerçek mağara/overhang/volumetric terrain için ayrı voxel/SDF/mesh temsil gerekir. Şimdi mevcut mobil pipeline'a erken sokulmaz.
- Büyük dünya global position precision ve floating-origin gereksinimi gerçek ölçüme bağlanır.

## Profesyonel referanslar

Bunlar önceki kaynak araştırmasında seçilmiş **okuma bağlantılarıdır**. Yeni mimari kararı verirken sürümlerini ve belge içeriğini yeniden doğrula.

- SideFX Houdini Heightfield Workflows: https://www.sidefx.com/docs/houdini/model/terrain_workflow.html — macro massing → seeding/lobing → erosion → detail.
- Gaea 2 Erosion_2: https://docs.gaea.app/using/using-gaea/understanding-erosion/erosion_2/index.html — sediment, yönlü yağış, ayrı erozyon aşamaları.
- NVIDIA GPU Gems 2, Geometry Clipmaps: https://developer.nvidia.com/gpugems/gpugems2/part-i-geometric-complexity/chapter-2-terrain-rendering-using-gpu-based-geometry — GPU bazlı geniş arazi LOD.
- Godot Terrain3D System Architecture: https://terrain3d.readthedocs.io/en/1.1/docs/system_architecture.html — region/clipmap bileşimi; dependency seçimi yapılmış değildir.
- Unreal Landscape Technical Guide: https://dev.epicgames.com/documentation/unreal-engine/landscape-technical-guide-in-unreal-engine — component/section/LOD maliyeti.
- Unreal Landscape Edit Layers belgeleri — non-destructive terrain katmanları.
- Filip Strugar, 2010, Continuous Distance-Dependent Level of Detail for Rendering Heightmaps (CDLOD).
- Godot resmî dokümanları: thread-safe APIs, 3D renderers, HeightMapShape3D, FileAccess, RenderingServer; hedef Godot 4.7.2 mobile ile API uyumunu her defasında doğrula.

## Son kalite kapısı

- [ ] Dağ-sırt-havza-vadi bağlantıları jeomorfolojik olarak anlamlı.
- [ ] Gerçek erozyon Float32 height üretir, kütle ve sediment hesabı korunur.
- [ ] Geometri uzaktan silüet, yakından fare göz hizası için ikna edici.
- [ ] Komşu LOD/region/physics sınırlarında çatlak yok.
- [ ] Kaynak veri ve procedural parametreler geri alınabilir/deterministik.
- [ ] Android 11 GPU, CPU/RAM, FPS p95/p99 ve 30 dk stres kanıtı var.
- [ ] Boyama/obje yerleştirme kullanıcı izin vermeden başlamaz.

Faz ve sıralama için [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md), ilk görev için [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md).
