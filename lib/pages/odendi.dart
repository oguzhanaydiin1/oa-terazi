import 'package:flutter/material.dart';

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
    action: SnackBarAction(label: 'Geri al', textColor: OA.amber, onPressed: () => Store.i.geriAl(t)),
  ));
}

/// Bildirimdeki "Ödendi" düğmesi: tutar sabitse sormadan kaydeder.
void hizliOdendi(BuildContext context, Tekrar t) {
  Store.i.odendi(t, t.duzenli.tutar);
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text('${t.duzenli.ad} ödendi olarak kaydedildi · ${para(t.duzenli.tutar)}'),
    action: SnackBarAction(label: 'Geri al', textColor: OA.amber, onPressed: () => Store.i.geriAl(t)),
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

  static String _yaz(int k) {
    final l = k ~/ 100, c = k % 100;
    return c == 0 ? '$l' : '$l,${c.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    tutar.dispose();
    super.dispose();
  }

  void odendi() {
    final v = paraOku(tutar.text);
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödenen tutarı yaz.')));
      return;
    }
    Store.i.odendi(widget.t, v);
    Navigator.pop(context, '${widget.t.duzenli.ad} gider olarak kaydedildi · ${para(v)}');
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
                    Text('${d.ad} ödendi mi?', style: oaDisplay(21)),
                    const SizedBox(height: 2),
                    Text('${t.sira} · ${kat.ad} · ${kalanYazi(t.tarih, bugun)}', style: oaBody(14, color: OA.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Ödenen tutar', style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: tutar,
            autofocus: d.degisken,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: oaDisplay(26),
            decoration: const InputDecoration(prefixText: '₺ '),
            onSubmitted: (_) => odendi(),
          ),
          const SizedBox(height: 8),
          Text(
            d.degisken
                ? 'Bu ödemenin tutarı her ay değişebiliyor; bu ay ödediğin tutarı yaz.'
                : 'Farklıysa düzelt; bu ay için kaydedilir, sonraki aylar değişmez.',
            style: oaBody(14, color: OA.muted),
          ),
          const SizedBox(height: 20),
          OAButton('Ödendi, gider olarak kaydet', kind: OAButtonKind.primary, big: true, onPressed: odendi),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OAButton('Yarın hatırlat', onPressed: () {
                  Store.i.ertele(t);
                  Navigator.pop(context, 'Yarın yeniden soracağım.');
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OAButton('Bu ay ödenmeyecek', onPressed: () {
                  Store.i.atla(t);
                  Navigator.pop(context, '${d.ad} bu ay için kapatıldı.');
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
