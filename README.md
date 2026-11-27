# FareOyunu — Native Terrain3D geliştirme dalı

> **Bu dalın aktif başlangıç noktası:** [Yeni sohbet / handoff](docs/native_terrain3d/HANDOFF_START_HERE_TR.md) · [Aktif ana plan](docs/native_terrain3d/NATIVE_TERRAIN3D_MASTER_PLAN_TR.md) · [İlerleme](docs/native_terrain3d/PROGRESS_TR.md).
> Eski TerraForge CPU runtime planları bu dalda tarihsel arşivdir. Sıradaki P1.8.2. [Mühendislik karar protokolü](docs/native_terrain3d/ENGINEERING_DECISIONS_TR.md). Orijinal dal ve geçmiş korunur.

## Aktif ürün kapsamı

TerraForge genel amaçlı terrain oluşturma ve düzenleme aracıdır. Dört Havza yalnızca test sahnesidir; oyun haritası veya zorunlu dünya formatı değildir. Joystickli gezinti ve fizik, üretilen arazinin doğrulama aracıdır. Oyun içeriği ve oyun sistemleri aktif kapsam dışıdır.

## Orijinal depo açıklaması (tarihsel)

Godot 4.7.2 (Mobile renderer) hedefli, çok adalı açık dünya fare oyunu.

`main` kararlı entegrasyon dalıdır. Üretim adımları ayrı `feat/`, `chore/`, `fix/` dallarında, test ve inceleme sonrası PR ile birleştirilir. İlk aşama teknik gereksinimler, arazi verisi doğrulaması ve üretim pipeline planıdır; henüz oynanabilir dünya uygulanmamıştır.
