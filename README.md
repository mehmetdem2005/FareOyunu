# FareOyunu

Godot 4.7.2 stable / Mobile Renderer için hedeflenen çok adalı açık dünya fare oyunu.

## Durum
Aşama 0: kaynak heightmap incelemesi, üretim kuralları, mimari sözleşmeleri, kalite kapıları ve aşamalı plan. Oyuncu, deniz, chunk akışı, editör terrain önizlemesi **henüz uygulanmadı**.

Bu depo sıfırdan kurulmuştur; önceki Fare deposundan dosya alınmamıştır.

## Başlangıç sırası
1. AGENTS.md: her işe başlamadan oku.
2. docs/production/PIPELINE.md: işlem sırası ve durdurma kapıları.
3. docs/production/ROADMAP.md: yalnızca yetkilendirilen parça.
4. docs/architecture/WORLD_ARCHITECTURE.md: bağımlılık sınırları.
5. docs/policies/: kalite, değişiklik, test kuralları.
6. docs/assets/SE_HEIGHTMAP.md: kaynak veri kaydı ve eksik ikili dosya.

## Kaynak durumu
Sağ alt ada (SE-01) için EXR float32 üretildi ve yerelde doğrulandı. GitHub bağlayıcısının ikili dosya yükleme sınırı nedeniyle EXR **bu dalda henüz commit edilmedi**; dosya kullanıcıya ayrıca teslim edilir. Tam veri entegrasyonu onaylanana kadar arazi sahnesi oluşturulmaz.

## Dal politikası
main = korunan bütünleşme dalı. feat/, fix/, chore/, docs/ ve test/ ön ekleri kullanılır. Yeni özellikler küçük, konuya odaklı commit ve PR ile taşınır. Onay ve test olmadan main'e merge edilmez.
