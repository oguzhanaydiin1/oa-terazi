import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../belge.dart';
import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'yedek.dart';

/// Bir dosyanın 25 MB'tan büyük olmasına izin verilmez (yedek dosyası da şişmesin).
const enBuyukDosya = 25 * 1024 * 1024;

typedef SecilenDosya = ({String ad, Uint8List veri});

/// Kamerayla belge fotoğrafı (yalnızca telefonda).
Future<SecilenDosya?> kameraylaTara() async {
  final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2200);
  if (x == null) return null;
  final simdi = DateTime.now();
  return (ad: 'tarama-${gunAnahtar(simdi)}-${simdi.millisecondsSinceEpoch % 100000}.jpg', veri: await x.readAsBytes());
}

/// PDF ya da fotoğraf seç (birden çok olabilir).
Future<List<SecilenDosya>> dosyaSec(BuildContext context) async {
  final r = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    allowMultiple: true,
    withData: true,
  );
  if (r == null) return const [];
  final out = <SecilenDosya>[];
  var buyuk = false;
  for (final f in r.files) {
    final b = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (b == null) continue;
    if (b.length > enBuyukDosya) {
      buyuk = true;
      continue;
    }
    out.add((ad: f.name, veri: b));
  }
  if (buyuk && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Lx('25 MB’tan büyük dosyalar eklenmedi.', 'Files larger than 25 MB were not added.'))));
  }
  return out;
}

/// Kamera ya da dosya düğmeleri (Windows'ta yalnızca dosya).
class DosyaKaynaklari extends StatelessWidget {
  const DosyaKaynaklari({super.key, required this.eklendi});
  final ValueChanged<List<SecilenDosya>> eklendi;

  @override
  Widget build(BuildContext context) {
    final kamera = Platform.isAndroid;
    Widget dugme(IconData i, String yazi, Future<void> Function() f, {bool ana = false}) => Expanded(
          child: Material(
            color: OA.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: OA.border2)),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onTap: f,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(i, color: ana ? OA.amber : OA.text2, size: 20),
                  const SizedBox(width: 8),
                  Flexible(child: Text(yazi, style: oaBody(15, weight: FontWeight.w600))),
                ]),
              ),
            ),
          ),
        );
    return Row(children: [
      if (kamera) ...[
        dugme(Icons.document_scanner_outlined, Lx('Kamerayla tara', 'Scan with camera'), () async {
          final d = await kameraylaTara();
          if (d != null) eklendi([d]);
        }, ana: true),
        const SizedBox(width: 10),
      ],
      dugme(Icons.upload_file_outlined, Lx('PDF ya da fotoğraf seç', 'Choose PDF or photo'), () async {
        final l = await dosyaSec(context);
        if (l.isNotEmpty) eklendi(l);
      }, ana: !kamera),
    ]);
  }
}

/// Dosyaları şifreleyip belgeye ekler.
Future<List<BelgeDosyasi>> dosyalariKaydet(List<SecilenDosya> l) async => [
      for (final d in l) BelgeDosyasi(id: await Kasa.yaz(d.veri), ad: d.ad, boyut: d.veri.length),
    ];

/// Belge listesi.
class BelgelerSayfasi extends StatefulWidget {
  const BelgelerSayfasi({super.key, required this.genis});
  final bool genis;

  @override
  State<BelgelerSayfasi> createState() => _BelgelerSayfasiState();
}

class _BelgelerSayfasiState extends State<BelgelerSayfasi> {
  String filtre = 'tum';
  String ara = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final bugun = DateTime.now();
          final q = ara.trim().toLowerCase();
          final liste = s.belgeler.where((b) {
            if (filtre != 'tum' && b.tur != filtre) return false;
            return q.isEmpty || b.ad.toLowerCase().contains(q);
          }).toList()
            ..sort((a, b) => b.eklenme.compareTo(a.eklenme));
          final yaklasan = s.yaklasanBelgeler(bugun);
          final toplam = s.belgeler.fold<int>(0, (a, b) => a + b.boyut);
          final g = widget.genis;

