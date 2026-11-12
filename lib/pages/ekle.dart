import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Yeni gelir/gider kaydı ya da var olanı düzenleme.
Future<void> kayitAc(BuildContext context, {Kayit? kayit, Tur tur = Tur.gider}) =>
    altSayfa<void>(context, (_) => EkleSayfasi(kayit: kayit, tur: tur));

class EkleSayfasi extends StatefulWidget {
  const EkleSayfasi({super.key, this.kayit, this.tur = Tur.gider});
  final Kayit? kayit;
  final Tur tur;

  @override
  State<EkleSayfasi> createState() => _EkleSayfasiState();
}

class _EkleSayfasiState extends State<EkleSayfasi> {
  late Tur tur = widget.kayit?.tur ?? widget.tur;
  late String girdi = _girdiYap(widget.kayit?.tutar);
  late String kat = widget.kayit?.kategori ?? kategoriler(tur).first.id;
  late DateTime tarih = widget.kayit?.tarih ?? gunBasi(DateTime.now());
  late final not = TextEditingController(text: widget.kayit?.aciklama ?? '');
  final odak = FocusNode();

  static String _girdiYap(int? k) {
    if (k == null || k == 0) return '';
    final l = k ~/ 100, c = k % 100;
    return c == 0 ? '$l' : '$l,${c.toString().padLeft(2, '0')}';
  }

  int get tutar => paraOku(girdi) ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => odak.requestFocus());
  }

  @override
  void dispose() {
    not.dispose();
    odak.dispose();
    super.dispose();
  }

  void tus(String t) {
    setState(() {
      if (t == '⌫') {
        if (girdi.isNotEmpty) girdi = girdi.substring(0, girdi.length - 1);
        return;
      }
      if (t == ',') {
        if (!girdi.contains(',')) girdi = girdi.isEmpty ? '0,' : '$girdi,';
        return;
      }
      final v = girdi.indexOf(',');
      if (v >= 0 && girdi.length - v > 2) return; // en çok iki kuruş basamağı
      if (v < 0 && girdi.replaceAll(',', '').length >= 9) return;
      if (girdi == '0') girdi = '';
      girdi += t;
    });
  }

  String get gosterim {
    if (girdi.isEmpty) return '₺0';
    final p = girdi.split(',');
    final tam = para((int.tryParse(p[0]) ?? 0) * 100, kurussuz: true);
    return p.length > 1 ? '$tam,${p[1]}' : tam;
  }

  KeyEventResult klavye(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final c = e.character;
    if (c != null && RegExp(r'^[0-9]$').hasMatch(c)) {
      tus(c);
      return KeyEventResult.handled;
    }
    if (c == ',' || c == '.') {
      tus(',');
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      tus('⌫');
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      kaydet();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> tarihSec() async {
    final t = await showDatePicker(
      context: context,
      initialDate: tarih,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (t != null) setState(() => tarih = gunBasi(t));
  }

  void kaydet() {
    if (tutar <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce tutarı yaz.')));
      return;
    }
    final k = widget.kayit;
    Store.i.kayitKaydet(Kayit(
      id: k?.id ?? yeniId(),
      tur: tur,
      tutar: tutar,
      kategori: kat,
      tarih: tarih,
      aciklama: not.text.trim(),
      duzenliId: k?.duzenliId,
    ));
    Navigator.pop(context);
  }

  Future<void> sil() async {
    final k = widget.kayit!;
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: OA.surface,
        title: Text('Kayıt silinsin mi?', style: oaDisplay(20)),
        content: Text(
          k.duzenliId != null
              ? 'Bu, bir düzenli ödemenin "ödendi" kaydı. Silersen o ayın ödemesi yeniden açık görünür.'
              : '${para(k.tutar)} tutarındaki kayıt silinecek.',
          style: oaBody(15, color: OA.text2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Sil', style: oaBody(15, color: OA.danger, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (evet == true && mounted) {
      Store.i.kayitSil(k.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    return Focus(
      focusNode: odak,
      onKeyEvent: klavye,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.kayit == null ? 'Yeni kayıt' : 'Kaydı düzenle', style: oaDisplay(22))),
                if (widget.kayit != null)
                  IconButton(tooltip: 'Sil', onPressed: sil, icon: const Icon(Icons.delete_outline, color: OA.danger)),
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: OA.text2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<Tur>(
              segments: const [
                ButtonSegment(value: Tur.gider, label: Text('Gider')),
                ButtonSegment(value: Tur.gelir, label: Text('Gelir')),
              ],
              selected: {tur},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                tur = s.first;
                if (kategori(kat).tur != tur) kat = kategoriler(tur).first.id;
              }),
              style: SegmentedButton.styleFrom(
                backgroundColor: OA.surface,
                foregroundColor: OA.text2,
                selectedBackgroundColor: OA.amber,
                selectedForegroundColor: OA.amberInk,
                side: const BorderSide(color: OA.border2),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  gosterim,
                  style: oaDisplay(52, color: girdi.isEmpty ? OA.faint : (tur == Tur.gelir ? OA.green : OA.text)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event_outlined, size: 18, color: OA.text2),
                  label: Text('${gunYazi(tarih, bugun)}${ayniGun(tarih, bugun) ? ', ${tarihYazi(tarih)}' : ''}'),
                  onPressed: tarihSec,
                  backgroundColor: OA.surface,
                  side: const BorderSide(color: OA.border2),
                  labelStyle: oaBody(14, color: OA.text2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: not,
                    style: oaBody(15),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Açıklama (ör. Migros)',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    ),
                    onSubmitted: (_) => kaydet(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Kategori', style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kategoriler(tur)) Secim(c.ad, c.id == kat, () => setState(() => kat = c.id), ikon: c.ikon),
              ],
            ),
            const SizedBox(height: 18),
            _TusTakimi(tus),
            const SizedBox(height: 16),
            OAButton('Kaydet', kind: OAButtonKind.primary, big: true, onPressed: tutar > 0 ? kaydet : null),
          ],
        ),
      ),
    );
  }
}

class _TusTakimi extends StatelessWidget {
  const _TusTakimi(this.bas);
  final ValueChanged<String> bas;

  @override
  Widget build(BuildContext context) {
    const tuslar = ['1', '2', '3', '4', '5', '6', '7', '8', '9', ',', '0', '⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: [
        for (final t in tuslar)
          Material(
            color: OA.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => bas(t),
              child: Center(
                child: t == '⌫'
                    ? const Icon(Icons.backspace_outlined, color: OA.text2, size: 22)
                    : Text(t, style: oaDisplay(24)),
              ),
            ),
          ),
      ],
    );
  }
}
