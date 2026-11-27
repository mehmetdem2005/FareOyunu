# Native Terrain3D — İlerleme Defteri

## 27 Kasım 2026 — Plan onaylandı
- P1.5 native temel: kullanıcı cihazında Dört Havza V2 açıldı, dokulu arazide gezildi ve JSON alındı. Kalan riskler ana planda.
- P1.6–P2.0: 0/43 plan adımı tamamlandı (bu sayım yalnız yeni plan içindir).
- P3.0/P4.0: plan başlıkları, alt adımlar açık.
- Sıradaki: 1.6.1 çalışan referansı ayrı güvenli dalda koruma.
- Bu commit yalnız belge kaydı; çalışma kodu, eski dallar, paket ve benchmark politikası değiştirilmedi.
- Referans commit: `fdbf49b2b5c1e0133a050e2a5f5592011f1fbf2c`.

Her sonraki geliştirmede tarih, adım numarası, commit, durum, ölçüm/kanıt, karar, risk ve sıradaki adım kaydedilir.

## P1.6.1–1.6.2 — 27 Kasım 2026
- 1.6.1 tamamlandı: stable/native-terrain3d-dort-havza-v2 dalı, fdbf49b2b5c1e0133a050e2a5f5592011f1fbf2c commit'ine sabitlendi.
- 1.6.2 aday uygulama: paket sırasında aynı Float32 dünya native 64 .res bölgesine dönüştürülür; 16.777.216 örneğin kayıpsız serileştirilmesi bit düzeyinde kontrol edilir. SHA256 manifesti; Android'de açık dosya isimleri ile native yükleme; tek toplu update_maps. Ham heightmap paketten çıkar. Eksik/bozuk bölge fail-closed. Dünya, materyal, LOD, fizik ayarları aynı. Yeni benchmark yok; paket üretim doğrulaması açık. Gerçek cihaz başlangıç hızlanması henüz ölçülmedi.
- 1/43 tamamlandı; 1.6.2 doğrulama bekliyor. Sonraki: 1.6.2 paket sonucu ve 1.6.3 kopyalar/maliyet.

## 27 Kasım 2026 — P1.6.2 karar ve paket sonucu
- CI 46011507225 başarıyla tamamlandı; 64 native bölge ve 16.777.216 Float32 örneğin tamamı bit düzeyinde eşleşti. Sunucu bake 2002 ms; telefon açılışı ölçülmedi. ZIP 80.989.685 bayt. Import logunda Vulkan VK_KHR_surface ve ERR_CANT_OPEN kayıtları mevcut; GL bake tamamlandı.
- Paket üretim hedefi tamamlandı: 2/43 (P1.6 2/7). Yeni native yükleyicinin gerçek cihaz doğrulaması açık; stabil referans önceki sürüm.
- Kullanıcı talimatıyla mühendislik karar protokolü ve P1.6.2 alternatif karşılaştırması kaydedildi. Sıradaki 1.6.3: ölçüm ayrımı ve kopya maliyeti. Yeni benchmark/paket başlatılmadı.

## 27 Kasım 2026 — Kullanıcı performans önceliğini kesinleştirdi
- ZIP boyutu hedef olmaktan çıkarıldı. Takılma, uzun kare, açılış ve sürdürülebilir FPS öncelikli. Disk boyutu yalnız cihaz kapasitesi açısından sınır. Karar protokolü ve ana plan güncellendi. 2/43; sıradaki P1.6.3. Bu commit belge değişikliği; runtime ve CI değişmedi.

## 27 Kasım 2026 — Yakın alan kalite şartı
- Yakın grafik, geometri, doku ve fizik kalite koruması zorunlu kabul kriteri oldu. Global dinamik çözünürlük varsayılan optimizasyon değil. Önce gereksiz iş ve uzak maliyetler. 2/43; P1.6.3 sırada. Yalnız belge değişikliği.

