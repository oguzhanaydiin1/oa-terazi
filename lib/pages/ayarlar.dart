import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../i18n.dart';
import '../bildirim.dart';
import '../kategoriler.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ozet.dart';
import 'sayfalar.dart';
import 'yedek.dart';

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
          Widget satir(IconData i, String baslik, String? alt, {VoidCallback? onTap, Widget? sag, Color? renk}) =>
              ListTile(
                onTap: onTap,
                leading: Icon(i, color: renk ?? OA.text2),
                title: Text(baslik, style: oaBody(16, weight: FontWeight.w600, color: renk)),
                subtitle: alt == null ? null : Text(alt, style: oaBody(14, color: OA.muted)),
                trailing: sag ?? (onTap != null ? Icon(Icons.chevron_right, color: OA.faint) : null),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              );
          return Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: EdgeInsets.fromLTRB(genis ? 32 : 20, genis ? 28 : 16, genis ? 32 : 20, 110),
                children: [
                  Text(L('Ayarlar'), style: oaDisplay(genis ? 30 : 24)),
                  const SizedBox(height: 14),
                  OACard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        if (!genis)
                          satir(Icons.pie_chart_outline, L('Bütçeler'),
                              s.butceler.isEmpty ? L('Kategorilere aylık sınır koy') : Lx('${s.butceler.length} kategori için sınır var', 'Limits set for ${s.butceler.length} categories'),
                              onTap: () => git(Sayfa.butceler)),
                        satir(Icons.backup_outlined, Lx('Yedek ve aktarım', 'Backup and transfer'),
                            s.sonYedek == null
                                ? Lx('Henüz yedek alınmadı', 'No backup yet')
                                : Lx('Son yedek ${tarihYazi(s.sonYedek!)}', 'Last backup ${tarihYazi(s.sonYedek!)}'),
                            onTap: () => yedekAc(context)),
                        if (Bildirim.destekli)
                          satir(
                            Icons.notifications_outlined,
                            L('Ödeme hatırlatmaları'),
                            L('Ödeme günü sabah 9\'da ve seçtiğin gün önce bildirim'),
                            sag: Switch(value: s.bildirim, onChanged: (v) async {
                              s.bildirimAyarla(v);
                              if (v) await Bildirim.izinIste();
                            }),
                          ),
                        if (disaAktar != null)
                          satir(Icons.file_download_outlined, L('Dışa aktar (CSV)'), L('Tüm hareketler; Excel ile açılır'),
                              onTap: disaAktar),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Gorunum(s),
                  const SizedBox(height: 14),
                  OACard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        satir(Icons.mail_outline, L('Bize ulaş'), 'destek@oalabs.dev',
                            onTap: () => launchUrl(Uri.parse(
                                'mailto:destek@oalabs.dev?subject=${Uri.encodeComponent('Terazi $appVersion')}'))),
                        satir(Icons.public, 'oalabs.dev', L('Diğer OA Labs uygulamaları'),
                            onTap: () => launchUrl(Uri.parse('https://oalabs.dev'), mode: LaunchMode.externalApplication)),
                        satir(Icons.delete_forever_outlined, L('Tüm verileri sil'), L('Kayıtlar, düzenli ödemeler ve bütçeler'),
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
                          Text(L('Terazi: Gelir Gider Takibi'), style: oaBody(15, weight: FontWeight.w700)),
                          Text(Lx('Sürüm $appVersion · OA Labs', 'Version $appVersion · OA Labs'), style: oaBody(14, color: OA.muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(L('Verilerin yalnızca bu cihazda saklanır.'), style: oaBody(14, color: OA.faint)),
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
        title: Text(L('Tüm veriler silinsin mi?'), style: oaDisplay(20)),
        content: Text(L('Bütün kayıtların, düzenli ödemelerin ve bütçelerin bu cihazdan silinir. Geri alınamaz.'),
            style: oaBody(15, color: OA.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Vazgeç'))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(L('Hepsini sil'), style: oaBody(15, color: OA.danger, weight: FontWeight.w600)),
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
                  if (genis) Text(L('Bütçeler'), style: oaDisplay(30)),
                  if (genis) const SizedBox(height: 6),
                  Text(L('Bir kategoriye aylık sınır koy; harcadıkça dolar, aşınca kırmızıya döner.'),
                      style: oaBody(15, color: OA.muted)),
                  const SizedBox(height: 14),
                  for (final b in s.butceler.entries)
                    InkWell(
                      onTap: () => _ayarla(context, b.key),
                      borderRadius: BorderRadius.circular(14),
                      child: ButceSatiri(b.key, harcanan[b.key] ?? 0, b.value),
                    ),
                  const SizedBox(height: 16),
                  Text(L('Sınır ekle'), style: oaBody(14, color: OA.muted, weight: FontWeight.w600)),
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
        title: Text(Lx('${k.ad} için aylık sınır', 'Monthly limit for ${k.ad}'), style: oaDisplay(20)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: oaDisplay(22),
          decoration: paraKutusu(),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
        actions: [
          if (mevcut != null)
            TextButton(
              onPressed: () => Navigator.pop(d, ''),
              child: Text(L('Sınırı kaldır'), style: oaBody(15, color: OA.danger, weight: FontWeight.w600)),
            ),
          TextButton(onPressed: () => Navigator.pop(d), child: Text(L('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(d, c.text), child: Text(L('Kaydet'))),
        ],
      ),
    );
    if (sonuc == null) return;
    Store.i.butceAyarla(kat, sonuc.isEmpty ? null : paraOku(sonuc));
  }
}

/// Dil, tema ve para birimi.
class _Gorunum extends StatelessWidget {
  const _Gorunum(this.s);
  final Store s;

  Widget _baslik(IconData i, String yazi) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(i, color: OA.text2, size: 22),
          const SizedBox(width: 12),
          Text(yazi, style: oaBody(16, weight: FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final birim = paraBirimi(s.paraBirimi);
    return OACard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _baslik(Icons.translate, L('Dil')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Secim(L('Sistem'), s.dil == 'sistem', () => s.gorunumAyarla(dil: 'sistem')),
            Secim('Türkçe', s.dil == 'tr', () => s.gorunumAyarla(dil: 'tr')),
            Secim('English', s.dil == 'en', () => s.gorunumAyarla(dil: 'en')),
          ]),
          const SizedBox(height: 20),
          _baslik(Icons.brightness_6_outlined, L('Tema')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Secim(L('Sistem'), s.tema == 'sistem', () => s.gorunumAyarla(tema: 'sistem'), ikon: Icons.settings_suggest_outlined),
            Secim(L('Koyu'), s.tema == 'koyu', () => s.gorunumAyarla(tema: 'koyu'), ikon: Icons.dark_mode_outlined),
            Secim(L('Açık'), s.tema == 'acik', () => s.gorunumAyarla(tema: 'acik'), ikon: Icons.light_mode_outlined),
          ]),
          const SizedBox(height: 20),
          _baslik(Icons.payments_outlined, L('Para birimi')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in paraBirimleri)
              Secim('${p.sembol}  ${p.kod}', p.kod == birim.kod, () => s.gorunumAyarla(paraBirimi: p.kod)),
          ]),
          const SizedBox(height: 10),
          Text('${Dil.en ? birim.adEn : birim.ad} · ${para(824050)}', style: oaBody(14, color: OA.text2)),
          const SizedBox(height: 2),
          Text(L('Tutarlar çevrilmez; yalnızca simge ve sayı biçimi değişir.'), style: oaBody(13, color: OA.muted)),
        ],
      ),
    );
  }
}
