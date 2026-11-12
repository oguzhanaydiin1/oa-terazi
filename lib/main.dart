import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bildirim.dart';
import 'models.dart';
import 'pages/ayarlar.dart';
import 'pages/ekle.dart';
import 'pages/hareketler.dart';
import 'pages/odendi.dart';
import 'pages/ozet.dart';
import 'pages/raporlar.dart';
import 'pages/sayfalar.dart';
import 'pages/takvim.dart';
import 'store.dart';
import 'theme.dart';

final gezgin = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.ac();
  await Bildirim.baslat();
  Store.i.degisince = Bildirim.yenidenPlanla;
  Bildirim.dokunulunca = bildirimIsle;
  Bildirim.planla();
  runApp(const TeraziApp());
}

class TeraziApp extends StatelessWidget {
  const TeraziApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Terazi',
        debugShowCheckedModeBanner: false,
        theme: oaTheme(),
        navigatorKey: gezgin,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Kabuk(),
      );
}

/// Bildirime ya da "Ödendi" / "Yarın hatırlat" düğmesine dokunulunca.
void bildirimIsle(String id, String donem, String? eylem) {
  final ctx = gezgin.currentContext;
  final d = Store.i.duzenli(id);
  if (ctx == null || d == null) return;
  final t = d.ayda(DateTime.parse('$donem-01'));
  if (t == null) return;
  final m = ScaffoldMessenger.of(ctx);
  if (t.durum != null) {
    m.showSnackBar(SnackBar(content: Text('${d.ad} bu ay için zaten kaydedilmiş.')));
    return;
  }
  if (eylem == 'odendi' && !d.degisken) {
    hizliOdendi(ctx, t);
  } else if (eylem == 'ertele') {
    Store.i.ertele(t);
    m.showSnackBar(SnackBar(content: Text('${d.ad} için yarın sabah yeniden soracağım.')));
  } else {
    odendiSor(ctx, t);
  }
}

class Kabuk extends StatefulWidget {
  const Kabuk({super.key});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  Sayfa sayfa = Sayfa.ozet;
  late final AppLifecycleListener _dongu;

  static const _alt = [Sayfa.ozet, Sayfa.hareketler, Sayfa.takvim, Sayfa.raporlar, Sayfa.ayarlar];

  @override
  void initState() {
    super.initState();
    // Uygulama gece açık kaldıysa ya da arka plandan dönünce: "bugün" değişmiş olabilir.
    _dongu = AppLifecycleListener(onResume: () {
      setState(() {});
      Bildirim.planla();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = Bildirim.acilis;
      if (a != null) {
        Bildirim.acilis = null;
        bildirimIsle(a.id, a.donem, a.eylem);
      }
    });
  }

  @override
  void dispose() {
    _dongu.dispose();
    super.dispose();
  }

  void git(Sayfa s, bool genis) {
    if (s == Sayfa.butceler && !genis) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: OA.bg,
            title: Text('Bütçeler', style: oaDisplay(20)),
          ),
          body: const ButcelerSayfasi(genis: false),
        ),
      ));
      return;
    }
    setState(() => sayfa = s);
  }

  Future<void> disaAktar() async {
    final m = ScaffoldMessenger.of(context);
    try {
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}terazi-hareketler-${gunAnahtar(DateTime.now())}.csv');
      await f.writeAsString(Store.i.csv());
      m.showSnackBar(SnackBar(
        content: Text('İndirilenler klasörüne kaydedildi: ${f.uri.pathSegments.last}'),
        action: SnackBarAction(label: 'Aç', textColor: OA.amber, onPressed: () => launchUrl(Uri.file(f.path))),
      ));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Dışa aktarılamadı: $e')));
    }
  }

  Widget govde(bool genis) {
    final aktar = Platform.isWindows ? disaAktar : null;
    void g(Sayfa s) => git(s, genis);
    return switch (sayfa) {
      Sayfa.ozet => OzetSayfasi(git: g, genis: genis, disaAktar: aktar),
      Sayfa.hareketler => HareketlerSayfasi(genis: genis),
      Sayfa.butceler => ButcelerSayfasi(genis: genis),
      Sayfa.takvim => TakvimSayfasi(genis: genis),
      Sayfa.raporlar => RaporlarSayfasi(genis: genis),
      Sayfa.ayarlar => AyarlarSayfasi(genis: genis, git: g, disaAktar: aktar),
    };
  }

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.sizeOf(context).width >= 900;
    if (genis) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => kayitAc(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                _KenarCubugu(secili: sayfa, sec: (s) => git(s, true)),
                const VerticalDivider(width: 1, color: OA.line),
                Expanded(child: SafeArea(child: govde(true))),
              ],
            ),
          ),
        ),
      );
    }
    final i = _alt.indexOf(sayfa);
    return Scaffold(
      body: SafeArea(bottom: false, child: govde(false)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => kayitAc(context),
        backgroundColor: OA.amber,
        foregroundColor: OA.amberInk,
        icon: const Icon(Icons.add),
        label: Text('Ekle', style: oaBody(16, color: OA.amberInk, weight: FontWeight.w700)),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: OA.bg2,
        indicatorColor: OA.amber.withValues(alpha: 0.18),
        selectedIndex: i < 0 ? 0 : i,
        onDestinationSelected: (n) => setState(() => sayfa = _alt[n]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: 'Özet'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Hareketler'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Takvim'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Raporlar'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}

class _KenarCubugu extends StatelessWidget {
  const _KenarCubugu({required this.secili, required this.sec});
  final Sayfa secili;
  final ValueChanged<Sayfa> sec;

  static const _ogeler = [
    (Sayfa.ozet, Icons.space_dashboard_outlined, 'Özet'),
    (Sayfa.hareketler, Icons.receipt_long_outlined, 'Hareketler'),
    (Sayfa.butceler, Icons.pie_chart_outline, 'Bütçeler'),
    (Sayfa.takvim, Icons.calendar_month_outlined, 'Ödeme takvimi'),
    (Sayfa.raporlar, Icons.bar_chart_outlined, 'Raporlar'),
    (Sayfa.ayarlar, Icons.settings_outlined, 'Ayarlar'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: 240,
        color: OA.bg2,
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const TeraziMark(size: 34),
                const SizedBox(width: 10),
                Text('Terazi', style: oaDisplay(22)),
              ],
            ),
            const SizedBox(height: 26),
            for (final (s, ikon, ad) in _ogeler)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: s == secili ? OA.amber.withValues(alpha: 0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => sec(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      child: Row(
                        children: [
                          Icon(ikon, size: 20, color: s == secili ? OA.amber : OA.text2),
                          const SizedBox(width: 12),
                          Text(ad,
                              style: oaBody(15,
                                  color: s == secili ? OA.amber : OA.text2,
                                  weight: s == secili ? FontWeight.w700 : FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Text('Ctrl+N: yeni kayıt', style: oaBody(13, color: OA.faint)),
            const SizedBox(height: 4),
            Text('Verilerin bu bilgisayarda saklanır', style: oaBody(13, color: OA.faint)),
          ],
        ),
      );
}
