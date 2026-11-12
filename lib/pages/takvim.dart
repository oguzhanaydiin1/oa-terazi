import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'duzenli.dart';
import 'ozet.dart';

/// Ödeme takvimi: düzenli ödemeler her ay kendiliğinden görünür.
class TakvimSayfasi extends StatefulWidget {
  const TakvimSayfasi({super.key, required this.genis});
  final bool genis;

  @override
  State<TakvimSayfasi> createState() => _TakvimSayfasiState();
}

class _TakvimSayfasiState extends State<TakvimSayfasi> {
  DateTime ay = ayBasi(DateTime.now());
  DateTime secili = gunBasi(DateTime.now());

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final simdi = DateTime.now();
          final tekrarlar = <Tekrar>[for (final d in s.duzenliler) if (d.ayda(ay) case final t?) t]
            ..sort((a, b) => a.tarih.compareTo(b.tarih));
          final gunun = tekrarlar.where((t) => ayniGun(t.tarih, secili)).toList();
          final kalan = tekrarlar.where((t) => t.acik(simdi)).fold<int>(0, (a, t) => a + t.duzenli.tutar);

          final takvim = OACard(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(child: Text(ayAdi(ay), style: oaDisplay(18))),
                    IconButton(
                      tooltip: 'Önceki ay',
                      onPressed: () => setState(() => ay = ayEkle(ay, -1)),
                      icon: const Icon(Icons.chevron_left, color: OA.text2),
                    ),
                    IconButton(
                      tooltip: 'Sonraki ay',
                      onPressed: () => setState(() => ay = ayEkle(ay, 1)),
                      icon: const Icon(Icons.chevron_right, color: OA.text2),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Izgara(ay: ay, secili: secili, bugun: simdi, tekrarlar: tekrarlar, sec: (g) => setState(() => secili = g)),
              ],
            ),
          );

          final gunListesi = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ayniGun(secili, simdi) ? 'Bugün, ${tarihYazi(secili)}' : tarihYazi(secili), style: oaDisplay(18)),
              const SizedBox(height: 6),
              if (gunun.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('Bu güne düzenli ödeme yok.', style: oaBody(15, color: OA.muted)),
                )
              else
                for (final t in gunun) TekrarSatiri(t, bugun: simdi),
            ],
          );

          final ayListesi = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Bu ay kalan düzenli ödemeler', style: oaBody(15, color: OA.text2, weight: FontWeight.w600))),
                  Text(para(kalan), style: oaDisplay(18, color: OA.amber)),
                ],
              ),
              const SizedBox(height: 6),
              if (tekrarlar.isEmpty)
                Bos(Icons.event_repeat_outlined, 'Düzenli ödeme yok',
                    'Kredi taksiti, kira, internet, abonelik… Bir kez ekle; kaç ay süreceğini seç, her ay kendiliğinden gelsin.',
                    eylem: 'Düzenli ödeme ekle', onEylem: () => duzenliAc(context))
              else
                for (final t in tekrarlar) TekrarSatiri(t, bugun: simdi),
            ],
          );

          final baslik = Row(
            children: [
              Expanded(child: Text('Ödeme takvimi', style: oaDisplay(widget.genis ? 30 : 24))),
              OAButton('Düzenli ödeme', onPressed: () => duzenliAc(context)),
            ],
          );

          if (widget.genis) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
              children: [
                baslik,
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(children: [takvim, const SizedBox(height: 18), OACard(child: gunListesi)]),
                    ),
                    const SizedBox(width: 18),
                    Expanded(flex: 2, child: OACard(child: ayListesi)),
                  ],
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              baslik,
              const SizedBox(height: 14),
              takvim,
              const SizedBox(height: 16),
              gunListesi,
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 10),
              ayListesi,
              const SizedBox(height: 8),
              Text('İpucu: bir ödemeye basılı tutarak düzenleyebilirsin.', style: oaBody(13, color: OA.faint)),
            ],
          );
        },
      );
}

class _Izgara extends StatelessWidget {
  const _Izgara({required this.ay, required this.secili, required this.bugun, required this.tekrarlar, required this.sec});
  final DateTime ay;
  final DateTime secili;
  final DateTime bugun;
  final List<Tekrar> tekrarlar;
  final ValueChanged<DateTime> sec;

  @override
  Widget build(BuildContext context) {
    final bos = DateTime(ay.year, ay.month, 1).weekday - 1; // Pazartesi = 0
    final gunler = ayinGunSayisi(ay.year, ay.month);
    final hucreler = bos + gunler;
    final satir = (hucreler / 7).ceil();
    return Column(
      children: [
        Row(
          children: [
            for (final g in gunKisa)
              Expanded(child: Center(child: Text(g, style: oaBody(12, color: OA.faint, weight: FontWeight.w600)))),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < satir; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _hucre(r * 7 + c - bos + 1, gunler)),
            ],
          ),
      ],
    );
  }

  Widget _hucre(int n, int gunler) {
    if (n < 1 || n > gunler) return const SizedBox(height: 46);
    final g = DateTime(ay.year, ay.month, n);
    final bu = tekrarlar.where((t) => t.tarih.day == n).toList();
    final secil = ayniGun(g, secili);
    final bugunMu = ayniGun(g, bugun);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: secil ? OA.amber : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => sec(g),
          child: Container(
            height: 42,
            decoration: bugunMu && !secil
                ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: OA.amber))
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$n',
                    style: oaBody(15,
                        color: secil ? OA.amberInk : OA.text, weight: bu.isNotEmpty ? FontWeight.w700 : FontWeight.w400)),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final t in bu.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: secil ? OA.amberInk : halRengi(t.hal(bugun)),
                        ),
                      ),
                    if (bu.isEmpty) const SizedBox(height: 6),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
