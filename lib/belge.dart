// Belge kasası: faturalar, poliçeler, garanti belgeleri, sözleşmeler.
//
// Belgeler yalnızca bu cihazda durur; hiçbir sunucuya gönderilmez.
// Dosyalar uygulamanın kendi klasöründe AES-256-GCM ile şifreli saklanır. Anahtar, cihazın güvenli
// deposunda (Android Keystore, Windows DPAPI) tutulur. Yedek dosyası kullanıcının parolasıyla şifrelenir.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'i18n.dart';
import 'models.dart';

/// Belge türleri. Kimlik, pasaport ve banka kartı bilerek yok.
class BelgeTuru {
  const BelgeTuru(this.id, this._tr, this._en, this.ikon, this.renk);
  final String id;
  final String _tr;
  final String _en;
  final IconData ikon;
  final Color renk;
  String get ad => Lx(_tr, _en);
}

const belgeTurleri = <BelgeTuru>[
  BelgeTuru('fatura', 'Fatura', 'Bill', Icons.receipt_long_outlined, Color(0xFFF2A541)),
  BelgeTuru('sigorta', 'Sigorta', 'Insurance', Icons.shield_outlined, Color(0xFF6EA8FE)),
  BelgeTuru('garanti', 'Garanti', 'Warranty', Icons.verified_outlined, Color(0xFF5BC48C)),
  BelgeTuru('sozlesme', 'Sözleşme', 'Contract', Icons.handshake_outlined, Color(0xFFC79BF2)),
  BelgeTuru('diger', 'Diğer', 'Other', Icons.description_outlined, Color(0xFF9EA2B3)),
];

BelgeTuru belgeTuru(String id) => belgeTurleri.firstWhere((t) => t.id == id, orElse: () => belgeTurleri.last);

/// Belgenin bir sayfası ya da dosyası.
class BelgeDosyasi {
  BelgeDosyasi({required this.id, required this.ad, required this.boyut});
  final String id; // diskteki şifreli dosyanın adı
  final String ad; // özgün dosya adı (uzantı türü belirler)
  final int boyut; // şifresiz bayt

  String get uzanti {
    final i = ad.lastIndexOf('.');
    return i < 0 ? '' : ad.substring(i + 1).toLowerCase();
  }

  bool get resim => const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'gif', 'bmp'].contains(uzanti);
  bool get pdf => uzanti == 'pdf';

  Map<String, dynamic> toJson() => {'id': id, 'ad': ad, 'boyut': boyut};
  factory BelgeDosyasi.fromJson(Map<String, dynamic> j) =>
      BelgeDosyasi(id: j['id'] as String, ad: j['ad'] as String? ?? 'belge', boyut: (j['boyut'] as num?)?.toInt() ?? 0);
}

class Belge {
  Belge({
    required this.id,
    required this.ad,
    required this.tur,
    required this.eklenme,
    List<BelgeDosyasi>? dosyalar,
    this.bitis,
    this.hatirlat = 15,
    this.duzenliId,
    this.kayitId,
  }) : dosyalar = dosyalar ?? [];

  final String id;
  String ad;
  String tur;
  final DateTime eklenme;
  final List<BelgeDosyasi> dosyalar;
  DateTime? bitis;
  int hatirlat; // bitişten kaç gün önce (30, 15, 7)
  String? duzenliId; // bağlı düzenli ödeme
  String? kayitId; // bağlı gider kaydı (ör. ödenen fatura)

  int get boyut => dosyalar.fold(0, (a, d) => a + d.boyut);

  /// Bitişe kalan gün (bitiş yoksa null; geçtiyse eksi).
  int? kalanGun(DateTime bugun) => bitis == null ? null : gunBasi(bitis!).difference(gunBasi(bugun)).inDays;

  /// Hatırlatma aralığına girdi mi (ya da süresi geçti mi)?
  bool yaklasti(DateTime bugun) {
    final k = kalanGun(bugun);
    return k != null && k <= hatirlat;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ad': ad,
        'tur': tur,
        'eklenme': gunAnahtar(eklenme),
        'dosyalar': dosyalar.map((d) => d.toJson()).toList(),
        if (bitis != null) 'bitis': gunAnahtar(bitis!),
        'hatirlat': hatirlat,
        if (duzenliId != null) 'duzenliId': duzenliId,
        if (kayitId != null) 'kayitId': kayitId,
      };

  factory Belge.fromJson(Map<String, dynamic> j) => Belge(
        id: j['id'] as String,
        ad: j['ad'] as String? ?? '',
        tur: j['tur'] as String? ?? 'diger',
        eklenme: DateTime.tryParse(j['eklenme'] as String? ?? '') ?? DateTime.now(),
        dosyalar: ((j['dosyalar'] as List?) ?? [])
            .map((e) => BelgeDosyasi.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        bitis: j['bitis'] == null ? null : DateTime.tryParse(j['bitis'] as String),
        hatirlat: (j['hatirlat'] as num?)?.toInt() ?? 15,
        duzenliId: j['duzenliId'] as String?,
        kayitId: j['kayitId'] as String?,
      );
}

/// "412 KB", "18,4 MB".
String boyutYazi(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
  final mb = (b / (1024 * 1024)).toStringAsFixed(1);
  return '${Dil.en ? mb : mb.replaceAll('.', ',')} MB';
}

// ---------------------------------------------------------------- Şifreli dosya deposu

final _aes = AesGcm.with256bits();

Future<Uint8List> sifrele(List<int> veri, SecretKey anahtar) async {
  final kutu = await _aes.encrypt(veri, secretKey: anahtar);
  return Uint8List.fromList(kutu.concatenation());
}

Future<Uint8List> coz(List<int> veri, SecretKey anahtar) async {
  final kutu = SecretBox.fromConcatenation(veri, nonceLength: _aes.nonceLength, macLength: 16);
  return Uint8List.fromList(await _aes.decrypt(kutu, secretKey: anahtar));
}

class Kasa {
  Kasa._();

