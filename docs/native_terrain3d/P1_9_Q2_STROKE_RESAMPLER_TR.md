# P1.9-Q2 — Kesintisiz fırça hareketi (izole deney)

Base: 48ebba3d29275011474724371c2bbb6e12fecbb7. Önceki native batch CI46065290637 korunur. Üretim dalı veya Türkçe panel değiştirilmedi.

Mevcut native_brush.dab 16.384 aday üzerindeki hareketleri önceki maliyete göre en az 75 ms boyunca atlıyor; iki kabul edilen nokta arasında örnek üretmiyor. Aday saf dünya koordinatı örnekleyici, yay uzunluğu fazını olaylar arasında korur, köşeyi takip eder, ray boşluğunda köprü kurmaz, kuyruğu 256 örnekle sınırlar ve kapasite aşımında atomik ret verir. Son nokta yarım adım veya daha uzaktaysa eklenir. Bekleyen örnekler tek tek tüketilebilir.

Bu deney sadece çekirdeği ve deterministik testlerini içerir; canlı editöre bağlı DEĞİL. Bir sonraki adım: tek karede sınırlı sayıda dab; native dab zaman/mesafe kapısını sadece planlanmış örneklerde atlamak; yük/işlem süresine göre yayınlama, gesture release sonrası kontrollü drain, save/undo/terrain switch ve multi-touch yaşam döngüsü. Ret gizlenmeyecek: tüketici bekleyen parçayı tekrar sunacak veya açık iptal bildirecek. Native işlem tek başına bütçeyi aşabilir, GPU upload ve raycast henüz ölçülmedi. Başarı yalnızca örnekleyici kanıtı, FPS veya tüm fırça kalitesi değildir. Üretime alma için gerçek editör ve Android testi gerekir.
