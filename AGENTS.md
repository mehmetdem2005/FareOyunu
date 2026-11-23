# FareOyunu: bağlayıcı çalışma kuralları (v1.2, 2026-11-23)

## Her görevden ÖNCE
- README, PIPELINE, ROADMAP, mimari sözleşme ve ilgili policies dosyalarını yeniden oku.
- Mevcut branch/HEAD/çalışma ağacı/PR, kullanılan Godot sürümü ve kaynak dosya kimliğini doğrula.
- İsteği kabul kriterlerine çevir; kapsamı tanımla; bağımlılık ve riskleri kaydet.
- Birden fazla bağımsız istek varsa ROADMAP üzerinde yapılacaklar listesi çıkar, sıralı parçalara ayır; kullanıcı talep etmedikçe sonraki parçaya geçme.
- Başka proje/depo/daldan içerik taşıma; onaysız varsayım, gizli değişiklik, kapsam şişirme yok.

## Her görev SIRASINDA
- Sahne (.tscn) yalnızca harici script, .tres, asset, registry ve konfigürasyonları referanslasın. Büyük dizi, mesh, heightmap, chunk state, dünya parametresi veya shader kodunu sahneye gömme.
- Domain modüllerini tek sorumluluklu kur; bağımlılıklar açık ve test edilebilir olsun; editör önizlemesi runtime sistemine veya Play tuşuna bağımlı olmasın.
- Değişiklikleri küçük ve birimsel tut. Conventional Commits kullan; ilgisiz değişiklikleri tek commit'e koyma.
- Kaynak asset'i silme/üzerine yazma; sürüm, provenance, hash ve dönüşüm yöntemini kayıt altına al.
- Performans iddiasını ölçüm olmadan yapma. Android GPU/CPU/RAM/VRAM/ısı için gerçek cihaz profili şarttır.
- Her özellikte unit, integration, editor, rendering, soak, adversarial test açılarından uygun olanı planla.
- CI'nin geçmediği, cihazda görülmediği veya eksik ikili verisi olan bir işi tamamlandı diye etiketleme.

## Her görev SONUNDA
- Kaynak, dönüştürme, Godot headless import, editor görünümü, farklı cihaz, performans ve asset doğrulamalarının hangileri geçti/kaldı yaz.
- ROADMAP, politikalar, kalite kriterleri ve ADR'leri gerektiğinde sürümleyerek iyileştir; aynı kural dosyalarını tekrar tekrar oluşturma.
- Değişen dosyalar, branch/commit/PR ve kalan engelleri açıkça bildir.
- Talep sınırında dur. Bir sonraki aşamaya otomatik atlama.

## Kritik kabul koşulları
Godot 4.7.2 stable + Mobile hedefi; editör içinde terrain görünür; minimum dört ada konsepti; ayrık chunk/LOD/streaming/deniz; dünya verisi harici; kesintisiz ve adil oyuncu deneyimi. Bunlar tasarım hedefidir, mevcut kodda uygulanmış özellikler değildir.

## Üretim/oyuncu kalite kapısı — 2026-11-23 revizyonu
- Yeni göreve başlamadan tek satırlık test listesi değil, **Definition of Ready**, **Definition of Done**, risk seviyesi, oyuncu faydası ve ölçüm yöntemi oluştur. Maliyet/performans/UX çakışması varsa çözmeden implementasyona geçme.
- Her proje değişikliğinde G0-G9 kontrollerinden hangilerinin gerekli olduğunu işaretle; doğrulanmamış olanı kanıtlandı diye yazma. İnsan playtest, Android cihaz ve editor önizlemesi, otomatik CI başarısından bağımsızdır.
- Birden çok onay bekleyen parça varsa ROADMAP'de beklet; kullanıcı onayı olmadan başka adıma atlama. Yeni kural ihtiyacında mevcut politika belgelerini güncelle; dosya çöplüğü yaratma.
- Görsel heightmap ve fiziksel gerçek DEM ayrımını koru; orijinal 1536² ile son 1254² varyantını metadata/hash olmadan birbirinin yerine kullanma.

## Çok oyunculu ve görsel chunk bağımsızlığı — zorunlu v1.2
- TerrainData yalnız dış kaynak yükseklik/world sample hizmeti verir. RPC, peer, görünür chunk, render kamerası veya GPU yükleme kodu içeremez.
- VisualChunkManager yalnız client visual loading/LOD/cache/render işini yönetir. Server world state, authoritative collision, actor lifetime, inventory, damage, replication interest veya object ownership değiştiremez.
- SimulationAuthority ve dedicated headless server, istemcinin chunk/LOD durumunu bilmeden gameplay ve collision'ı çalıştırır; doğruluk ekran/cihaz kalitesine göre değişemez.
- NetworkInterest/AOI, network replication ve transport ayrı arayüzlerdir; visual chunk görünürlük hesaplarından veya player FPS'den authoritative state kararları çıkarılmaz.
- İlk prototipte server authority, protocol/world revision handshake, stable entity IDs ve late join/reconnect durumları güvenlik/QA önkoşulu olarak planlanır.
- Bug önleme kuralı: yalnız happy-path değil, cross-module contract, packet loss/reorder, malicious RPC, hızlı chunk unload, low-memory ve iki+ client headless testleri olmadan tamamlandı denmez.
- Yeni asset, shader, terrain veya chunk optimizasyonu multiplayer regresyon risk analizi ve gerekli testleri tetikler. Uygulanmamış güvenlik/testler asla tamamlandı diye yazılmaz.

## Ayrı plan dosyalarını okumadan kod yazma (2026-11-24)
- Terrain/heightmap/collider işi öncesinde `docs/architecture/TERRAIN_ARCHITECTURE.md` okunur.
- Görsel chunk/LOD/streaming işi öncesinde `docs/architecture/CHUNK_STREAMING_ARCHITECTURE.md` okunur.
- Multiplayer/auth/replication/network interest işi öncesinde `docs/architecture/MULTIPLAYER_ARCHITECTURE.md` okunur.
- Modüller arası değişiklikte `docs/testing/MULTIPLAYER_INTEGRATION_TEST_PLAN.md` ve `docs/policies/QUALITY.md` birlikte okunur.
- Genel dünya invariants için `docs/architecture/WORLD_ARCHITECTURE.md` esastır; alt sistemlerin detayları kendi planlarında sürümlenir. Çelişki ADR ile çözümlenir. Kopyalanmış politikalar oluşturulmaz.

## Dünya tasarımı ve yeni modül açma kontrolü (2026-11-24)
- Ada yerleşimi, kıyı/deniz tabanı, hidroloji, biyom, navmesh, foliage, world editor veya world persistence ile ilgili yeni bir göreve başlamadan `docs/production/WORLD_CREATION_GAP_AUDIT.md` aç; kapsamdaki W01-W24 boşluk, sahibin modülü, önkoşulları ve kalite kapısını oku.
- Yeni dünyaya yönelik alan ayrı bir uzmanlık planı gerektiriyorsa yalnız o alanın işi başlatılınca ayrı .md dosyası oluştur; başta boş planlar üretme. İçeriği mevcut WORLD_ARCHITECTURE/PIPELINE/ROADMAP ile linkle; politika kopyalaması yapma.
- Kritik veri contract'ları ve gerçek cihaz/oyuncu testleri eksikken bitmiş dünya veya AAA kalitesi iddia etme. Alt modül tamamlanmadan sonraki fazı otomatik başlatma.
