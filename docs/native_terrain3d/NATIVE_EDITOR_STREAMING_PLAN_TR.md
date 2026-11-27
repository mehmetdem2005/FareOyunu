# Native editör streaming — güvenli politika prototipi

Son doğrulanmış editör paketi: 46043674834 / artifact 15220518777. Linux editöründe 8m Raise 3.205 örneği değiştirdi, merkez +3m, undo/redo başarılı; Android cihaz doğrulaması açık. Aktif fırça ve runtime kodu bu adımda değişmez.

## Aşama S1 — karar mekanizması (izole)
experiments/native_residency/residency_policy.gd. Saf metadata, hiçbir IO veya native mutasyon yok. Dünya koordinatları Vector2i, mevcut native 32x32 grid ve 64 aktif slot sınırı. Bölge dikdörtgenine en kısa XZ mesafesi. Yakın koruma <= yükleme < boşaltma: hysteresis. Dirty, undo/redo, aktif stroke, fizik için çağıranın sağladığı pin union. Bir çağrıda en fazla bir load veya eviction adayı. Doğrulanmamış kaynak yüklenmez/tahliye adayı olmaz. Yakın doğrulanmamış kaynakta fail closed. Bütçe gerçek ölçümlerden veya kullanıcıdan sağlanmalı; varsayılan fiziksel RAM tahmini yok. Staging cost yüklemeden önce bütçeye eklenir; tahliye gerçekleşmeden hayali bellek kredisi verilmez. Yalnız basınç veya bekleyen yük varsa tahliye adayı. Eviction burada veri silme yetkisi değildir. Henüz çalıştırılmış test veya profil ölçümü yok, paket içinde değil.

## Aşama S2 — güvenli native veri kaynağı
Editör projelerinde manifest ve immutable verified snapshots. Dirty editleri kaynak dosyasına otomatik yazma yok; kaynak kaybı/corruption fail closed, kullanıcıya görünür. Aynı koordinat için eski/yeni generation ayrımı, cancellation dedup. Snapshot kimliği, undo pin seti, stroke footprint+smooth halo, collision pin seti. Kaynak doğrulaması ile decode arasında değişim kontrolü. Fırça edit readiness yalnız bütün gerekli bölgeler mevcutken.

## Aşama S3 — native slot replacement
Mevcut Terrain3D v1.1.0 remove_region + save_directory semantiği dosya silmeye dönüşebilir ve GPU texture array/collision rebuild yaratır. Kullanma. Native C++ isolated fork: stabil slot ID, immutable catalog, boş slot/generation, layer texture update, atomic region indirection publication, eski referansların güvenli yaşam süresi, render ve collision transaction. GDScript'ten güvenli API yoksa aktif sistemde streaming yok. Shader ve collision mapping birlikte doğrulanmadan promote edilmez. Android native binary/toolchain ayrı iş; eski motor geri gelmez.

## Aşama S4 — editör entegrasyonu
Kamera anlamlı hareket edince veya budget/settings değişince plan; sürekli polling yok. S1 sonucu bir öneri. Pin union güncel olmalı, işlem öncesi tekrar doğrulama. Near editability first, far silhouette separate, byte/slot budget fail closed. Dirty/history/active/near never evict. Mevcut full resident mode varsayılan kalır; kullanıcı onaylı opt-in streaming ancak Android performans ve kayıpsızlık kanıtıyla. View presets ayrı ve korunur. No new benchmark requested.

## Açıklar
S1 kodu inactive, test edilmedi; S2–S4 uygulanmadı. RAM kazancı sıfır olarak ölçülmüş değil, hiç ölçülmedi; mevcut runtime unchanged. 22/43 + integration gate. Android fırça doğrulaması sürüyor.
