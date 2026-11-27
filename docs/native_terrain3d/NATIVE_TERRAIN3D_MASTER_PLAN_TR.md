# TerraForge Native Terrain3D — Aktif Ana Yol Haritası (TR)

Onay: 27 Kasım 2026, kullanıcı mevcut oynanabilir sürümü beğendi ve bu planın eski planlardan ayrı kaydedilmesini istedi.
Dal: `feat/terraforge-terrain3d-runtime`
Kararlı referans (kullanıcının oynadığı Dört Havza V2): `fdbf49b2b5c1e0133a050e2a5f5592011f1fbf2c`.
Durum: P1.5 native temel gerçek cihazda çalıştı; P1.6.1–7 paket/uygulama hedefleri tamamlandı (7/43); yeni runtime cihaz doğrulaması açık. Sıradaki P1.7.4; P1.7.1–3 kaynak/uygulama ve paket hedefleri tamamlandı (10/43).
Bu belge bu dalın TEK aktif geliştirme planıdır. Eski `addons/terra_forge/` altındaki özel CPU mesh/worker mimarisi planları tarihsel referanstır; görev sırası, faz numaraları ve başarı ölçütleri buraya taşınmaz. Orijinal dal `feat/terraforge-mobile-addon` korunur.

## Başlangıç noktası ve kararlar
- Godot 4.7.2, upstream Terrain3D 1.1.0-stable native C++ çekirdeği, GL Compatibility; Vulkan yazılım renderer hareket testinde geçmiş çökme nedeniyle varsayılan değil.
- Dört Havza V2: 4096² Float32, 25 cm aralık, 1023,75 m kare, 64 adet 512×512 örnekli region; 7 clipmap LOD; kamera far 850 m; dört prosedürel 512px renk dokusu; ağaç/su/obje yok. Tüm region'lar başlangıçta resident; streaming henüz yok.
- Redmi Note 8 Pro kullanıcı raporu `TerraForge_1795786773_4172413.json`: 264,59 s, 15.566 kare, yaklaşık 2.128 m, FPS cap 60, yaklaşık 58,94 FPS tüm oturum, normal hareket yaklaşık 60 FPS, iki ciddi donma, ilk fiziksel zemin 6,71 s, 258 örnek zemin kontrolünde 1 başarısız kontrol, 0 düşme. Önceki sohbet analiz değerleri; ham rapor yeniden incelenmeden daha güçlü sonuç çıkarılmasın. Cihaz performans rezervi ve toplam RSS/GPU belleği bilinmiyor.
- Referans paket: https://github.com/mehmetdem2005/FareOyunu/actions/runs/46007864545/artifacts/15201923633
- Native görsel LOD, geomorphing, dinamik fizik korunacak. Eski CPU mesh fabrikası, özel worker/scheduler ve eski runtime geri getirilmeyecek.
- Gerçek cihaz paketi, joystick, FPS ve JSON kayıt korunur. Kullanıcı her küçük değişiklikte telefon testi yapmak istemiyor. Otomatik benchmark push devre dışı; paketleme ile performans doğrulaması ayrı. Başarı ancak ölçümle ilan edilir, CI PASS FPS sayılmaz.
- Her değişiklikte fayda, bedel, risk, geri dönüş ve açık işler yazılır. Bağımsız görevler paralel olabilir; doğrulanmamış deney ana sürüme taşınmaz. Kullanıcı onayı olmadan eski dalı değiştirme.
- Aktif görevler aşağıdaki sıradan izlenir. Her adımın durumunu ilerleme defterinde güncelle.