          return ListView(
            padding: EdgeInsets.fromLTRB(g ? 32 : 20, g ? 28 : 16, g ? 32 : 20, 110),
            children: [
              Row(
                children: [
                  Expanded(child: Text(Lx('Belgeler', 'Documents'), style: oaDisplay(g ? 30 : 24))),
                  TextButton.icon(
                    onPressed: () => yedekAc(context),
                    icon: Icon(Icons.lock_outline, size: 16, color: OA.green),
                    label: Text(Lx('Bu cihazda, şifreli · Yedek', 'On this device, encrypted · Backup'),
                        style: oaBody(13, color: OA.green, weight: FontWeight.w600)),
                  ),
                  if (g) ...[
                    const SizedBox(width: 8),
                    OAButton(Lx('Belge ekle', 'Add document'), kind: OAButtonKind.primary, onPressed: () => belgeEkle(context)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => ara = v),
                style: oaBody(16),
                decoration: InputDecoration(
                  hintText: Lx('Ara: belge adı', 'Search: document name'),
                  prefixIcon: Icon(Icons.search, color: OA.faint),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Secim(L('Tümü'), filtre == 'tum', () => setState(() => filtre = 'tum')),
                for (final t in belgeTurleri) Secim(t.ad, filtre == t.id, () => setState(() => filtre = t.id)),
              ]),
              for (final b in yaklasan.take(2)) ...[const SizedBox(height: 12), BitisKarti(b)],
              const SizedBox(height: 16),
              if (s.belgeler.isEmpty)
                Bos(
                  Icons.folder_open_outlined,
                  Lx('Henüz belge yok', 'No documents yet'),
                  Lx('Faturalarını, poliçelerini, garanti belgelerini ve sözleşmelerini burada sakla. Bitiş tarihi olanları zamanı gelmeden hatırlatırım. Belgeler yalnızca bu cihazda, şifreli durur.',
                      'Keep your bills, policies, warranties and contracts here. I’ll remind you before the ones with an end date expire. Documents stay on this device only, encrypted.'),
                  eylem: Lx('Belge ekle', 'Add document'),
                  onEylem: () => belgeEkle(context),
                )
              else if (liste.isEmpty)
                Bos(Icons.search_off, Lx('Belge bulunamadı', 'No documents found'),
                    Lx('Aramana ya da seçtiğin türe uyan belge yok.', 'Nothing matches your search or the type you chose.'))
              else ...[
                Text(Lx('${liste.length} belge · ${boyutYazi(toplam)}', '${liste.length} documents · ${boyutYazi(toplam)}'),
                    style: oaBody(13, color: OA.muted)),
                const SizedBox(height: 4),
                if (g)
                  GridView.extent(
                    maxCrossAxisExtent: 240,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.25,
                    padding: const EdgeInsets.only(top: 8),
                    children: [for (final b in liste) _BelgeKarti(b, bugun)],
                  )
                else
                  for (final b in liste) BelgeSatiri(b, bugun: bugun),
              ],
            ],
          );
        },
      );
}

/// Belge türü simgesi (sayfa biçiminde).
class BelgeSimgesi extends StatelessWidget {
  const BelgeSimgesi(this.b, {super.key, this.boyut = 44});
  final Belge b;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    final t = belgeTuru(b.tur);
    return Container(
      width: boyut,
      height: boyut * 1.18,
      decoration: BoxDecoration(
        color: t.renk.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(boyut * 0.22),
        border: Border.all(color: t.renk.withValues(alpha: 0.35)),
      ),
      child: Icon(t.ikon, color: t.renk, size: boyut * 0.5),
    );
  }
}

String belgeAltYazi(Belge b, DateTime bugun) {
  final t = belgeTuru(b.tur).ad;
  final k = b.kalanGun(bugun);
  if (k == null) return '$t · ${tarihYazi(b.eklenme)}';
  if (k < 0) return Lx('$t · süresi ${-k} gün önce doldu', '$t · expired ${-k} days ago');
  if (k == 0) return Lx('$t · bugün bitiyor', '$t · ends today');
  if (k <= b.hatirlat) return Lx('$t · $k gün sonra bitiyor', '$t · ends in $k days');
  return Lx('$t · bitiş ${tarihYazi(b.bitis!)} ${b.bitis!.year}', '$t · ends ${tarihYazi(b.bitis!)} ${b.bitis!.year}');
}

