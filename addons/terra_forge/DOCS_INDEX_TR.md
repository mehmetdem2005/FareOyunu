# TerraForge Mobile — Kalıcı Proje Hafızası ve Teknik Doküman İndeksi

**Hazırlanma:** 24 Kasım 2026. **Aktif dal:** `feat/terraforge-mobile-addon`. **Kod tabanı:** v0.4.3-dev.2.  
Bu dosyalar GitHub dalında saklanır, **sohbet hafızasına bağlı değildir**. Başka sohbet, model veya geliştirici ile devam edildiğinde önce bu indeks ve merkez devir dosyası okunacak.

## 1. Yeni sohbetin başlangıç sırası

| Okuma sırası | MD | İçerik / neden zorunlu |
|---:|---|---|
| 1 | [HANDOFF_START_HERE_TR.md](HANDOFF_START_HERE_TR.md) | Repo, branch, güncel sürüm, güvenli çalışma, hangi iş sırada, yeni sohbet promptu |
| 2 | [STATUS_AND_CHANGELOG_TR.md](STATUS_AND_CHANGELOG_TR.md) | Başlangıçtan v0.4.3-dev.2'ye kadar tarihçe, commit prefix, DONE/CI/PENDING |
| 3 | [ROADMAP_MASTER_TR.md](ROADMAP_MASTER_TR.md) | **P0–P7** fazları, alt fazlar, bağımlılıklar, kabul kapıları |
| 4 | [NEXT_SESSION_IMPLEMENTATION_TR.md](NEXT_SESSION_IMPLEMENTATION_TR.md) | **ŞİMDİ BAŞLANACAK P1.3 cihaz kalite kapısı / P1.4 tasarım** dosya, API ve test düzeyinde iş listesi |
| 5 | [ENGINE_ARCHITECTURE_TR.md](ENGINE_ARCHITECTURE_TR.md) | Mevcut gerçek kod akışı, TFH/TFL/TFR/TFM formatları, LOD/collision, sınırlamalar |
| 6 | [RISKS_AND_DECISIONS_TR.md](RISKS_AND_DECISIONS_TR.md) | Sözleşmeler, kritik riskler, eski veri/backup/manifest koruma ve rollback |
| 7 | [QUALITY_TESTS_AND_BENCHMARKS_TR.md](QUALITY_TESTS_AND_BENCHMARKS_TR.md) | 25 test, GitHub Actions ve cihazda ölçülmesi gereken gerçek performans/kalite |
| 8 | [TERRAIN_GEOMORPHOLOGY_TR.md](TERRAIN_GEOMORPHOLOGY_TR.md) | Profesyonel doğal arazi algoritmaları, su/erozyon, LOD alternatifleri ve kaynaklar |
| 9 | [MOBILE_WORKFLOW_TR.md](MOBILE_WORKFLOW_TR.md) | Telefon editör kullanım kuralları, CI'ı GitHub'dan izleme, güvenli ZIP yükleme |

**P1.2 teknik ek:** [P1_2_PAGED_SAMPLER_TR.md](P1_2_PAGED_SAMPLER_TR.md) — salt okunur Float32 sampler, kamera ön yükleme, API ve CI 22/22, kalan async IO işi.

**Yeni P1.2b teknik ek:** [P1_2_ASYNC_IO_TR.md](P1_2_ASYNC_IO_TR.md) — worker Thread, Mutex/Semaphore, bounded IO, camera cancellation, 23/23 CI ve P1.3 geçiş koşulları.

**P1.3b kamera/cache iyileştirmesi:** [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md) — 9 sayfa cache stress, eski background IO cancellation, 25/25 CI.

**Yeni P1.3 teknik ek:** [P1_3_PAGED_RENDER_TR.md](P1_3_PAGED_RENDER_TR.md) — ilk gerçek opt-in TFR1 ArrayMesh/HeightMapShape3D, editör kamerası, 24/24 CI, Android bekleyen testler ve READ-ONLY güvenlik.

## 2. Eski ama korunan proje belgeleri

Bu belgeler silinmez. Zaman içinde bir bölümü tarihsel kalmıştır; **as-built son durum için güncel kod + yukarıdaki yeni MD'leri kullan**.

| Belge | Ne anlatıyor |
|---|---|
| [README.md](README.md) | Özellik tarihçesi, kullanım, kurulum, CI ve sonraki adımlar |
| [KULLANIM_TR.md](KULLANIM_TR.md) | Android ekranı, 9 sculpt tool, layer/restore ve eski sürüm talimatları |
| [QUALITY_GATE.md](QUALITY_GATE.md) | İlk geometri/performans kabul kapısı, mobil test hedefleri |
| [MOBILE_TEST_PLAN.md](MOBILE_TEST_PLAN.md) | Android smoke, UI/touch/LOD/soak kontrol listesi |
| [P0_P1_IMPLEMENTATION_TR.md](P0_P1_IMPLEMENTATION_TR.md) | İlk data layer fazları ve sonraki TFL2 güvenlik adımları, tarihsel ekler |
| [REGION_STREAMING_PLAN_TR.md](REGION_STREAMING_PLAN_TR.md) | TFR1 LRU/TFM1 export prototipi ve canlıya bağlama sınırları |

