import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'belge.dart';
import 'i18n.dart';
import 'kategoriler.dart';
import 'models.dart';

/// Uygulamanın tüm verisi: cihazda tek bir JSON dosyasında (terazi.json) durur.
class Store extends ChangeNotifier {
  Store._(this._dosya);

  static late Store i;

  final File? _dosya;
  final List<Kayit> kayitlar = [];
  final List<Duzenli> duzenliler = [];
  final Map<String, int> butceler = {}; // kategori → aylık sınır (kuruş)
  final List<Belge> belgeler = [];
  DateTime? sonYedek;
  bool yedekHatirlat = true;
  bool bildirim = true;
  String dil = 'sistem'; // sistem, tr, en
  String tema = 'sistem'; // sistem, koyu, acik
  String paraBirimi = 'TRY';

  /// Veri değişince (bildirimleri yeniden planlamak için) çağrılır.
  void Function()? degisince;

  Future<void> _yazma = Future.value();

  static Future<Store> ac() async {
    File? f;
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      f = File('${dir.path}${Platform.pathSeparator}terazi.json');
    } catch (e) {
      debugPrint('Veri klasörü açılamadı: $e');
    }
    final s = Store._(f);
    await s._oku();
    i = s;
    return s;
  }

  /// Testler için dosyasız depo.
  @visibleForTesting
  factory Store.bellekte() => Store._(null);

  Future<void> _oku() async {
    final f = _dosya;
    if (f == null || !await f.exists()) return;
    try {
      _yukle(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (e) {
      // Bozuk dosyayı silmek yerine kenara al; kullanıcı verisi kaybolmasın.
      debugPrint('terazi.json okunamadı: $e');
      try {
        await f.copy('${f.path}.bozuk-${DateTime.now().millisecondsSinceEpoch}');
      } catch (_) {}
    }
  }

  void _yukle(Map<String, dynamic> j) {
    {
      kayitlar
        ..clear()
        ..addAll(((j['kayitlar'] as List?) ?? []).map((e) => Kayit.fromJson(Map<String, dynamic>.from(e as Map))));
      duzenliler
        ..clear()
        ..addAll(((j['duzenliler'] as List?) ?? []).map((e) => Duzenli.fromJson(Map<String, dynamic>.from(e as Map))));
      butceler
        ..clear()
        ..addAll(((j['butceler'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt())));
      bildirim = j['bildirim'] != false;
      belgeler
        ..clear()
        ..addAll(((j['belgeler'] as List?) ?? []).map((e) => Belge.fromJson(Map<String, dynamic>.from(e as Map))));
      sonYedek = j['sonYedek'] == null ? null : DateTime.tryParse(j['sonYedek'] as String);
      yedekHatirlat = j['yedekHatirlat'] != false;
      dil = (j['dil'] as String?) ?? 'sistem';
      tema = (j['tema'] as String?) ?? 'sistem';
      paraBirimi = (j['paraBirimi'] as String?) ?? 'TRY';
    }
    _sirala();
  }

  Map<String, dynamic> toJson() => {
        'surum': 1,
        'kayitlar': kayitlar.map((k) => k.toJson()).toList(),
        'duzenliler': duzenliler.map((d) => d.toJson()).toList(),
        'butceler': butceler,
        'bildirim': bildirim,
        'belgeler': belgeler.map((b) => b.toJson()).toList(),
        if (sonYedek != null) 'sonYedek': sonYedek!.toIso8601String(),
        'yedekHatirlat': yedekHatirlat,
        'dil': dil,
        'tema': tema,
        'paraBirimi': paraBirimi,
      };

  void _degisti() {
    _sirala();
    notifyListeners();
    degisince?.call();
    final f = _dosya;
    if (f == null) return;
    final metin = const JsonEncoder.withIndent(' ').convert(toJson());
    _yazma = _yazma.then((_) async {
      try {
        final tmp = File('${f.path}.yeni');
        await tmp.writeAsString(metin, flush: true);
        await tmp.rename(f.path);
      } catch (e) {
        debugPrint('terazi.json yazılamadı: $e');
      }
    });
  }

  void _sirala() {
    kayitlar.sort((a, b) {
      final c = b.tarih.compareTo(a.tarih);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    duzenliler.sort((a, b) => a.gun.compareTo(b.gun));
  }

  // ---- Kayıtlar ----

  void kayitKaydet(Kayit k) {
    final i = kayitlar.indexWhere((e) => e.id == k.id);
    if (i >= 0) {
      kayitlar[i] = k;
    } else {
      kayitlar.add(k);
    }
    _degisti();
  }

  void kayitSil(String id) {
    kayitlar.removeWhere((k) => k.id == id);
    // Bir düzenli ödemenin "ödendi" kaydıysa o ay yeniden açık olsun.
    for (final d in duzenliler) {
      d.durumlar.removeWhere((_, v) => v.kayitId == id);
    }
    _degisti();
  }

  // ---- Düzenli ödemeler ----

  Duzenli? duzenli(String id) {
    for (final d in duzenliler) {
      if (d.id == id) return d;
    }
    return null;
  }

  void duzenliKaydet(Duzenli d) {
    final i = duzenliler.indexWhere((e) => e.id == d.id);
    if (i >= 0) {
      duzenliler[i] = d;
    } else {
      duzenliler.add(d);
    }
    _degisti();
  }

  /// Düzenli ödemeyi siler. Geçmişte "ödendi" diye kaydedilen giderler hareketlerde kalır.
  void duzenliSil(String id) {
    duzenliler.removeWhere((d) => d.id == id);
    for (final k in kayitlar) {
      if (k.duzenliId == id) k.duzenliId = null;
    }
    _degisti();
  }

  /// "Ödendi": gider olarak kaydeder. Ödeme günü gelmeden ödendiyse bugünün tarihi yazılır.
  String odendi(Tekrar t, int tutar, {DateTime? simdi}) {
    final bugun = gunBasi(simdi ?? DateTime.now());
    final k = Kayit(
      id: yeniId(),
      tur: Tur.gider,
      tutar: tutar,
      kategori: t.duzenli.kategori,
      tarih: t.tarih.isAfter(bugun) ? bugun : t.tarih,
      aciklama: t.duzenli.ad,
      duzenliId: t.duzenli.id,
    );
    kayitlar.add(k);
    t.duzenli.durumlar[t.donem] = AyDurumu(Durum.odendi, kayitId: k.id);
    t.duzenli.ertelenen.remove(t.donem);
    _degisti();
    return k.id;
  }

  void atla(Tekrar t) {
    t.duzenli.durumlar[t.donem] = AyDurumu(Durum.atlandi);
    t.duzenli.ertelenen.remove(t.donem);
    _degisti();
  }

  /// "Yarın hatırlat".
  void ertele(Tekrar t, {DateTime? simdi}) {
    final b = gunBasi(simdi ?? DateTime.now());
    t.duzenli.ertelenen[t.donem] = DateTime(b.year, b.month, b.day + 1);
    _degisti();
  }

  /// Ödendi / bu ay ödenmeyecek kararını geri alır.
  void geriAl(Tekrar t) {
    final d = t.duzenli.durumlar.remove(t.donem);
    t.duzenli.ertelenen.remove(t.donem);
    if (d?.kayitId != null) kayitlar.removeWhere((k) => k.id == d!.kayitId);
    _degisti();
  }

  /// Şu an "ödendi mi?" diye sorulması gereken ödemeler: günü gelmiş ya da geçmiş, kapanmamış,
  /// ertelendiyse erteleme günü gelmiş olanlar. Son iki ayın ödemelerine bakılır.
  List<Tekrar> sorulacaklar([DateTime? simdi]) {
    final bugun = gunBasi(simdi ?? DateTime.now());
    final out = <Tekrar>[];
    for (final d in duzenliler) {
      for (final ay in [ayEkle(bugun, -1), ayBasi(bugun)]) {
        final t = d.ayda(ay);
        if (t == null) continue;
        final h = t.hal(bugun);
        if (h != TekrarHali.gecikti && h != TekrarHali.bugun) continue;
        final e = d.ertelenen[t.donem];
        if (e != null && e.isAfter(bugun)) continue;
        out.add(t);
      }
    }
    out.sort((a, b) => a.tarih.compareTo(b.tarih));
    return out;
  }

  /// Bu ay ve gelecek ay kapanmamış ödemeler, tarihe göre (gecikenler de dahil).
  List<Tekrar> yaklasanlar([DateTime? simdi]) {
    final bugun = gunBasi(simdi ?? DateTime.now());
    final out = <Tekrar>[];
    for (final d in duzenliler) {
      for (final ay in [ayBasi(bugun), ayEkle(bugun, 1)]) {
        final t = d.ayda(ay);
        if (t != null && t.acik(bugun)) out.add(t);
      }
    }
    out.sort((a, b) => a.tarih.compareTo(b.tarih));
    return out;
  }

  // ---- Bütçe ve ayarlar ----

  void butceAyarla(String kategori, int? sinir) {
    if (sinir == null || sinir <= 0) {
      butceler.remove(kategori);
    } else {
      butceler[kategori] = sinir;
    }
    _degisti();
  }

  void gorunumAyarla({String? dil, String? tema, String? paraBirimi}) {
    if (dil != null) this.dil = dil;
    if (tema != null) this.tema = tema;
    if (paraBirimi != null) this.paraBirimi = paraBirimi;
    _degisti();
  }

  void bildirimAyarla(bool v) {
    bildirim = v;
    _degisti();
  }

  void hepsiniSil() {
    for (final b in belgeler) {
      for (final d in b.dosyalar) {
        Kasa.sil(d.id);
      }
    }
    kayitlar.clear();
    duzenliler.clear();
    butceler.clear();
    belgeler.clear();
    _degisti();
  }

  // ---- Belgeler (yalnızca bu cihazda) ----

  Belge? belge(String id) {
    for (final b in belgeler) {
      if (b.id == id) return b;
    }
    return null;
  }

  void belgeKaydet(Belge b) {
    final i = belgeler.indexWhere((e) => e.id == b.id);
    if (i >= 0) {
      belgeler[i] = b;
    } else {
      belgeler.add(b);
    }
    _degisti();
  }

  Future<void> belgeSil(String id) async {
    final b = belge(id);
    if (b == null) return;
    belgeler.remove(b);
    _degisti();
    for (final d in b.dosyalar) {
      await Kasa.sil(d.id);
    }
  }

  /// Bitişi yaklaşan ya da geçen belgeler (en yakın önce).
  List<Belge> yaklasanBelgeler([DateTime? simdi]) {
    final bugun = gunBasi(simdi ?? DateTime.now());
    final l = belgeler.where((b) => b.yaklasti(bugun)).toList()..sort((a, b) => a.bitis!.compareTo(b.bitis!));
    return l;
  }

  /// Yedek alma zamanı geldi mi? (hiç alınmadıysa ve en az bir belge varsa ya da son yedek 30 günden eskiyse)
  bool yedekZamani([DateTime? simdi]) {
    if (!yedekHatirlat || (belgeler.isEmpty && kayitlar.length < 20)) return false;
    final s = sonYedek;
    return s == null || (simdi ?? DateTime.now()).difference(s).inDays >= 30;
  }

  void yedekAlindi() {
    sonYedek = DateTime.now();
    _degisti();
  }

  void yedekHatirlatAyarla(bool v) {
    yedekHatirlat = v;
    _degisti();
  }

  /// Yedek için: veri ve bütün belge dosyalarının şifresiz hâli.
  Future<Map<String, List<int>>> belgeDosyalari() async {
    final out = <String, List<int>>{};
    for (final b in belgeler) {
      for (final d in b.dosyalar) {
        try {
          out[d.id] = await Kasa.oku(d.id);
        } catch (e) {
          debugPrint('Belge okunamadı ${d.id}: $e');
        }
      }
    }
    return out;
  }

  /// Yedekten geri yükler: bu cihazdaki her şeyin yerine yedektekiler gelir.
  Future<void> geriYukle(Map<String, dynamic> veri, Map<String, List<int>> dosyalar) async {
    final eskiler = [for (final b in belgeler) ...b.dosyalar.map((d) => d.id)];
    // Ayarlar (dil, tema, para birimi) bu cihazda kalsın.
    final ayar = (dil: dil, tema: tema, para: paraBirimi);
    _yukle(veri);
    dil = ayar.dil;
    tema = ayar.tema;
    paraBirimi = ayar.para;
    for (final e in dosyalar.entries) {
      final f = File('${(await Kasa.klasor()).path}${Platform.pathSeparator}${e.key}.bin');
      await f.writeAsBytes(await sifrele(e.value, await Kasa.anahtar()), flush: true);
    }
    final yeniler = {for (final b in belgeler) ...b.dosyalar.map((d) => d.id)};
    for (final id in eskiler) {
      if (!yeniler.contains(id)) await Kasa.sil(id);
    }
    _degisti();
  }

  /// Hareketleri CSV olarak (Excel'de açılır; ayırıcı ";").
  String csv() {
    final b = StringBuffer(Lx('\uFEFFTarih;Tür;Kategori;Açıklama;Tutar (${Bicim.birim.kod})\n',
        '\uFEFFDate;Type;Category;Description;Amount (${Bicim.birim.kod})\n'));
    for (final k in kayitlar) {
      final aciklama = k.aciklama.replaceAll('"', '""');
      final tutar = (k.isaretli / 100).toStringAsFixed(2).replaceAll('.', Bicim.ondalik);
      b.write('${gunAnahtar(k.tarih)};${k.tur == Tur.gelir ? L('Gelir') : L('Gider')};${kategori(k.kategori).ad};"$aciklama";$tutar\n');
    }
    return b.toString();
  }
}