class BelgeSatiri extends StatelessWidget {
  const BelgeSatiri(this.b, {super.key, required this.bugun});
  final Belge b;
  final DateTime bugun;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => belgeAyrinti(context, b),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Row(children: [
            BelgeSimgesi(b),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: oaBody(16, weight: FontWeight.w600)),
                Text(belgeAltYazi(b, bugun),
                    style: oaBody(13, color: b.yaklasti(bugun) ? OA.amber : OA.muted)),
              ]),
            ),
            if (b.dosyalar.length > 1)
              Text('${b.dosyalar.length}', style: oaBody(13, color: OA.faint, weight: FontWeight.w600)),
          ]),
        ),
      );
}

class _BelgeKarti extends StatelessWidget {
  const _BelgeKarti(this.b, this.bugun);
  final Belge b;
  final DateTime bugun;

  @override
  Widget build(BuildContext context) {
    final yakin = b.yaklasti(bugun);
    return Material(
      color: OA.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18), side: BorderSide(color: yakin ? OA.amber : OA.border)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: () => belgeAyrinti(context, b),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BelgeSimgesi(b, boyut: 40),
            const Spacer(),
            Text(b.ad, maxLines: 2, overflow: TextOverflow.ellipsis, style: oaBody(15, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(belgeAltYazi(b, bugun),
                maxLines: 2, style: oaBody(13, color: yakin ? OA.amber : OA.muted)),
          ]),
        ),
      ),
    );
  }
}

/// "Kasko poliçesi 15 gün sonra bitiyor" kartı (Belgeler ve Özet).
class BitisKarti extends StatelessWidget {
  const BitisKarti(this.b, {super.key});
  final Belge b;

  @override
  Widget build(BuildContext context) {
    final k = b.kalanGun(DateTime.now()) ?? 0;
    final gecti = k < 0;
    final renk = gecti ? OA.danger : OA.amber;
    final baslik = gecti
        ? Lx('${b.ad}: süresi doldu', '${b.ad} has expired')
        : k == 0
            ? Lx('${b.ad} bugün bitiyor', '${b.ad} ends today')
            : Lx('${b.ad} $k gün sonra bitiyor', '${b.ad} ends in $k days');
    return Material(
      color: renk.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: renk, width: 1.5)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: () => belgeAyrinti(context, b),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.timer_outlined, color: renk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(baslik, style: oaBody(15, weight: FontWeight.w600)),
                Text(Lx('Bitiş ${tarihYazi(b.bitis!)} ${b.bitis!.year}', 'Ends ${tarihYazi(b.bitis!)} ${b.bitis!.year}'),
                    style: oaBody(13, color: OA.text2)),
              ]),
            ),
            Icon(Icons.chevron_right, color: renk),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Belge ekle / düzenle

Future<void> belgeEkle(BuildContext context, {Belge? belge}) =>
    altSayfa<void>(context, (_) => BelgeEkleSayfasi(belge: belge));

class BelgeEkleSayfasi extends StatefulWidget {
  const BelgeEkleSayfasi({super.key, this.belge});
  final Belge? belge;

  @override
  State<BelgeEkleSayfasi> createState() => _BelgeEkleSayfasiState();
}

class _BelgeEkleSayfasiState extends State<BelgeEkleSayfasi> {
  late final Belge? b = widget.belge;
  late final ad = TextEditingController(text: b?.ad ?? '');
  late String tur = b?.tur ?? 'fatura';
  late DateTime? bitis = b?.bitis;
  late bool bitisVar = b?.bitis != null;
  late int hatirlat = b?.hatirlat ?? 15;
  late String? duzenliId = b?.duzenliId;
  final yeni = <SecilenDosya>[];
  bool kaydediliyor = false;

  @override
  void dispose() {
    ad.dispose();
    super.dispose();
  }

  void eklendi(List<SecilenDosya> l) => setState(() {
        yeni.addAll(l);
        if (ad.text.trim().isEmpty && l.isNotEmpty && !l.first.ad.startsWith('tarama-')) {
          final n = l.first.ad;
          final i = n.lastIndexOf('.');
          ad.text = i > 0 ? n.substring(0, i) : n;
        }
      });

