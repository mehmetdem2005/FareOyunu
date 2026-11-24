# TerraForge Mobile — Tam İlerleme Kaydı, Kanıt Düzeyi ve Sürüm Günlüğü

**Son durum tarihi:** 2026-11-24. **Aktif kod tabanı:** v0.4.3-dev.2, `bf5c1dde57cf4f56a08b606b03c89270d09599c2` (dokümantasyon öncesi uygulama commit'i). **Dal:** `feat/terraforge-mobile-addon`.  
**Durum anahtarı:** **DONE** = kod commit edildi; **CI PASS** = GitHub Actions Godot Linux headless testleri geçti; **DEVICE PENDING** = Android kullanıcı testinde henüz kanıt yok; **PLAN** = uygulanmadı. GitHub CI sonuçları, “kullanıcının telefonunda sorunsuz” anlamına gelmez.

## 1. En son kanıt ve geçerlilik

- **GitHub Actions run:** https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507  
  **Sonuç:** 25/25 GDScript regresyonu PASS, Godot 4.7.2 stable, ubuntu-24.04 headless. Son kod SHA `bf5c1dde57cf4f56a08b606b03c89270d09599c2`.
- İş akışı kaynağı: `.github/workflows/terraforge-ci.yml`. Eklentiyi geçici `project.godot` ile parse eder, editör eklentisinin başlatılmasını kontrol eder, `tests/run_all.sh` ile tek tek test çalıştırır. Exit code + `PASS:` + istenmeyen Godot ERROR/SCRIPT ERROR denetimi vardır.
- İstisna: bazı testler **bilerek** salt okunur kaynak-koruma hatası üretir; test çalıştırıcısı yalnız bu beklenen mesajları filtreler.
- Gerçek **Android 11 Mobile Renderer**, GPU, touch davranışı, uzun stres, VRAM, sıcaklık, 30/60 FPS, görsel doğallık ve Terrain3D karşılaştırması **DEVICE PENDING**.
- Kod değişiklikleri `addons/terra_forge/` ve tek GitHub CI workflow'u ile sınırlı; main ve oyun dosyaları korunmuş.

## 2. Sürümler ve işlenen kilometre taşları (kronolojik)

| Aşama | Yaklaşık commit/prefix | Gerçek yapılan iş | Doğrulama notu |
|---|---|---|---|
| v0.1.x — başlangıç | Tarihsel | Godot Android terrain editor eklentisi, Float32 yükseklik, ilk mesh + sculpt | Erken sürümler telefon ekranında UI ve yüzey sorunları gösterdi |
| v0.2.0 | `c8c9557` | `plugin.cfg` göreli `script="plugin.gd"` yolu; yanlış `res://addons/.../res://...` plugin yükleme hatasını giderme | Sürüm tarihinde Android gözlem vardı, kapsamlı CI yoktu |
| v0.2.1 | `6f6b632` | Yüzey triangle winding düzeltmesi; dev alt dock yerine kompakt 3D toolbar popup | İlk büyük görsel/telefon UI düzeltmeleri |
| v0.2.2 | `df00a911` | LOD seam yükseklik uyarlaması; checkerboard/grimsi etek sorunu; tile kurulum bütçesi; ilk HeightStore/LOD testleri | Gerçek cihaz görsel geçişleri sonra da kontrol edilmeli |
| v0.2.3 | `805c207` | Touch event sayısına bağımlılığı azaltan dünya-mesafesine göre fırça stroke örneklemesi; seyrek/sık input regresyonu | Sayısal yaklaşım kodlandı; yüksek hızdaki patolojiler benchmark ister |
| v0.3.0 | `e04524c` | Ridge, Valley, Ramp, Stamp; dört yeni şekillendirme aracı ve ilgili test/kılavuz | Başlangıçta doğal olmayan “boncuk” biçimli yol riski vardı |
| v0.3.1 | `d0bee77` | Tek parça kıvrımlı asimetrik Ridge/Valley; termal Weather; edit CPU/mesh sayaçları, bütçe, QA kapısı | **Bu fiziksel su erozyonu değildir** |
| v0.3.2 | `d45d863` | Organic Stamp; Smooth snapshot/bilateral; LOD histerezis, görünür mesh normalleri; bölgesel dirty işaretleme | Gölge/parlama iyileşmesi cihazda görsel olarak onaylanmadı |
| v0.3.3 | `098030b` | Yerel priority-flood/MFD drenaj analizi (salt okunur); eksik TFH read-only koruması; komşu tile sınır normal düzeltmesi; noise cache | Drenaj hâlâ arazi oymaz; canlıya akış çizimi eklenmedi |
| v0.4.0-dev.1 | `418e9fe` | İzole sparse additive Float32 katman çekirdeği, ilk `TFL1`, test çalıştırıcısı | Bu sürümde katmanlar live sculpt'a bağlı **değildi** |
| CI başlangıç ve düzeltmeleri | `0a54e7`, `68df408` | GitHub Actions workflow; geçici Godot projesi, script parse, editör start; off-tree transform uyarısı düzeltmesi; sıkı log filtreleri | 15/15 headless CI |
| v0.4.0-dev.2 | `27324d0` → `b09b017` | **Opt-in live layers**: Enable Layers, +, On; katman bazlı Undo/Redo, tek TFL otorite, sahne kaydet/aç regresyonu | 17/17 CI; eski TFH korunuyor |
| v0.4.0-dev.3 | `32e59fb` | `TFL2` SHA-256, .tmp staging, .bak önceki sağlam kayıt, manuel Restore, bozuk dosyanın korunması, TFL1 okumak | 18/18 CI; eşzamanlı/asenkron kayıt çözülmedi |
| v0.4.1-dev.1 | `1a36674` | **İzole** `region_store.gd`: `TFR1` 32×32 Float32 disk sayfası, LRU resident limit, güvenli kayıt ve checksum | 19/19 CI. **Oyun RAM'i henüz azalmadı** |
| v0.4.1-dev.2 | `c0e3a0d` → `734c908` | `TFM1` world manifest, kaynak SHA + tüm TFR1 page SHA doğrulaması; `TFH1/TFL1/TFL2` için staged, kaynağa dokunmayan snapshot export; kaynak değişim kontrolü | **20/20 CI PASS**. Canlı mesh/physics/brush entegrasyonu henüz yok |

| v0.4.2-dev.1 | `d516147` → `a214c907` | İzole `paged_height_source.gd` ile TFM1/TFR1 read-only Float32 ve bilinear LRU; `camera_page_prefetch.gd` ile nearest-first senkron read budget + generation, 2 yeni test | **22/22 CI PASS**; canlı renderer/physics henüz bağlı değil |

| v0.4.2-dev.2 | `f7b3413` → `4d5ed1b` | `async_region_source.gd` düşük öncelikli Godot Thread, bounded job/result+LRU, tek snapshot SHA, `camera_page_prefetch.configure_async()`, stale generation drop ve `test_async_page_io.gd` | **23/23 Godot CI PASS**; full manifest open senkron; canlı mesh bağlı değil |

| v0.4.3-dev.1 | `4422e0b6` → `286b135d` | `paged_tile_geometry.gd`, opt-in `paged_terrain_preview.gd`: TFR1 async → ArrayMesh + LOD0 HeightMapShape3D; editor camera bridge ve read-only toolbar; legacy LOD0/1/2 parity regression | **24/24 Godot CI PASS**; Android ve legacy migration henüz yok |

| v0.4.3-dev.2 | `bf5c1dde` | P1.3b: büyük kamera sıçraması worker generation iptali; mevcut tile halo sayfalarını LRU'da öne al; duplicate cold request job-budget koruması; 9 sayfa/2 job kamera stres testi | **25/25 CI PASS**; mobil ölçüm bekliyor |

Not: erken commit prefix'leri tarihsel kayıt amacıyla verilmiştir; yeni dal ilerledikçe tam baş SHA'yı **GitHub'dan yeniden okuyun**. `main`'e merge edilmedi.

## 3. Güncel özellik envanteri (gerçek / kısmi / plan)

| Alt sistem | Durum | Detay |
|---|---|---|
| Godot eklenti aktivasyonu | DONE / CI PASS | Android editörde son sürüm cihaz teyidi bekleniyor |
| Küçük Terrain popup / dokunmatik | DONE / CI parse | Ekran alanı ve çoklu touch cihaz testi bekleniyor |
| Raise, Lower, Smooth, Flatten | DONE / CI PASS | Smooth snapshot ve bilateral bileşen var |
| Ridge / Valley sürekli koridor | DONE / CI PASS | Ağırlıklar/noktalar path boyunca; gerçek havza kontrolü değil |
| Ramp / Hill-Crater-Mesa Stamp | DONE / CI PASS | Organik warp var; geolojik olarak bütünüyle gerçekçilik garantisi yok |
| Weather termal aşınma | DONE / CI PASS | Lokal malzeme aktarımı; sediment-su simülasyonu değil |
| Yerel priority-flood + MFD | DONE / CI PASS | Salt okunur analiz; 97×97 örnek sınırı |
| Float32 TFH | DONE / CI PASS | Kodda hücre aralığı 32–2048; base master tüm RAM'de |
| Opt-in TFL2 katmanlar | DONE / CI PASS | En fazla 8, sparse 32×32 Float32 delta; görünürlük ve Undo/Redo; non-destructive |
| TFL2 checksum/yedek/Restore | DONE / CI PASS | SHA-256; önceki kayda dönme olası değişiklik kaybı |
| 3 LOD ve tile mesh resident yönetimi | DONE / CI PASS | Tam crack-free stitched topology / geomorph henüz onaylı değil |
| Gerçek TFR1 disk sayfaları | DONE / CI PASS **izole** | Canlı scene height kaynağında kullanılmıyor |
| TFM1 dünya manifesti/export | DONE / CI PASS **izole** | Snapshot, TFL edit katmanlarını düzleştirir; gerçek runtime değil |
| Kamera yönlü **senkron** bounded prefetch | DONE / CI PASS **izole** | P1.2 |
| Worker-thread asenkron disk IO | **DONE / CI PASS (izole)** | P1.2b; tek worker, bounded IO, late cancellation |
| Async startup manifest verification | **PLAN** | P1.5 / sonraki optimizasyon |
| Salt okunur paged sampler + LRU | DONE / CI PASS **izole** | P1.2 |
| Opt-in **ayrı read-only** regional preview ArrayMesh/collision | **DONE / CI PASS (izole)** | P1.3; eski live node unchanged |
| Eski TerraForgeTerrain'e ortak HeightSource adaptörü, bölgesel edit/sculpt | **PLAN** | P1.3 sonrası / P1.4 |
| Multi-page atomik düzenleme ve Undo/Redo | **PLAN** | P1.4 |
| Ridge graph, watershed graph | **PLAN** | P2 |
| Gerçek hidrolik erozyon/sediment | **PLAN** | P3 |
| Quadtree/CDLOD/geometry clipmap karşılaştırması | **PLAN** | P4 |
| Gerçek Android profiler ve cihaz onayı | **DEVICE PENDING** | P0/P5/P7 |
| Malzeme boyama/obje | **KAPSAM DIŞI** | Kullanıcı izin vermedi |

## 4. Kullanıcının geçmişten getirdiği önemli sorunlar / dersler

- Yanlış plugin script yolu: `res://addons/terra_forge/res://addons/terra_forge/plugin.gd` biçiminde hata vermişti. Bu yüzden `plugin.cfg` daima `script="plugin.gd"` kalmalı.
- Terrain önce boş/altı oyulmuş gibi ve kareli görünmüştü; triangle winding, skirt, normals, LOD seam ve tile budget bu yüzden düzeltildi. **Yeni gerçek cihazda yakın görüş kontrolü yine gerekli.**
- Büyük alt dock telefon ekranını kaplamıştı; mobil toolbar + geçici popup kuralı kritik, UI'ı tekrar dev panel yapma.
- 8-bit/JPEG kaynaklı yükselti basamaklanmaları kullanıcı için kabul edilemez. Float32 native kayıt var ama JPEG'den dönüştürme kaybolmuş kaynağı geri getirmez; gerçek kaynak doğruluğu ayrıca test edilmeli.
- Kullanıcı “çakma dağ”, kopya dairesel yükseltiler ve detaysız profil istemiyor. Jeomorfolojik neden-sonuç ilişkisi ve fare-boyutunda yakın kamera önemlidir.
- Birden fazla sistemin tek anda değiştirilmesi Android hata ayıklamayı zorlaştırır; izole dal, küçük CI ile onaylanmış aşamalara devam.
- Dönüşümlerin eski veriyi değiştirmemesi ve yedekleri koruması birincil gereklilik.

## 5. Şimdiki öncelik / sıradaki değişiklik

**P1.3b uygulandı:** `async_region_source.is_requested/prioritize_resident` ve `paged_terrain_preview` camera generation cancellation. `test_paged_camera_stress.gd` ile 9 sayfa/2 job/çoklu teleport, LOD0 collision ve source SHA regresyonu, [25/25 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507). Bu, gerçek Android render/FPS ölçümü değildir; eski editable TerrainNode full Float32 RAM yolu değişmedi. Bir sonraki iş Android Mobile Renderer görsel/deliksizlik ve gerçek RSS/p95 ölçümü, ardından kaynak abstraction ve atomik P1.4 işlemler.



**P1.3 ilk gerçek render/collision prototipi UYGULANDI / [24/24 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45413288421):** ayrı `paged_terrain_preview.gd` Node3D, `paged_tile_geometry.gd` ve editör kamera forwarding. Legacy `TerraForgeTerrain` ve TFH/TFL dosyaları korunur; **eski oyun RAM'i otomatik azalmadı**. Sırada Android 11 gerçek Mobile Renderer UI/görsel/collision/memory profiler, hızlı kamera tile gaps/LOD normal seam ve ortak `HeightSource` adapter ile güvenli legacy geçiş; P1.4 atomik multi-page transaction yok. Ayrıntı [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md).

## 6. Kanıt ve geçmiş kuralları

- CI'da **gerçek run ID** bulunmadan test geçişi yazılmaz.
- Başarısız eski run'lar kayıttan silinmez; sonraki düzeltilmiş run ile ilişkilendirilir (örnek: v0.4.0-dev.3 ilk 17/18 beklenen uyarı, sonra 18/18).
- Kullanıcı donanımı üzerinde kanıt olmayan hız/RAM/GPU iyileşmesi **“mimari hazır” veya “test bekliyor”** olarak ifade edilir.
- Yeni değişikliklerde bu günlüğe “neyi değiştirdik, neden, test sonucu, risk, geri dönüş” maddeleri ekle.
