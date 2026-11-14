import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'hesap.dart';
import 'store.dart';

/// Eşitlenen veri: küme adı → (kimlik → değer).
/// Kümeler: kayitlar, duzenliler, belgeler (yalnız bilgileri, dosyalar değil), butceler, ayar.
typedef EsitlemeVerisi = Map<String, Map<String, dynamic>>;

/// Uçtan uca şifreli eşitleme.
///
/// Kayıtlar cihazdan, kullanıcının eşitleme parolasından (PBKDF2-HMAC-SHA256) türetilen anahtarla
/// AES-256-GCM ile şifrelenmiş tek bir kutu olarak çıkar; sunucu içini göremez. Parola hiçbir yere
/// gönderilmez, türetilen anahtar yalnız cihazın güvenli deposunda durur. Belge dosyaları hiç
/// gönderilmez; yalnız belgenin adı, türü ve bitiş tarihi gibi bilgileri eşitlenir.
///
/// Birleştirme üç yönlüdür: son eşitlenen hâl (taban), bu cihaz ve sunucu kayıt kayıt karşılaştırılır.
/// Yalnız bir tarafta değişen kayıt o taraftan alınır; silmeler de böyle taşınır. İki tarafta da
/// değiştiyse bu cihazdaki kalır (silinen ile değiştirilen çakışırsa değiştirilen kalır).
class Esitleme extends ChangeNotifier {
  Esitleme._();
  static final i = Esitleme._();

  static const _anahtarK = 'terazi_esitle_anahtar';
  static const _tuzK = 'terazi_esitle_tuz';
  static const _yineleme = 120000;
  static const ogeAdi = 'terazi';

  final _depo = const FlutterSecureStorage();
  final _aes = AesGcm.with256bits();

  List<int>? _anahtar;
  String? _tuz;
  EsitlemeVerisi? _taban;
  File? _tabanDosyasi;

  DateTime? son;
  String? hata;
  bool calisiyor = false;
  Timer? _zamanlayici;
  bool _uyguluyor = false;
  bool _yeniden = false;

  bool get acik => _anahtar != null && Hesap.i.oturumVar;
  bool get kurulu => _anahtar != null;

  Future<void> yukle() async {
    try {
      final k = await _depo.read(key: _anahtarK);
      _tuz = await _depo.read(key: _tuzK);
      if (k != null && _tuz != null) _anahtar = base64Decode(k);
    } catch (_) {}
    try {
      final dir = await getApplicationSupportDirectory();
      _tabanDosyasi = File('${dir.path}${Platform.pathSeparator}esitleme.json');
      if (await _tabanDosyasi!.exists()) {
        final j = jsonDecode(await _tabanDosyasi!.readAsString()) as Map;
        son = DateTime.tryParse((j['son'] ?? '').toString());
        _taban = _veriyeCevir(j['taban']);
      }
    } catch (_) {}
    Store.i.addListener(_degisti);
  }

  void _degisti() {
    if (_uyguluyor || !acik) return;
    planla();
  }

  /// Kısa bir bekleyişten sonra eşitle (art arda değişiklikler tek seferde gitsin).
  void planla([Duration gecikme = const Duration(seconds: 4)]) {
    _zamanlayici?.cancel();
    _zamanlayici = Timer(gecikme, esitle);
  }

  // ---------------------------------------------------------------- Kurulum

  /// Sunucudaki şifreli kutu (başka cihazda eşitleme açıldıysa); yoksa null.
  Future<({Map? kutu, String? hata})> sunucudakiKutu() async {
    final r = await Hesap.i.istek('/v1/me/sync?only=$ogeAdi');
    if (r['ok'] != true) return (kutu: null, hata: r['error']?.toString() ?? 'sunucu');
    return (kutu: _kutuyuAl(r), hata: null);
  }

  Map? _kutuyuAl(Map r) {
    final items = r['items'];
    if (items is! Map) return null;
    final o = items[ogeAdi];
    if (o is! Map) return null;
    final d = o['data'];
    if (d is List && d.isNotEmpty && d.first is Map) return d.first as Map;
    return null;
  }