  Future<void> kaydet() async {
    final isim = ad.text.trim();
    if (isim.isEmpty || ((b?.dosyalar.isEmpty ?? true) && yeni.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(Lx('Belgenin adını yaz ve bir dosya ekle.', 'Enter a name and add a file.'))));
      return;
    }
    if (bitisVar && bitis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Lx('Bitiş tarihini seç.', 'Choose the end date.'))));
      return;
    }
    setState(() => kaydediliyor = true);
    final eklenen = await dosyalariKaydet(yeni);
    final x = b;
    Store.i.belgeKaydet(Belge(
      id: x?.id ?? yeniId(),
      ad: isim,
      tur: tur,
      eklenme: x?.eklenme ?? DateTime.now(),
      dosyalar: [...?x?.dosyalar, ...eklenen],
      bitis: bitisVar ? bitis : null,
      hatirlat: hatirlat,
      duzenliId: duzenliId,
      kayitId: x?.kayitId,
    ));
    if (mounted) Navigator.pop(context);
  }

  Widget etiket(String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(s, style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    final duzenliler = Store.i.duzenliler;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
                child: Text(b == null ? Lx('Belge ekle', 'Add document') : Lx('Belgeyi düzenle', 'Edit document'),
                    style: oaDisplay(22))),
            IconButton(
                tooltip: L('Kapat'),
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: OA.text2)),
          ]),
          const SizedBox(height: 8),
          DosyaKaynaklari(eklendi: eklendi),
          if (yeni.isNotEmpty || (b?.dosyalar.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in b?.dosyalar ?? const <BelgeDosyasi>[])
                Chip(
                  avatar: Icon(d.pdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, size: 18, color: OA.text2),
                  label: Text(d.ad, overflow: TextOverflow.ellipsis),
                  backgroundColor: OA.surface,
                  side: BorderSide(color: OA.border2),
                  labelStyle: oaBody(13, color: OA.text2),
                ),
              for (final d in yeni)
                Chip(
                  avatar: Icon(d.ad.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                      size: 18, color: OA.amber),
                  label: Text('${d.ad} · ${boyutYazi(d.veri.length)}', overflow: TextOverflow.ellipsis),
                  backgroundColor: OA.surface,
                  side: BorderSide(color: OA.amber),
                  labelStyle: oaBody(13, color: OA.text),
                  onDeleted: () => setState(() => yeni.remove(d)),
                ),
            ]),
          ],
          etiket(Lx('Belgenin adı', 'Document name')),
          TextField(
            controller: ad,
            style: oaBody(17),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: Lx('Kasko poliçesi, kira sözleşmesi…', 'Car insurance, lease…')),
          ),
          etiket(Lx('Türü', 'Type')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in belgeTurleri) Secim(t.ad, tur == t.id, () => setState(() => tur = t.id), ikon: t.ikon),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OA.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: OA.danger.withValues(alpha: 0.35)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, color: OA.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  Lx('Kimlik, pasaport ve banka kartı ekleme. Terazi bu belgeler için değil; kaybolurlarsa kötüye kullanılabilirler.',
                      'Don’t add ID cards, passports or bank cards. Terazi isn’t meant for them; they could be misused if lost.'),
                  style: oaBody(13, color: OA.text2),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: bitisVar,
            onChanged: (v) => setState(() => bitisVar = v),
            contentPadding: EdgeInsets.zero,
            title: Text(Lx('Bitiş tarihi var', 'Has an end date'), style: oaBody(16, weight: FontWeight.w600)),
            subtitle: Text(Lx('Poliçe, garanti, sözleşme; bitmeden haber veririm.', 'Policy, warranty, contract; I’ll remind you before it ends.'),
                style: oaBody(13, color: OA.muted)),
          ),
          if (bitisVar) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final simdi = DateTime.now();
                final t = await showDatePicker(
                  context: context,
                  initialDate: bitis ?? DateTime(simdi.year + 1, simdi.month, simdi.day),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (t != null) setState(() => bitis = gunBasi(t));
              },
              icon: Icon(Icons.event_outlined, color: OA.text2),
              label: Text(
                bitis == null
                    ? Lx('Bitiş tarihini seç', 'Choose end date')
                    : '${tarihYazi(bitis!)} ${bitis!.year}',
                style: oaBody(15, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in const [30, 15, 7])
                Secim(Lx('$g gün önce', '$g days before'), hatirlat == g, () => setState(() => hatirlat = g)),
            ]),
          ],
          if (duzenliler.isNotEmpty) ...[
            etiket(Lx('Bağlı ödeme (isteğe bağlı)', 'Linked payment (optional)')),
            DropdownButtonFormField<String?>(
              value: duzenliler.any((d) => d.id == duzenliId) ? duzenliId : null,
              isExpanded: true,
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(Lx('Yok', 'None'))),
                for (final d in duzenliler) DropdownMenuItem<String?>(value: d.id, child: Text(d.ad)),
              ],
              onChanged: (v) => setState(() => duzenliId = v),
            ),
          ],
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, size: 14, color: OA.green),
            const SizedBox(width: 6),
            Flexible(
              child: Text(Lx('Bu cihazda şifreli saklanır, hiçbir yere gönderilmez.', 'Stored encrypted on this device, never sent anywhere.'),
                  style: oaBody(13, color: OA.muted)),
            ),
          ]),
          const SizedBox(height: 10),
          OAButton(kaydediliyor ? Lx('Kaydediliyor…', 'Saving…') : L('Kaydet'),
              kind: OAButtonKind.primary, big: true, onPressed: kaydediliyor ? null : kaydet),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Belge ayrıntısı

