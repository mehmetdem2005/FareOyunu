# TerraForge P1 — Bölgesel Float32 yükseklik belleği (v0.4.2-dev.1)

**Durum: API prototipi + regresyon testi; canlı Terrain3D mesh/çarpışma/fırça sistemine henüz entegre değil.**

## Bu aşama neden gerekli?
Önceki TerraForge Terrain nesnesi, yakın tile meshlerini kısıtlasa da **bütün** heightmap'i `PackedFloat32Array heights` içinde tutuyor. 8192×8192 örnek, sadece yükseklik için yaklaşık 256 MiB anlamına gelir; Undo/Redo, katmanlar, texture veya mesh bunun dışındadır. Açık dünya için bu kabul edilemez.

## Prototip: `core/region_store.gd`
- Diskte `TFR1` dosyaları: `r_00000_00000.tfr`, `r_00001_00000.tfr` vb.
- Her dosya **32×32 adet kanonik Float32 örnek** (=4096 byte payload) taşır; bölge anahtarları dünya koordinatında `floor(x/32), floor(z/32)`.
- Bir sample tek dosyada saklanır. **x=32** sınır örneği, sol bölgenin x=32 kopyası değil, sağ bölgenin x=0 örneğidir. Render ve fizik tarafı gerekli kenar örneğini komşu sayfadan okuyabilir.
- Son dış çerçeve (`x=world_cells.x`) için ayrıca bölge açılır; bu sebeple örneğin 96×96 cell dünyasının bölge sayısı **4×4**'tür.
- Düşük maliyetli LRU: `max_resident` sayfaya kadar hafızada tutar; örnek olarak 4 sayfa × 4096 bayt = **16 KiB saf height örneği**. Godot Dictionary, Node, dosya sistemi ve diğer uygulama bellekleri buna **dahil değildir**.
- Değişen (dirty) bölge çıkarılmadan önce diske yazılır. Disk hatasında dirty veri RAM'de korunur ve sayfa boşaltılmaz.
- `create_blank_page(Vector2i)` **açıkça** çağrılmadan eksik bölge otomatik boş oluşturulmaz. Bilinmeyen/kayıp bölge `ERR_FILE_NOT_FOUND` ile bildirilir.
- `read_height(x,z)` sonucu `{error, height}` döndürür; `write_height(x,z,h)`, `flush_all()`, `unload_all()`, `stats()` ve `page_count()` temel API'dir.
- Sayfalar sabit boyutlu ve sürümlüdür (`TFR1` header + 1024 Float32 + SHA-256). Yanlış koordinat, farklı dünya boyutu/spacing, bozuk checksum reddedilir.
- Değişiklik önce `.tmp` dosyasına yazılır ve tekrar doğrulanır. Önceki sağlam sürüm üzerine yazmadan önce `.bak` saklanır.
- Dosya okuma/yazma bu sürümde **senkron** yapılır. CPU/GPU frame-time garantisi veya sıfır takılma iddiası **yoktur**.

## Neden doğrudan canlı arazinin RAM kullanımını düşürmedik?

Canlı `terra_forge_terrain.gd` şu anda gridde doğrudan `height_data.heights[index]` üzerinden çalışıyor. LOD mesh, collision, Undo/Redo, Ridge/Valley ve Weather hâlâ bütün veri dizisini varsayıyor. Sadece `region_store` dosyasını eklemek bu uygulamanın RAM maliyetini **hiç değiştirmez**. Ani geçiş kırık sahneye ve kayıp yüksekliğe neden olabilir.

Mevcut `.tfh`, `.tfl` ve `.tfl.bak` kayıtları **dokunulmadan korunuyor**.

## Kabul kapısı
1. Godot 4.7.2 CI'da `test_region_store.gd`: sınır tek-sahipliği, LRU limit, dirty yazım, kaydet/aç, bozulma kontrolü, eksik sayfa için fail-closed.
2. **Tamamlanan prototip:** TFM1 manifest, world dimensions, region listesi ve bütün dosya SHA-256 kontrolü. Staging klasörü doğrulanmadan son dünyaya taşınmaz.
3. **Tamamlanan prototip:** Eski TFH ve TFL1/TFL2 yüksekliğini kaynaktaki dosyaları değiştirmeden bölge dosyalarına aktarır. TFL katman yapısı sadece kaynağında korunur; bölge çıktısı görsel yüksekliğin düzleştirilmiş hâlidir.
4. Mesh ve collision için asenkron/bütçeli region sampler ve sayfa ön yükleme. Godot node yaratma yalnız ana thread.
5. Fırça/Undo/Redo için çok-sayfalı işlemlerin atomik kaydedilmesi, sınır testleri.
6. Android üzerinde 10–30 dakika LOD ve RAM ölçümü; p95/p99 frame time ve kayıt süresi karşılaştırması.

**Boyama, dokular, bitki ve obje yerleştirme bu aşamada yok.**
## 0.4.1-dev.2 — Yayınlama ve veri bütünlüğü

- Yeni `core/region_manifest.gd`: tüm TFR1 dosyalarını ve SHA-256 değerlerini içeren TFM1 manifest. Dünyanın büyüklüğü, Float32 sample aralığı, kaynak türü ve SHA-256 kimliği belirtilir.
- `core/region_export.gd`: kaynak TFH/TFL1/TFL2 kompozitini **yeni** bir staging klasörüne tam Float32 hassasiyetle aktarır, **her bölgeyi** doğrular ve son olarak staging klasörünü dünya klasörüne taşır.
- Çıktı klasörü zaten bulunuyorsa işlem reddedilir, eski dünya korunur. Başarısız dönüşümde son çıktı klasörü oluşturulmaz; staging klasörü teşhis için kalabilir.
- `tests/test_region_export.gd` ile tam boyut/sınır örnekleri, görünür TFL kompoziti, bozulmuş/eksik bölge, kaynak dokunulmazlığı ve tekrarlı export engeli test edilir.
- **Bu gerçek zamanlı streaming entegrasyonu değildir.** Mobilde RAM/CPU kazancı için sonraki aşamada bounded region sampler, mesh ve collision değişiklikleri gerekir.

## v0.4.2-dev.1 — TFM1 kontrollü P1.2 sampler ve kamera ön yükleme

- **DONE:** `core/paged_height_source.gd` doğrulanan TFM1/TFR1 dosyalarından Float32 örnek/bilinear değer okur; 1–64 page LRU, SHA-256, IO süre/hit/miss ölçümü ve başta sıfır resident page.
- **DONE:** `core/camera_page_prefetch.gd` en yakın/yön önceliği, 1–8 synchronous cold page read/tick, eski queued generation iptali; gerçek worker thread, canlı kamera ve mesh bağlantısı **yok**.
- **CI:** `test_paged_height_source.gd` ve `test_camera_page_prefetch.gd` eklendi, [Godot 4.7.2 22/22 PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825).
- **DEVAM:** Asenkron IO ve immutable buffer, bounded inflight/late cancellation, startup verification budget, opt-in read-only render+collision, ardından çok-bölge transaction. Detay: [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md).