## P1.6.3 — 27 Kasım 2026
- Kullanıcı: arka plan optimizasyonu kendisi gecikme yaratmamalı. Zorunlu karar protokolüne worker bütçesi, iptal/dedup/backpressure ve kaynak rekabeti eklendi.
- Aday kod: baked başlangıçta gereksiz boş region resize kaldırıldı (upstream load_region boyutu kendisi ayarlar); raw import korunur. Dört doku aynı format ve mip byte'larıyla paket sırasında Image .res olarak hazırlanır. Telefonda PNG decode ve mip üretimi yerine hazır zincir, GPU upload aynıdır. Bir defalık startup faz süreleri JSON'a eklenir. Yeni worker yok; SHA256 ve yakın grafik ayarları aynı. Paket üretim doğrulaması açık, cihaz hızı henüz ölçülmedi.
- 2/43; P1.6.3 doğrulama açık. Sıradaki P1.6.4 ve 1.6.7 ölçüm/IO kararları.
## P1.6.4 — 27 Kasım 2026
- P1.6.3 paket çalışması 46012663880 son kontrolde aktif; bağımsız materyal kaynağı incelemesi sürdürüldü.
- World profili final Terrain3DMaterial ayarları tree öncesi hazırlanır. Native macro variation her zaman kapalıydı; kullanılmayan noise uniform'u ve branch kaldırıldı. Native otomatik NoiseTexture2D üretim ihtiyacı azalır, görünüm ve yakın kalite korunması hedeflenir. Checker final map update sonrası kapatılır. Baker world shader yolunu kullanır. Yeni worker yok. Karar protokolünde kaynak gerekçeleri ve riskler yazılı. Paket ve telefon doğrulaması açık; 2/43.

## P1.6.3/P1.6.4 — Paket hatası ve düzeltme
- 46012663880 ve 46013072810 başarısız: bake_native.gd texture_path değişkeninde Variant kaynaklı GDScript tür çıkarımı hatası; native bake ve shader çalışma aşamasına geçilmedi. Önceki başarılı paket korunuyor.
- Her iki yüzey döngüsü String olarak tiplendi, texture_path açık String oldu. Import logunda parse hatası görülürse 240 s timeout beklemeden paket kesilir; dört mip zinciri başarı işareti ayrıca zorunlu. Yeni tek birleşik paketleme doğrulaması; benchmark yok. P1.6.3/4 doğrulanmadı, 2/43.

## P1.6.3/P1.6.4 — Birleşik paket sonucu ve temizlik
- CI 46013911229 başarılı: NATIVE_SURFACE_MIPS_OK count=4, NATIVE_BAKE_OK regions=64 exact_height_samples=16777216 elapsed_ms=2892. Önceki parse hatası giderildi. Artifact 15205900568. 4/43 paket/uygulama hedefi; cihaz açılış, shader derleme ve FPS ölçümleri açık.
- Logda sunucu ses aygıtı ve Vulkan VK_KHR_surface hatası, VSync desteği uyarısı, offline PNG yükleme uyarısı mevcut. GL bake ve artifact başarılı. Ses için import komutunda Dummy seçildi. Offline raw PNG okuması açık byte buffer decode ile değiştirildi; Android baked yoluna, geometriye, shader'a veya fizik ayarına dokunulmadı. Vulkan ve VSync uyarıları maskelenmedi; sunucu ortamına özgü olabileceği için mobil renderer değiştirilmedi. Temizlik commit'inin paket sonucu açık. Sıradaki P1.6.5.

## P1.6.5 — 27 Kasım 2026
- P1.6.3/4 temizlik CI 46014546324 başarılı: 64 region, 16.777.216 Float32 örnek, dört mip zinciri. Ses ve PNG log uyarıları yok; Vulkan/VSync ortam kayıtları duruyor. Artifact 15204524992.
- P1.6.5 aday: mevcut spawn/respawn ray kontrolü doğru native collider id + beklenen yükseklik ile güçlendirildi; 3 s hata sınırı ve manuel retry. Geçersiz spawn yüksekliğinde backend aktive edilmez. Normal oynanışta ek ray yok; fizik/LOD ayarları korunur. Gate olayları rapora yazılır. Paket doğrulaması açık, cihaz sonucu yok. 4/43. Sonraki P1.6.6/7: takılma teşhisi ve düşük maliyetli recorder.

