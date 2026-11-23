# AAA-yaklaşımlı üretim pipeline'ı — yaşayan plan v1.2

Bu plan AAA ölçeğinde rol disiplini ve kanıt standardı hedefler. Tek başına bu dosya AAA kalitesi garanti etmez.

## A. İstek ve karar hattı
INTAKE -> kaynak/doğrulama -> kapsam/bağımlılık -> risk/ADR -> faz checklist -> feature branch -> uygulama -> statik test -> entegrasyon -> görsel+cihaz testleri -> performans -> inceleme -> PR -> merge -> geriye dönük değerlendirme.

Her kapıda gerekli kanıt eksikse DUR; sonraki işe atlama.

## B. Her işin zorunlu dosyaları
- AGENTS.md: çalışma kuralları ve kapsam.
- ROADMAP.md: küçük görevler, bekleme ve önkoşullar.
- docs/policies/ENGINEERING.md ve QUALITY.md: sürekli iyileşen teknik/politik kalite standardı.
- docs/architecture/WORLD_ARCHITECTURE.md: modül arayüzleri ve sahiplik.
- Gerekirse docs/adr/NNNN-konu.md: performans, format, ölçek veya kullanıcı deneyimini etkileyen tasarım kararı.
- Modül gerçekten uygulanırken: modül/README.md, config/resources, tests ve ölçüm dosyaları o modüle özel açılır. Şimdiden boş dosya iskeletleri üretme.

## C. Git ve PR kapısı
Başlangıç: main HEAD, repo durumu ve var olan açık iş kontrolü. Bir özellik = bir feature branch; tarih yerine anlamlı ad; Conventional Commits; PR açıklamasında neden, kapsam, risk, test raporu, görsel kanıt, geri alma yolu. main'e doğrudan feature commit yok. Force push ve history rewrite yok. CI/inceleme tamamlanmadan merge yok.

## D. Kalite katmanları
G0 kaynak doğruluğu: uzantı yerine codec, bit derinliği, hash, boyut, sıra, koordinat dönüşümü, metadata.
G1 statik kalite: schema/syntax, asset lint, drift ve bağlantılar, yasak sahne içine gömülmüş veri.
G2 otomatik birim ve bileşen: deterministik seed, sınır değerleri, hatalı giriş.
G3 Godot 4.7.2 headless import ve test: resource/script yüklenmesi, sahne ağacı, memory/perf smoke.
G4 editörde doğrulama: Play tuşuna basılmadan mesh; inspector ayarları; editor reload; undo/redo; cache silme.
G5 render/doğruluk: Mobile renderer, farklı GPU ve ekran çözünürlüklerinde ekran görüntüsü, LOD/seam/underwater.
G6 cihaz kalitesi: frame time p50/p95/p99, RAM/VRAM, upload spikes, termal throttling, soğuk açılış, uzun oturum.
G7 üretim gözden geçirme: regresyon, kullanıcı yönlendirme/erişilebilirlik, rollback ve release notu.

G4-G7 headless ile kanıtlanamaz; ayrı gerçek editör/cihaz oturumu gerekir.

## E. CI büyüme planı
Aşama 0: converter unit test, manifest/sözleşme kontrolü, SHA ile sabit checkout, salt-okunur izin.
Aşama 1: Godot 4.7.2 resmi binary pin, import, script parsing, editör data referansları.
Aşama 2: scene-inlining kontrolü, terrain seam/LOD/chunk property ve falsification testleri.
Aşama 3: Android export smoke, ekran görüntüsü için GPU/renderer runner, profilleme artifaktları, soak ve budget regression.
Tüm testler ayrışmış işler: lint != logic != editor != rendering != device. CI başarıları yalnızca koşan testleri kapsar.

## F. Uzmanlık akışları
Creative direction/worldbuilding; game design & pacing; player UX/accessibility; level/world design; terrain/GIS; rendering/shaders; technical art/materials; environment art/vegetation; character anatomy/rig/animation; physics/collision; AI/gameplay; water/ocean; audio/acoustics; narrative; UI; optimization/profiling; tools/editor; build/release; QA/test engineering; telemetry; security/license/provenance. Her disiplin için ihtiyaç doğduğunda ayrı modül, sahibi ve ölçülebilir kalite hedefi aç.