## 3. Değişmeyen kararlar

- **Boyama ve obje yerleştirmeye geçilmiyor**; yalnız terrain geometrisi, erozyon, veri, LOD, collision, editör ve performans.
- Telefon Android 11, Godot 4.7.2 hedefi; UI kompakt.
- Branch `feat/terraforge-mobile-addon`; `main`, diğer oyun dosyaları, harita verisi ve `terraforge_data` korunacak.
- Gerçek data Float32; JPEG yükseltmesi kaybolan yükseklik bilgisi değildir.
- TFH/TFL asıl kaynak korunur; TFR1/TFM1 şu an sadece **izole snapshot** veri prototipi. Canlı data RAM streaming henüz yok.
- Godot GitHub CI **Linux headless**, Android GPU/gesture/ısınma kanıtı sayılmaz.
- Her yeni kod değişimi için GitHub Actions sonuçları; son gerçek 25/25 PASS run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45415690507 .

## 4. Güncelleme disiplini — yeni sohbette unutulmayı engelle

Her yeni geliştirme turu sonunda:
1. **Gerçek kod SHA**'yı GitHub'dan kontrol et. Eski dokümandaki SHA'yı canlı HEAD sanma.
2. Test ekle/çalıştır; GitHub CI run linkini ve sonucu kaydet.
3. `STATUS_AND_CHANGELOG_TR.md`'de yeni sürüm ve commit, gerçek tamamlanan kod/fail logu/Android sınırı.
4. `ROADMAP_MASTER_TR.md`'de görev checkbox/status, kabul kapısı ve bağımlılıkları.
5. `NEXT_SESSION_IMPLEMENTATION_TR.md`'de sıradaki açık iş, gerçek dosya yolları, test ve rollback.
6. `RISKS_AND_DECISIONS_TR.md`'de çözülmüş/yeni risk, veri güvenliği kararları.
7. `QUALITY_TESTS_AND_BENCHMARKS_TR.md`'de yeni test adı, test sayısı ve yeni Android ölçümü.
8. `ENGINE_ARCHITECTURE_TR.md`'de data schema/API/LOD/physics değişiklikleri; `TERRAIN_GEOMORPHOLOGY_TR.md`'de bilimsel algoritma değişimleri.
9. `HANDOFF_START_HERE_TR.md` başlangıç özeti ve “sonraki tek görev” güncel mi kontrol et.
10. GitHub commit docs + CI sonucu; belge dosyalarının gerçekten remote branch'te varlığını doğrula.

**Tutarsızlık politikası:** Kod gerçeği > başarılı CI > yeni status notu > tarihsel README. Geçmiş not “henüz yok” diyorsa yeni sürümde gerçekten kodlanmış olabilir; kodu yeniden oku. Aksi yönde de salt plan başlığı kodlandı sanılmaz.

## 5. Copy-paste yeni sohbet mesajı

> FareOyunu / TerraForge Mobile projesini GitHub'da sürdür. Depo `mehmetdem2005/FareOyunu`, dal `feat/terraforge-mobile-addon`. Önce `addons/terra_forge/DOCS_INDEX_TR.md`, `HANDOFF_START_HERE_TR.md` ve oradan bağlı tüm güncel MD belgelerini **repo içinden oku**; gerekiyorsa gerçek kodu kontrol et. v0.4.3-dev.2 snapshot: `bf5c1dde`, GitHub Actions CI 25/25 PASS (Linux Godot 4.7.2); Android cihaz GPU testi yok. Boyama ve obje yok, sadece profesyonel gerçekçi terrain; main ve kullanıcı veri dosyalarını koru. `NEXT_SESSION_IMPLEMENTATION_TR.md`'deki P1.3 Android kalite kapısını ve P1.4 ilk açık işe uygulamayla başla, test ekle, CI çalıştır, en son Markdown kayıtlarını güncelle. Telefon kullanıyorum; testleri GitHub CI üzerinden yap.

## 6. Tamamlanma statüsü

**Güncelleme:** İzole read-only sampler, kamera scheduler ve worker-thread async IO veri çekirdeğidir, CI 23/23 PASS; canlı terrain render/physics/Brush entegrasyonu **yapılmadı**. Belgeler GitHub'da commit edildikten sonra kodun regression CI sonucu ayrıca doğrulanır. Belgelerin kapsamı bugüne kadar konuşulmuş ve kodda görülebilen özellik/planları açık biçimde korumayı amaçlar; gelecekteki her küçük kararın otomatik kaydedildiğini varsaymayın.
