import 'package:flutter/material.dart';

import '../i18n.dart';
import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class RaporlarSayfasi extends StatefulWidget {
  const RaporlarSayfasi({super.key, required this.genis});
  final bool genis;

  @override
  State<RaporlarSayfasi> createState() => _RaporlarSayfasiState();
}

class _RaporlarSayfasiState extends State<RaporlarSayfasi> {
  DateTime ay = ayBasi(DateTime.now());

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final gider = ayGideri(ay, s.kayitlar);
          final kiyas = oncekiAyla(ay, s.kayitlar);
          final kat = kategoriGideri(ay, s.kayitlar).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final aylar6 = [for (var i = 5; i >= 0; i--) ayEkle(ay, -i)];
          final degerler = [for (final a in aylar6) ayGideri(a, s.kayitlar)];
          final yorum = _yorum(s, ay);

          final grafik = OACard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Lx('${aylar[ay.month - 1]} gideri', 'Spending in ${aylar[ay.month - 1]}'), style: oaBody(15, color: OA.text2, weight: FontWeight.w600)),
                Text(para(gider, kurussuz: true), style: oaDisplay(38)),
                if (kiyas != null) Text(kiyas, style: oaBody(14, color: OA.muted)),
                const SizedBox(height: 18),
                _Cubuklar(aylar6, degerler),
              ],
            ),
          );

          final dagilim = OACard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Baslik(L('Nereye gitti?')),
                if (kat.isEmpty)
                  Text(L('Bu ay gider yok.'), style: oaBody(15, color: OA.muted))
                else ...[
                  for (final e in kat.take(5)) _KategoriSatiri(e.key, e.value, gider),
                  if (kat.length > 5)
                    _KategoriSatiri(null, kat.skip(5).fold<int>(0, (a, e) => a + e.value), gider,
                        ad: Lx('Diğer ${kat.length - 5} kategori', '${kat.length - 5} other categories')),
                ],
              ],
            ),
          );

          final ipucu = yorum == null
              ? null
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: OA.amber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: OA.amber.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline, color: OA.amber),
                      const SizedBox(width: 10),
                      Expanded(child: Text(yorum, style: oaBody(15, color: OA.text2))),
                    ],
                  ),
                );

          final baslik = Row(
            children: [
              Expanded(child: Text(L('Raporlar'), style: oaDisplay(widget.genis ? 30 : 24))),
              AySecici(ay, (a) => setState(() => ay = a)),
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
                    Expanded(child: Column(children: [grafik, if (ipucu != null) ...[const SizedBox(height: 18), ipucu]])),
                    const SizedBox(width: 18),
                    Expanded(child: dagilim),
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
              grafik,
              const SizedBox(height: 14),
              dagilim,
              if (ipucu != null) ...[const SizedBox(height: 14), ipucu],
            ],
          );
        },
      );

  /// Ayın en dikkat çekici durumu: aşılan bütçe ya da en çok artan kategori.
  String? _yorum(Store s, DateTime ay) {
    final bu = kategoriGideri(ay, s.kayitlar);
    final once = kategoriGideri(ayEkle(ay, -1), s.kayitlar);
    for (final e in s.butceler.entries) {
      final h = bu[e.key] ?? 0;
      if (h > e.value) {
        return Lx('${kategori(e.key).ad} bütçeni ${para(h - e.value, kurussuz: true)} aştın '
            '(${para(h, kurussuz: true)} / ${para(e.value, kurussuz: true)}).',
            'You’re ${para(h - e.value, kurussuz: true)} over your ${kategori(e.key).ad} budget '
            '(${para(h, kurussuz: true)} / ${para(e.value, kurussuz: true)}).');
      }
    }
    String? enCok;
    var fark = 0;
    for (final e in bu.entries) {
      final f = e.value - (once[e.key] ?? 0);
      if (f > fark) {
        fark = f;
        enCok = e.key;
      }
    }
    if (enCok != null && (once[enCok] ?? 0) > 0) {
      return Lx('Geçen aya göre en çok artan kalem ${kategori(enCok).ad}: ${para(fark, kurussuz: true)} fazla.',
          'The category that grew most since last month is ${kategori(enCok).ad}: ${para(fark, kurussuz: true)} more.');
    }
    return null;
  }
}

class _Cubuklar extends StatelessWidget {
  const _Cubuklar(this.aylar6, this.degerler);
  final List<DateTime> aylar6;
  final List<int> degerler;

  @override
  Widget build(BuildContext context) {
    final enBuyuk = degerler.fold<int>(1, (a, b) => b > a ? b : a);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < aylar6.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: para(degerler[i], kurussuz: true),
                      child: Container(
                        height: 4 + 112 * degerler[i] / enBuyuk,
                        decoration: BoxDecoration(
                          color: i == aylar6.length - 1 ? OA.amber : OA.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(ayKisa[aylar6[i].month - 1],
                        style: oaBody(13,
                            color: i == aylar6.length - 1 ? OA.text : OA.muted, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KategoriSatiri extends StatelessWidget {
  const _KategoriSatiri(this.id, this.tutar, this.toplam, {this.ad});
  final String? id;
  final int tutar;
  final int toplam;
  final String? ad;

  @override
  Widget build(BuildContext context) {
    final k = id == null ? null : kategori(id!);
    final oran = toplam == 0 ? 0.0 : tutar / toplam;
    final renk = k?.renk ?? OA.faint;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(k?.ikon ?? Icons.more_horiz, size: 18, color: renk),
              const SizedBox(width: 8),
              Expanded(child: Text(ad ?? k!.ad, style: oaBody(15, weight: FontWeight.w600))),
              Text('%${(oran * 100).round()}', style: oaBody(14, color: OA.muted)),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: Text(para(tutar, kurussuz: true),
                    textAlign: TextAlign.right, style: oaBody(15, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Cubuk(oran, renk: renk, yukseklik: 6),
        ],
      ),
    );
  }
}