## G. Değişiklik yönetimi
Bir darboğaz, başarısız test veya yeni gereksinim çıktığında ilgili politika/planı in-place sürümleyerek güncelle. Her revizyon neden/kanıt/tarih ile kaydedilir. Kapsam dışı öneriler ROADMAP Backlog'a alınır; kendiliğinden uygulanmaz.

## H. Eksik üretim disiplinleri — genişletme v1.1 (2026-11-23)
Bu bölüm planlama aşamasıdır; aşağıdaki kapılar henüz otomasyonla uygulanmış değildir.

### H1. Dikey kesit önce, tam dünya sonra
- **Proof of concept (PoC):** tek EXR ve editor preview yeteneğinin teknik olarak mümkün olduğunun kanıtı.
- **Vertical slice:** oynanabilir fare ölçeğinde küçük, cilalı kıyı→yamaç→tepe rotası; kontrol, kamera, materyal, ses, kayıt, performans ve UX beraber sınanır. Dört adaya yayılmadan önce karar kapısı.
- **Content production:** kanıtlanmış modüllerle diğer adalara ancak kabul edilen kalite/bütçe sınırlarında ölçeklenir. Haritanın büyük olması oynanışı kendi başına güçlendirmez.
- **Alpha:** tüm temel oyun döngüleri birbiriyle çalışır; geçici içerik olabilir.
- **Beta:** içerik bütünlüğü, hata azaltma ve oynanabilirlik; belgesiz özellik ekleme yok.
- **Release candidate:** bilinen kritik arıza yok; sürüm, test kanıtı, geri dönüş ve destek planı sabitlenmiştir.

### H2. Karar, sahiplik ve objektif kapılar
Her modül ticket/PR'ında: owner rolü, neden/oyuncu değeri, dahil-hariç kapsam, giriş bağımlılıkları, **Definition of Ready**, ölçülebilir **Definition of Done**, test/kanıt linki, risk/severity, rollback, dokunduğu asset/sözleşme, uyumluluk matrisi ve bir sonraki karar. Roller (rendering, level art, gameplay, QA, producer vs.) sorumluluk tanımlar; tek kişi birden çok rolü üstlenebilir, bağımsız eleştirel inceleme yine yapılır.

**Ready:** gerçek asset ve kabul kriterleri belli, ilgili veri sürümü doğrulanmış, Godot sürümü doğrulanmış, risk ve test stratejisi yazılmış.
**Done:** unit/integration/editor/cihaz kapsamından ilgili testler tamam; sonuçlar tekrar üretilebilir; perf & UX bütçesi ölçülmüş veya açık blocker; lisans/provenance ve dokümanlar güncel; kullanıcı onayı; onaysız kapsam yok.

### H3. Kanıt katmanları ve release kararları
- G8 **oyuncu deneyimi:** first-time user experience, kamera/kontrol, fare algısı, okunabilirlik, navigasyon, özgürlük/amaç dengesi, tekrarlama ve erişilebilirlik; gerçek kör/ilk-kez oyuncu testleri.
- G9 **sürüm ve kurtarma:** deterministik build, package/signing, versiyon, kurulum/güncelleme, save migration, crash/ANR ve hata raporu, roll-back planı, dağıtım öncesi go/no-go.
- CI green yalnız makinenin test ettiği koşulları kanıtlar. G4 editor, G5 GPU visual, G6 termal, G8 insan playtest olmadan AAA veya cihaz doğrulaması iddia edilmez.
- Faz özetinde **done / unverified / blocked / deferred / rejected** etiketlerinden biri ve kanıt zorunlu.

### H4. Kalite ve üretim maliyeti bütçeleri
Device-tier tanımı (low / target / high), 30/60 FPS hedefi ve RAM/VRAM/depolama/CPU/GPU/ısı/işlemci batarya bütçeleri gerçek cihaz ölçümünden sonra ADR ile belirlenir. Başlangıç hesabı: 30 fps = 33.33ms, 60 fps = 16.67ms kare süresi; bu hedefler değil matematiksel referanslardır. Ortalama FPS tek başına geçiş kriteri değil: p50, p95, p99, jank/hitch, shader compilation, streaming upload, editor latency, overdraw ve termal sürdürülebilirlik raporlanır.

### H5. Tek kaynaktan üretim, veri ve sürüm izlenebilirliği
Her kaynak: asset ID, ada/lokasyon, sürüm, özgün hash, codec gerçek pixel type, kanal, çözünürlük, renk/lineer dönüşümü, autor/izin, dönüşüm kod sürümü, hedef hash, importer parametreleri, önceki sürüm ve geçiş kararı. İçerik editörden değiştirilebilmeli ancak editör cache veya .tscn büyük veri deposu olamaz. Veri manifest değiştiyse downstream invalidation ve yeniden test zorunlu.

