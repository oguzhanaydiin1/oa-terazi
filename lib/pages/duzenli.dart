import 'package:flutter/material.dart';

import '../i18n.dart';
import '../bildirim.dart';
import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Düzenli ödeme ekleme / düzenleme: her ay kendiliğinden takvime düşer, kaç ay süreceği seçilir.
Future<void> duzenliAc(BuildContext context, {Duzenli? duzenli}) =>
    altSayfa<void>(context, (_) => DuzenliSayfasi(duzenli: duzenli));

class DuzenliSayfasi extends StatefulWidget {
  const DuzenliSayfasi({super.key, this.duzenli});
  final Duzenli? duzenli;

  @override
  State<DuzenliSayfasi> createState() => _DuzenliSayfasiState();
}

class _DuzenliSayfasiState extends State<DuzenliSayfasi> {
  final bugun = gunBasi(DateTime.now());
  late final Duzenli? d = widget.duzenli;
  late final ad = TextEditingController(text: d?.ad ?? '');
  late final tutar = TextEditingController(text: d == null ? '' : _yaz(d!.tutar));
  late String kat = d?.kategori ?? 'kredi';
  late int gun = d?.gun ?? bugun.day;
  late bool suresiz = d?.suresiz ?? false;
  late int toplam = d?.ayAdedi ?? 12;
  late int sira = _ilkSira();
  late int hatirlat = d?.hatirlat ?? 1;
  late bool degisken = d?.degisken ?? false;

  static String _yaz(int k) => paraYaz(k);

  /// Sıradaki ödemenin ayı: günü bu ay henüz geçmediyse bu ay, geçtiyse gelecek ay.
  DateTime get siradakiAy {
    final son = ayinGunSayisi(bugun.year, bugun.month);
    final g = gun > son ? son : gun;
    return g >= bugun.day ? ayBasi(bugun) : ayEkle(bugun, 1);
  }

  DateTime get siradakiTarih {
    final a = siradakiAy;
    final son = ayinGunSayisi(a.year, a.month);
    return DateTime(a.year, a.month, gun > son ? son : gun);
  }

  int _ilkSira() {
    final x = d;
    if (x == null || x.suresiz) return 1;
    final n = ayFarki(x.baslangic, siradakiAy) + 1;
    return n < 1 ? 1 : (n > x.ayAdedi! ? x.ayAdedi! : n);
  }

  @override
  void dispose() {
    ad.dispose();
    tutar.dispose();
    super.dispose();
  }

  int get kalanOdeme => toplam - sira + 1;

  String get ozet {
    final t = paraOku(tutar.text) ?? 0;
    final gunYazisi = Lx(gun >= 29 ? 'her ${ayinGunu(gun)} (kısa aylarda son gün)' : 'her ${ayinGunu(gun)}',
        gun >= 29 ? 'on the ${ingSira(gun)} of each month (last day in short months)' : 'on the ${ingSira(gun)} of each month');
    final ilk = Lx('İlk hatırlatma ${tarihYazi(siradakiTarih)}.', 'First reminder ${tarihYazi(siradakiTarih)}.');
    if (t <= 0) return L('Tutarı yazınca özet burada görünecek.');
    if (suresiz) {
      return Lx('${para(t, kurussuz: true)} $gunYazisi, sen durdurana kadar. $ilk',
          '${para(t, kurussuz: true)} $gunYazisi, until you stop it. $ilk');
    }
    return Lx('${para(t, kurussuz: true)} $gunYazisi, $kalanOdeme ödeme daha · kalan toplam ${para(t * kalanOdeme, kurussuz: true)}. $ilk',
        '${para(t, kurussuz: true)} $gunYazisi, $kalanOdeme more payments · ${para(t * kalanOdeme, kurussuz: true)} left in total. $ilk');
  }

