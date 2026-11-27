# Yeni sohbette BURADAN BAŞLA — Native Terrain3D

**Aktif dal:** `feat/terraforge-terrain3d-runtime`
**Tek aktif plan:** [NATIVE_TERRAIN3D_MASTER_PLAN_TR.md](NATIVE_TERRAIN3D_MASTER_PLAN_TR.md)
**İlerleme:** [PROGRESS_TR.md](PROGRESS_TR.md)

Eski `addons/terra_forge/HANDOFF_START_HERE_TR.md`, `P1_5_MASTER_PLAN_TR.md`, `P1_5_11_HYBRID_MASTER_PLAN_TR.md`, `ROADMAP_MASTER_TR.md`, `REGION_STREAMING_PLAN_TR.md` ve diğer eski özel runtime belgeleri bu dalda ARŞİV niteliğindedir. Bunlardan sıradaki görev seçme; eski motoru tekrar entegre etme. Eski dalın belgeleri ve geçmişi silinmedi.
Kullanıcı mevcut native dünyayı beğendi. Çalışan paket commit'i `fdbf49b2b5c1e0133a050e2a5f5592011f1fbf2c`. Önce aktif plan ve ilerleme defterini, sonra son commit/CI sonuçlarını oku. 1.6.1–1.6.4 paket üretim hedefleri tamamlandı (46013911229); yeni runtime cihaz doğrulaması açık. Sıradaki 1.6.5. Kullanıcı onayı olmadan kapsamı daraltma, fazı tamamlanmış sayma, eski dalı değiştirme.

**Zorunlu:** [Mühendislik karar protokolü](ENGINEERING_DECISIONS_TR.md). Her görevden önce alternatifleri değerlendir; sonucu beklemeden gerekçeli karar ver, doğrulamayı karar yerine kullanma.

## Performans önceliği
ZIP boyutu hedef değil. Takılmasız kare akışı, hızlı açılış, bellek bütçesi ve fizik doğruluğu öncelikli. P1.6.3 öncesi karar protokolündeki sıkıştırma/I/O ayrımını oku.

## Yakın kalite kuralı
Oyuncu çevresindeki geometri, doku, fizik ve görüntü keskinliğini FPS uğruna sessizce düşürme. Global çözünürlük azaltımı varsayılan değil. Karar protokolü ve ana plandaki yakın kalite kabul kriterlerini uygula.

Güncel: P1.6.5 paket başarılı (46015224588); P1.6.6–7 birleşik bellek içi recorder aday. Cihaz davranışı ölçülmedi; sıradaki P1.6.6–7 paket sonucu, ardından P1.7.1 native array maliyeti.

P1.6 paket/uygulama kapanışı: 7/7, genel 7/43. Başarılı CI 46016265505, artifact 15205259073. Yeni runtime gerçek cihaz doğrulaması açık. Sıradaki P1.7.1 (native region ekleme/çıkarma ve GPU texture array yeniden oluşturma maliyetini incele); ölçümsüz agresif streaming/worker yok.

P1.7.1 tamamlandı: 8/43; NATIVE_RESIDENCY_AUDIT_TR.md zorunlu oku. Mevcut 64 resident region; add/remove streaming veya save_directory ile eviction yapma. Sıradaki P1.7.2. Cihaz timing açık.

P1.7.2 aday: terrain_runtime.gd build_region_index ve region_descriptor; native GPU ID yerine kararlı Vector2i. Metadata only, resident dünya korunur. Paket doğrulaması açık; sonraki P1.7.3.

P1.7.2 paket başarılı 46018260377 (9/43). P1.7.3 advisory memory inventory + başlangıç/elle export snapshot aday; device safe budgets unknown. Sıradaki paket sonucu; P1.7.4–8 gereklilik değerlendirmesi.

P1.7.3 paket başarılı 46018743594, artifact 15207231764; 10/43. Cihaz bellek bütçesi açık; sıradaki P1.7.4, gereklilik analizi önce. Resident dünya korunur.