## P1.6.6–7 — 27 Kasım 2026
- 46015224588 paket sonucu başarılı; P1.6.5 cihaz gate davranışı açık. 5/43 paket/uygulama hedefi.
- Aday recorder schema 3: normal oyun sırasında disk yazma/flush ve RSS okuma kaldırıldı; RAM sınırları, dropped sayaçları, 50ms+ stall bağlamı ve P99.9, bir saniyelik HUD özetini tekrar kullanma. Manuel export korunur; crash recovery yok, cihaz ölçümü açık. Yeni worker/kalite değişikliği yok. P1.6.6/7 birleşik paket doğrulaması açık.

## P1.6 kapanış — 27 Kasım 2026
- CI 46016265505 başarılı; 64 native region, 16.777.216 Float32 örnek, 4/4 mip zinciri kayıpsız doğrulandı; offline bake 2045 ms. Artifact 15205259073. Vulkan/VSync ortam uyarıları devam ediyor. Bu CI paket üretimi, recorder çalışma davranışı veya FPS benchmark değil.
- 7/43 paket/uygulama hedefi; P1.6 7/7 bu kapsamda kapandı. Gerçek cihaz başlangıç/gate/recorder ve donma analizi açık; önceki donmanın nedeni kanıtlanmadı. P1.7.1 sırada. Kararlı V2 referans değişmedi.

## P1.7.1 — kaynak denetimi tamamlandı
- Native add/remove tüm texture array ve region_map_changed üzerinden fizik rebuild yapabilir; remove_region gerçek RAM eviction değil, save_directory silinmiş disk kaynaklarını silebilir. Ayrıntılı kaynak ve 213.333 MiB teorik harita yükü: NATIVE_RESIDENCY_AUDIT_TR.md. Cihaz GPU/RSS/timing ölçümü yok.
- 64 region resident korunur, naive streaming reddedildi. 8/43, P1.7 1/10. Sıradaki 1.7.2 kararlı koordinat indeksi. Yalnız belge commit, CI tetiklenmez.

## P1.7.2 — 27 Kasım 2026
- Aday: mevcut geçici seen kontrolü yerine doğrulanmış salt okunur Vector2i -> dosya/hash indeksi. Tam origin-zero kare format, strict JSON tür/koordinat/region boyutu/hash kontrolleri. Başarılı native yükleme sonunda indeks yayınlanır. Metadata dışında yeni kopya, worker, GPU/fizik değişikliği yok. Baker aynı parser ile 64 descriptor doğrulaması; paket CI açık. 8/43; sıradaki P1.7.3.

## P1.7.3 — 27 Kasım 2026
- P1.7.2 CI 46018260377 başarılı: NATIVE_REGION_INDEX_OK count=64; tüm 16.777.216 yükseklik örneği ve 4 mip doğrulandı. Artifact 15208290578. 9/43.
- P1.7.3 aday: yükleme sırasında mevcut native image byte inventory, OS/renderer startup öncesi ve sonrası ayrı snapshots, export snapshot; safe process/GPU budget unknown -1, advisory resident. Yeni per-frame iş, worker, quality change yok. Paket doğrulaması açık, telefon ölçümü yok. P1.7.4–8 gereklilik koşullu; resident dünyada gereksiz streaming kurma.

## P1.7.3 paket sonucu
- CI 46018743594 başarılı; 64 region ve indeks, 16.777.216 Float32 örnek, dört mip zinciri doğrulandı; offline bake 2193 ms. Artifact 15207231764. Vulkan/VSync sunucu uyarıları devam. Bellek snapshot runtime davranışı ve güvenli cihaz bütçeleri doğrulanmadı; paket CI performans testi değil.
- 10/43, P1.7 3/10; sıradaki P1.7.4 asenkron disk erişiminin gereklilik analizi; resident dünya için ölçümsüz worker ekleme. Belge güncellemesi yeni CI tetiklemez.

## P1.7.4 — 27 Kasım 2026
- Aday: salt okunur region index ile SHA256 doğrulaması tek açılış Thread'ine ayrıldı, native kurulumdan önce biter; join, sync fallback, fail-closed, tek tüketim. Oyun sırasında worker yok, ResourceLoader/native/GPU main thread. startup_io raporu ekli. Toplam açılış hızı ve cihaz davranışı açık; paket doğrulaması bekliyor. 10/43.

