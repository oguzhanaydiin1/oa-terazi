import 'package:flutter/material.dart';

import '../i18n.dart';
import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Düzenli ödemenin günü gelince: "Ödendi mi?"
Future<void> odendiSor(BuildContext context, Tekrar t) async {
  final sonuc = await altSayfa<String>(context, (_) => OdendiSayfasi(t));
  if (sonuc == null || !context.mounted) return;
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(sonuc),
    action: SnackBarAction(label: L('Geri al'), textColor: OA.amber, onPressed: () => Store.i.geriAl(t)),
  ));
}

/// Bildirimdeki "Ödendi" düğmesi: tutar sabitse sormadan kaydeder.
void hizliOdendi(BuildContext context, Tekrar t) {
  Store.i.odendi(t, t.duzenli.tutar);
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(Lx('${t.duzenli.ad} ödendi olarak kaydedildi · ${para(t.duzenli.tutar)}', '${t.duzenli.ad} recorded as paid · ${para(t.duzenli.tutar)}')),
    action: SnackBarAction(label: L('Geri al'), textColor: OA.amber, onPressed: () => Store.i.geriAl(t)),
  ));
}

class OdendiSayfasi extends StatefulWidget {
  const OdendiSayfasi(this.t, {super.key});
  final Tekrar t;

  @override
  State<OdendiSayfasi> createState() => _OdendiSayfasiState();
}

class _OdendiSayfasiState extends State<OdendiSayfasi> {
  late final tutar = TextEditingController(text: _yaz(widget.t.duzenli.tutar));

  static String _yaz(int k) => paraYaz(k);

  @override
  void dispose() {
    tutar.dispose();
    super.dispose();
  }

  void odendi() {
    final v = paraOku(tutar.text);
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L('Ödenen tutarı yaz.'))));
      return;
    }
    Store.i.odendi(widget.t, v);
    Navigator.pop(context, Lx('${widget.t.duzenli.ad} gider olarak kaydedildi · ${para(v)}', '${widget.t.duzenli.ad} recorded as spending · ${para(v)}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final d = t.duzenli;
    final bugun = DateTime.now();
    final kat = kategori(d.kategori);
    final h = t.hal(bugun);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TarihKutusu(t.tarih, renk: halRengi(h)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Lx('${d.ad} ödendi mi?', '${d.ad}: paid yet?'), style: oaDisplay(21)),
                    const SizedBox(height: 2),
                    Text('${t.sira} · ${kat.ad} · ${kalanYazi(t.tarih, bugun)}', style: oaBody(14, color: OA.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(L('Ödenen tutar'), style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: tutar,
            autofocus: d.degisken,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: oaDisplay(26),
            decoration: paraKutusu(ipucu: false),
            onSubmitted: (_) => odendi(),
          ),
          const SizedBox(height: 8),
          Text(
            d.degisken
                ? L('Bu ödemenin tutarı her ay değişebiliyor; bu ay ödediğin tutarı yaz.')
                : L('Farklıysa düzelt; bu ay için kaydedilir, sonraki aylar değişmez.'),
            style: oaBody(14, color: OA.muted),
          ),
          const SizedBox(height: 20),
          OAButton(L('Ödendi, gider olarak kaydet'), kind: OAButtonKind.primary, big: true, onPressed: odendi),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OAButton(L('Yarın hatırlat'), onPressed: () {
                  Store.i.ertele(t);
                  Navigator.pop(context, L('Yarın yeniden soracağım.'));
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OAButton(L('Bu ay ödenmeyecek'), onPressed: () {
                  Store.i.atla(t);
                  Navigator.pop(context, Lx('${d.ad} bu ay için kapatıldı.', '${d.ad} closed for this month.'));
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