## P1.6 — Kararlılık ve açılış (7 adım)
- [x] 1.6.1 Çalışan sürümü güvenli GitHub dalında koruma.
- [x] 1.6.2 (paket dönüşümü doğrulandı; gerçek cihaz yüklemesi açık) Heightmap'i önceden native Terrain3D bölgelerine dönüştürme.
- [x] 1.6.3 (paket doğrulandı; cihaz ölçümü açık) Açılıştaki gereksiz veri kopyalarını kaldırma.
- [x] 1.6.4 (paket doğrulandı; cihaz ölçümü açık) İlk shader derlemesi gecikmelerini ölçme ve azaltma.
- [x] 1.6.5 (paket doğrulandı; cihaz davranışı açık) Fiziksel zemin hazır olmadan oyuncu hareketini engelleme.
- [x] 1.6.6 (paket doğrulandı; cihaz teşhisi açık) Ani donmaların kaynağını belirleyen teşhis sistemi.
- [x] 1.6.7 (paket doğrulandı; cihaz maliyeti açık) Düşük maliyetli performans kaydı.
Hedef: ilk fiziksel zemin 6,71 s bazına göre iyileşsin; saniyelik donmaların kök nedeni belirlenip azaltılsın. Mevcut dünya aynı kalsın.

## P1.7 — Profesyonel chunk ve bellek yönetimi (10 adım)
- [x] 1.7.1 Native bölge ekleme/kaldırma kaynak analizi (gerçek cihaz maliyeti açık).
- [x] 1.7.2 (paket doğrulandı; cihaz yüklemesi açık) Dünya bölge indeksi.
- [x] 1.7.3 (paket doğrulandı; cihaz güvenli limitleri ölçülmedi) Cihaz kapasitesine göre bellek bütçesi.
- [ ] 1.7.4 Asenkron disk okuma.
- [ ] 1.7.5 Hareket yönüne göre akıllı prefetch.
- [ ] 1.7.6 Bölge verisi önbelleği.
- [ ] 1.7.7 Yükleme/boşaltma mesafelerinde histerezis.
- [ ] 1.7.8 Kare başına yükleme bütçesi.
- [ ] 1.7.9 Fizik bölgelerini koruma.
- [ ] 1.7.10 Uzak arazinin kesintisiz görünmesini sağlama.
Native 1.1 aktif bölgeleri GPU belleğinde tutuyor. GPU texture array yeniden oluşturma maliyeti ölçülmeden streaming ana sürüme kabul edilmez. Görsel LOD Terrain3D'ye ait kalır; disk önbelleği ile fizik alanı ve görsel alan birbirinden ayrılır. Uzak siluet kaybolması ve fizik boşluğu kabul edilmez; çözüm fizibilitesi açık.

## P1.8 — Profesyonel LOD ve çizim optimizasyonu (8 adım)
- [ ] 1.8.1 LOD profillerinin maliyet analizi.
- [ ] 1.8.2 Cihaz performansına göre adaptif görüş mesafesi.
- [ ] 1.8.3 LOD geçişlerinde titreşim ve şekil değişimi kontrolü.
- [ ] 1.8.4 Horizon culling fizibilitesi.
- [ ] 1.8.5 Mesafeye bağlı shader kalitesi.
- [ ] 1.8.6 Dinamik render çözünürlüğü.
- [ ] 1.8.7 Isınma ve uzun süreli performans yönetimi.
- [ ] 1.8.8 FPS dalgalanmasını önleyen adaptif kalite denetimi.
Mevcut 7 LOD teorik örnek aralıkları 25 cm, 50 cm, 1 m, 2 m, 4 m, 8 m, 16 m. Yakın arazi kalitesi/fizik korunur. Adaptif kararlar kararlı ve histerezisli olmalı.