## P1.7.4–9 — 27 Kasım 2026
- 46019414487 başarılı: 64 native region/indeks, 16.777.216 Float32 örnek, dört mip; artifact 15207077561. Native bake 2014ms sunucu ölçümü. Thread davranışı gerçek cihazda açık. 11/43.
- P1.7.5–8 resident dünya için koşullu ertelendi; tamamlanmış sayılmadı; prefetch/cache/hysteresis/budget döngüsü yok. Büyük dünya fixed-slot/ölçüm önkoşulları karar defterinde.
- P1.7.9 aday: tüm resident koordinat seti doğrulanır, spawn validation, mevcut 1Hz ray terrain height merkezli ve native collider id doğrulamalı, miss reason. Yeni worker, ek ray, eviction yok. Paket doğrulaması açık. Sonraki P1.7.10 uzak arazi.

## P1.7.9 paket sonucu
- CI 46020199322 başarılı; 64 region ve indeks, 16.777.216 Float32 örnek, dört mip zinciri doğrulandı; offline bake 2521 ms. Artifact 15207522916. Vulkan/VSync sunucu uyarıları devam. Bu CI paket üretimidir; resident set ve ground probe runtime davranışı gerçek cihazda doğrulanmadı.
- 12/43; P1.7 5/10 tamamlanan kaynak/uygulama/paket hedefi, 4 koşullu ertelenen, 1 sırada. Sonraki P1.7.10. Belge commit yeni CI tetiklemez.

## P1.7.10 — 27 Kasım 2026
- Candidate world shader bounds safe region map, safe layer index and missing texel guards. Native resident world, seven LOD, 850m far and near spacing unchanged. Nominal outer tile half-width 544m (not measured visibility); startup render_coverage event. Edge appearance and GPU cost unverified. No forced LOD8; P1.8.1 profiles next. 12/43, four deferred streaming tasks remain open. Package CI pending.

## P1.7.10 / P1.8.1 — 27 Kasım 2026
- 46021022190 paket başarılı, 64 region/indeks, 16.777.216 örnek, 4 mip; artifact 15208371670, sunucu bake 2226ms. Görsel/FPS doğrulaması açık; 13/43.
- P1.8.1 kaynak analizi: 16/7 baseline 57024 topoloji üçgeni, 144 instance; 16/8 64800, 164. Native snap tüm ring transform/teleport gönderiyor; ring bazlı dedup aday, native patch henüz yok. Kaynak/topoloji, FPS ölçümü değil. NATIVE_LOD_COST_AUDIT_TR.md. 14/43; P1.8.2 sırada. Belge commit, yeni CI yok.

## Kullanıcı kapsam düzeltmesi — 27 Kasım 2026
Dört Havza yalnız test sahnesi; TerraForge genel terrain oluşturma/düzenleme aracı. Aktif ana plan, README, karar ve handoff güncellendi. P1.9.7–8 nihai oyun haritası değil genel üretim iş akışı; P3 koşullu editör genişletmesi, P4 oyun sistemleri kapsam dışı. 14/43 teknik ilerleme korunur; yeni editör işlerinin kapsamı ve kabul kriterleri ayrıntılandırılacak. Kod ve test sahnesi değişmedi, yeni CI yok.

## P1.8.2 — aday
Reusable preview_range.gd, camera far only, reference default 850m test profile, manual 75%, explicit adaptive one-shot trial with rollback/no repeated rebuild, existing summary reuse. New file packaged. 14/43 confirmed, package pending. Editor integration and real device impact open.

## P1.8.2–3 — 27 Kasım 2026
- P1.8.2 CI 46022529495 successful, 64 native index, 16.777.216 height samples, 4 mip chains, 2023ms server bake; artifact 15208633565. 15/43; adaptive runtime/device pending.
- P1.8.3 candidate: exact morph endpoints/unchanged shifts sample 3 rather than 6 height texels; true morph band unchanged. Exact camera pose no-op in test fixture only. No LOD/near quality/physics changes. GPU branch cost and device visual equivalence open; package pending. P1.8.4 next.