### H6. Bütçe ve zaman yönetimi
Prototip hedefi, sprint olmayan küçük bir feature queue, risk register, dependency map, değişiklik maliyeti, teknik borç limiti, build süresi/CI dakika maliyeti, asset paket boyutu, mobil depolama ve teslim tarihi aralığı gözetilir. Kanıtsız “AAA” etiketine zaman harcanmaz. Üretimi durduran kalite borcu yeni özellik önüne alınır.

### H7. Bilinen açıklar ve öncelikli takvim
1. Şimdi: DOD/DOR, risk matrisi, oyuncu kalite kriteri, üretim kapıları, sürüm izleri (yalnız belgeler).
2. Sonraki teknik parça: eski 1536² asset manifest ↔ yeni 1254² yumuşak sahil f32 EXR farkı uzlaştırma; önce gerçek source/output checksum ve metadata, sonra asset'i GitHub'a bağla.
3. İlk editor+terrain parçası: Godot 4.7.2 binary hash ve @tool lifecycle/safe preview.
4. İlk oynanabilir vertical slice: gerçek oyuncu testleri, sürüm-kayıt/geri yükleme ve cihaz bütçesi.
5. Diğer adalar sonra: dünya sürekliliği, büyük ölçek ve UX doğrulanınca.

### H8. Referanslar (dış doğrulama, 2026-11-23)
- Godot Mobile/Compatibility renderer sınırları: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot editörde kod çalıştırma: https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html
- Android performans/termal: https://developer.android.com/games/optimize
- Android vitals: https://developer.android.com/games/optimize/vitals
- GitHub branch protection: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches
- Game Accessibility Guidelines: https://gameaccessibilityguidelines.com/full-list/

## I. Çok oyunculu dünya entegrasyon kapısı — v1.2
**Mimari belgeler önce:** WORLD_ARCHITECTURE'daki TerrainData/VisualChunkManager/SimulationAuthority/NetworkInterest/Replication sınırları kabul edilir; yeni sistem bu sınırların dışına çıkarsa ADR ve kalite incelemesi yapılmadan uygulanmaz.

**Sıralama (implementasyon değil):**
1. TerrainSource + world manifest erişim sözleşmesi; server ve client aynı logical terrain revizyonunu tanır.
2. Authoritative Physics/Simulation sorguları görsel tile'dan bağımsız; dedicated headless testler.
3. VisualChunkManager, renderer ve LOD sadece istemci; bağımsız boşaltma/yükleme mock testleri.
4. NetworkAuthority + protokol, snapshot/revision handshake, auth, RPC validation ve NetworkInterest sözleşmesi ayrı.
5. İki istemci + server entegrasyonu; packet loss/jitter/late join/desync + farklı LOD/telefon testleri.
6. Vertical slice gameplay ve gerçek cihaz ölçümleri; ancak sonra ölçeklendirme.

**Bağımlılık kontrolü:** `terrain-data-contract` -> `authoritative-physics` ve `visual-chunk-only` birbirinden bağımsız. `network-interest` -> `replication-protocol` -> `multi-peer-integration` -> `device-e2e`. Basamak atlanmaz ve tek başarı hepsine uygulanmaz.

**Protokol kararı için ADR:** dedicated vs listen-server (öneri dedicated), server tick, maksimum oyuncu, transport, auth, interest radius/shape, state snapshot strategy, prediction/reconciliation, anti-cheat threat model, disconnection policy, authoritative coordinate/origin model, dynamic world mutation. Benchmark ve prototip olmadan değerler kesinleştirilmez.

**Değişiklik/QA kıstası:** chunk/LOD değişikliği multiplayer contract testini; terrain revision değişikliği server-collision ve handshake testini; replication değişikliği headless multi-peer regression'ı tetikler. Her feature'ın PR'ında hangi çapraz testlerin koştuğu yazılır.

**Dağıtım riski:** server ve client farklı release sürümleri arasındaki protokol/asset compatibility kontrollü yürütülür; onaysız eski client'a yeni dünya gösterilip state bozmasına izin verilmez.

**Kapsam:** Bu revizyon yalnız belge ve yapılacaklar listesi değişikliğidir; server/client/terrain/chunk uygulama kodu eklenmemiştir.
