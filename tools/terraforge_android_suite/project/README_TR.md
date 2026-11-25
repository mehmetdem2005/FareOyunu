# TerraForge Android otomatik test paketi

Godot 4.7.2 Android Editor'de ZIP'i çıkarıp **project.godot** dosyasını içe aktar ve Play (F6 değil, F5 / Run Project) bas. Proje otomatik başlar. Gerçek oyun projesini veya arazilerini açmaz. Test verileri ayrı user:// alanında oluşturulur.

- 90 orijinal regresyonun SceneTree giriş/çıkışını Node'a uyarlayan otomatik koşucu; her testten sonra sonuç kaydedilir.
- Gerçek Mobile Renderer profilinde 1024×1024 TFM2, 20 saniyelik 6 koşu: A/E/F/G/H/A. Aynı sahne ve rota.
- JSON KOPYALA: devam eden veya tamamlanmış özet rapor. Ayrıntılı ham kayıtlar user://tf_android_details/ içinde test başına JSON.
- Uygulama kapanırsa tekrar aç: son geçerli kontrol noktası alınır, yarım test "interrupted" olarak işaretlenir. "Yeniden başlat" tüm testleri baştan başlatır.
- Test süresince ekranı açık tut, başka uygulamaya geçme. Şarja bağlı olup olmadığını ve başlangıçta cihazın ısısını ChatGPT'ye ayrıca bildir. Telefon aşırı ısınırsa durdur. Bazı eşzamanlı eski testler ana iş parçacığını bloke edebilir; duraklatma bir sonraki test sınırında işler.
- Android'deki ortak süreç sonuçları Linux CI ile birebir eşdeğer değildir. Native çökme veya kilitlenme PASS sayılmaz. RSS örneklenmiş süreç belleği; GPU süresi değildir. Termal sensör erişimi garanti edilmez.
- Rapor dosyaları user://tf_android_report_a.json ve _b.json. JSON kopyalamak mümkün değilse Godot kullanıcı verisi klasöründen dosyaları paylaş.