## P1.9 — Gerçekçi arazi geometrisi (8 adım)
- [ ] 1.9.1–1.9.2 Jeomorfoloji: doğal sırtlar, su aşındırması, tortu birikimi ve bağlantılı vadiler.
- [ ] 1.9.3–1.9.4 Mikro arazi: fare ölçeğinde tümsek, oyuk, hendek ve küçük aşınmalar.
- [ ] 1.9.5–1.9.6 Bölgesel geçişler: ova, dağ, dik kıyı, yumuşak sahil, doğal biyom sınırları.
- [ ] 1.9.7–1.9.8 Asıl oyun dünyası: dört adalı özgün haritanın hazırlanması ve fare ölçeğine uyarlanması.
Geometri fazı; boya ve obje sistemleri ayrı fazlarda. Dört Havza test dünyası asıl dört ada haritası değildir. Özgün harita referansları korunmalı; eski teknik mimari değil.

## P2.0 — Profesyonel materyal ve boyama (10 adım)
- [ ] 2.0.1 Gerçek 1K PBR materyalleri.
- [ ] 2.0.2 Normal ve roughness haritaları.
- [ ] 2.0.3 Eğim/yükseklik tabanlı boyama.
- [ ] 2.0.4 Triplanar doku projeksiyonu.
- [ ] 2.0.5 Height-based texture blending.
- [ ] 2.0.6 Doku tekrarının azaltılması.
- [ ] 2.0.7 Mikro ve makro doku katmanları.
- [ ] 2.0.8 Uzakta sadeleştirilmiş materyaller.
- [ ] 2.0.9 Mobil doku sıkıştırması.
- [ ] 2.0.10 Editörde arazi boyama araçları.
Örnek materyaller: toprak, kaya, çam iğneleri, yosun, çakıl. 1K hedef; gerçek kaynak ve lisans kaydı korunur.

## P3.0 — Bitki örtüsü ve obje yerleştirme
Ağaç, çalı, çimen, taş, kuru dal ve diğer doğal objeler; MultiMesh, mesh LOD, impostor, mesafeye bağlı yoğunluk, pooling, bölgesel yerleştirme, oyuncu yakınında fizik. Alt adımlar henüz ayrıntılandırılmadı.

## P4.0 — Bütünleşik açık dünya altyapısı
Dünya kaydı, kalıcı obje durumları, canlıların bölgesel simülasyonu, multiplayer uyumluluğu, büyük koordinat hassasiyeti ve oyun sistemleri entegrasyonu. Alt adımlar henüz ayrıntılandırılmadı.

## Hedef ölçütler (gerçekleşmiş sonuç değil)
Redmi Note 8 Pro için normal gezinti 60 FPS, P99 ≤20 ms, 100 ms üzeri oyun içi donma 0, zeminden düşme 0, ilk oynanabilir zemin ≤2 sn, sınırlı ve istikrarlı bellek. FPS cap/VSync, iş yükü, rota, cihaz koşulları ve örneklenen ölçüm türü raporlanır. Normal FPS ile istisnai donmalar ayrı ve birlikte raporlanır.
Toplam P1.6–P2.0: 43 ana adım. P3.0 ve P4.0 bu sayıya dahil değil.

## Zorunlu karar protokolü
Her görev öncesi [ENGINEERING_DECISIONS_TR.md](ENGINEERING_DECISIONS_TR.md) okunur; alternatifler, bedeller ve gerekçe kaydedilir. CI başarı işareti kararın yerine geçmez.

