## Ürün kapsamı — kullanıcı netleştirmesi (27 Kasım 2026, bağlayıcı)
**TerraForge, genel amaçlı terrain oluşturma ve düzenleme aracıdır. Dört Havza yalnızca değiştirilebilir test/önizleme sahnesidir; nihai oyun haritası değildir. Şu an oyun geliştirmiyoruz.** Fare karakteri, joystick, fizik ve dolaşım yalnızca araçtan çıkan arazinin çalışma zamanı doğrulamasına hizmet eder. 4096², 64 bölge, 25 cm, 850 m, 7 LOD ve Dört Havza biyomları referans profilidir; ürünün sabit sınırları veya kullanıcı projelerine zorunlu ayarlar değildir.
- Araç tasarımı farklı heightmap, dünya boyutu, çözünürlük, seed, bölge düzeni ve materyal setlerine uyarlanabilir olmalı; mevcut formatın desteklemediği seçenekler destekleniyor gibi gösterilmez.
- Editör ve runtime önizleme ayrı sorumluluklar; mevcut kararlı runtime korunarak import, oluşturma, şekillendirme, kaydetme/yükleme, geri al/yinele, dışa aktarma ve performanslı önizleme iş akışları planlanır. Bunlar henüz gerçekleştirilmiş özellikler değildir.
- P1.8 performans çalışmaları aracı ve ürettiği araziyi iyileştirmek içindir. P1.9 jeomorfoloji/mikrodetay/biome geçişleri, P2.0 materyal ve boya özellikleri tekrar kullanılabilir araçlar olarak ele alınır; nihai oyun adalarını tasarlama görevi kapsam dışıdır.
- Oyun hikayesi, yapay zeka, canlı simülasyonu, multiplayer ve oyun içeriği kapsam dışı. Obje/bitki yerleştirme yalnız genel arazi editörü özelliği olarak ileride kapsamı netleşirse değerlendirilir.
- Başarı yalnız test sahnesi FPS'i değildir: düzenleme etkileşim gecikmesi, fırça/önizleme akıcılığı, veri doğruluğu, farklı arazi girdileri, güvenli kaydetme ve export da ürün kriteridir. Önceki cihaz ölçümleri test referansı olarak geçerlidir.

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

P1.7.4 aday: startup-only verification Thread, prepare_baked_regions await -> initialize -> load_baked_regions() consumes verified metadata. No gameplay streaming, native mutation main thread, worker joined. Paket/cihaz açık; 1.7.5–8 conditional.

P1.7.4 paket başarılı 46019414487 (11/43). P1.7.5–8 deferred/conditional for bigger world, not completed, no speculative background queue. P1.7.9 candidate exact resident membership, spawn and existing ray diagnostic; no extra steady-state ray. CI pending; then P1.7.10.

P1.7.9 paket başarılı 46020199322, artifact 15207522916; 12/43. P1.7.5–8 ertelenmiş ve tamamlanmış sayılmadı; P1.7.10 sırada. Cihaz doğrulaması açık.

P1.7.10 candidate: world shader bounds guard; render_coverage report (nominal outer tile half-width 544m vs camera far850m, not measured). No forced LOD8, near unchanged. Package/visual device validation pending. Next P1.8.1 source profile cost analysis. P1.7.5–8 remain deferred, not done.

P1.7.10 paket başarılı 46021022190 artifact 15208371670. P1.8.1 kaynak/topoloji analizi NATIVE_LOD_COST_AUDIT_TR.md; 14/43. Native snap ring dedup aday (native patch yok); set_mesh_lods/size runtime rebuild, default 16/7/.25 unchanged. P1.8.2 sırada. 4 deferred streaming tasks remain open.

P1.8.2 candidate: preview_range.gd + test preview UI, default reference, manual/adaptive opt-in camera far only; no native setters/worker. Device comparison not proven; actual editor integration pending. Next P1.8.3 after package.

P1.8.2 package passed 46022529495 artifact 15208633565, 15/43. P1.8.3 candidate exact endpoint/shift-zero sample reduction + exact stationary camera transform no-op. Morph/near/physics unchanged; package/device visual pending. Native dedup not implemented. Next P1.8.4.

