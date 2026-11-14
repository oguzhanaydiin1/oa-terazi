import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'i18n.dart';
import 'shared_session.dart';

const _surum = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

/// OA Labs hesabı (oalabs.dev ile aynı hesap). Giriş isteğe bağlıdır.
///
/// Giriş şifresiz: e-postaya 6 haneli kod gider, doğrulanınca sunucu `oa_s` oturum çerezini
/// verir. Çerez cihazın güvenli deposunda durur ve isteklerde `Cookie` başlığıyla gönderilir.
/// Windows'ta başka bir OA uygulamasında (Center, Pusula) açık oturum varsa ondan tek
/// kullanımlık kodla Terazi'nin kendi oturumu açılır.
class Hesap extends ChangeNotifier {
  Hesap._();
  static final i = Hesap._();

  static const api = 'https://api.oalabs.dev';
  static const _cerez = 'oa_s';
  static const _anahtar = 'oa_session';

  final _depo = const FlutterSecureStorage();
  String? _token;
  String? ad;
  String? eposta;
  bool yukleniyor = true;

  bool get girisli => _token != null && eposta != null;

  String get basHarf => (ad ?? '').trim().isEmpty ? '?' : ad!.trim().substring(0, 1).toUpperCase();

  String get _userAgent {
    final os = Platform.isAndroid
        ? 'Linux; Android'
        : Platform.isWindows
            ? 'Windows NT 10.0'
            : Platform.operatingSystem;
    return 'Terazi/$_surum ($os)';
  }

  Map<String, String> _basliklar({bool json = false, String? ile}) {
    final t = ile ?? _token;
    return {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (t != null) 'Cookie': '$_cerez=$t',
    };
  }

  Future<void> yukle() async {
    try {
      _token = await _depo.read(key: _anahtar);
    } catch (_) {
      _token = null;
    }
    // Hesabı daha önce açılmış ve sonra çıkış yapılmışsa ortak oturumdan kendiliğinden girme.
    if (_token == null && await _depo.read(key: 'oa_cikis') != '1') await _ortakOturumuAl();
    if (_token != null) await yenile(bildir: false);
    yukleniyor = false;
    notifyListeners();
  }

  Future<void> _ortakOturumuAl() async {
    try {
      final ortak = await SharedSession.read();
      if (ortak == null) return;
      final h = await _istek('/v1/auth/handoff', {'app': 'terazi'}, ortak.token);
      final kod = h['code'];
      if (h['ok'] != true || kod is! String) return;
      await _istek('/v1/auth/redeem', {'code': kod});
    } catch (_) {}
  }

  /// Oturumla sunucu isteği. Gövde verilirse POST.
  Future<Map<String, dynamic>> istek(String yol, [Map<String, dynamic>? govde]) => _istek(yol, govde);

