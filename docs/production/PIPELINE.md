# AAA-yaklaşımlı üretim pipeline'ı — yaşayan plan v1.0

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
