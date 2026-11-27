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