## P1.8.3–5 — 27 Kasım 2026
- 46023381680 package successful, native bake 2370ms, 64/16.777.216/4 verified; artifact 15212205063; visual/device validation open. 16/43.
- P1.8.4 feasibility closed (17/43), horizon culling implementation deferred: NATIVE_HORIZON_CULLING_AUDIT_TR.md. No redundant CPU occluder or unsafe visibility cutoff.
- P1.8.5 candidate opt-in far exact zero-weight texture skip, default reference, gradients valid in nonuniform branches. Source reads 1–4 instead of always 4 in eligible far branch, not measured GPU instructions. Package/device pending. Next P1.8.6.

## P1.8.5–6 — 27 Kasım 2026
- 46023920638 package passed: native index 64, 16.777.216 exact heights, 4 mips, 2021ms offline server bake; artifact 15211800852. Device shader performance open. 18/43.
- P1.8.6 candidate: 100% 3D scale default, manual 90/85% options in preview menu; bilinear, 2D UI unaffected, close view may blur; no auto-scale, no native rebuild, event records change and reset range trial. Package/actual device open. Next P1.8.7.

## P1.8.6–7 — 27 Kasım 2026
- 46024518373 package passed: native index64, 16.777.216 exact heights, 4 mips, 2020ms server bake; artifact 15210593260. 19/43; scale visual/device pending.
- P1.8.7 candidate thermal_monitor.gd Android PowerManager API29+; 30s foreground samples in existing HUD, status/cost logged, unknown on unsupported, expensive/failed steady-state polls stop. Advisory severe+ message; no forced quality change. Package/device pending; P1.8.8 next.

## P1.8.7–8 — 27 Kasım 2026
- 46025159030 package passed, 64 native regions, 16.777.216 exact samples, 4 mips, 1530ms server bake; artifact 15211157179. 20/43; Android actual thermal status open.
- P1.8.8 candidate: one controller, full-context/contiguous windows and export exclusion, immediate context invalidation, no repeated trials without opt-in, >=5% mean improvement and nonworsening avg window p95/p99, verdict evidence. Default reference. Package/device pending; P1.9 next.

## P1.8.8 / P1.9.1 — 27 Kasım 2026
- 46025759250 passed: 64 regions, 16.777.216 exact heights, 4 mips, 1522ms server bake, artifact 15210674580. 21/43. P1.8 technical scope closed, device validation open.
- P1.9.1 candidate separate authoring/landform_tool.tscn with reusable RF stamp kernel, metre parameters, deterministic seed, preview-only L8, manual RF resource+JSON export. Fixture unchanged. No erosion/full editor yet. Package pending; P1.9.2 next.

P1.9.1 correctness/package passed; P1.9.2/3 inactive kernels 3/3 CI 46027043596, latest package 46027043547 artifact 15212108928. 22/43.

## Öncelikli düzeltme — orijinal TerraForge paneli (27 Kasım 2026)
Kullanıcı son ZIP'te yalnız upstream Terrain3D alt panelini gördü. Kök neden: paket workflow'u sadece addons/terrain_3d kopyalıyordu; repo kökündeki tam addons/terra_forge (316 dosya, önceki dal ile aynı) pakete dahil değildi. Düzeltme: tam eski addon byte-for-byte pakete kopyalanır, paket project.godot içinde yalnız TerraForge Mobile varsayılan etkinleştirilir, terraforge_workspace.tscn boş Node3D düzenleme başlangıcı eklenir. Native GDExtension ve play.tscn korunur; upstream editor plugin varsayılan kapalı. Eski panel hâlâ kendi legacy renderer'ıyla çalışır; native backend entegrasyonu ve yeni kernel bağlantısı henüz yok. Paket editör import kontrolü eklendi; telefon görünümü doğrulanmadı. P1.9 ilerlemesi 22/43; önce panel/native veri bağlama ve mevcut özelliklerin korunması, ardından yeni şekillendirme araçları. Orijinal addon/dal değiştirilmedi.

