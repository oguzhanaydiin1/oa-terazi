import 'package:flutter/material.dart';

import '../i18n.dart';
import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ekle.dart';

class HareketlerSayfasi extends StatefulWidget {
  const HareketlerSayfasi({super.key, required this.genis});
  final bool genis;

  @override
  State<HareketlerSayfasi> createState() => _HareketlerSayfasiState();
}

class _HareketlerSayfasiState extends State<HareketlerSayfasi> {
  DateTime ay = ayBasi(DateTime.now());
  Tur? filtre;
  String ara = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final simdi = DateTime.now();
          final q = ara.trim().toLowerCase();
          final liste = Store.i.kayitlar.where((k) {
            if (!ayniAy(k.tarih, ay)) return false;
            if (filtre != null && k.tur != filtre) return false;
            if (q.isEmpty) return true;
            return k.aciklama.toLowerCase().contains(q) || kategori(k.kategori).ad.toLowerCase().contains(q);
          }).toList();
          final gelir = liste.where((k) => k.tur == Tur.gelir).fold<int>(0, (a, k) => a + k.tutar);
          final gider = liste.where((k) => k.tur == Tur.gider).fold<int>(0, (a, k) => a + k.tutar);

          final govde = <Widget>[];
          DateTime? gun;
          for (final k in liste) {
            if (gun == null || !ayniGun(gun, k.tarih)) {
              gun = k.tarih;
              final g = gun;
              final net = liste.where((e) => ayniGun(e.tarih, g)).fold<int>(0, (a, e) => a + e.isaretli);
              govde.add(Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4, left: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(gunYazi(g, simdi), style: oaBody(14, color: OA.muted, weight: FontWeight.w700))),
                    Text(para(net, isaret: true), style: oaBody(14, color: OA.muted)),
                  ],
                ),
              ));
            }
            govde.add(HareketSatiri(k, onTap: () => kayitAc(context, kayit: k)));
          }

          return ListView(
            padding: EdgeInsets.fromLTRB(widget.genis ? 32 : 20, widget.genis ? 28 : 16, widget.genis ? 32 : 20, 110),
            children: [
              Row(
                children: [
                  Expanded(child: Text(L('Hareketler'), style: oaDisplay(widget.genis ? 30 : 24))),
                  AySecici(ay, (a) => setState(() => ay = a)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => ara = v),
                style: oaBody(16),
                decoration: InputDecoration(
                  hintText: L('Ara: açıklama ya da kategori'),
                  prefixIcon: Icon(Icons.search, color: OA.faint),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Secim(L('Tümü'), filtre == null, () => setState(() => filtre = null)),
                  Secim(L('Gider'), filtre == Tur.gider, () => setState(() => filtre = Tur.gider)),
                  Secim(L('Gelir'), filtre == Tur.gelir, () => setState(() => filtre = Tur.gelir)),
                ],
              ),
              const SizedBox(height: 12),
              OACard(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: _Toplam(L('Gelir'), para(gelir), OA.green)),
                    Expanded(child: _Toplam(L('Gider'), para(gider), OA.text)),
                    Expanded(child: _Toplam(L('Net'), para(gelir - gider, isaret: true), gelir >= gider ? OA.amber : OA.danger)),
                  ],
                ),
              ),
              if (liste.isEmpty)
                Bos(Icons.receipt_long_outlined, L('Bu ay için kayıt yok'),
                    q.isNotEmpty ? L('Aramana uyan kayıt bulunamadı.') : L('Eklediğin gelir ve giderler burada gün gün listelenir.'))
              else
                ...govde,
            ],
          );
        },
      );
}

class _Toplam extends StatelessWidget {
  const _Toplam(this.e, this.d, this.r);
  final String e;
  final String d;
  final Color r;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e, style: oaBody(13, color: OA.muted, weight: FontWeight.w600)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(d, style: oaBody(16, color: r, weight: FontWeight.w700))),
        ],
      );
}