  static const _depo = FlutterSecureStorage();
  static SecretKey? _anahtar;
  static Directory? _klasor;

  static Future<Directory> klasor() async {
    if (_klasor != null) return _klasor!;
    final kok = await getApplicationSupportDirectory();
    final d = Directory('${kok.path}${Platform.pathSeparator}belgeler');
    if (!await d.exists()) await d.create(recursive: true);
    return _klasor = d;
  }

  /// Bu cihazın belge anahtarı; ilk kullanımda üretilir.
  static Future<SecretKey> anahtar() async {
    if (_anahtar != null) return _anahtar!;
    final kayitli = await _depo.read(key: 'terazi_belge_anahtari');
    if (kayitli != null) return _anahtar = SecretKey(base64Decode(kayitli));
    final r = Random.secure();
    final b = List<int>.generate(32, (_) => r.nextInt(256));
    await _depo.write(key: 'terazi_belge_anahtari', value: base64Encode(b));
    return _anahtar = SecretKey(b);
  }

  static Future<File> _dosya(String id) async => File('${(await klasor()).path}${Platform.pathSeparator}$id.bin');

  /// Şifresiz baytları şifreleyip kaydeder; dosyanın kimliğini döndürür.
  static Future<String> yaz(List<int> veri) async {
    final id = yeniId();
    final f = await _dosya(id);
    await f.writeAsBytes(await sifrele(veri, await anahtar()), flush: true);
    return id;
  }

  static Future<Uint8List> oku(String id) async => coz(await (await _dosya(id)).readAsBytes(), await anahtar());

  static Future<void> sil(String id) async {
    try {
      final f = await _dosya(id);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Açmak ya da paylaşmak için geçici, şifresiz kopya (uygulama kapanınca temizlenir).
  static Future<File> geciciKopya(BelgeDosyasi d) async {
    final tmp = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}terazi-acik');
    if (!await tmp.exists()) await tmp.create(recursive: true);
    final guvenli = d.ad.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final f = File('${tmp.path}${Platform.pathSeparator}$guvenli');
    await f.writeAsBytes(await oku(d.id), flush: true);
    return f;
  }

  /// Açılış: önceki oturumdan kalan şifresiz geçici kopyaları sil.
  static Future<void> geciciTemizle() async {
    try {
      final tmp = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}terazi-acik');
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } catch (_) {}
  }
}

// ---------------------------------------------------------------- Yedek dosyası

/// Yedek biçimi: "TRZY1" + tuz (16) + AES-GCM(nonce + şifreli JSON + mac).
/// Anahtar: PBKDF2-HMAC-SHA256(parola, tuz, 100.000 tur).
class Yedek {
  Yedek._();

  static const _imza = 'TRZY1';
  static const turSayisi = 100000;

  static Future<SecretKey> _parolaAnahtari(String parola, List<int> tuz) => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: turSayisi,
        bits: 256,
      ).deriveKeyFromPassword(password: parola, nonce: tuz);

  /// [veri]: uygulama verisi (terazi.json), [dosyalar]: dosya kimliği → şifresiz bayt.
  static Future<Uint8List> paketle(Map<String, dynamic> veri, Map<String, List<int>> dosyalar, String parola) async {
    final govde = utf8.encode(jsonEncode({
      'surum': 1,
      'tarih': DateTime.now().toIso8601String(),
      'veri': veri,
      'dosyalar': dosyalar.map((k, v) => MapEntry(k, base64Encode(v))),
    }));
    final r = Random.secure();
    final tuz = List<int>.generate(16, (_) => r.nextInt(256));
    final sifreli = await sifrele(govde, await _parolaAnahtari(parola, tuz));
    return Uint8List.fromList([...ascii.encode(_imza), ...tuz, ...sifreli]);
  }

  /// Yedeği açar. Parola yanlışsa ya da dosya Terazi yedeği değilse [YedekHatasi] fırlatır.
  static Future<({Map<String, dynamic> veri, Map<String, Uint8List> dosyalar})> ac(List<int> b, String parola) async {
    if (b.length < 5 + 16 + 28 || ascii.decode(b.sublist(0, 5), allowInvalid: true) != _imza) {
      throw const YedekHatasi('bicim');
    }
    final tuz = b.sublist(5, 21);
    Uint8List govde;
    try {
      govde = await coz(b.sublist(21), await _parolaAnahtari(parola, tuz));
    } on SecretBoxAuthenticationError {
      throw const YedekHatasi('parola');
    }
    final j = jsonDecode(utf8.decode(govde)) as Map<String, dynamic>;
    final dosyalar = ((j['dosyalar'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, Uint8List.fromList(base64Decode(v as String))));
    return (veri: Map<String, dynamic>.from(j['veri'] as Map), dosyalar: dosyalar);
  }
}

class YedekHatasi implements Exception {
  const YedekHatasi(this.neden);
  final String neden; // 'bicim' ya da 'parola'
  @override
  String toString() => 'YedekHatasi($neden)';
}

@visibleForTesting
Future<Uint8List> testSifrele(List<int> v, List<int> k) => sifrele(v, SecretKey(k));
@visibleForTesting
Future<Uint8List> testCoz(List<int> v, List<int> k) => coz(v, SecretKey(k));