## Kullanıcı düzeltmesi — sadece native backend, eski panel görünümü
9ba31d1 legacy addon packaging kararı geçersiz. Paket yalnız upstream native extension ve yeni addons/terraforge_native içerir; eski motor/eklenti dahil edilmez. Orijinal panel düzeni/toolbar kodu uyarlanır, backend native RF region. İlk aday: +New 1×512 region .25m, 7 LOD/mesh16, mevcut world shader/mips, Raise/Lower/Smooth/Flatten, bounded sparse stroke undo/redo (8), native partial height layer update; save unique RF region snapshot readback, scene separately. No duplicate legacy mesh worker. Per-dab calc_height_range and upload can be costly; no measured editor latency or Android validation. Existing advanced tools, layers, profile selection disabled explicitly until migrated; no claim full parity. Native region boundary/multi-region, robust save and source migration remain open. Previous runtime code/fixture unchanged. 22/43; integration gate priority.

## Native panel integration 2 — multi-region basics
CI 46031210136 package/editor import passed artifact 15215080064; no actual interactive device proof. New candidate removes one-region limit, 1/4/16 region creation via small +New confirmation (64 region read/edit cap, no 64-region default allocation). One native region array rebuild at creation. Basic brush global integer coordinates, floor region mapping including negative coords, no duplicated seam vertex. Smooth computes all changes before writes; neighboring region samples, native get_control_hole skip, no missing flat data. Per-dab source refs only, no persistent height copy. Conservative height bounds grow by changed values instead of full region scan, update_maps(TYPE_HEIGHT,false,false) once per dab, only touched layers marked edited; exact height range recalculated on manual save. Native snap invalidates collision target, not custom physics; runtime collision behavior needs device validation. Sparse history 8 strokes / 131072 distinct stroke samples across history, 65536 stroke, 16384 dab bounding cells; GDScript dictionary cost not measured. Large brush still restricted, no claim frame budget guarantee. Multi-region snapshot unique directory, ResourceSaver without native region path takeover, RF/control/color byte readback before directory switch; synchronous native reload and Android enumeration risk remain, verified files retained if reload fails. Advanced tools/layers not migrated. P1.6–8 runtime/shader unchanged; 22/43, integration gate. Next advanced path/stamp/thermal tools with bounded native edit transactions. No benchmark.

## Native edit input repair + streaming requirements (user 27 Nov 2026)
User reports finger sculpt not working after native panel migration. Screenshot Brush OFF but user reports no action; direct code inspection: plugin only _handles selected workspace and lacked set_input_event_forwarding_always_enabled. Candidate enables documented always-forward method; guards active native scene and Brush ON, auto-find only unique workspace on lost selection, hides popup on Brush ON, handles first touch index and mouse-emulation duplicate suppression, counts actual input/hit/edited samples, shows reason in Check/popup. No new picking loop/worker, native CPU intersection retained, no claim exact device root cause until touch verification. Package 46034200604 passed (artifact 15216575410); candidate pending. User also explicitly wants configurable editor view distance, distance-based region IO, memory-budget eviction, pin edited/near regions. Plan: view distance independent of native LOD, explicit editor camera setting first; true native residency separate, do not use destructive remove/save, preserve unsaved changes/history/collision and never synthesize missing data. Resident region policy unchanged pending safe native implementation. Legacy engine not restored. 22/43; edit usability gate before advanced tools.

## Native brush functional gate — 27 Nov 2026
46038598075 package succeeded, artifact 15217888755; input forwarding repaired but Android input unverified. Follow-up: popup resets active stroke/touch (release can be consumed), reject all invalid hit axes, allow native scene root, only Flatten requires valid nearest target, status/tooltip show edits. Package smoke executes native RF blank regions, surface intersection, cross-region Raise, Lower, Undo/Redo with actual native data readback; no FPS benchmark, no synthetic proof of Android touch events. No native runtime optimization changes. Current editor view distance/streaming requirements pending; fix usability first.

