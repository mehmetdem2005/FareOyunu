# Parçalı TO-DO ve faz kapıları (gözden geçirme: 2026-11-23, v1.2)

Durum anahtarı: [x] doğrulandı; [~] kısmen/engel var; [ ] başlamadı.
Birden fazla görev aynı istekte verilmiş olsa bile fazlar sırayla ilerler; sonraki fazın dosyaları erkenden yazılmaz.

## Faz 0 — temeller (şimdiki teslimat)
- [x] Sıfırdan FareOyunu/main başlat, feature branch oluştur.
- [x] Kaynak heightmap gerçek biçimini, boyutunu ve kaybını incele.
- [x] Yerelde tek kanallı float32 EXR üret; yazma/okuma değerlerini doğrula.
- [x] Kaynak/çıktı manifesti, çalışma politikaları, QA ve mimari/pipeline planları.
- [x] Converter'a yönelik sentetik otomatik test ve başlangıç CI tanımla.
- [~] EXR ikili veriyi repo asset yoluna koy: yalnızca yerel artifakt hazır, GitHub commit henüz yok.
- [x] GitHub Actions üzerinde Phase 0 converter-tests başarılı: workflow run 45255819266; ayrıca 5 sentetik unit test yerelde geçti (2026-11-23).

## Faz 1 — sonraki açık kullanıcı onayıyla
- [ ] Godot 4.7.2 Mobile tam proje iskeleti ve engine-pin testleri.
- [ ] EXR'yi repo asset registry'ye bağla; yükleme/metadata checksum testleri.
- [ ] @tool tabanlı editör önizlemesi, dış kaynaktan konfigürasyon; Play gerektirmesin.
- [ ] Editör görünümü, shader/mesh/sahne veri gömülmeme denetimi.
- [ ] Hafıza, soğuk açılış, editörde değişiklik/undo/reload ölçümleri.

## Faz 2 — mimari karar sonrası
- [ ] Quadtree/clipmap/mesh tile seçeneklerini mobil cihazda ölçerek chunk/LOD stratejisi seç.
- [ ] Bağımsız streaming, LOD, cache, scheduler, mesh, collision ve world coordinate modülleri.
- [ ] Kenar continuity, negative coordinate, scale, off-by-one, teleport, concurrency ve cache eviction testleri.

## Faz 3 — dünya topoğrafyası
- [ ] En az dört ada için harici world layout + seed + kimlik sistemi.
- [ ] Güneydoğu ada bölge pozisyonu ve gerçek deniz seviyesi, dar geçitler/topolojik doğruluk.
- [ ] Bathymetry/shores/coastline, deniz/nehir bağlantı modeli; parça bazında onay.

## Faz 4 ve sonrası — ayrı uzmanlık bölümleri
- [ ] Okyanus ve su fiziği/grafikleri (bağımsız adımlar).
- [ ] Doğal çevre, malzemeler, ışık, bitki örtüsü, ses ve hava.
- [ ] Fare hareketi/animasyon, etkileşim, AI, kamerası, kontrol ve kullanıcı deneyimi.
- [ ] Cihaz ve görsel performans, erişilebilirlik, uzun oturum, kalite ve sürümleme.

## Kabul ilkesi
AAA hedefi, görsel kalite ve oyuncu deneyimi için test kanıtı olmadan "tamamlandı" sayılmaz. Sonraki fazlar bu teslimatın dışında.

## Faz 0B — AAA kalite açığı taraması (yalnız belge, şimdi)
- [x] Mevcut AGENTS/PIPELINE/ROADMAP/QUALITY/ENGINEERING/WORLD_ARCHITECTURE ve PR durumunu yeniden oku.
- [x] Godot/Android/GitHub resmi kaynaklarından üretim/test stratejilerini incele.
- [x] Tekrar eden dosyalar açmadan mevcut plan ve politikalara DOR/DOD, risk ve insani UX kapılarını ekle.
- [x] Teknik/oyuncu deneyimi/üretim kontrollerinin bağımsız kanıt gerektiğini belgele.
- [ ] Belgesel olmayan kontrollerin gerçek araç/cihaz entegrasyonu (kendi parçalarında yapılacak).

