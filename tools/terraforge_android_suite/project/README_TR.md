# TerraForge M10 — Ön doğrulama (telefon testi isteme)

Bu paket bir **CI ön doğrulama** paketidir; M9 ve son cihaz yeterlilik paketi değildir. Önceki I2 aracı ve manuel başlatma/JSON bütünlüğü korunur. Yeni terrain pin: 9fa7ff158dd156faf221174afde45d6ed24d456e. Addon tree: d72072c6b2ce43c14e4f928ca405575d4bd82dc2. Envanter 143 regresyon; eski 4 hızlı test ve 8/24 profil aynen korunur. Henüz gerçek cihaz çalıştırma istemiyoruz.

Final M10 planı: M9 sonuçlarına göre 16/32 sayfa, F / I-G / I-H bağımsız eşleştirilmiş ABBA/BAAB blokları; hedefli kısa ve kapsamlı tek paket, sabit iş karşılaştırması ile süreli profiller ayrı; normal ölçümde mikro gözlem kapalı, ayrı teşhis kolu açık. En az 30 dakika soak, gerçek Android arka plan/geri dönüş, ayrı export runtime ve editör, fizik ray/gerçek zemin güvenliği, RAM/RSS/termal ve GPU ölçümleri mevcutsa kaydet; yoksa null. Bu maddelerin uygulanması ve doğrulanması hâlâ açık. A varsayılanı ve cap2 değiştirilmez. M9 birleştirilince son pin ve envanter güncellenir. Bu dal eski I2 paketini değiştirmez.

# TerraForge I2 — hedefli cihaz karşılaştırması

Godot 4.7.2 Android editöründe ZIP'i tek klasöre çıkar, project.godot'u içe aktar ve Play. Başlat'a basmadan hiçbir test başlamaz, eski rapor okunmaz. Hedefli varsayılan: 4 I0/H3 testi (14 rota) ve 8 gerçek kamera profili (20 s/profil). Tam: 137 regresyon ve 24 profil; her aday için üç ABBA/BAAB blok. F, I-G cropped, I-H cropped. Aynı fixture, çözünürlük ve ayarlar. Profil eşit duvar süresi, iş sayıları ayrıca karşılaştırılır. Cihaz termal durumu ve GPU timestamp ölçülmez; RSS okunamazsa null. Tam seçenek de 30 dakika soak, gerçek arka plan/geri dönüş veya export runtime doğrulaması değildir. Özet ve ayrıntılı JSON kaydet. Isınma veya hata durumunda duraklat; eski oturum otomatik başlamaz. CI yalnız paket/adaptör doğrulaması; gerçek FPS için telefonda çalıştır.

Terrain pin: d7aa19b503497ae34298957e8d141409829fd828

CI: 24 profilin sıralaması ve rapor zinciri ayrı yazılımsal Mobile Renderer kontrolünde 5 s/profil ile sınanır. Telefon çalışması 20 s/profil kalır. Adaptör ön kontrolü bütün test sınıflarını yükler; test çalıştırmanın yerine geçmez.