## Native editör görüş kapsamı — aday (27 Kasım 2026)
Previous 4031eb1 CI 46040268915 package + actual native brush smoke passed, artifact 15219473636; 46040268834 isolated kernel 3/3 passed. Android touch not proven. User asked configurable editor view range and later streaming/eviction/pinning. Godot 4.7.2 source editor/scene/3d/node_3d_editor_plugin.cpp sets camera projection with get_zfar from editor state; repeatedly forcing Camera3D.far would fight editor. Reuse original Quality row as View: explicit native 5/6/7 LOD profiles. Nominal clipmap half-width formula (2*mesh_size+2)*spacing*2^(levels-1); current mesh16/.25 gives 136/272/544m. These are square coverage approximations, not guaranteed view distance; frustum, world bounds and snapping apply. Near LOD0 spacing and mesh size unchanged, no height/texture/data/collision settings altered. Native mesh_lods setter rebuilds clipmap once per explicit action; may stall on change; no automatic per-frame switching. User selection is undoable through Godot editor history and changes scene property (saved scene runtime LOD also affected); not temporary editor-only camera setting. Default new terrain 7 remains, existing custom levels untouched until selection. Brush is finished/disabled when changing profile. Runtime fixture unchanged. No claim FPS gain or RAM release: native all regions still resident. Future real distance-based region streaming requires safe fixed slots/native rebuild cost decision, clean/dirty/history pins, verified source, byte budget; no destructive eviction. 22/43 plus integration gate. Package pending; no new benchmark.

## Android brush incident: Input 255 / Hit 255 / Edit 0 (27 Nov 2026)
User screenshot proves callback and native ray succeed; generic No editable native regions originates before brush writes, exact failed predicate unknown. Switch editing from strict GDScript Image wrapper gate to native active resources get_regions_active(false,false), native scalar get_height/set_height and actual per-value readback. Detailed region count/list/resource/grid errors, actual changed sample counter; no format conversion or old backend. Native engine owns RF maps (sanitize_map TYPE_HEIGHT RF); save retains strict RF format/size byte validation. Existing changed-layer upload, conservative height bounds, history, LOD profiles unchanged. More native calls per dab; device latency unmeasured. CI adds radius8/power3 interior case to existing cross-region smoke, does not prove Android editor input/ABI or fix. Latest previous view CI 46041677868 success. Do not claim exact root cause until device result; failed save metadata is reported, not forced. Streaming work paused until brush works.

## Editor-mode brush reproduction gate
CI 46042612211 package/native runtime smoke passed (including radius8 power3 interior), artifact 15220242954. CI 46042612406 isolated kernels 3/3. User Android symptom previously Input255 Hit255 Edit0; actual Android fix remains unverified. Add CI-only disposable package injection of editor_brush_smoke.inc: actual EditorPlugin +New 1 region, clear selection, native intersection and radius8 power3 dab, native readback + Undo/Redo, no save. Restore original plugin byte-for-byte before artifact upload; no new runtime behavior, worker or benchmark. Linux editor verification is not Android input/ABI validation; user should try successful package before any further speculative rewrite. Streaming remains paused.

## Editor streaming S1 — isolated policy, no promotion
46043674834 Linux actual editor brush PASS changed=3205 height=3.0, artifact 15220518777; Android touch pending. Implement inactive experiments/native_residency/residency_policy.gd metadata-only candidate selection, rectangle distance, near/dirty/history/physics pins, hysteresis, caller-supplied byte/slot/staging budgets, fail closed unverified sources, one proposed action per call. No IO, no deletion, no native call, no worker, no package or active runtime changes. S2 verified sources/dirty identity; S3 native fixed slot transactional layer replacement; S4 opt-in integration after device validation. Detailed plan NATIVE_EDITOR_STREAMING_PLAN_TR.md. No CI/benchmarks triggered. 22/43 unchanged.

