# P1.5.1 — İzole arazi performans profili

> **GÜNCEL DEVİR — P1.5.1 profil aracı (24 Kasım 2026):** Kod SHA `73f3b7b078c0893bbe78d20a45d8989702028f78`, [28/28 Godot Linux CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955). [P1_5_1_PROFILE_TR.md](P1_5_1_PROFILE_TR.md) güncel teknik kayıt. Android gerçek cihaz ölçümü henüz YOK. Sıradaki kod görevi P1.4: immutable generation, copy-on-write region transaction, atomik publication ve crash-injection testleri; editör fırçası şimdilik read-only. Boya/obje yok, main ve kullanıcı TFH/TFL korunur. Önceki devir notları tarihsel kayıttır.

## Kullanım (Android Godot editör, klavye/terminal gerekmez)

1. FileSystem'de `addons/terra_forge/profiling/profile_scene.tscn` aç ve **Run Current Scene** kullan. Oyun sahnesine ekleme.
2. **Create isolated 256x256 sample** düğmesi yalnız benzersiz `user://tf_profile_...` TFH ve TFM1/TFR1 scratch dosyalarını üretir. İstersen mevcut doğrulanmış TFM1 klasörünün yolunu yaz; veri okunur, düzenlenmez. Fixture üretimi senkron ve süre ölçümüne dahil değil.
3. **Run strict full verification** ve **Run lazy on-demand** aynı kamera odak rotasında ayrı ayrı çalışır. Inspector'da varsayılan 20 s, 5–1800 s aralığı; 16 page, 4 job. Aynı parametrelerle ters sırada da tekrarla. OS disk cache temizlenmez; cold-cache garantisi yok.
4. **Save / show JSON report** en fazla son sekiz sonucu benzersiz user:// JSON dosyasına yazar; panel gerçek kaydetme yolunu gösterir. Dosyayı telefonun dosya yöneticisinden paylaş; permission/Android erişim henüz gerçek cihazda sınanmadı.

## Ölçüm sözleşmesi
- Open, manifest verify, ilk focus collision shape, shutdown: monotonic Time ticks. İlk shape hazır olması fizik raycast veya yürüme güvenliği kanıtı değil.
- Gerçek frame interval ve main-thread pump ayrı histogram; fixed 26 bucket, p50/p95/p99 **bucket upper bounds**, sample count, mean, max, overflow. Frame interval GPU süresi değildir.
- Worker IO: kabul edilen sonuçlar, başarı/başarısızlık dahil; iptal edilen job ve strict açılış taraması hariç.
- Linux/Android /proc/self/status VmRSS; process-wide 500 ms örnekli peak, erişim yoksa null. Godot debug static allocation ayrı; RSS ile karıştırılmaz. Baseline ve peak cihazdaki tüm süreçten etkilenir.
- Resident pages/tiles/vertices peak, cache evictions, worker errors, verified pages, focus frames without collision shape.
- JSON schema TF_PROFILE_1, OS/device/renderer/headless bilgisi. Veriler yalnız manuel rapor kaydıyla diske çıkar; otomatik ağ aktarımı yok.
- Fixture kaynak TFH/TFR1 korunur, legacy terrain davranışı değiştirilmedi. Varsayılan sahne kendi başına profil çalıştırmaz. Scratch dosyaları disk alanı kullanır.

## Kanıt
28/28 PASS: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424665955 .
test_profile_scene.gd gerçek headless sahneyi her iki modda çalıştırır, histogram uçları, null RSS parse, collision, IO örnekleri, page limit, JSON export ve manifest değişmezliğini kontrol eder. Android GPU, RSS karşılaştırması, thermals, 30 dk soak, dev dünya kapasitesi henüz ölçülmedi.

## Sıradaki
P1.4 generation-pinned write transaction. Mevcut strict/lazy readonly kaynakları ve TFH/TFL korunmalı. Önce scratch dünyada copy-on-write sayfa seti, atomik manifest/generation publication, hata ve crash injection; eski reader eski generation'ı görmeye devam etmeli. Android profil sahnesi gerçek cihaz doğrulaması paralel açık.