Future<void> belgeAyrinti(BuildContext context, Belge b) =>
    altSayfa<void>(context, (_) => BelgeAyrintiSayfasi(id: b.id));

/// Belgenin şifresiz kopyasını sistemin uygulamasıyla açar.
Future<void> belgeDosyasiniAc(BuildContext context, BelgeDosyasi d) async {
  try {
    final f = await Kasa.geciciKopya(d);
    if (Platform.isWindows) {
      await launchUrl(Uri.file(f.path));
    } else {
      final r = await OpenFilex.open(f.path);
      if (r.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(Lx('Bu dosyayı açacak bir uygulama bulunamadı.', 'No app found to open this file.'))));
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Lx('Açılamadı: $e', 'Couldn’t open: $e'))));
    }
  }
}

class BelgeAyrintiSayfasi extends StatelessWidget {
  const BelgeAyrintiSayfasi({super.key, required this.id});
  final String id;

  Future<void> _paylas(BuildContext context, Belge b) async {
    try {
      final dosyalar = [for (final d in b.dosyalar) XFile((await Kasa.geciciKopya(d)).path)];
      await Share.shareXFiles(dosyalar, subject: b.ad);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Lx('Paylaşılamadı: $e', 'Couldn’t share: $e'))));
      }
    }
  }

  Future<void> _farkliKaydet(BuildContext context, BelgeDosyasi d) async {
    try {
      final veri = await Kasa.oku(d.id);
      final yol = await FilePicker.platform.saveFile(fileName: d.ad, bytes: veri);
      if (yol == null) return;
      if (Platform.isWindows) await File(yol).writeAsBytes(veri, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Lx('Kaydedildi.', 'Saved.'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Lx('Kaydedilemedi: $e', 'Couldn’t save: $e'))));
      }
    }
  }

  Future<void> _sil(BuildContext context, Belge b) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: OA.surface,
        title: Text(Lx('Belge silinsin mi?', 'Delete this document?'), style: oaDisplay(20)),
        content: Text(
            Lx('“${b.ad}” bu cihazdan silinir. Yedeğin yoksa geri getirilemez.',
                '“${b.ad}” will be deleted from this device. Without a backup it can’t be recovered.'),
            style: oaBody(15, color: OA.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Vazgeç'))),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(L('Sil'), style: oaBody(15, color: OA.danger, weight: FontWeight.w600))),
        ],
      ),
    );
    if (evet == true && context.mounted) {
      Navigator.pop(context);
      await Store.i.belgeSil(b.id);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final b = Store.i.belge(id);
          if (b == null) return const SizedBox(height: 120);
          final bugun = DateTime.now();
          final t = belgeTuru(b.tur);
          final bagli = b.duzenliId == null ? null : Store.i.duzenli(b.duzenliId!);
          Widget satir(String e, String d, {Color? renk}) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  Expanded(child: Text(e, style: oaBody(14, color: OA.muted))),
                  Flexible(
                      child: Text(d,
                          textAlign: TextAlign.right, style: oaBody(14, weight: FontWeight.w600, color: renk))),
                ]),
              );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(b.ad, style: oaDisplay(22))),
                IconButton(
                    tooltip: L('Düzenle'),
                    onPressed: () {
                      Navigator.pop(context);
                      belgeEkle(context, belge: b);
                    },
                    icon: Icon(Icons.edit_outlined, color: OA.text2)),
                IconButton(
                    tooltip: L('Kapat'),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: OA.text2)),
              ]),
              const SizedBox(height: 8),
              _Onizleme(b),
              if (b.yaklasti(bugun)) ...[const SizedBox(height: 12), BitisKarti(b)],
              const SizedBox(height: 12),
              OACard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(children: [
                  satir(Lx('Tür', 'Type'), t.ad),
                  if (b.bitis != null) satir(Lx('Bitiş', 'Ends'), '${tarihYazi(b.bitis!)} ${b.bitis!.year}'),
                  if (bagli != null) satir(Lx('Bağlı ödeme', 'Linked payment'), '${bagli.ad} · ${para(bagli.tutar, kurussuz: true)}', renk: OA.amber),
                  satir(Lx('Eklenme', 'Added'), '${tarihYazi(b.eklenme)} ${b.eklenme.year}'),
                  satir(Lx('Dosya', 'File'),
                      Lx('${b.dosyalar.length} dosya · ${boyutYazi(b.boyut)}', '${b.dosyalar.length} file(s) · ${boyutYazi(b.boyut)}')),
                  satir(Lx('Saklandığı yer', 'Stored'), Lx('Bu cihaz · şifreli', 'This device · encrypted'), renk: OA.green),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: OAButton(Lx('Aç', 'Open'),
                        kind: OAButtonKind.primary, onPressed: b.dosyalar.isEmpty ? null : () => belgeDosyasiniAc(context, b.dosyalar.first))),
                const SizedBox(width: 10),
                Expanded(
                  child: Platform.isAndroid
                      ? OAButton(Lx('Paylaş', 'Share'), onPressed: () => _paylas(context, b))
                      : OAButton(Lx('Farklı kaydet', 'Save as'),
                          onPressed: b.dosyalar.isEmpty ? null : () => _farkliKaydet(context, b.dosyalar.first)),
                ),
              ]),
              if (b.dosyalar.length > 1) ...[
                const SizedBox(height: 12),
                for (final d in b.dosyalar)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(d.pdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: OA.text2),
                    title: Text(d.ad, style: oaBody(14), overflow: TextOverflow.ellipsis),
                    subtitle: Text(boyutYazi(d.boyut), style: oaBody(12, color: OA.muted)),
                    trailing: Icon(Icons.open_in_new, size: 18, color: OA.faint),
                    onTap: () => belgeDosyasiniAc(context, d),
                  ),
              ],
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _sil(context, b),
                icon: Icon(Icons.delete_outline, color: OA.danger),
                label: Text(Lx('Belgeyi sil', 'Delete document'), style: oaBody(15, color: OA.danger, weight: FontWeight.w600)),
              ),
            ]),
          );
        },
      );
}

