import 'package:flutter/material.dart';

import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'duzenli.dart';
import 'ekle.dart';
import 'odendi.dart';
import 'sayfalar.dart';

class OzetSayfasi extends StatelessWidget {
  const OzetSayfasi({super.key, required this.git, required this.genis, this.disaAktar});
  final void Function(Sayfa) git;
  final bool genis;
  final VoidCallback? disaAktar;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) => genis ? _genis(context) : _dar(context),
      );

  // ---- Telefon ----

  Widget _dar(BuildContext context) {
    final s = Store.i;
    final simdi = DateTime.now();
    final o = ayOzeti(ayBasi(simdi), simdi, s.kayitlar, s.duzenliler);
    final sor = s.sorulacaklar(simdi);
    final bos = s.kayitlar.isEmpty && s.duzenliler.isEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Row(
          children: [
            const TeraziMark(size: 32),
            const SizedBox(width: 10),
            Text('Terazi', style: oaDisplay(22)),
            const Spacer(),
            Text(ayAdi(simdi), style: oaBody(15, color: OA.muted, weight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 18),
        _KalanKarti(o),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Kucuk('Gelir', para(o.gelir, isaret: true, kurussuz: true), OA.green)),
            const SizedBox(width: 12),
            Expanded(child: _Kucuk('Gider', para(-o.gider, kurussuz: true), OA.text)),
          ],
        ),
        for (final t in sor) ...[const SizedBox(height: 12), _SoruKarti(t)],
        const SizedBox(height: 12),
        _SiradakiKarti(o, git: git),
        if (bos) ...[
          const SizedBox(height: 12),
          OACard(
            child: Bos(Icons.account_balance_wallet_outlined, 'Terazi\'ye hoş geldin',
                'İlk gelirini ya da giderini ekle; ay sonuna kadar günde ne kadar harcayabileceğini hesaplayayım.',
                eylem: 'İlk kaydı ekle', onEylem: () => kayitAc(context, tur: Tur.gelir)),
          ),
        ] else ...[
          const SizedBox(height: 24),
          Baslik('Bütçeler', eylem: 'Tümü', onEylem: () => git(Sayfa.butceler)),
          _ButceListesi(adet: 3, git: git),
          const SizedBox(height: 18),
          Baslik('Son hareketler', eylem: 'Tümü', onEylem: () => git(Sayfa.hareketler)),
          if (s.kayitlar.isEmpty)
            Text('Henüz kayıt yok.', style: oaBody(15, color: OA.muted))
          else
            for (final k in s.kayitlar.take(5)) HareketSatiri(k, bugun: simdi, onTap: () => kayitAc(context, kayit: k)),
        ],
      ],
    );
  }

  // ---- Windows / geniş ekran ----

  Widget _genis(BuildContext context) {
    final s = Store.i;
    final simdi = DateTime.now();
    final ay = ayBasi(simdi);
    final o = ayOzeti(ay, simdi, s.kayitlar, s.duzenliler);
    final sor = s.sorulacaklar(simdi);
    final kiyas = oncekiAyla(ay, s.kayitlar);
    final kalanGun = ayinGunSayisi(simdi.year, simdi.month) - simdi.day;
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ayAdi(simdi), style: oaDisplay(30)),
                  Text(kalanGun == 0 ? 'Ayın son günü' : 'Ay sonuna $kalanGun gün var',
                      style: oaBody(15, color: OA.muted)),
                ],
              ),
            ),
            if (disaAktar != null) ...[OAButton('Dışa aktar', onPressed: disaAktar), const SizedBox(width: 10)],
            OAButton('Yeni kayıt', kind: OAButtonKind.primary, onPressed: () => kayitAc(context)),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Istatistik('Kalan', para(o.kalan, kurussuz: true), renk: o.kalan < 0 ? OA.danger : OA.text)),
            const SizedBox(width: 14),
            Expanded(child: _Istatistik('Gelir', para(o.gelir, kurussuz: true), renk: OA.green)),
            const SizedBox(width: 14),
            Expanded(child: _Istatistik('Gider', para(o.gider, kurussuz: true), alt: kiyas)),
            const SizedBox(width: 14),
            Expanded(
              child: _Istatistik('Günde harcayabileceğin', para(o.gunluk, kurussuz: true),
                  renk: OA.amber, alt: o.yaklasan > 0 ? 'Yaklaşan ödemeler düşüldü' : null),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final t in sor) ...[_SoruKarti(t), const SizedBox(height: 12)],
                  OACard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Baslik('Son hareketler', eylem: 'Tümünü gör', onEylem: () => git(Sayfa.hareketler)),
                        if (s.kayitlar.isEmpty)
                          Bos(Icons.receipt_long_outlined, 'Henüz kayıt yok', 'Gelir ve giderlerin burada listelenir.',
                              eylem: 'İlk kaydı ekle', onEylem: () => kayitAc(context, tur: Tur.gelir))
                        else
                          HareketTablosu(s.kayitlar.take(8).toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OACard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Baslik('Yaklaşan ödemeler', eylem: 'Takvim', onEylem: () => git(Sayfa.takvim)),
                        ..._yaklasanSatirlari(context, s, simdi),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  OACard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Baslik('Bütçeler', eylem: 'Düzenle', onEylem: () => git(Sayfa.butceler)),
                        _ButceListesi(adet: 5, git: git),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _yaklasanSatirlari(BuildContext context, Store s, DateTime simdi) {
    final y = s.yaklasanlar(simdi).take(5).toList();
    if (y.isEmpty) {
      return [
        Text('Kredi, kira, abonelik gibi her ay tekrar eden ödemelerini ekle.', style: oaBody(15, color: OA.muted)),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: OAButton('Düzenli ödeme ekle', onPressed: () => duzenliAc(context))),
      ];
    }
    return [for (final t in y) TekrarSatiri(t, bugun: simdi)];
  }
}