  Future<Map<String, dynamic>> _istek(String yol, [Map<String, dynamic>? govde, String? ile]) async {
    try {
      final uri = Uri.parse('$api$yol');
      final res = govde == null
          ? await http.get(uri, headers: _basliklar(ile: ile)).timeout(const Duration(seconds: 20))
          : await http
              .post(uri,
                  headers: _basliklar(json: true, ile: ile),
                  body: jsonEncode({'lang': Dil.en ? 'en' : 'tr', ...govde}))
              .timeout(const Duration(seconds: 20));
      if (ile == null) await _cereziOku(res.headers['set-cookie']);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map<String, dynamic>) return data;
      return {'ok': false, 'error': 'sunucu'};
    } catch (_) {
      return {'ok': false, 'error': 'ag'};
    }
  }

  Future<void> _cereziOku(String? baslik) async {
    if (baslik == null) return;
    final m = RegExp('$_cerez=([0-9a-f]{64})?').firstMatch(baslik);
    if (m == null) return;
    _token = m.group(1); // boş değer: sunucu oturumu kapattı
    await _sakla();
  }

  Future<void> _sakla() async {
    try {
      if (_token == null) {
        await _depo.delete(key: _anahtar);
      } else {
        await _depo.write(key: _anahtar, value: _token);
        await _depo.delete(key: 'oa_cikis');
      }
    } catch (_) {}
  }

  /// 1. adım: e-postaya kod gönder. [ad] verilirse yeni üyelik açılır. Hata kodu döner, başarılıysa null.
  Future<String?> kodGonder(String eposta, {String? ad, bool duyuru = false}) async {
    final r = await _istek('/v1/auth/start', {
      'mode': ad == null ? 'login' : 'register',
      'email': eposta.trim(),
      if (ad != null) 'name': ad.trim(),
      if (ad != null) 'consent': true,
      if (ad != null) 'announce': duyuru,
      'website': '', // sitedeki bot tuzağı alanı; insanlar boş bırakır
    });
    return r['ok'] == true ? null : (r['error']?.toString() ?? 'sunucu');
  }

  /// 2. adım: kodu doğrula. Hata kodu döner, başarılıysa null.
  Future<String?> dogrula(String eposta, String kod) async {
    final r = await _istek('/v1/auth/verify', {'email': eposta.trim(), 'code': kod.trim()});
    if (r['ok'] != true) return r['error']?.toString() ?? 'sunucu';
    await yenile();
    if (_token != null && SharedSession.supported && await SharedSession.read() == null) {
      await SharedSession.write(_token!, 'terazi');
    }
    return null;
  }

  Future<void> yenile({bool bildir = true}) async {
    if (_token == null) {
      ad = null;
      eposta = null;
    } else {
      final r = await _istek('/v1/me');
      if (r['ok'] == true && r['user'] is Map) {
        final u = r['user'] as Map;
        ad = (u['name'] ?? '').toString();
        eposta = (u['email'] ?? '').toString();
      } else if (r['error'] == 'giris') {
        // Oturum sunucuda kapanmış (süresi dolmuş ya da başka cihazdan kapatılmış).
        _token = null;
        ad = null;
        eposta = null;
        await _sakla();
      }
      // Ağ yoksa eldeki bilgiler kalır; eposta hiç yoksa hesap yüklenmemiş sayılır.
    }
    if (bildir) notifyListeners();
  }

  /// Oturum var ama ağ yüzünden kullanıcı bilgisi alınamadıysa da eşitleme denenebilir.
  bool get oturumVar => _token != null;

  Future<void> cikis() async {
    final eski = _token;
    if (_token != null) await _istek('/v1/auth/logout', {});
    await SharedSession.clearIf(eski);
    _token = null;
    ad = null;
    eposta = null;
    await _sakla();
    try {
      await _depo.write(key: 'oa_cikis', value: '1');
    } catch (_) {}
    notifyListeners();
  }
}

/// Sunucunun hata kodları için metinler (sitedekilerle aynı).
String hesapHatasi(String? kod) {
  switch (kod) {
    case 'eposta':
      return Lx('Bu e-posta adresi geçerli görünmüyor.', 'This email address doesn’t look valid.');
    case 'uye-yok':
      return Lx('Bu e-postayla bir üyelik bulamadık. Üye ol sekmesinden yeni hesap açabilirsin.',
          'We couldn’t find an account with this email. You can create one on the Sign up tab.');
    case 'uye-var':
      return Lx('Bu e-postayla zaten bir üyelik var. Giriş yap sekmesini kullan.',
          'There’s already an account with this email. Use the Sign in tab.');
    case 'ad':
      return Lx('Adını yaz (en az 2 harf).', 'Enter your name (at least 2 letters).');
    case 'onay':
      return Lx('Devam etmek için koşulları kabul etmen gerekiyor.', 'You need to accept the terms to continue.');
    case 'bekle':
      return Lx('Az önce bir kod gönderdik. Bir dakika sonra yeniden isteyebilirsin.',
          'We just sent a code. You can ask for a new one in a minute.');
    case 'cok':
      return Lx('Çok fazla deneme oldu, biraz sonra tekrar dene.', 'Too many attempts. Try again a bit later.');
    case 'kod':
      return Lx('Kod yanlış. E-postadaki 6 haneli kodu kontrol et.', 'Wrong code. Check the 6-digit code in the email.');
    case 'sure':
      return Lx('Kodun süresi doldu. Yeni bir kod iste.', 'The code has expired. Ask for a new one.');
    case 'deneme':
      return Lx('Çok fazla yanlış deneme oldu. Yeni bir kod iste.', 'Too many wrong attempts. Ask for a new code.');
    case 'kapali':
      return Lx('Üyelik şu an kapalı. Biraz sonra tekrar dene.', 'Sign-up is closed right now. Try again later.');
    case 'giris':
      return Lx('Oturumun kapanmış. Yeniden giriş yap.', 'You’ve been signed out. Sign in again.');
    case 'buyuk':
      return Lx('Eşitlenecek veri çok büyük.', 'There’s too much data to sync.');
    case 'ag':
      return Lx('Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.', 'Couldn’t reach the server. Check your connection.');
    default:
      return Lx('Bir sorun çıktı, biraz sonra tekrar dene.', 'Something went wrong. Try again a bit later.');
  }
}