  Future<void> kaydet() async {
    final t = paraOku(tutar.text);
    final isim = ad.text.trim();
    if (isim.isEmpty || t == null || t <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L('Ödemenin adını ve aylık tutarını yaz.'))));
      return;
    }
    final baslangic = suresiz ? siradakiAy : ayEkle(siradakiAy, -(sira - 1));
    final x = d;
    final yeni = Duzenli(
      id: x?.id ?? yeniId(),
      ad: isim,
      tutar: t,
      kategori: kat,
      gun: gun,
      baslangic: x != null && suresiz && x.suresiz ? x.baslangic : baslangic,
      takipten: x?.takipten ?? bugun,
      ayAdedi: suresiz ? null : toplam,
      hatirlat: hatirlat,
      degisken: degisken,
      durumlar: x?.durumlar,
      ertelenen: x?.ertelenen,
    );
    Store.i.duzenliKaydet(yeni);
    Navigator.pop(context);
    if (x == null) await Bildirim.izinIste();
  }

  Future<void> sil() async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: OA.surface,
        title: Text(L('Düzenli ödeme silinsin mi?'), style: oaDisplay(20)),
        content: Text(L('Takvimden kalkar. Daha önce "ödendi" dediğin aylar hareketlerinde kalır.'),
            style: oaBody(15, color: OA.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Vazgeç'))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(L('Sil'), style: oaBody(15, color: OA.danger, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (evet == true && mounted) {
      Store.i.duzenliSil(d!.id);
      Navigator.pop(context);
    }
  }

  Widget etiket(String s) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(s, style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final bitis = ayEkle(siradakiAy, kalanOdeme - 1);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(d == null ? L('Düzenli ödeme') : L('Düzenli ödemeyi düzenle'), style: oaDisplay(22))),
              if (d != null)
                IconButton(tooltip: L('Sil'), onPressed: sil, icon: Icon(Icons.delete_outline, color: OA.danger)),
              IconButton(
                tooltip: L('Kapat'),
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: OA.text2),
              ),
            ],
          ),
          etiket(L('Ne ödüyorsun?')),
          TextField(
            controller: ad,
            style: oaBody(17),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: L('Kredi taksiti, kira, internet…')),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in giderKategorileri)
                Secim(c.ad, c.id == kat, () => setState(() => kat = c.id), ikon: c.ikon),
            ],
          ),
          etiket(L('Aylık tutar')),
          TextField(
            controller: tutar,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: oaDisplay(24),
            decoration: paraKutusu(),
            onChanged: (_) => setState(() {}),
          ),
          etiket(L('Her ayın')),
          _Sayac(
            yazi: Lx('$gun. günü', 'Day $gun'),
            azalt: gun > 1 ? () => setState(() => gun--) : null,
            artir: gun < 31 ? () => setState(() => gun++) : null,
          ),
          etiket(L('Kaç ay sürecek?')),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(L('Belli bir süre'))),
              ButtonSegment(value: true, label: Text(L('Süresiz'))),
            ],
            selected: {suresiz},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => suresiz = s.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: OA.surface,
              foregroundColor: OA.text2,
              selectedBackgroundColor: OA.amber,
              selectedForegroundColor: OA.amberInk,
              side: BorderSide(color: OA.border2),
            ),
          ),
          const SizedBox(height: 12),
          if (suresiz)
            Text(L('Kira, abonelik ve fatura gibi; sen durdurana kadar her ay eklenir.'), style: oaBody(14, color: OA.muted))
          else ...[
            _Sayac(
              yazi: Lx('$toplam ay', '$toplam months'),
              azalt: toplam > 1
                  ? () => setState(() {
                        toplam--;
                        if (sira > toplam) sira = toplam;
                      })
                  : null,
              artir: toplam < 360 ? () => setState(() => toplam++) : null,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final n in [3, 6, 12, 24, 36, 48])
                  Secim(Lx('$n ay', '$n months'), toplam == n, () => setState(() {
                        toplam = n;
                        if (sira > toplam) sira = toplam;
                      })),
              ],
            ),
            etiket(Lx('Sıradaki ödeme (${tarihYazi(siradakiTarih)}) kaçıncı?', 'Which payment is the next one (${tarihYazi(siradakiTarih)})?')),
            _Sayac(
              yazi: Lx('$sira. ödeme', 'Payment $sira'),
              azalt: sira > 1 ? () => setState(() => sira--) : null,
              artir: sira < toplam ? () => setState(() => sira++) : null,
            ),
            const SizedBox(height: 6),
            Text(
              Lx('Kredin devam ediyorsa sıradaki taksitin numarasını seç. Son ödeme: ${ayAdi(bitis)}.',
                  'If your loan is already under way, choose the number of the next instalment. Last payment: ${ayAdi(bitis)}.'),
              style: oaBody(14, color: OA.muted),
            ),
          ],
          etiket(L('Hatırlat')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Secim(L('Aynı gün'), hatirlat == 0, () => setState(() => hatirlat = 0)),
              Secim(L('1 gün önce'), hatirlat == 1, () => setState(() => hatirlat = 1)),
              Secim(L('3 gün önce'), hatirlat == 3, () => setState(() => hatirlat = 3)),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: degisken,
            onChanged: (v) => setState(() => degisken = v),
            contentPadding: EdgeInsets.zero,
            title: Text(L('Tutar her ay değişebilir'), style: oaBody(16, weight: FontWeight.w600)),
            subtitle: Text(L('Fatura gibi; ödeme günü gerçek tutarı sorar.'), style: oaBody(14, color: OA.muted)),
          ),
          const SizedBox(height: 8),
          OACard(
            padding: const EdgeInsets.all(16),
            child: Text(ozet, style: oaBody(15, color: OA.text2)),
          ),
          const SizedBox(height: 16),
          OAButton(d == null ? L('Takvime ekle') : L('Kaydet'), kind: OAButtonKind.primary, big: true, onPressed: kaydet),
        ],
      ),
    );
  }
}

class _Sayac extends StatelessWidget {
  const _Sayac({required this.yazi, this.azalt, this.artir});
  final String yazi;
  final VoidCallback? azalt;
  final VoidCallback? artir;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: OA.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: OA.border2),
        ),
        child: Row(
          children: [
            IconButton(onPressed: azalt, icon: const Icon(Icons.remove), color: OA.text, tooltip: L('Azalt')),
            Expanded(child: Text(yazi, textAlign: TextAlign.center, style: oaDisplay(20))),
            IconButton(onPressed: artir, icon: const Icon(Icons.add), color: OA.text, tooltip: L('Artır')),
          ],
        ),
      );
}