  static Future<List<int>> anahtarTuret(String parola, List<int> tuz, {int yineleme = _yineleme}) async {
    final p = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: yineleme, bits: 256);
    final k = await p.deriveKeyFromPassword(password: parola, nonce: tuz);
    return k.extractBytes();
  }

  /// Eşitlemeyi parolayla açar. Sunucuda kutu varsa parola onunla denenir.
  /// Hata kodu döner ('kisa', 'parola' ya da sunucu hatası); başarılıysa null.
  Future<String?> kur(String parola, Map? uzak) async {
    if (parola.length < 8) return 'kisa';
    String tuz;
    if (uzak != null && uzak['s'] is String) {
      tuz = uzak['s'] as String;
    } else {
      final r = Random.secure();
      tuz = base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
    }
    final k = await anahtarTuret(parola, base64Decode(tuz));
    if (uzak != null && uzak['c'] is String && await kutuAc(uzak, k) == null) return 'parola';
    _anahtar = k;
    _tuz = tuz;
    hata = null;
    try {
      await _depo.write(key: _anahtarK, value: base64Encode(k));
      await _depo.write(key: _tuzK, value: tuz);
    } catch (_) {}
    // Yeni kurulumda taban boştur: bu cihazdaki ve sunucudaki her şey birleşir, hiçbir şey silinmez.
    _taban = null;
    await _tabaniYaz(null);
    notifyListeners();
    await esitle();
    return hata;
  }

  /// Eşitlemeyi bu cihazda kapatır. Cihazdaki veriler silinmez.
  Future<void> kapat({String? neden}) async {
    _zamanlayici?.cancel();
    _anahtar = null;
    _tuz = null;
    _taban = null;
    son = null;
    hata = neden;
    try {
      await _depo.delete(key: _anahtarK);
      await _depo.delete(key: _tuzK);
    } catch (_) {}
    await _tabaniYaz(null);
    notifyListeners();
  }

  // ---------------------------------------------------------------- Şifreleme

  Future<Map<String, dynamic>> kutula(EsitlemeVerisi veri, {List<int>? anahtar, String? tuz}) async {
    final acikMetin = gzip.encode(utf8.encode(jsonEncode(veri)));
    final kutu = await _aes.encrypt(acikMetin, secretKey: SecretKey(anahtar ?? _anahtar!));
    return {
      'v': 1,
      'z': 1,
      's': tuz ?? _tuz,
      'n': base64Encode(kutu.nonce),
      'c': base64Encode(kutu.cipherText),
      'm': base64Encode(kutu.mac.bytes),
    };
  }

  Future<EsitlemeVerisi?> kutuAc(Map kutu, [List<int>? anahtar]) async {
    final k = anahtar ?? _anahtar;
    if (k == null) return null;
    try {
      final sb = SecretBox(
        base64Decode(kutu['c'] as String),
        nonce: base64Decode(kutu['n'] as String),
        mac: Mac(base64Decode(kutu['m'] as String)),
      );
      var acikMetin = await _aes.decrypt(sb, secretKey: SecretKey(k));
      if (kutu['z'] == 1) acikMetin = gzip.decode(acikMetin);
      return _veriyeCevir(jsonDecode(utf8.decode(acikMetin)));
    } catch (_) {
      return null;
    }
  }

  static EsitlemeVerisi? _veriyeCevir(Object? j) {
    if (j is! Map) return null;
    return {
      for (final e in j.entries)
        if (e.value is Map) e.key.toString(): Map<String, dynamic>.from(e.value as Map),
    };
  }

  // ---------------------------------------------------------------- Eşitleme

  Future<void> esitle() async {
    if (!acik) return;
    if (calisiyor) {
      _yeniden = true;
      return;
    }
    calisiyor = true;
    notifyListeners();
    try {
      hata = await _esitle();
      if (hata == null) son = DateTime.now();
    } catch (e) {
      hata = 'sunucu';
      debugPrint('Eşitleme: $e');
    } finally {
      calisiyor = false;
      notifyListeners();
    }
    if (_yeniden) {
      _yeniden = false;
      planla(const Duration(seconds: 1));
    }
  }

  Future<String?> _esitle() async {
    for (var deneme = 0; deneme < 3; deneme++) {
      final r = await Hesap.i.istek('/v1/me/sync?only=$ogeAdi');
      if (r['ok'] != true) return r['error']?.toString() ?? 'sunucu';
      final kutu = _kutuyuAl(r);
      EsitlemeVerisi? uzak;
      if (kutu != null) {
        if (kutu['s'] != _tuz) {
          // Başka bir cihazda eşitleme farklı bir parolayla baştan kuruldu.
          await kapat(neden: 'tuz');
          return 'tuz';
        }
        uzak = await kutuAc(kutu);
        if (uzak == null) {
          await kapat(neden: 'parola');
          return 'parola';
        }
      }

      final yerel = Store.i.esitlemeVerisi();
      final birlesik = birlestir(_taban, yerel, uzak);
      if (!ayni(birlesik, yerel)) {
        _uyguluyor = true;
        try {
          Store.i.esitlemeyiUygula(birlesik);
        } finally {
          _uyguluyor = false;
        }
      }
      if (uzak == null || !ayni(birlesik, uzak)) {
        final zaman = DateTime.now().toUtc().toIso8601String();
        final g = await Hesap.i.istek('/v1/me/sync?only=$ogeAdi', {
          'items': {
            ogeAdi: {
              'updated': zaman,
              'data': [await kutula(birlesik)],
            },
          },
        });
        if (g['ok'] != true) return g['error']?.toString() ?? 'sunucu';
        // Sunucuda bizimkinden yeni bir kutu varsa (aynı anda başka cihaz yazdı) yeniden dene.
        final yazilan = g['items'] is Map ? (g['items'] as Map)[ogeAdi] : null;
        final tarih = yazilan is Map ? DateTime.tryParse((yazilan['updated'] ?? '').toString()) : null;
        if (tarih == null || !tarih.isAtSameMomentAs(DateTime.parse(zaman))) continue;
      }
      _taban = birlesik;
      await _tabaniYaz(birlesik);
      return null;
    }
    return 'sunucu';
  }

  Future<void> _tabaniYaz(EsitlemeVerisi? t) async {
    final f = _tabanDosyasi;
    if (f == null) return;
    try {
      if (t == null) {
        if (await f.exists()) await f.delete();
        return;
      }
      final tmp = File('${f.path}.yeni');
      await tmp.writeAsString(jsonEncode({'son': DateTime.now().toIso8601String(), 'taban': t}), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }
}

/// Anahtar sırası farkı yokmuş gibi karşılaştırmak için kanonik JSON.
String kanonik(Object? v) {
  if (v is Map) {
    final k = v.keys.map((e) => e.toString()).toList()..sort();
    return '{${k.map((e) => '${jsonEncode(e)}:${kanonik(v[e])}').join(',')}}';
  }
  if (v is List) return '[${v.map(kanonik).join(',')}]';
  return jsonEncode(v);
}

bool ayni(EsitlemeVerisi a, EsitlemeVerisi b) => kanonik(a) == kanonik(b);

/// Üç yönlü birleştirme. [taban]: son eşitlenen hâl (yoksa ilk eşitleme: her şey birleşir).
EsitlemeVerisi birlestir(EsitlemeVerisi? taban, EsitlemeVerisi yerel, EsitlemeVerisi? uzak) {
  if (uzak == null) return yerel;
  final out = <String, Map<String, dynamic>>{};
  final kumeler = {...yerel.keys, ...uzak.keys};
  for (final kume in kumeler) {
    final b = taban?[kume] ?? const <String, dynamic>{};
    final l = yerel[kume] ?? const <String, dynamic>{};
    final r = uzak[kume] ?? const <String, dynamic>{};
    final m = <String, dynamic>{};
    for (final id in {...l.keys, ...r.keys, ...b.keys}) {
      final lv = l.containsKey(id) ? kanonik(l[id]) : null;
      final rv = r.containsKey(id) ? kanonik(r[id]) : null;
      final bv = b.containsKey(id) ? kanonik(b[id]) : null;
      String? sec; // 'l' ya da 'r'
      if (lv == rv) {
        sec = 'l';
      } else if (lv == bv) {
        sec = 'r'; // yalnız sunucuda değişti (ya da silindi)
      } else if (rv == bv) {
        sec = 'l'; // yalnız bu cihazda değişti (ya da silindi)
      } else {
        sec = lv != null ? 'l' : 'r'; // ikisinde de değişti: bu cihaz; silme ile değişiklikte değişiklik
      }
      final kaynak = sec == 'l' ? l : r;
      if (kaynak.containsKey(id)) m[id] = kaynak[id];
    }
    out[kume] = m;
  }
  return out;
}