class _KalanKarti extends StatelessWidget {
  const _KalanKarti(this.o);
  final AyOzeti o;

  @override
  Widget build(BuildContext context) {
    final eksik = o.kalan - o.yaklasan;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OA.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OA.amber.withValues(alpha: 0.13), OA.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bu ay kalan', style: oaBody(15, color: OA.text2, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(para(o.kalan, kurussuz: true), style: oaDisplay(46, color: o.kalan < 0 ? OA.danger : OA.text)),
          ),
          const SizedBox(height: 6),
          if (o.yaklasan > 0 && eksik < 0)
            Text('Yaklaşan ödemeler bu ayki kalanı ${para(-eksik, kurussuz: true)} aşıyor.',
                style: oaBody(15, color: OA.danger))
          else
            Text(
              o.yaklasan > 0
                  ? 'Yaklaşan ödemeler düşülünce günde ${para(o.gunluk, kurussuz: true)}'
                  : 'Ay sonuna kadar günde ${para(o.gunluk, kurussuz: true)}',
              style: oaBody(15, color: OA.amber, weight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

class _Kucuk extends StatelessWidget {
  const _Kucuk(this.etiket, this.deger, this.renk);
  final String etiket;
  final String deger;
  final Color renk;

  @override
  Widget build(BuildContext context) => OACard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket, style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(deger, style: oaDisplay(22, color: renk))),
          ],
        ),
      );
}

class _Istatistik extends StatelessWidget {
  const _Istatistik(this.etiket, this.deger, {this.renk = OA.text, this.alt});
  final String etiket;
  final String deger;
  final Color renk;
  final String? alt;

  @override
  Widget build(BuildContext context) => OACard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket, style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(deger, style: oaDisplay(30, color: renk))),
            const SizedBox(height: 2),
            Text(alt ?? ' ', style: oaBody(13, color: OA.muted)),
          ],
        ),
      );
}

/// "Kredi taksiti ödendi mi?" kartı.
class _SoruKarti extends StatelessWidget {
  const _SoruKarti(this.t);
  final Tekrar t;

