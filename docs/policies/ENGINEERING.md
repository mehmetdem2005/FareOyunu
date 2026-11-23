# Mühendislik ve varlık politikası v1.1

1. Branch: main sadece PR üzerinden; feat/, fix/, chore/, docs/, test/ tipleri. Bir iş / bir reviewable commit grubu; Conventional Commit başlıkları.
2. Değişiklik: bağımlılıklar, uyumluluk matrisi, veri sözleşmesi, ölçülebilir kriter ve geri alma yöntemi olmadan riskli değişiklik yapma.
3. Reproducibility: Engine 4.7.2 pin, eklenti/bağımlılık sürümü ve dosya hash'ı; deterministic transform. Kaynak asla in-place dönüşmez.
4. Data ownership: res://assets kaynakları; res://configs harici değişkenler; res://world domain scripts; res://scenes sadece ext_resource kompozisyonu. Runtime cache user:// veya bellekte; repoda GENERATED asset sadece kaynağı ve kimliği biliniyorsa.
5. Terrain: float32 örnekler 0..1, image-origin top-left, +X columns, +Z row direction varsayımı ancak onaylanmış transform ile dünyaya aktarılır. Dik yükseklik ölçeği/sea level kaynakta sıfır kabul edilmez; config'te karar verilir.
6. Style: typed GDScript / açık arayüzler; uyumluluk, minimal state, tespit edilebilir hatalar, CI ve test.
7. UX: oyuncu gözü/ölçeği, okunabilirlik, input tepki süresi, kameranın sıkışmaması, hareket tutarlılığı görsel kaliteden daha az önemli sayılmaz.
8. Security/legal: eklenti ve dokuların lisansı, provenance; sırlar commit edilmez; CI varsayılan read-only; dış action SHA pin.
9. Enstrümantasyon: perf karşılaştırmasında cihaz/GPU/sürüm/ısı/sahne/tekrar sayısı; p50/p95/p99 ve sınır değerleri; hedefler ölçümle onaylanır.
10. Sürekli gelişim: bu dosyayı yeni risklerle revize et, başta tekrar benzer politika dosyaları türetme.

## Kapsam genişletme ve teknik borç denetimi (v1.1)
11. **Kaynak tekliği:** Her asset'in logical ID + content hash + revision + producer + importer ayarı vardır. 1536² eski SE-01 ve 1254² yumuşak kıyı SE-01 birbirinin üzerine sessizce yazılmaz; değişiklik kayıt/inceleme ve downstream asset invalidate gerektirir. EXR f32 olmak kaynak yüksekliğinin ölçülmüş DEM olduğu anlamına gelmez.
12. **Sözleşme ve göç:** Resource schema versioning, backward compatibility, farklı dünya sürümleri ve save yükleme planı baştan değerlendirilir; implementation ilgili fazda. Özellikle world origin/scale/sea datum verileri sahnede gizli kalmaz.
13. **Tekrarlanabilir build:** Godot editor/export templates sürümleri ve SHA; Android SDK/JDK/template bağımlılıkları; kontrollü lock/pin; hermetic olmayan işlemlere bayrak; debug/profiling/release build ayrımı; CI geçerken izinler minimumdur. Debug kaydı, symbol dosyası ve paket kimliği eşleşir.
14. **Branch protection:** main'i koruyan required checks/PR review/no force push GitHub ayarlarıyla gerçek anlamda etkin olmalıdır. Sadece belgedeki kuralın varlığı teknik enforcement sayılmaz. Admin bypass ve branch rule durumu ayrıca denetlenir.
15. **Varlık üretim hattı:** ham kaynak ayrı, işlenmiş asset ayrı; lineer data için color conversion/gamma yapılmaz; her converter parametresi sürümlenir, tüm exportlar tekrar üretilebilir. Mesh/texture/audio için import budgets ve lisans denetimi uygulanacak fazda eklenir.
16. **Oyuncu-odaklı evrim:** sisteme eklenen her teknoloji oyuncunun algısal kazanımını ve bütçe maliyetini gerekçelendirmeli. Teknik üstünlük hissedilen performans/okunabilirliğe zarar veriyorsa tasarım yeniden değerlendirilir.
17. **Güvenlik/gizlilik:** cihaz günlüklerine, hata dump'ına veya telemetriye kişisel verileri/secret'ları plansız yazma; veri toplama sadece ihtiyaç olduğunda, rıza ve saklama politikasıyla tasarlanır. Harici eklentiler ve yapay üretim kaynakları için provenance/lisans audit.
18. **Kurtarma:** repo/asset yedekleme, yanlış commit geri alma ve artifact kaybında restore tatbikatı gelecekte planlanır. “main korunuyor” ancak branch rules doğrulaması ve yedek testiyle kanıtlanır.
