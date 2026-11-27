# TerraForge Native Terrain3D — Aktif Ana Yol Haritası (TR)

Onay: 27 Kasım 2026, kullanıcı mevcut oynanabilir sürümü beğendi ve bu planın eski planlardan ayrı kaydedilmesini istedi.
Dal: `feat/terraforge-terrain3d-runtime`
Kararlı referans (kullanıcının oynadığı Dört Havza V2): `fdbf49b2b5c1e0133a050e2a5f5592011f1fbf2c`.
Durum: P1.5 native temel gerçek cihazda çalıştı; P1.6–4.0 planlandı, henüz uygulanmadı. Sıradaki görev P1.6.1.
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
- [ ] 1.6.1 Çalışan sürümü güvenli GitHub dalında koruma.
- [ ] 1.6.2 Heightmap'i önceden native Terrain3D bölgelerine dönüştürme.
- [ ] 1.6.3 Açılıştaki gereksiz veri kopyalarını kaldırma.
- [ ] 1.6.4 İlk shader derlemesi gecikmelerini ölçme ve azaltma.
- [ ] 1.6.5 Fiziksel zemin hazır olmadan oyuncu hareketini engelleme.
- [ ] 1.6.6 Ani donmaların kaynağını belirleyen teşhis sistemi.
- [ ] 1.6.7 Düşük maliyetli performans kaydı.
Hedef: ilk fiziksel zemin 6,71 s bazına göre iyileşsin; saniyelik donmaların kök nedeni belirlenip azaltılsın. Mevcut dünya aynı kalsın.

## P1.7 — Profesyonel chunk ve bellek yönetimi (10 adım)
- [ ] 1.7.1 Native bölge ekleme/kaldırma maliyetlerini inceleme.
- [ ] 1.7.2 Dünya bölge indeksi.
- [ ] 1.7.3 Cihaz kapasitesine göre bellek bütçesi.
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
