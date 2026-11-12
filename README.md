# Terazi: Gelir Gider Takibi

OA Labs'in bütçe uygulaması (Android ve Windows, Flutter).

- Gelir ve gider kaydı; bu ay kalan ve ay sonuna kadar günde harcanabilecek tutar
- Ödeme takvimi: kredi taksiti, kira, abonelik gibi düzenli ödemeler bir kez eklenir, kaç ay süreceği seçilir
- Ödeme günü "Ödendi mi?" sorusu ve Android bildirimi
- Kategori bütçeleri ve aylık raporlar

Veriler cihazda `terazi.json` dosyasında saklanır.

## Derleme

`main` dalına her gönderimde GitHub Actions Windows kurulum programını (`Terazi-Kurulum.exe`) ve Android APK'sını derler,
`pubspec.yaml`'daki sürümle Releases'a ekler. Yeni sürüm için `version`'ı artır ve `release-notes.md`'ye not yaz.

Platform klasörleri depoda tutulmaz; `scripts/platform_hazirla.sh` derleme sırasında üretir.