  @override
  Widget build(BuildContext context) {
    final d = t.duzenli;
    final bugun = DateTime.now();
    final h = t.hal(bugun);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OA.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: h == TekrarHali.gecikti ? OA.danger : OA.amber, width: 1.5),
      ),
      child: Row(
        children: [
          TarihKutusu(t.tarih, renk: halRengi(h), boyut: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.ad} ödendi mi?', style: oaBody(16, weight: FontWeight.w700)),
                Text('${d.degisken ? '~' : ''}${para(d.tutar)} · ${kalanYazi(t.tarih, bugun)}',
                    style: oaBody(14, color: OA.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OAButton('Yanıtla', kind: OAButtonKind.primary, onPressed: () => odendiSor(context, t)),
        ],
      ),
    );
  }
}

/// Sıradaki düzenli ödeme ve bu ay kalanların toplamı.
class _SiradakiKarti extends StatelessWidget {
  const _SiradakiKarti(this.o, {required this.git});
  final AyOzeti o;
  final void Function(Sayfa) git;

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final simdi = DateTime.now();
    final y = s.yaklasanlar(simdi).where((t) => t.hal(simdi) != TekrarHali.gecikti).toList();
    if (s.duzenliler.isEmpty) {
      return OACard(
        child: Row(
          children: [
            const Icon(Icons.event_repeat_outlined, color: OA.amber, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Kredi, kira, abonelik gibi ödemelerini bir kez ekle; her ay kendiliğinden takvime düşsün.',
                  style: oaBody(15, color: OA.text2)),
            ),
            const SizedBox(width: 10),
            OAButton('Ekle', onPressed: () => duzenliAc(context)),
          ],
        ),
      );
    }
    if (y.isEmpty) return const SizedBox.shrink();
    final t = y.first;
    final digerleri = o.acikTekrarlar
        .where((e) => !(e.duzenli.id == t.duzenli.id && e.donem == t.donem) && e.hal(simdi) != TekrarHali.gecikti).toList();
    final toplam = digerleri.fold<int>(0, (a, e) => a + e.duzenli.tutar);
    return InkWell(
      onTap: () => git(Sayfa.takvim),
      borderRadius: BorderRadius.circular(20),
      child: OACard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TarihKutusu(t.tarih),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.duzenli.ad, style: oaBody(16, weight: FontWeight.w700)),
                      Text('${t.sira} · ${kalanYazi(t.tarih, simdi)}', style: oaBody(14, color: OA.muted)),
                    ],
                  ),
                ),
                Text('${t.duzenli.degisken ? '~' : ''}${para(t.duzenli.tutar, kurussuz: true)}',
                    style: oaDisplay(20)),
              ],
            ),
            if (digerleri.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text('Bu ay ${digerleri.length} düzenli ödeme daha var · ${para(toplam)}',
                  style: oaBody(14, color: OA.text2)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bütçe çubukları (en çok dolanlar önce).
class _ButceListesi extends StatelessWidget {
  const _ButceListesi({required this.adet, required this.git});
  final int adet;
  final void Function(Sayfa) git;

  @override
  Widget build(BuildContext context) {
    final s = Store.i;
    final harcanan = kategoriGideri(ayBasi(DateTime.now()), s.kayitlar);
    final b = s.butceler.entries.toList()
      ..sort((x, y) => ((harcanan[y.key] ?? 0) / y.value).compareTo((harcanan[x.key] ?? 0) / x.value));
    if (b.isEmpty) {
      return InkWell(
        onTap: () => git(Sayfa.butceler),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('Market, eğlence gibi kategorilere aylık sınır koy; aşınca haber vereyim.',
              style: oaBody(15, color: OA.muted)),
        ),
      );
    }
    return Column(children: [for (final e in b.take(adet)) ButceSatiri(e.key, harcanan[e.key] ?? 0, e.value)]);
  }
}

class ButceSatiri extends StatelessWidget {
  const ButceSatiri(this.kat, this.harcanan, this.sinir, {super.key});
  final String kat;
  final int harcanan;
  final int sinir;

  @override
  Widget build(BuildContext context) {
    final k = kategori(kat);
    final asim = harcanan - sinir;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(k.ikon, size: 18, color: k.renk),
              const SizedBox(width: 8),
              Expanded(child: Text(k.ad, style: oaBody(15, weight: FontWeight.w600))),
              Text(
                '${para(harcanan, kurussuz: true)} / ${para(sinir, kurussuz: true)}${asim > 0 ? ' · ${para(asim, kurussuz: true)} aştı' : ''}',
                style: oaBody(14, color: asim > 0 ? OA.danger : OA.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Cubuk(harcanan / sinir, renk: k.renk),
        ],
      ),
    );
  }
}

