import 'package:flutter/material.dart';

import 'kategoriler.dart';
import 'models.dart';
import 'theme.dart';

/// Ekranlar arasında ortak parçalar.

/// "KAS / 14" tarih kutusu.
class TarihKutusu extends StatelessWidget {
  const TarihKutusu(this.tarih, {super.key, this.renk = OA.amber, this.boyut = 52});
  final DateTime tarih;
  final Color renk;
  final double boyut;

  @override
  Widget build(BuildContext context) => Container(
        width: boyut,
        height: boyut,
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: renk.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(ayKisa[tarih.month - 1].toUpperCase(),
                style: oaBody(boyut * 0.21, color: renk, weight: FontWeight.w700, height: 1.1)),
            Text('${tarih.day}', style: oaDisplay(boyut * 0.4, color: OA.text)),
          ],
        ),
      );
}

/// Bölüm başlığı ve sağında isteğe bağlı bağlantı.
class Baslik extends StatelessWidget {
  const Baslik(this.yazi, {super.key, this.eylem, this.onEylem});
  final String yazi;
  final String? eylem;
  final VoidCallback? onEylem;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(yazi, style: oaDisplay(19))),
            if (eylem != null)
              TextButton(
                onPressed: onEylem,
                style: TextButton.styleFrom(foregroundColor: OA.amber, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(eylem!, style: oaBody(15, color: OA.amber, weight: FontWeight.w600)),
              ),
          ],
        ),
      );
}

/// İlerleme çubuğu; sınır aşıldıysa kırmızı.
class Cubuk extends StatelessWidget {
  const Cubuk(this.oran, {super.key, this.renk = OA.amber, this.yukseklik = 8});
  final double oran;
  final Color renk;
  final double yukseklik;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: yukseklik,
          child: Stack(
            children: [
              Container(color: OA.surface2),
              FractionallySizedBox(
                widthFactor: oran.clamp(0.0, 1.0).toDouble(),
                child: Container(color: oran > 1 ? OA.danger : renk),
              ),
            ],
          ),
        ),
      );
}

/// Hareket listesi satırı.
class HareketSatiri extends StatelessWidget {
  const HareketSatiri(this.k, {super.key, this.onTap, this.bugun});
  final Kayit k;
  final VoidCallback? onTap;
  final DateTime? bugun;

  @override
  Widget build(BuildContext context) {
    final kat = kategori(k.kategori);
    final ad = k.aciklama.isNotEmpty ? k.aciklama : kat.ad;
    final alt = k.tur == Tur.gelir ? 'Gelir' : kat.ad;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            KategoriIkon(kat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: oaBody(16, weight: FontWeight.w600)),
                  Text(bugun == null ? alt : '$alt · ${gunYazi(k.tarih, bugun!)}',
                      style: oaBody(14, color: OA.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(para(k.isaretli, isaret: true),
                style: oaBody(16, weight: FontWeight.w700, color: k.tur == Tur.gelir ? OA.green : OA.text)),
          ],
        ),
      ),
    );
  }
}

/// Boş liste yerine gösterilen kısa açıklama.
class Bos extends StatelessWidget {
  const Bos(this.ikon, this.baslik, this.metin, {super.key, this.eylem, this.onEylem});
  final IconData ikon;
  final String baslik;
  final String metin;
  final String? eylem;
  final VoidCallback? onEylem;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          children: [
            Icon(ikon, size: 40, color: OA.faint),
            const SizedBox(height: 12),
            Text(baslik, textAlign: TextAlign.center, style: oaDisplay(18)),
            const SizedBox(height: 6),
            Text(metin, textAlign: TextAlign.center, style: oaBody(15, color: OA.muted)),
            if (eylem != null) ...[
              const SizedBox(height: 16),
              OAButton(eylem!, kind: OAButtonKind.primary, onPressed: onEylem),
            ],
          ],
        ),
      );
}

/// Ay seçici: ‹ Kasım 2026 ›
class AySecici extends StatelessWidget {
  const AySecici(this.ay, this.degis, {super.key});
  final DateTime ay;
  final ValueChanged<DateTime> degis;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Önceki ay',
            onPressed: () => degis(ayEkle(ay, -1)),
            icon: const Icon(Icons.chevron_left, color: OA.text2),
          ),
          Text(ayAdi(ay), style: oaBody(16, weight: FontWeight.w600)),
          IconButton(
            tooltip: 'Sonraki ay',
            onPressed: () => degis(ayEkle(ay, 1)),
            icon: const Icon(Icons.chevron_right, color: OA.text2),
          ),
        ],
      );
}

/// Seçilebilir küçük düğme (kategori, süre, hatırlatma seçimleri).
class Secim extends StatelessWidget {
  const Secim(this.yazi, this.secili, this.onTap, {super.key, this.ikon});
  final String yazi;
  final bool secili;
  final VoidCallback onTap;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) => Material(
        color: secili ? OA.amber.withValues(alpha: 0.16) : OA.surface,
        shape: StadiumBorder(side: BorderSide(color: secili ? OA.amber : OA.border2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ikon != null) ...[
                  Icon(ikon, size: 18, color: secili ? OA.amber : OA.text2),
                  const SizedBox(width: 6),
                ],
                Text(yazi, style: oaBody(15, color: secili ? OA.amber : OA.text2, weight: FontWeight.w600, height: 1.1)),
              ],
            ),
          ),
        ),
      );
}

/// Alttan açılan sayfaların ortak çerçevesi.
Future<T?> altSayfa<T>(BuildContext context, Widget Function(BuildContext) build) {
  final genis = MediaQuery.sizeOf(context).width >= 900;
  if (genis) {
    return showDialog<T>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: OA.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: OA.border)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460, maxHeight: 760), child: build(c)),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: OA.bg2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: build,
  );
}

Color halRengi(TekrarHali h) => switch (h) {
      TekrarHali.odendi => OA.green,
      TekrarHali.atlandi || TekrarHali.onceden => OA.faint,
      TekrarHali.gecikti => OA.danger,
      TekrarHali.bugun || TekrarHali.yaklasan => OA.amber,
    };

String halYazi(Tekrar t, DateTime bugun) => switch (t.hal(bugun)) {
      TekrarHali.odendi => 'Ödendi',
      TekrarHali.atlandi => 'Bu ay yok',
      TekrarHali.onceden => 'Önceden',
      TekrarHali.gecikti => 'Ödendi mi?',
      TekrarHali.bugun => 'Bugün',
      TekrarHali.yaklasan => kalanYazi(t.tarih, bugun),
    };
