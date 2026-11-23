# FareOyunu: bağlayıcı çalışma kuralları (v1.0, 2026-11-23)

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
