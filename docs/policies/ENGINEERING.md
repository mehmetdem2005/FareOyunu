# Mühendislik ve varlık politikası v1.0

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
