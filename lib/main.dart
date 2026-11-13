import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'i18n.dart';
import 'belge.dart';
import 'bildirim.dart';
import 'models.dart';
import 'pages/ayarlar.dart';
import 'pages/belgeler.dart';
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
  Kasa.geciciTemizle();
  await Bildirim.baslat();
  Store.i.degisince = Bildirim.yenidenPlanla;
  Bildirim.dokunulunca = bildirimIsle;
  runApp(const TeraziApp());
}

class TeraziApp extends StatefulWidget {
  const TeraziApp({super.key});

  @override
  State<TeraziApp> createState() => _TeraziAppState();
}

/// Dil, tema ve para birimini ayarlardan (ya da "Sistem" seçiliyse cihazdan) uygular.
class _TeraziAppState extends State<TeraziApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.i.addListener(_degisti);
  }

  @override
  void dispose() {
    Store.i.removeListener(_degisti);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _iz = '';

  /// Görünüm ayarı değiştiyse bütün uygulamayı yeniden kur (renkler ve metinler her yerde değişsin).
  void _degisti() {
    if (_imza() != _iz) setState(() {});
  }

  @override
  void didChangePlatformBrightness() => _degisti();

  @override
  void didChangeLocales(List<Locale>? locales) => _degisti();

  String _imza() {
    final s = Store.i;
    final d = WidgetsBinding.instance.platformDispatcher;
    final en = s.dil == 'en' || (s.dil == 'sistem' && d.locale.languageCode != 'tr');
    final koyu = s.tema == 'koyu' || (s.tema == 'sistem' && d.platformBrightness == Brightness.dark);
    return '$en|$koyu|${s.paraBirimi}';
  }

  @override
  Widget build(BuildContext context) {
    _iz = _imza();
    final p = _iz.split('|');
    Dil.en = p[0] == 'true';
    OA.koyu = p[1] == 'true';
    Bicim.birim = paraBirimi(p[2]);
    Bildirim.yenidenPlanla();
    return MaterialApp(
      key: ValueKey(_iz),
      title: 'Terazi',
      debugShowCheckedModeBanner: false,
      theme: oaTheme(),
      navigatorKey: gezgin,
      locale: Dil.en ? const Locale('en') : const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: OA.koyu ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: const Kabuk(),
      ),
    );
  }
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
    m.showSnackBar(SnackBar(content: Text(Lx('${d.ad} bu ay için zaten kaydedilmiş.', '${d.ad} is already recorded for this month.'))));
    return;
  }
  if (eylem == 'odendi' && !d.degisken) {
    hizliOdendi(ctx, t);
  } else if (eylem == 'ertele') {
    Store.i.ertele(t);
    m.showSnackBar(SnackBar(content: Text(Lx('${d.ad} için yarın sabah yeniden soracağım.', 'I’ll ask about ${d.ad} again tomorrow morning.'))));
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
  /// Tema ya da dil değişince uygulama yeniden kurulur; açık olan bölüm korunsun.
  static Sayfa _son = Sayfa.ozet;
  Sayfa get sayfa => _son;
  set sayfa(Sayfa s) => _son = s;
  late final AppLifecycleListener _dongu;

  static const _alt = [Sayfa.ozet, Sayfa.hareketler, Sayfa.takvim, Sayfa.belgeler, Sayfa.raporlar];

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
            title: Text(L('Bütçeler'), style: oaDisplay(20)),
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
        content: Text(Lx('İndirilenler klasörüne kaydedildi: ${f.uri.pathSegments.last}', 'Saved to Downloads: ${f.uri.pathSegments.last}')),
        action: SnackBarAction(label: L('Aç'), textColor: OA.amber, onPressed: () => launchUrl(Uri.file(f.path))),
      ));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(Lx('Dışa aktarılamadı: $e', 'Couldn’t export: $e'))));
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
      Sayfa.belgeler => BelgelerSayfasi(genis: genis),
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
                VerticalDivider(width: 1, color: OA.line),
                Expanded(child: SafeArea(child: govde(true))),
              ],
            ),
          ),
        ),
      );
    }
    // Telefonda Ayarlar alt menüde değil; Özet'teki dişliden açılır, geri tuşuyla Özet'e dönülür.
    if (sayfa == Sayfa.ayarlar) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => sayfa = Sayfa.ozet);
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: OA.bg,
            leading: BackButton(onPressed: () => setState(() => sayfa = Sayfa.ozet)),
          ),
          body: SafeArea(top: false, child: govde(false)),
        ),
      );
    }
    final i = _alt.indexOf(sayfa);
    final belgeler = sayfa == Sayfa.belgeler;
    return Scaffold(
      body: SafeArea(bottom: false, child: govde(false)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => belgeler ? belgeEkle(context) : kayitAc(context),
        backgroundColor: OA.amber,
        foregroundColor: OA.amberInk,
        icon: const Icon(Icons.add),
        label: Text(belgeler ? Lx('Belge ekle', 'Add document') : L('Ekle'),
            style: oaBody(16, color: OA.amberInk, weight: FontWeight.w700)),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: OA.bg2,
        indicatorColor: OA.amber.withValues(alpha: 0.18),
        selectedIndex: i < 0 ? 0 : i,
        onDestinationSelected: (n) => setState(() => sayfa = _alt[n]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard), label: L('Özet')),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: L('Hareketler')),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: L('Takvim')),
          NavigationDestination(icon: const Icon(Icons.description_outlined), selectedIcon: const Icon(Icons.description), label: Lx('Belgeler', 'Docs')),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: L('Raporlar')),
        ],
      ),
    );
  }
}

class _KenarCubugu extends StatelessWidget {
  const _KenarCubugu({required this.secili, required this.sec});
  final Sayfa secili;
  final ValueChanged<Sayfa> sec;

  static List<(Sayfa, IconData, String)> get _ogeler => [
    (Sayfa.ozet, Icons.space_dashboard_outlined, L('Özet')),
    (Sayfa.hareketler, Icons.receipt_long_outlined, L('Hareketler')),
    (Sayfa.butceler, Icons.pie_chart_outline, L('Bütçeler')),
    (Sayfa.takvim, Icons.calendar_month_outlined, L('Ödeme takvimi')),
    (Sayfa.belgeler, Icons.description_outlined, Lx('Belgeler', 'Documents')),
    (Sayfa.raporlar, Icons.bar_chart_outlined, L('Raporlar')),
    (Sayfa.ayarlar, Icons.settings_outlined, L('Ayarlar')),
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
            Text(L('Ctrl+N: yeni kayıt'), style: oaBody(13, color: OA.faint)),
            const SizedBox(height: 4),
            Text(L('Verilerin bu bilgisayarda saklanır'), style: oaBody(13, color: OA.faint)),
          ],
        ),
      );
}