## Android confirmation + large brush/storage follow-up
User screenshot shows sculpted hills; RF transport worked on Android for actual edits. Screenshot Input281 Hit279 Edit0 after radius29.5, power9.2, exact message Brush too large for current native edit budget. Previous bound 16384 candidates (15.75m at .25 max centered); full 36m needs <=84100 candidates. Raise bound 85000; use verified RF image refs for height sample/write (packed native transport prevents original conversion), retain native hole checks, actual readback, partial layer upload; no repeated full rebuild. 131072 stroke segment cap with automatic commit/rebase, 262144 history cells, large dab cadence uses previous synchronous time; no continuous frame guarantee, large dab can stall, undo may be multiple segments. External baked ImageTexture .res verified against mip source; +New uses external texture refs, assigns unique empty native data dir so Godot pre-save persists modified regions. Existing embedded texture migration only explicit panel Save, then verified snapshot + scene save. No old engine. User currently edits play.tscn, fixture is not authoring workspace: advise save/migrate existing work, use terraforge_workspace for future. CI verifies 29.5/36m and disposable editor scene save/readback, not Android performance. Candidate previous 46045909301 5/5 passed, user confirmed sculpt. No main promotion yet.

## 16-region save/reopen safety candidate
Last successful 46051156699: 5/5, 29.5m changed43705, 36m changed65097, single-region editor scene2481 bytes, saved RF readback; artifact15224767720. User confirmed packed RF sculpt on Android, large brush/storage latest device verification open. Replace panel snapshot directory swap/reload with verified external backup folder and final SHA256 manifest, retain current native data object and directory, native scene pre-save then compare all live disk map hashes to backup. No automatic deletion of old snapshots, no claim atomic multi-file scene transaction; ordinary Ctrl-S still native save, panel Save creates backup. Explicit save costs disk IO and space, no per-frame overhead. Linux editor CI now 16 regions, actual panel Save no native reload, boundary/far probes, separate editor process reopen all 16 height/control/color maps match backup and disk (4,194,304 height samples), disposable workspace restored before packaging. Android reopen/latency remains open. No change packed C++/shader or brush optimization. No streaming promotion.

## Streaming S2 — source identity and pins (isolated, 27 Nov 2026)
CI 46057341699 5/5 success, 16-region actual editor save/reopen map hashes match, 4,194,304 exact height samples, scene2480 bytes, artifact15228165400. Preserve packed RF and current save/brush implementation. Added inactive experiments/native_residency/snapshot_catalog.gd parses existing backup manifest schema1, validates coordinates/filename/hash/map metadata, uses manifest digest generation, calculates logical map bytes, explicitly verifies individual source SHA256 and rechecks ticket before eventual commit. No automatic resource load; verified flag is not permanent proof, no TOCTOU guarantee without future staged immutable decode. region_pins.gd unions dirty/undo/redo/active footprint+one-sample smooth halo/physics metadata; caller must intersect brush halo with actual world catalog, recompute on changes and reject unknown pins. No runtime hookup, no benchmark or CI triggered; code not yet executed. S2 partial: verified manifest metadata and pin set implemented, async decode and generation-safe native transaction remain. S3 native slot replacement needs explicit non-destructive API and Android compatibility; no remove_region misuse. Last package unchanged; Android save/reopen remains unverified.

## Ana plana dönüş — P1.9.1 panel entegrasyonu adayı
Aktif kullanıcı geliştirme dalı fix/terraforge-rf-mobile-packed (eski native dalı atası, 5 ileri/0 geri ec0a525). Son paket 46057341699/15228165400, 16 bölge kayıt/reopen başarılı. P1.7.5–8 S1/S2 ve S3.1 ayrı deney experiment/terraforge-native-slot-swap, CI46060117071 son kontrolde aktif; production promotion yok, 4 görev açık. P1.9.1 Ridge/Valley: native_landform.gd eski max-nearest-segment influence, asimetrik sırt/vadi profili, world noise, .42 amplitude mantığı native RF global grid'e port; legacy backend yok. 128 point/256m/600k visit/131072 cell bounded, reject before write, no partial planned result; one synchronous release transaction, same native partial upload and undo. Popup, tool switch, scene switch, multitouch cancel path; release commits, missed ray cancels. Size/Power captured at start; path no live preview, no per-frame worker. Large release may stall; no measured Android latency. Actual editor package gate extends prior 16-region save/reopen with signed cross-region corridor and undo. 22/43 unchanged until integration verified; P1.9.2/3 kernels remain partial; next Weather/erosion and Stamp. Preserve packed shader/native, save, large basic brushes. Do not reset phases or count CI as FPS.
