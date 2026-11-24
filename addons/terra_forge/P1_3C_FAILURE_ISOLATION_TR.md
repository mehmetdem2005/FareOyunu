# P1.3c — Bölgesel hata izolasyonu ve son sağlam geometri

> **GÜNCEL DEVİR — P1.3c (24 Kasım 2026):** Kod/test SHA `4790ef5bd411b5ca4a3865366d694809e9f8078c`, [27/27 Linux Godot CI PASS](https://github.com/mehmetdem2005/FareOyunu/actions/runs/45424020683). Önce [P1_3C_FAILURE_ISOLATION_TR.md](P1_3C_FAILURE_ISOLATION_TR.md) oku. Aşağıdaki 26/26 referansları tarihsel v0.4.4-dev.1 kaydıdır. Sonraki iş: izole Android profil sahnesi/ölçüm aracı (strict vs lazy startup, first collision, frame p95/p99, resident page/mesh ve IO), ardından P1.4 atomik generation transaction. Gerçek telefon testi hâlâ AÇIK; boya/obje yok.

## Uygulama
paged_terrain_preview.gd: _blocked_tiles map, _block_tile(), blocked_tiles/retained_failed_tiles stats; terminal error olan tile yeni IO almadan atlanır; generation/LOD/neighbor değişimi yeniden değerlendirebilir. Kaynak hata cache'i generation-local. Stop temizler. Eski editable node değişmedi.

R-21: Hasarlı page yakın tile üzerinden head-of-line blocking yapabiliyordu. Artık generation-local blocked tile; aynı koordinatta mevcut sağlam geometry korunur. Hiç yüklenmeyen tile veya view dışı tile için collision garanti edilmez. Retained LOD komşu seam QA gerekir; gerçek Android ve P1.4 açık.

## CI ve geçmiş
P1.3c: 79f27560 (kod), 0b41af31 (test), 241e28f3 (runner), 4790ef5b (legacy test zamanlama düzeltmesi). İlk CI 26/27; yeni test geçti, eski test 3ms altında her zaman iki mesh bekliyordu. Son CI 27/27. Plugin.cfg sürümü değiştirilmedi.

27. test: test_paged_failure_isolation.gd; disposable cold missing page, aynı mesh/shape identity, bağımsız tile LOD0 collision, 9 page cap, no fake height, immutable TFH, no same-generation IO retry. Eski test_stream_budget.gd artık frame başına 1–2 iş, queue conservation ve eventual completion kontrol eder; üretim bütçesi değişmedi.

İlk başarısız run: https://github.com/mehmetdem2005/FareOyunu/actions/runs/45423829642 . Üretim kodu veya zaman bütçesi gevşetilmedi. Sadece eski testin yanlış kesin iki mesh varsayımı giderildi.

## Sonraki tek iş
Ayrı Android profil sahnesi: izole snapshot ile strict/lazy startup ve ilk collision süreleri, bounded frame/IO histogram, resident sayfalar/mesh count, export edilebilir cihaz raporu. Linux headless ölçümleri Android GPU/RSS kanıtı değildir. Ardından P1.4 copy-on-write immutable generation transaction, crash injection. main, oyun dosyaları, TFH/TFL korunur.
