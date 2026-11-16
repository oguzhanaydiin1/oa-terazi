import 'dart:io' show Platform;

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
import 'hesap_sayfasi.dart';
import '../esitle.dart';
import '../hesap.dart';
import '../oa_muhur.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

/// "Windows 10.0", "Android" gibi kısa sistem bilgisi.
String _sistemYazi() {
  final ad = Platform.isAndroid ? 'Android' : Platform.isWindows ? 'Windows' : Platform.operatingSystem;
  final surum = RegExp(r'(\d+(\.\d+)+)').firstMatch(Platform.operatingSystemVersion)?.group(1);
  final mimari = RegExp(r'_(\w+)"').firstMatch(Platform.version)?.group(1);
  return [ad, if (surum != null) surum, if (mimari != null) '($mimari)'].join(' ');
}

/// Dart sürümü, örn. "3.5.4".
String _dartSurumu() => RegExp(r'^(\S+)').firstMatch(Platform.version)?.group(1) ?? '';

Widget _bilgiSatiri(String etiket, String deger) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        SizedBox(width: 92, child: Text(etiket, style: oaBody(14, color: OA.muted))),
        Expanded(child: Text(deger, style: oaBody(14, weight: FontWeight.w600, color: OA.text))),
      ]),
    );

class _UygulamaHakkinda extends StatelessWidget {
  const _UygulamaHakkinda();

  @override
  Widget build(BuildContext context) => OACard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              OALabsSeal(
                size: 88,
                color: OA.text,
                accent: OA.amber,
                text: Lx('OA LABS · ATÖLYE · 2026 · OA LABS · ATÖLYE · 2026 · ', 'OA LABS · WORKSHOP · 2026 · OA LABS · WORKSHOP · 2026 · '),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L('Uygulama hakkında'), style: oaBody(16, weight: FontWeight.w700)),
                    Text(L('OA Labs atölyesinde özenle yapıldı.'), style: oaBody(14, color: OA.muted)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Divider(height: 1, color: OA.line),
            _bilgiSatiri(L('Sürüm'), appVersion),
            Divider(height: 1, color: OA.line),
            _bilgiSatiri(L('Sistem'), _sistemYazi()),
            Divider(height: 1, color: OA.line),
            _bilgiSatiri(L('Altyapı'), 'Flutter · Dart ${_dartSurumu()}'),
            Divider(height: 1, color: OA.line),
            const SizedBox(height: 12),
            Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(L('OA Labs uygulamaları ücretsiz ve reklamsız. Beğendiysen bir kahve ısmarlayarak devam etmemize yardım edebilirsin.'), style: oaBody(14, color: OA.muted)),
              ),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('https://buymeacoffee.com/oalabs'), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.coffee_outlined, size: 18),
                label: Text(L('Bir kahve ısmarla')),
              ),
            ]),
            const SizedBox(height: 12),
            Text('© ${DateTime.now().year} Oğuzhan Aydın', style: oaBody(14, color: OA.muted)),
          ],
        ),
      );
}

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
                  ListenableBuilder(
                    listenable: Listenable.merge([Hesap.i, Esitleme.i]),
                    builder: (context, _) => OACard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: satir(
                        Hesap.i.girisli ? Icons.cloud_sync_outlined : Icons.account_circle_outlined,
                        Hesap.i.girisli
                            ? (Hesap.i.ad?.isNotEmpty == true ? Hesap.i.ad! : Lx('Hesap ve eşitleme', 'Account and sync'))
                            : Lx('Giriş yap ve eşitle', 'Sign in and sync'),
                        hesapOzeti(),
                        renk: Esitleme.i.hata != null && Esitleme.i.kurulu ? OA.danger : null,
                        onTap: () => hesapAc(context),
                      ),
                    ),
                  ),
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
                  const SizedBox(height: 14),
                  const _UygulamaHakkinda(),
                  const SizedBox(height: 14),
                  Text(
                      Esitleme.i.acik
                          ? Lx('Verilerin bu cihazda ve uçtan uca şifreli olarak hesabında saklanır. Belge dosyaları yalnızca bu cihazda.',
                              'Your data is stored on this device and, end-to-end encrypted, in your account. Document files stay only on this device.')
                          : L('Verilerin yalnızca bu cihazda saklanır.'),
                      style: oaBody(14, color: OA.faint)),
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
