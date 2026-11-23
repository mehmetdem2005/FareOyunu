# SE-01 / Güneydoğu ada heightmap provenance v1.0

## Alınan veri
Kullanıcı görseli adı PNG gibi bitiyor, gerçek codec JPEG (JFIF), RGB uint8, 1536x1536.
SHA-256 kaynak: e5f3348669c1941fdf0ec225fff46c54c31cc4f101ddc5204ecdaaaa319b1d4e
Bu resim metre cinsinden ölçülmüş bir DEM değil, yükseklik temsili olarak değerlendirilen görseldir.

## Dönüştürme
Pillow convert(L) ile RGB -> 8-bit gri kanal (BT.601 luma ağırlıkları); her byte / 255.0 ile float32 [0,1] olur. Gamma veya otomatik min/max stretch uygulanmaz. OpenCV OpenEXR single-channel float32 / PIZ.
Output önerilen yolu: assets/terrain/heightmaps/island_se_01_f32.exr
Yerelde üretilen çıktının SHA-256 değeri: 126ba5de760160a1562b2beefc2000562a227007c21569feeda2db04deac0d1f
Çıktı: 1536x1536; grayscale sample min 0 max 161 (0..255 üzerinden); float32 min 0, max yaklaşık 0.63137257; EXR yazma-okuma max mutlak hata 0; 1,165,362 byte.
Bu FLOAT32 dosya orijinalde olmayan arazi detayını GERI GETIRMEZ; JPEG banding ve compression artifacts barındırabilir.

## Asset teslim/entegrasyon durumu
Dönüştürülmüş EXR ayrı indirme artifaktı olarak hazır; GitHub ikili commit bu adımda yok. Varlık registry'ye import, per-island positions, dünya ölçeği, mean sea level, erosion ve materyaller henüz seçilmedi. asset yokken testler asset varmış gibi raporlamaz.

## Kabul için sonraki işler
Kaynak EXR gerçek Godot 4.7.2 editor import ve FORMAT_RF doğrulama; asset commit ve checksum; dış konfigürasyon, @tool editör görünümü ve terrain-kıyı ilişkisi. Bu işler faz 1 kapsamındadır.
