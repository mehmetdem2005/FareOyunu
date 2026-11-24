# TerraForge Mobile — YENİ SOHBETTE BURADAN BAŞLA

**Güncelleme tarihi:** 24 Kasım 2026  
**Belge amacı:** Bağlam kaybolduğunda tek başına yeterli proje devri. Bu dosyayı ve bağlantılı diğer MD'leri okuyup çalışmaya kaldığı yerden devam et.  
**Güncel geliştirme sürümü:** `0.4.2-dev.1`  
**Kaynak doğrulama tabanı:** `a214c907b6fba2d3cd7dba32f883ee5fad7ed446` (belge güncellemesinden önceki uygulama commit'i).  
**Depo:** `mehmetdem2005/FareOyunu` — **geliştirme dalı:** `feat/terraforge-mobile-addon`  
**Korunacak dal:** `main`; hiçbir kullanıcı talebi olmadan değiştirilmeyecek.  
**Eklenti dizini:** `addons/terra_forge/`  
**CI:** `.github/workflows/terraforge-ci.yml`  
**En son çalıştırılmış ve doğrulanmış CI:** [22/22 PASS, run 45404989825](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825) — Godot 4.7.2 stable, Linux headless. Bu sonuç Android testlerinin yerine geçmez.

> **ÇOK ÖNEMLİ:** Kullanıcı Android telefon üzerinden çalışıyor. Kod geliştirme, derleme/parse ve regresyon testleri için GitHub dalı + Actions CI tercih edilecek. Kullanıcıya Termux/PC kurulumu veya uzun manuel adımlar yüklemeye çalışma. Her değişiklikten sonra gerçekten GitHub'a push et, Actions sonucunu izle, başarısızsa düzelt. Başarılı olmayan CI'ı başarılı diye bildirme.

## 1. Hedef ve proje kimliği

TerraForge Mobile, **Godot 4.7.2 Mobile Renderer hedefli**, Android editörde ekrandan yer çalmayan, bağımsız profesyonel açık dünya **terrain geometri** eklentisidir. Nihai kullanım bağlamı, kullanıcının Fare Martin / Fare Vadisi açık dünya oyununda fare ölçeğinde, doğal görünen yeryüzü, vadi, akarsu havzası, dağ ve kıyı biçimleri üretmektir.

Kullanıcının açık ve yinelenen kararı: **Malzeme/texture boyama ve obje, bitki, taş yerleştirme sistemlerine HENÜZ GEÇME.** Önce arazinin gerçekçi ve topolojik olarak sağlam, yüksek hassasiyetli, tahribatsız düzenlenebilir, LOD/collision açısından doğru ve Android'de ölçülmüş biçimde optimize olduğu gösterilecek. Sadece rastgele gürültü ve tekrar eden dairesel damgalarla “gerçekçi” iddiası kurulmayacak.

## 2. Şu anda gerçekten var olanlar

- Kompakt Godot 3D toolbar: `Terrain` popup + `Brush` toggle; büyük alt dock kaldırıldı. Terrain oluşturma, kaydetme, Undo/Redo, kalite seçenekleri, `Check` ve isteğe bağlı `Enable Layers` var.
- Dokuz araç: Raise, Lower, Smooth, Flatten, Ridge, Valley, Ramp, Stamp (Hill/Crater/Mesa), Weather. Ridge/Valley sürekli, hafif bozulmuş koridorlar; Weather **termal** eğim gevşetme, **hidrolik erozyon değil**.
- `TFH1` Float32 temel yükseklik verisi; kaybolmuş/bozulmuş eski dosya için salt okunur güvenlik.
- İsteğe bağlı canlı Float32 katman modu; `TFL2` dosyasına temel yükseklik + 8'e kadar seyrek katman; katmana özel sculpt/Undo/Redo ve görünürlük. `TFL1` okuma geriye dönük var. `TFL2` SHA-256, `.tmp` staging, `.bak` önceki kayıt, açık `Restore` kurtarma; `.tfh` kaynak yedek olarak korunur.
- Render: 32×32 hücre tile, 3 LOD (stride 1/2/4), resident tile sayısı ve her karede mesh yeniden oluşturma bütçeleri, hizalanmış sınır yükseklikleri ve normal hesabı; stream edilen şey **mesh/collision tile**, bütün yükseklik dizisi değil.
- Jeomorfoloji: world-space Ridge/Valley; asimetrik stamp; bounded Weather; 97×97 örnek sınırlı **salt okunur** priority-flood / MFD drenaj analizi; gerçek su/taşınım yok.
- Ayrı P1 disk veri prototipi: `TFR1` 32×32 Float32 sayfa, LRU örnek önbellek, SHA-256; `TFM1` dünya manifesti; `region_export.gd` ile `TFH1`/`TFL1`/`TFL2` kaynaklardan **ayrı, doğrulanmış bölgesel snapshot** dışa aktarma.
- **P1.2 read-only sampler DONE:** `core/paged_height_source.gd` (TFM1/TFR1 checksum, Float32 bilinear, 1–64 LRU) ve `core/camera_page_prefetch.gd` (kamera önceliği, 1–8 senkron read/tick, pending generation reset) **22/22 CI PASS**. Bu **izole prototip**, gerçek sahneye bağlı değil.
- En kritik **henüz yapılmayan entegrasyon**: `region_store.gd` ve `region_manifest.gd` **canlı `terra_forge_terrain.gd` render, collision, sculpt, Undo/Redo yollarına bağlı değil**. Şu an canlı haritanın bütün Float32 yüksekliği RAM'de. Yeni bölgesel API tek başına oyun RAM'ini azaltmıyor.
- Son başarılı CI: toplam 22 test; kodun Linux headless Godot sürümünde açıldığını ve algoritmaların regresyonlarını kapsıyor. Android 11 dokunmatik, GPU, bellek/FPS/p95/p99, ısınma, uzun dayanıklılık henüz ölçülmedi.

## 3. Belgeler — hangisini ne için oku?

1. [STATUS_AND_CHANGELOG_TR.md](STATUS_AND_CHANGELOG_TR.md): tüm sürümler, commit'ler, tamamlanan işler, kanıt durumu.
2. [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md): **P0–P7** fazları, alt işler, bağımlılıklar, kabul kapıları, uzun dönem terrain hedefleri.
3. [ENGINE_ARCHITECTURE_TR.md](ENGINE_ARCHITECTURE_TR.md): gerçek kod haritası, API'ler, `TFH1/TFL1/TFL2/TFR1/TFM1` formatları, render/physics ve veri akışı.
4. [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md): **hemen başlanacak ilk görev**, dosya bazında yapılacak değişiklikler, adım adım GitHub CI kabul testleri.
5. [QUALITY_TESTS_AND_BENCHMARKS_TR.md](QUALITY_TESTS_AND_BENCHMARKS_TR.md): tüm 22 test, GitHub Actions, telefon gerçek dünya QA planı, hedef ölçümler.
6. [RISKS_AND_DECISIONS_TR.md](RISKS_AND_DECISIONS_TR.md): değiştirilmeyecek sözleşmeler, açık riskler, veri kaybı önleme, teknik kararların gerekçeleri.
7. [TERRAIN_GEOMORPHOLOGY_TR.md](TERRAIN_GEOMORPHOLOGY_TR.md): jeoloji, hidrolik aşınma, mikro/makro detay, LOD algoritmaları, teknik kaynaklar.
8. [MOBILE_WORKFLOW_TR.md](MOBILE_WORKFLOW_TR.md): telefon için kullanım ve sınama, ZIP/klasör korunumu, cihaz üzerinde QA.
9. [DOCS_INDEX_TR.md](DOCS_INDEX_TR.md): doküman indeksi ve güncelleme disiplini.
10. Mevcut tarihsel kaynaklar: [README.md](README.md), [KULLANIM_TR.md](KULLANIM_TR.md), [QUALITY_GATE.md](QUALITY_GATE.md), [REGION_STREAMING_PLAN_TR.md](REGION_STREAMING_PLAN_TR.md), [P0_P1_IMPLEMENTATION_TR.md](P0_P1_IMPLEMENTATION_TR.md), [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md).

**Çelişki kuralı:** Kod ve başarılı CI gerçek davranış konusunda otoritedir. Bu belge bugünkü durumu özetler; eski MD dosyalarının tarihsel “henüz yapılmadı” açıklamaları daha sonra tamamlanmış olabilir. Bir sonraki sohbette ilgili `.gd` dosyalarını da açıp kontrol et.

## 4. Hemen sıradaki teknik iş: P1.2b asenkron ve güvenli disk IO

**Tamamlananlar:** `core/paged_height_source.gd` ve `tests/test_paged_height_source.gd` — commit `d516147`, 21/21 CI; `core/camera_page_prefetch.gd` ve `tests/test_camera_page_prefetch.gd` — commit `a214c907`, [22/22 CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45404989825).

**İlk yapılacak iş (PLAN):** Senkron `tick()` dosya okumasını, Godot Node/SceneTree/mesh öğelerine dokunmadan arka plan thread'de yürütülebilen bounded, immutable-buffer ve SHA kontrollü bir iş akışına dönüştür. Pending/inflight sınırı, generation-id ile geç gelen eski işi atma, timeout/disk hatası ve hızlı kamera zıplama testleri ekle. En az 23/23 CI sonucunu doğrula.

**Sonraki iş:** P1.3 opt-in **salt okunur** mesh ve collision height source adaptörü; mevcut `TerraForgeTerrain`'in `height_data.heights` bağımlılığını kaldırmadan oyun RAM'inin düştüğünü iddia etme. P1.4 çok-bölge atomik kayıt olmadan bölgesel fırça/Undo/Redo yazımı AÇMA.

Tam API/kalan risk: [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md), uygulama listesi: [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md). Android cihaz ölçümü ve boya/obje yok.

## 5. Çalışma ve GitHub kuralları

- **Depo:** `mehmetdem2005/FareOyunu`. **Dal:** `feat/terraforge-mobile-addon`. **Ana dal:** `main` korunur; oyun sahneleri, karakter/nehir kodu, `terraforge_data` kesinlikle değişmez.
- Değişiklikler normalde yalnız `addons/terra_forge/**` içinde. Gerekli CI değişikliği istisnası: `.github/workflows/terraforge-ci.yml`.
- Her anlamlı adım: kodu yaz → `tests/*.gd` regresyonu ekle → `run_all.sh` listesine ekle → dalda commit/push → gerçek GitHub Actions sonucunu ve logları kontrol et → gerekirse düzelt → MD ve sürüm notunu güncelle → yalnız doğrulanan sonucu bildir.
- Godot CI projesi geçici, headless; depo kökünde `project.godot` bulunması gerekmiyor. Workflow gerekli dosyayı runner üzerinde yaratıyor.
- Eski `.tfh` ve `.tfl` kullanıcı kaynakları asla üzerine yazılmamalı/silinmemeli. Bir denemeden önce bağımsız yedek öner.
- Dokunmatik, Mobile Renderer GPU, gerçek telefon performansı CI testi değildir. Belirsiz noktaları belgelerde **PLAN / NOT VERIFIED** olarak işaretle.
- Eklenti ismi/kısayol yapısı küçük telefona göre, popup genişlemeden gelişmeli.
- Kullanıcı tam hazır ZIP istediğinde branch commit arşivi linki verilebilir; bu **tam repo arşividir**, eklenti olarak yalnız `addons/terra_forge/` kopyalanır. `terraforge_data/` korunur.

## 6. Yeni sohbet için hazır devam komutu

> `mehmetdem2005/FareOyunu` deposunda `feat/terraforge-mobile-addon` dalında TerraForge Mobile açık dünya terrain eklentisini geliştiriyoruz. Önce `addons/terra_forge/HANDOFF_START_HERE_TR.md` ve oradaki tüm bağlı proje Markdown belgelerini, sonra güncel ilgili `.gd` kodlarını oku. Son durum v0.4.2-dev.1; GitHub Actions Godot 4.7.2 CI 22/22 başarılı. Sadece terrain geometri/veri/LOD/fizik; boya ve obje yok. Telefon kullanıyorum, testleri GitHub CI'da yap. Şimdi `NEXT_SESSION_IMPLEMENTATION_TR.md` dosyasındaki ilk tamamlanmamış P1.2b asenkron IO görevini uygula; branch'i koru, regresyon ekle, CI çalıştır, sonucu ve MD notlarını güncelle.`

## 7. Dokümantasyon bakım sözleşmesi

Her yeni commit/sürüm sonunda en az `STATUS_AND_CHANGELOG_TR.md`, `ROADMAP_MASTER_TR.md`, `NEXT_SESSION_IMPLEMENTATION_TR.md` ve `QUALITY_TESTS_AND_BENCHMARKS_TR.md` güncellenmeli. Bir özelliğin `DONE` yazılabilmesi için uygulamanın gerçekten commit edilmiş olması; `CI PASS` yazılabilmesi için o commit'in başarılı Actions run bağlantısı olması gerekir. Android/FPS/görsel kalite için cihaz kanıtı yoksa `NOT VERIFIED` yazılır.