## Faz 1 için zorunlu önkoşul TO-DO (bir sonraki parça, henüz uygulanmadı)
- [ ] **Veri migrasyonu kararı:** eski 1536x1536 SE-01 heightmap, güncel 1254x1254 yumuşak kıyı f32 EXR ile karşılaştır; onaylı active revision'ı sabitle; source/output checksum ve EXR channel/linear/range doğrula, sonra manifest update yap.
- [ ] EXR'nin gerçekten repo yoluna girdiğini, import edildiğini ve hash kontrolünün geçtiğini kanıtla.
- [ ] Godot 4.7.2 editor ve export templates'ı sürüm/hash ile sabitle ve yerel/headless import kontrolünü çalıştır.
- [ ] Godot @tool preview için editor memory, undo/redo, import loop, scene dirty ve Play gereksizliği kalite kapısını tanımla; ilgili yerel testleri uygula.
- [ ] GitHub main branch protection/required checks durumunu **gerçek ayarlarla** doğrula; plan yazmak enforcement değildir.

## İlk oynanabilir vertical slice'dan ÖNCE (gelecek ayrı işler)
- [ ] Fare kamerası ölçeği, dokunmatik kontrol ve 5 dakikalık ilk oyuncu yolculuğu için UX hypothesis/test planı.
- [ ] Baseline cihaz matrisi: düşük/hedef/yüksek GPU, Android sürümü, 30/60 FPS bütçe seçimi, termal ve frame pacing veri formatı.
- [ ] Oynanabilir tek kıyı/yamaç/tepe rotası, ilk kullanıcı görevleri ve gerçek blind playtest.
- [ ] Save schema, crash-safe write, recovery, sürüm migration testleri (oyuncu ilerlemesi olduğunda).
- [ ] CI pipeline: format/lint -> Godot import/script parse -> deterministic unit/contract -> editor smoke -> Android export -> on-device visual/perf (nightly) -> approval.
- [ ] Risk matrix, performance and UX go/no-go thresholds, artifact hash ve reproducible build kanıtı.

## Dünya büyümeden ÖNCE (dört ada / deniz / içerik üretimi için)
- [ ] World coordinate origin/sea datum, world layout contracts, teleport/LOD seam/shore/bathymetry stress matrisi.
- [ ] Texture/material, flora/fauna, sound, props, VFX import pipeline; shader compilation, instancing, batching, impostor ve paketi büyütme bütçeleri.
- [ ] System-of-systems stres: streaming + collision + camera + ocean + gameplay + save + temperature.
- [ ] Player navigation, keşif, içerik yoğunluğu, algılanan ölçek ve backtracking testleri.
- [ ] Ses, UI, input alternatifleri, erişilebilirlik, lokalizasyon alanları ve onboarding doğrulaması.

## Release öncesi — geleceğe kayıt, şimdi yapılmayacak
- [ ] S0/S1 bug zero, escape hatch/rollback, reproducible/signed APK, symbol/hash kayıtları.
- [ ] Fresh install / upgrade / downgrade policy / yedek save restore, crash/ANR ve Android vitals takibi.
- [ ] Package size, kaynak lisansı, içerik doğruluğu, privacy/telemetry, bilinen sorun ve support/bug intake.
- [ ] Risk review ve gerçek kullanıcı kalite testi ile go/no-go kararı.

## Öncelik/erişim matrisi
**P0:** asset revizyonu, scene dışı veri, editor görünümü, Godot sürüm pin, cihaz uyumluluğu, acceptance proof.
**P1:** chunk/LOD/streaming ve collision tutarlılığı, mobile frame pacing/termal, kaynak kayıt/kurtarma, vertical slice UX, save ilerlemesi.
**P2:** genişleme içerik araçları, otomatik visual diff, telemetri, ileri erişilebilirlik, uzun dönem release optimizasyonu.

Bu maddeler mevcut sistemlerin ve yeni sektör uygulamalarının **planı**dır; “uygulandı” anlamına gelmez. Kullanıcı açıkça istemedikçe bir sonraki faza geçilmez.

## Faz 0C — Çok oyunculu dünya sınırları (2026-11-23, bu belge revizyonu)
- [x] Mevcut `AGENTS` + `WORLD_ARCHITECTURE` + `PIPELINE` + `QUALITY` + `ENGINEERING` kurallarını tekrar oku.
- [x] Godot 4.7 networking/dedicated server resmi dokümanlarından protokol ve authority risklerini gözden geçir.
- [x] TerrainData, visual chunks, simulation/physics, NetworkInterest, replication ve editor preview için bağımlılık yönünü yazılı sözleşmeye bağla.
- [x] QA'da client unload ≠ server despawn; LOD ≠ collider; low-end device ≠ gameplay authority testlerini ekle.
- [ ] Teknik modüller / ağ kodu / gameplay implementasyonu — kullanıcı ayrıca parça onayı verdikten sonra.