## Kullanıcı önceliği — 27 Kasım 2026
Paket/ZIP boyutu optimizasyon hedefi değildir. En önemli hedef oyun içi takılma ve gecikmelerin azaltılması, istikrarlı kare süreleri ve hızlı açılıştır. Öncelik sırası: fizik ve veri doğruluğunu koru; uzun kareleri/donmaları azalt; sürdürülebilir FPS ve performans rezervi; hızlı açılış ve bölge erişimi; RAM/GPU belleğini cihaz bütçesinde tut. Disk alanı ve indirme boyutu yalnız uygulanabilirlik sınırı olarak değerlendirilir. Daha büyük dosya daha az CPU çözme maliyeti veya daha düşük I/O gecikmesi sağlıyorsa kabul edilebilir; sıkıştırılmamış veri her durumda daha hızlı varsayılmaz, disk okuma maliyeti de hesaba katılır. ZIP dağıtım sıkıştırması ile oyun içi resource sıkıştırması ayrı konulardır. P1.6.3'te native .res sıkıştırılmış/sıkıştırılmamış alternatiflerini, hash ve okuma geçişlerini, resource decode, kopyaları ve GPU aktarımını ayrı değerlendir; gereksiz yeniden oluşturma veya oyun sırasında senkron disk I/O yapma. P1.7'de fizik önceliği, asenkron hazırlık, bütçeli native aktarım ve histerezis; texture array toplu yeniden oluşturma maliyeti özellikle incelenecek. Ortalama FPS tek başına başarı değildir: p95/p99/p99.9, 33/50/100 ms üzeri kare sayısı, en uzun donma, art arda yavaş kareler, başlangıç ve uzun süreli termal davranış izlenir. Mevcut görsel kalite ve Float32 doğruluğu korunur; performans uğruna sessiz kalite kaybı yapılmaz. Yeni benchmark veya paket yalnız politika/istek kapsamında çalıştırılır.

## Yakın alan görsel kalite koruması — 27 Kasım 2026
Kullanıcı şartı: yakın grafik kalitesi bozulmadan akıcı FPS ve düşük gecikme hedeflenir. Fare ölçeğinde oyuncu/kamera çevresi birincil kalite alanıdır. Mevcut referans Dört Havza V2 (stable/native-terrain3d-dort-havza-v2): 25 cm yükseklik örnek aralığı, Float32, mevcut geometrik detay, dört doku, yedi clipmap LOD. Yakın LOD0 örnek aralığı, fizik doğruluğu, doku keskinliği/filtreleme, materyal ve siluet görünümü sırf FPS için düşürülmez; oyuncunun yakınında pop-in, doku bulanıklığı ve şekil değişimi kabul edilmez. İleride daha ayrıntılı mikro geometri ve 1K PBR hedefi korunur. Önce gereksiz CPU/GPU işi, görünmeyen geometri, uzak LOD ve uzak shader maliyeti, tekrarlanan texture fetch, kaynak kopyası, upload ve I/O optimizasyonu; sonra profil bazlı bütçe. Uzak kalite düşüşü de görünür geçiş ve siluet kaybı oluşturmamalı. Global dinamik çözünürlük (P1.8.6) yakın görüntüyü de etkilediğinden otomatik varsayılan değil; opt-in deney olarak değerlendirilir, yakın kalite koruması sağlanamıyorsa reddedilir veya kullanıcıya açık seçenek olarak sunulur. 60 FPS hedefi 16.67 ms toplam kare bütçesidir, gerçek GPU/CPU zamanları ve frame pacing ayrı ölçülür. Yeni materyal/obje özellikleri performans rezervi olmadan zorunlu açılmaz. Karşılaştırmalar aynı kamera, rota, görüş mesafesi, çözünürlük ve kalite ayarlarında yapılır; yakın görünüm referans kareleri ve ölçümleri saklanır. Görsel kalite ve kare süresi birlikte kabul kriteridir; donanım sınırında ikisi aynı anda sağlanamıyorsa bedel açıkça raporlanır, kullanıcıya danışmadan yakın kaliteyi düşürerek başarı ilan edilmez.

Arka plan iş yükü de maliyet sayılır: öncelik gereksiz işi tamamen kaldırmak ve offline hazırlamak; ölçülmemiş worker, agresif prefetch ve sınırsız kuyruk eklenmez.

P1.7.1 kararı: [NATIVE_RESIDENCY_AUDIT_TR.md](NATIVE_RESIDENCY_AUDIT_TR.md). Mevcut dünya resident kalır; naive add/remove streaming reddedildi. P1.7.4–8 gereklilik ve ölçüm koşullu; gereksiz worker/cache/prefetch oluşturma. 8/43.