/// Düzenli ödeme satırı (Özet, Takvim).
class TekrarSatiri extends StatelessWidget {
  const TekrarSatiri(this.t, {super.key, required this.bugun});
  final Tekrar t;
  final DateTime bugun;

  @override
  Widget build(BuildContext context) {
    final h = t.hal(bugun);
    final kapali = h == TekrarHali.odendi || h == TekrarHali.atlandi || h == TekrarHali.onceden;
    final d = t.duzenli;
    final tutar = t.tutar(Store.i.kayitlar);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (h == TekrarHali.onceden) {
          duzenliAc(context, duzenli: d);
        } else if (kapali) {
          _kapaliMenu(context);
        } else {
          odendiSor(context, t);
        }
      },
      onLongPress: () => duzenliAc(context, duzenli: d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            TarihKutusu(t.tarih, renk: halRengi(h), boyut: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: oaBody(16, weight: FontWeight.w600)),
                  Text('${t.sira}${d.degisken ? ' · tutar değişebilir' : ''}', style: oaBody(14, color: OA.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${d.degisken && h != TekrarHali.odendi ? '~' : ''}${para(tutar)}',
                    style: oaBody(15, weight: FontWeight.w700, color: kapali ? OA.muted : OA.text)),
                Text(halYazi(t, bugun), style: oaBody(13, color: halRengi(h), weight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _kapaliMenu(BuildContext context) async {
    final h = t.hal(bugun);
    final sec = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: OA.bg2,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.undo, color: OA.text2),
              title: Text(h == TekrarHali.odendi ? '"Ödendi" kararını geri al' : '"Bu ay ödenmeyecek" kararını geri al'),
              onTap: () => Navigator.pop(c, 'geri'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: OA.text2),
              title: const Text('Düzenli ödemeyi düzenle'),
              onTap: () => Navigator.pop(c, 'duzenle'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (sec == 'geri') Store.i.geriAl(t);
    if (sec == 'duzenle') await duzenliAc(context, duzenli: t.duzenli);
  }
}

/// Windows'taki hareket tablosu.
class HareketTablosu extends StatelessWidget {
  const HareketTablosu(this.kayitlar, {super.key});
  final List<Kayit> kayitlar;

  @override
  Widget build(BuildContext context) {
    Widget hucre(String s, {int flex = 2, TextAlign hiza = TextAlign.left, Color renk = OA.muted, bool kalin = false}) =>
        Expanded(
          flex: flex,
          child: Text(s,
              textAlign: hiza,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: oaBody(15, color: renk, weight: kalin ? FontWeight.w700 : FontWeight.w400)),
        );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(children: [
            hucre('Açıklama', flex: 3),
            hucre('Kategori'),
            hucre('Tarih'),
            hucre('Tutar', hiza: TextAlign.right),
          ]),
        ),
        const Divider(height: 1),
        for (final k in kayitlar)
          InkWell(
            onTap: () => kayitAc(context, kayit: k),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
              child: Row(children: [
                hucre(k.aciklama.isNotEmpty ? k.aciklama : kategori(k.kategori).ad, flex: 3, renk: OA.text, kalin: true),
                hucre(k.tur == Tur.gelir ? 'Gelir' : kategori(k.kategori).ad),
                hucre(tarihYazi(k.tarih)),
                hucre(para(k.isaretli, isaret: true),
                    hiza: TextAlign.right, renk: k.tur == Tur.gelir ? OA.green : OA.text, kalin: true),
              ]),
            ),
          ),
      ],
    );
  }
}