/// İlk dosya resimse önizler; PDF'te simge gösterir.
class _Onizleme extends StatelessWidget {
  const _Onizleme(this.b);
  final Belge b;

  @override
  Widget build(BuildContext context) {
    final ilk = b.dosyalar.isEmpty ? null : b.dosyalar.first;
    Widget kutu(Widget c) => Container(
          height: 220,
          decoration: BoxDecoration(
            color: OA.surface2,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: OA.border),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: c,
        );
    if (ilk == null || !ilk.resim) {
      return InkWell(
        onTap: ilk == null ? null : () => belgeDosyasiniAc(context, ilk),
        borderRadius: BorderRadius.circular(18),
        child: kutu(Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(ilk?.pdf == true ? Icons.picture_as_pdf_outlined : Icons.description_outlined, size: 54, color: OA.text2),
          const SizedBox(height: 8),
          Text(ilk?.ad ?? '', style: oaBody(14, color: OA.muted)),
          const SizedBox(height: 4),
          Text(Lx('Açmak için dokun', 'Tap to open'), style: oaBody(13, color: OA.amber, weight: FontWeight.w600)),
        ])),
      );
    }
    return InkWell(
      onTap: () => belgeDosyasiniAc(context, ilk),
      borderRadius: BorderRadius.circular(18),
      child: kutu(FutureBuilder<Uint8List>(
        future: Kasa.oku(ilk.id),
        builder: (context, s) {
          if (s.hasData) return Image.memory(s.data!, fit: BoxFit.contain, width: double.infinity);
          if (s.hasError) return Icon(Icons.broken_image_outlined, color: OA.faint, size: 40);
          return const CircularProgressIndicator();
        },
      )),
    );
  }
}