## Multiplayer için gelecekteki ayrı parça listesi
- [ ] P0 — World manifest + terrain asset revision handshake kararı; 1536² eski /1254² yeni heightmap sürümlerini karşılaştır; aktif kaynak onayı.
- [ ] P1 — TerrainData API ve immutable height sampler; editor preview ve headless server aynı veri sözleşmesi, ayrı client/server koşulları.
- [ ] P2 — Server authoritative collision/simulation, ayrı kinematik sorgu testleri; görsel chunk bulunmasa da collision çalışmalı.
- [ ] P3 — Client-only visual chunk streaming/LOD; render unload hiçbir entity ve server state'i silememeli.
- [ ] P4 — Network protocol ADR, server identity/auth, entity/world/region ID, interest management, snapshot/sequence/reconciliation; ayrı sunucu ve peer testleri.
- [ ] P5 — Dedicated headless server + en az iki client + network chaos test harness ve CI quality gates.
- [ ] P6 — Gerçek cihaz ve insan oyuncu vertical slice; gerçek ping/loss/termal/UX ölçümleri.
- [ ] P7 — Çeşitli oyuncu sayısı, farklı adalar, persistent world ve operasyonel server release/observability ancak önceki kapılar geçince.

**Bağımlılık uyarısı:** Multiplayer gereksinimi **şimdi mimariyi kısıtlar**, multiplayer mekaniklerini terrain ve chunk koduna gömmeyi haklı çıkarmaz. Bir parça onaylandığında yalnız o parçanın görevi yapılır.

## Faz 0D — Ayrı teknik plan belgeleri (2026-11-24)
- [x] Terrain veri ve canonical collision planını ayrı Markdown dosyasında tut.
- [x] Visual chunk/LOD/streaming planını ayrı Markdown dosyasında tut.
- [x] Dedicated server/network interest/replication planını ayrı Markdown dosyasında tut.
- [x] Çok oyunculu entegrasyon/chaos test planını ayrı Markdown dosyasında tut.
- [x] WORLD_ARCHITECTURE ve AGENTS'den ilgili planları bulmayı zorunlu/kolay hâle getir.
- [ ] Bu belgelere uygun terrain/chunk/network kodu ve testleri: sonraki açık aşamalarda ele alınacak.

## Faz 0E — Dünya üretimi ve modül eksiklikleri audit'i (2026-11-24)
- [x] [WORLD_CREATION_GAP_AUDIT.md](WORLD_CREATION_GAP_AUDIT.md) içinde 24 dünya oluşturma boşluğunu P0/P1/P2 olarak sınıflandır.
- [x] World topology, coordinate/precision, coast/bathymetry, data pipeline, editor authoring, terrain caves, hydro, biome, navigation, ecology, persistence ve packaging için domain ownership/kalite kapılarını belirle.
- [x] Yeni uzmanlık plan dosyalarını yalnız ilgili iş parçası başladığında oluşturma yaklaşımını koru.
- [ ] Öncelikli W01-W06 modüllerinin gerçek sözleşme ve implementasyonları — daha sonra, her biri ayrı onay ve PR.
- [ ] Çoklu ada, oyun içi dünya, biyom ve gerçek cihaz/oyuncu testleri — henüz uygulanmadı.

## Faz 1A — Dokusuz terrain önizlemesi (2026-11-24)
- [x] Dört son kaynak EXR için ayrı revision/SHA/gerçek boyut manifesti hazırlandı. Kuzey kaynak 1536x1024; diğer üçü 1254x1254. Eski 1536² SE manifesti korunmuştur.
- [x] Dört statik dokusuz harici GLB editor mesh preview ve dört .tscn + .tres tanımı Python'da üretildi; sahneye height/vertex dizisi gömülmedi.
- [x] Godot 4.7.2 Mobile `project.godot`, editor preview @tool ölçek kontrolü ve yeniden üretme aracı ZIP'te teslim edildi.
- [x] ZIP içeriğinde 6 yerel otomatik test geçti (EXR/sha, GLB topology/normal, material sıfır, dış sahne referansları).
- [~] GitHub dalında sahne, kaynak kodu ve manifest mevcut; **ikili EXR/GLB'ler GitHub'a commit edilmedi**, tamamı teslim edilen ZIP'te. Depo binary asset'ler eklenene kadar import edilebilir değildir.
- [ ] Godot 4.7.2 gerçek editör importu ve Play'e basmadan 3D görünürlük/Inspector güncelleme kontrolü (Godot binary bu çalışma ortamında kurulu değil).
- [ ] Android Mobile Renderer gerçek cihaz testi.
- [ ] Dünya yerleşimi, deniz, collider, chunk/LOD, NPC ve multiplayer **sonraki fazlar**; bu aşamada yapılmadı.
