import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bildirim.dart';
import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ozet.dart';
import 'sayfalar.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key, required this.genis, required this.git, this.disaAktar});
  final bool genis;
  final void Function(Sayfa) git;
  final VoidCallback? disaAktar;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          Widget satir(IconData i, String baslik, String? alt, {VoidCallback? onTap, Widget? sag, Color renk = OA.text}) =>
              ListTile(
                onTap: onTap,
                leading: Icon(i, color: renk == OA.text ? OA.text2 : renk),
                title: Text(baslik, style: oaBody(16, weight: FontWeight.w600, color: renk)),
                subtitle: alt == null ? null : Text(alt, style: oaBody(14, color: OA.muted)),
                trailing: sag ?? (onTap != null ? const Icon(Icons.chevron_right, color: OA.faint) : null),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              );
          return Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.fromLTRB(genis ? 32 : 20, genis ? 28 : 16, genis ? 32 : 20, 110),
                children: [
                  Text('Ayarlar', style: oaDisplay(genis ? 30 : 24)),
                  const SizedBox(height: 14),
                  OACard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        if (!genis)
                          satir(Icons.pie_chart_outline, 'Bütçeler',
                              s.butceler.isEmpty ? 'Kategorilere aylık sınır koy' : '${s.butceler.length} kategori için sınır var',
                              onTap: () => git(Sayfa.butceler)),
                        if (Bildirim.destekli)
                          satir(
                            Icons.notifications_outlined,
                            'Ödeme hatırlatmaları',
                            'Ödeme günü sabah 9\'da ve seçtiğin gün önce bildirim',
                            sag: Switch(value: s.bildirim, onChanged: (v) async {
                              s.bildirimAyarla(v);
                              if (v) await Bildirim.izinIste();
                            }),
                          ),
                        if (disaAktar != null)
                          satir(Icons.file_download_outlined, 'Dışa aktar (CSV)', 'Tüm hareketler; Excel ile açılır',
                              onTap: disaAktar),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  OACard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        satir(Icons.mail_outline, 'Bize ulaş', 'destek@oalabs.dev',
                            onTap: () => launchUrl(Uri.parse(
                                'mailto:destek@oalabs.dev?subject=${Uri.encodeComponent('Terazi $appVersion')}'))),
                        satir(Icons.public, 'oalabs.dev', 'Diğer OA Labs uygulamaları',
                            onTap: () => launchUrl(Uri.parse('https://oalabs.dev'), mode: LaunchMode.externalApplication)),
                        satir(Icons.delete_forever_outlined, 'Tüm verileri sil', 'Kayıtlar, düzenli ödemeler ve bütçeler',
                            renk: OA.danger, onTap: () => _sil(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const TeraziMark(size: 40),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Terazi: Gelir Gider Takibi', style: oaBody(15, weight: FontWeight.w700)),
                          Text('Sürüm $appVersion · OA Labs', style: oaBody(14, color: OA.muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Verilerin yalnızca bu cihazda saklanır.', style: oaBody(14, color: OA.faint)),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _sil(BuildContext context) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: OA.surface,
        title: Text('Tüm veriler silinsin mi?', style: oaDisplay(20)),
        content: Text('Bütün kayıtların, düzenli ödemelerin ve bütçelerin bu cihazdan silinir. Geri alınamaz.',
            style: oaBody(15, color: OA.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Hepsini sil', style: oaBody(15, color: OA.danger, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (evet == true) Store.i.hepsiniSil();
  }
}

/// Kategori bütçeleri: her kategoriye aylık sınır.
class ButcelerSayfasi extends StatelessWidget {
  const ButcelerSayfasi({super.key, required this.genis});
  final bool genis;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final harcanan = kategoriGideri(ayBasi(DateTime.now()), s.kayitlar);
          return Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.fromLTRB(genis ? 32 : 20, genis ? 28 : 16, genis ? 32 : 20, 40),
                children: [
                  if (genis) Text('Bütçeler', style: oaDisplay(30)),
                  if (genis) const SizedBox(height: 6),
                  Text('Bir kategoriye aylık sınır koy; harcadıkça dolar, aşınca kırmızıya döner.',
                      style: oaBody(15, color: OA.muted)),
                  const SizedBox(height: 14),
                  for (final b in s.butceler.entries)
                    InkWell(
                      onTap: () => _ayarla(context, b.key),
                      borderRadius: BorderRadius.circular(14),
                      child: ButceSatiri(b.key, harcanan[b.key] ?? 0, b.value),
                    ),
                  const SizedBox(height: 16),
                  Text('Sınır ekle', style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final k in giderKategorileri)
                        if (!s.butceler.containsKey(k.id)) Secim(k.ad, false, () => _ayarla(context, k.id), ikon: k.ikon),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _ayarla(BuildContext context, String kat) async {
    final k = kategori(kat);
    final mevcut = Store.i.butceler[kat];
    final c = TextEditingController(text: mevcut == null ? '' : '${mevcut ~/ 100}');
    final sonuc = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: OA.surface,
        title: Text('${k.ad} için aylık sınır', style: oaDisplay(20)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: oaDisplay(22),
          decoration: const InputDecoration(prefixText: '₺ ', hintText: '0'),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          if (mevcut != null)
            TextButton(
              onPressed: () => Navigator.pop(d, ''),
              child: Text('Sınırı kaldır', style: oaBody(15, color: OA.danger, weight: FontWeight.w600)),
            ),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Kaydet')),
        ],
      ),
    );
    if (sonuc == null) return;
    Store.i.butceAyarla(kat, sonuc.isEmpty ? null : paraOku(sonuc));
  }
}
