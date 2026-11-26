# TerraForge M10 — paired matrix candidate (not for distribution)
Pin: fdfa7f952186c4bbf22986814182ccfd8427f7a7; addon tree 8975712aa381cc9a227ce96da00a69977808dd32; 147 adapters. Pin is pending combined CI when prepared. No runtime changes. Previous I2 and M10 preflight branches untouched.

Manual start and fresh isolated session; quick: four M9 tests, 12 profiles (F16/F32, F32/I-G32, F32/I-H32 ABBA). Full: 147 regressions and 56 timing profiles, seven pairs with ABBA and BAAB in reversed block order; all same TFM2 fixture, 20 seconds each. Four extra F32 observer-off/on/on/off profiles are explicitly marked diagnostic, not normal performance samples. Report includes page cap, arm, block, flags. CI smoke checks all 60 at 5 seconds, identity, samples, flags, order, diagnostic export. Fixed-time profiles are not equal-work; M6 and M9 controlled tests are separate.

Remaining before final qualification: exact post-integration pin, rendered M9 result, 30-minute soak, actual Android background/foreground lifecycle, actual RSS/thermal/GPU availability (unknown if unsupported), release/export versus editor, actual device run. No phone request until final gate. Default A, cap2, page16 unchanged.

# TerraForge M10 — Ön doğrulama (telefon testi isteme)

Bu paket bir **CI ön doğrulama** paketidir; M9 ve son cihaz yeterlilik paketi değildir. Önceki I2 aracı ve manuel başlatma/JSON bütünlüğü korunur. Yeni terrain pin: 9fa7ff158dd156faf221174afde45d6ed24d456e. Addon tree: d72072c6b2ce43c14e4f928ca405575d4bd82dc2. Envanter 143 regresyon; eski 4 hızlı test ve 8/24 profil aynen korunur. Henüz gerçek cihaz çalıştırma istemiyoruz.

Final M10 planı: M9 sonuçlarına göre 16/32 sayfa, F / I-G / I-H bağımsız eşleştirilmiş ABBA/BAAB blokları; hedefli kısa ve kapsamlı tek paket, sabit iş karşılaştırması ile süreli profiller ayrı; normal ölçümde mikro gözlem kapalı, ayrı teşhis kolu açık. En az 30 dakika soak, gerçek Android arka plan/geri dönüş, ayrı export runtime ve editör, fizik ray/gerçek zemin güvenliği, RAM/RSS/termal ve GPU ölçümleri mevcutsa kaydet; yoksa null. Bu maddelerin uygulanması ve doğrulanması hâlâ açık. A varsayılanı ve cap2 değiştirilmez. M9 birleştirilince son pin ve envanter güncellenir. Bu dal eski I2 paketini değiştirmez.

# TerraForge I2 — hedefli cihaz karşılaştırması

Godot 4.7.2 Android editöründe ZIP'i tek klasöre çıkar, project.godot'u içe aktar ve Play. Başlat'a basmadan hiçbir test başlamaz, eski rapor okunmaz. Hedefli varsayılan: 4 I0/H3 testi (14 rota) ve 8 gerçek kamera profili (20 s/profil). Tam: 137 regresyon ve 24 profil; her aday için üç ABBA/BAAB blok. F, I-G cropped, I-H cropped. Aynı fixture, çözünürlük ve ayarlar. Profil eşit duvar süresi, iş sayıları ayrıca karşılaştırılır. Cihaz termal durumu ve GPU timestamp ölçülmez; RSS okunamazsa null. Tam seçenek de 30 dakika soak, gerçek arka plan/geri dönüş veya export runtime doğrulaması değildir. Özet ve ayrıntılı JSON kaydet. Isınma veya hata durumunda duraklat; eski oturum otomatik başlamaz. CI yalnız paket/adaptör doğrulaması; gerçek FPS için telefonda çalıştır.

Terrain pin: d7aa19b503497ae34298957e8d141409829fd828

CI: 24 profilin sıralaması ve rapor zinciri ayrı yazılımsal Mobile Renderer kontrolünde 5 s/profil ile sınanır. Telefon çalışması 20 s/profil kalır. Adaptör ön kontrolü bütün test sınıflarını yükler; test çalıştırmanın yerine geçmez.
