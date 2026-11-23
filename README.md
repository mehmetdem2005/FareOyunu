# FareOyunu

Godot 4.7.2 stable / Mobile Renderer için hedeflenen çok adalı açık dünya fare oyunu.

## Durum
Aşama 1 textureless terrain preview kodu ve dört harici GLB/EXR kaynağı için hazırlık. Editor görünümü gerçek Godot cihazında henüz kanıtlanmadı. Deniz, chunk, fizik ve multiplayer uygulanmadı.

Bu depo sıfırdan kurulmuştur; önceki Fare deposundan dosya alınmamıştır.

## Başlangıç sırası
1. AGENTS.md: her işe başlamadan oku.
2. docs/production/PIPELINE.md: işlem sırası ve durdurma kapıları.
3. docs/production/ROADMAP.md: yalnızca yetkilendirilen parça.
4. docs/architecture/WORLD_ARCHITECTURE.md: bağımlılık sınırları.
5. docs/policies/: kalite, değişiklik, test kuralları.
6. docs/assets/SE_HEIGHTMAP.md: kaynak veri kaydı ve eksik ikili dosya.

## Kaynak durumu
Dört adanın önceki EXR'leri 240–256 ayrı yükseklik seviyesi taşıyordu. Yeni sürekli FLOAT32 v2 heightmap'ler (810.622–906.051 farklı değer) hesaplanarak yeniden üretildi. Bunun fiziksel ölçülmüş arazi detayını geri getirmediği belgelenmiştir. Github dalındaki metin dosyaları yüklenmiştir; ikili 4 EXR + 4 GLB yalnız indirme ZIP'indedir. GitHub tek başına Godot'a import edilebilir değildir.

## Dal politikası
main = korunan bütünleşme dalı. feat/, fix/, chore/, docs/ ve test/ ön ekleri kullanılır. Yeni özellikler küçük, konuya odaklı commit ve PR ile taşınır. Onay ve test olmadan main'e merge edilmez.

Yeni kaynak üretimi: `tools/terrain/reconstruct_continuous_heightmaps.py`; ayrıntılar: `docs/implementation/TERRAIN_FLOAT32_V2.md`. Yeni yükseklikler yalnız görsel preview içindir; gerçek dünya ölçeği ve collision yetkisi oluşturulmadı.
