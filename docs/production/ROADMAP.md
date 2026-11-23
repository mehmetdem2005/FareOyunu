# Parçalı TO-DO ve faz kapıları (2026-11-23)

Durum anahtarı: [x] doğrulandı; [~] kısmen/engel var; [ ] başlamadı.
Birden fazla görev aynı istekte verilmiş olsa bile fazlar sırayla ilerler; sonraki fazın dosyaları erkenden yazılmaz.

## Faz 0 — temeller (şimdiki teslimat)
- [x] Sıfırdan FareOyunu/main başlat, feature branch oluştur.
- [x] Kaynak heightmap gerçek biçimini, boyutunu ve kaybını incele.
- [x] Yerelde tek kanallı float32 EXR üret; yazma/okuma değerlerini doğrula.
- [x] Kaynak/çıktı manifesti, çalışma politikaları, QA ve mimari/pipeline planları.
- [x] Converter'a yönelik sentetik otomatik test ve başlangıç CI tanımla.
- [~] EXR ikili veriyi repo asset yoluna koy: yalnızca yerel artifakt hazır, GitHub commit henüz yok.
- [ ] GitHub Actions üzerindeki CI yürütmesini incele ve sonuçlarını raporla (PR / run gerektirir).

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