P1.8.3 package successful 46023381680 artifact 15212205063, 16/43. P1.8.4 feasibility closed, implementation deferred (17/43); audit NATIVE_HORIZON_CULLING_AUDIT_TR.md. P1.8.5 candidate opt-in exact zero weight far material sampling, default reference. Package and device visual/FPS open. Next P1.8.6.

P1.8.5 CI 46023920638 successful artifact 15211800852, 18/43. P1.8.6 candidate manual 3D scale 100(default)/90/85 percent in preview; no autonomous downscale or FSR on GL. Device/editor open; next P1.8.7.

P1.8.6 CI 46024518373 successful artifact 15210593260, 19/43. P1.8.7 candidate thermal_monitor.gd Android API29+ status advisory, no worker/auto downscale, 30s sampling via existing HUD, unsupported/slow stop. Device bridge and query latency unverified. Next P1.8.8.

P1.8.7 package passed 46025159030 artifact 15211157179; 20/43. P1.8.8 candidate existing range controller hardened, context/full window guards and mean+tail acceptance, no second controller or automatic resolution/LOD downgrade. Package/device pending. P1.9 generic terrain authoring next; Dört Havza fixture only.

P1.8.8 package passed 46025759250 artifact 15210674580, 21/43. P1.9.1 candidate generic authoring/landform_tool.tscn F6, RF ridge/valley stamp, export, fixture unchanged. Not erosion or complete editor yet. P1.9.2 next.


## P1.9.1–3 — 27 Kasım 2026, paralel doğruluk CI
Package 46026392317 success (64 regions / 16,777,216 exact height samples; native bake 2590 ms, not FPS). Candidate 84a7ed8fb2bf281c0095c0535dfdd8b6bd6dc21c correctness run 46026922437: ridge, flow, micro all passed (3/3). Promote inactive reusable kernels only to active development branch; no editor or runtime call sites changed, no performance/default-quality promotion. P1.9.1 package + basic deterministic test complete (22/43); P1.9.2/3 kernel-only partial, UI/cancel/undo/region integration and device latency open. Existing user panel Terrain toggle, Brush switch, collapsible tool controls, quality, save/undo must survive integration. Next: bounded interactive integration and regional micro details; preserve stable runtime and legacy branch. Details: [P1_9_FLOW_MICRO_CANDIDATE_TR.md](P1_9_FLOW_MICRO_CANDIDATE_TR.md).

## Öncelikli düzeltme — orijinal TerraForge paneli (27 Kasım 2026)
Kullanıcı son ZIP'te yalnız upstream Terrain3D alt panelini gördü. Kök neden: paket workflow'u sadece addons/terrain_3d kopyalıyordu; repo kökündeki tam addons/terra_forge (316 dosya, önceki dal ile aynı) pakete dahil değildi. Düzeltme: tam eski addon byte-for-byte pakete kopyalanır, paket project.godot içinde yalnız TerraForge Mobile varsayılan etkinleştirilir, terraforge_workspace.tscn boş Node3D düzenleme başlangıcı eklenir. Native GDExtension ve play.tscn korunur; upstream editor plugin varsayılan kapalı. Eski panel hâlâ kendi legacy renderer'ıyla çalışır; native backend entegrasyonu ve yeni kernel bağlantısı henüz yok. Paket editör import kontrolü eklendi; telefon görünümü doğrulanmadı. P1.9 ilerlemesi 22/43; önce panel/native veri bağlama ve mevcut özelliklerin korunması, ardından yeni şekillendirme araçları. Orijinal addon/dal değiştirilmedi.

## Kullanıcı düzeltmesi — sadece native backend, eski panel görünümü
9ba31d1 legacy addon packaging kararı geçersiz. Paket yalnız upstream native extension ve yeni addons/terraforge_native içerir; eski motor/eklenti dahil edilmez. Orijinal panel düzeni/toolbar kodu uyarlanır, backend native RF region. İlk aday: +New 1×512 region .25m, 7 LOD/mesh16, mevcut world shader/mips, Raise/Lower/Smooth/Flatten, bounded sparse stroke undo/redo (8), native partial height layer update; save unique RF region snapshot readback, scene separately. No duplicate legacy mesh worker. Per-dab calc_height_range and upload can be costly; no measured editor latency or Android validation. Existing advanced tools, layers, profile selection disabled explicitly until migrated; no claim full parity. Native region boundary/multi-region, robust save and source migration remain open. Previous runtime code/fixture unchanged. 22/43; integration gate priority.
