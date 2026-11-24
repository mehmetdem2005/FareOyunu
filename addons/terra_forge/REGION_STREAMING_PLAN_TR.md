# TerraForge P1 — Bölgesel Float32 yükseklik belleği (v0.4.1-dev.1)

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
2. Yeni bir **dünya manifesti** (region listesi, schema/version, koordinat sistemi, checksums) ve başarısız dönüşüm için geri alma.
3. Kaynak `.tfl` üzerinden **isteğe bağlı, tahribatsız dışa aktarım**. Kopyalama bitene kadar kaynağı değiştirip silme.
4. Mesh ve collision için asenkron/bütçeli region sampler ve sayfa ön yükleme. Godot node yaratma yalnız ana thread.
5. Fırça/Undo/Redo için çok-sayfalı işlemlerin atomik kaydedilmesi, sınır testleri.
6. Android üzerinde 10–30 dakika LOD ve RAM ölçümü; p95/p99 frame time ve kayıt süresi karşılaştırması.

**Boyama, dokular, bitki ve obje yerleştirme bu aşamada yok.**