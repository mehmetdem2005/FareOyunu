# Terrain FLOAT32 V2 — Yeni sürekli yükseklik verisi

## Sorun
Eski EXR dosyaları OpenEXR FLOAT32 (kanal Y) olmasına rağmen 8-bit görselden türetildi: adalara göre yalnızca 240–256 farklı yükseklik örneği vardı. Bunlar dosya düzeyinde 32-bit olsa da daha yüksek bilgi hassasiyeti içermiyordu.

## Yalnız bu adımın çözümü
Kaynak EXR'ler SHA256 korunarak ayrı duruyor. Deterministik çok ölçekli Gaussian yumuşatma, bölgeye göre kıyı yaklaşımı (çoğunlukla kademeli, yer yer dik) ve düşük genlikli sürekli prosedürel mikrorelief ile yeni **float32 sayısal heightfield** üretildi. Yeni örnek sayıları 810.622–906.051; OpenEXR Y/FLOAT32 read-back tam eşittir. Çıktı bir **yeni, türetilmiş yüzey tasarımıdır**; kaybedilmiş gerçek coğrafi ölçüleri veya doğal DEM ayrıntılarını geri getirmez.

## Ayrımlar ve sınırlar
- **Veri sahibi** TerrainSource; görünür chunk, collision, AOI/network authority değildir.
- EXR binary ve yeniden üretilmiş harici GLB meshleri yerel tamamlanmış ZIP'te. GitHub text dosyaları bunlara referans verir fakat binary dosyaları burada **henüz yoktur**.
- Godot editör ve Android Mobile üzerinde gerçek import/render testi henüz koşulmadı.
- `.tscn` içinde mesh ya da height verisi gömülü değildir; mevcut harici referans yapısı korunur.
- Terrain preview dikey ölçekleri yeni `.tres` değerleriyle düşürüldü. Bunlar **metre değil**, yalnız editör gösterim birimleridir.
- Dört adayı tek dünya sahnesine birleştirme, collision, chunk, su ve multiplayer bu adımın dışında.

## Repro ve doğrulama
Python bağımlılıkları: `tools/terrain/requirements.txt`. Parametreler: `data/terrain/continuous_v2_presets.json`.
Dönüşüm: `python tools/terrain/reconstruct_continuous_heightmaps.py --root .`. Bu işlem var olan EXR'yi izinsiz üzerine yazmaz; var olanı hesaplanan değerlerle karşılaştırır, eksikse yeni dosyayı üretir ve manifest SHA'yı kontrol eder.
Preview GLB oluşturma: `python tools/terrain/build_preview_meshes.py --root .`.
Test: `python -m unittest discover -s tests -p "test_*.py" -v` (tam ZIP'te 9 test geçti).
