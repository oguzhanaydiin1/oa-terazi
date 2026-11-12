// Terazi veri modeli. Flutter'a bağlı değil; test/model_test.dart doğrudan bunu dener.
// Tutarlar her yerde kuruş cinsinden tam sayıdır (₺642,50 = 64250).

import 'i18n.dart';

enum Tur { gelir, gider }

/// Tek bir gelir ya da gider kaydı.
class Kayit {
  Kayit({
    required this.id,
    required this.tur,
    required this.tutar,
    required this.kategori,
    required this.tarih,
    this.aciklama = '',
    this.duzenliId,
  });

  final String id;
  Tur tur;
  int tutar;
  String kategori;
  DateTime tarih; // yalnızca gün (saat 00:00)
  String aciklama;
  String? duzenliId; // bir düzenli ödemenin "ödendi" kaydıysa

  /// Gelir +, gider −.
  int get isaretli => tur == Tur.gelir ? tutar : -tutar;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tur': tur.name,
        'tutar': tutar,
        'kategori': kategori,
        'tarih': gunAnahtar(tarih),
        if (aciklama.isNotEmpty) 'aciklama': aciklama,
        if (duzenliId != null) 'duzenliId': duzenliId,
      };

  factory Kayit.fromJson(Map<String, dynamic> j) => Kayit(
        id: j['id'] as String,
        tur: j['tur'] == 'gelir' ? Tur.gelir : Tur.gider,
        tutar: (j['tutar'] as num).toInt(),
        kategori: j['kategori'] as String? ?? 'diger',
        tarih: DateTime.parse(j['tarih'] as String),
        aciklama: j['aciklama'] as String? ?? '',
        duzenliId: j['duzenliId'] as String?,
      );
}

/// Bir düzenli ödemenin bir aydaki durumu.
enum Durum { odendi, atlandi }

class AyDurumu {
  AyDurumu(this.durum, {this.kayitId});
  final Durum durum;
  final String? kayitId;

  Map<String, dynamic> toJson() => {'durum': durum.name, if (kayitId != null) 'kayitId': kayitId};
  factory AyDurumu.fromJson(Map<String, dynamic> j) =>
      AyDurumu(j['durum'] == 'atlandi' ? Durum.atlandi : Durum.odendi, kayitId: j['kayitId'] as String?);
}

/// Kredi taksiti, kira, abonelik gibi her ay tekrar eden ödeme.
class Duzenli {
  Duzenli({
    required this.id,
    required this.ad,
    required this.tutar,
    required this.kategori,
    required this.gun,
    required this.baslangic,
    required this.takipten,
    this.ayAdedi,
    this.hatirlat = 1,
    this.degisken = false,
    Map<String, AyDurumu>? durumlar,
    Map<String, DateTime>? ertelenen,
  })  : durumlar = durumlar ?? {},
        ertelenen = ertelenen ?? {};

  final String id;
  String ad;
  int tutar; // değişkense tahmini tutar
  String kategori;
  int gun; // ayın kaçı (1–31; kısa aylarda ayın son günü)
  DateTime baslangic; // 1. ödemenin ayı (gün = 1)
  int? ayAdedi; // null: süresiz
  DateTime takipten; // eklendiği gün; bundan önceki ödemeler "zaten ödenmiş" sayılır
  int hatirlat; // kaç gün önce hatırlatılsın (0 = aynı gün)
  bool degisken; // tutar her ay değişebilir (fatura gibi)
  final Map<String, AyDurumu> durumlar; // "2026-11" → durum
  final Map<String, DateTime> ertelenen; // "2026-11" → "yarın hatırlat" günü

  bool get suresiz => ayAdedi == null;

  /// Bu ödemenin [ay] ayındaki tekrarı (yoksa null).
  Tekrar? ayda(DateTime ay) {
    final i = ayFarki(baslangic, ay);
    if (i < 0) return null;
    if (ayAdedi != null && i >= ayAdedi!) return null;
    final son = ayinGunSayisi(ay.year, ay.month);
    return Tekrar(this, i + 1, DateTime(ay.year, ay.month, gun > son ? son : gun));
  }

  /// Son ödemenin ayı (süresizse null).
  DateTime? get bitis => ayAdedi == null ? null : ayEkle(baslangic, ayAdedi! - 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'ad': ad,
        'tutar': tutar,
        'kategori': kategori,
        'gun': gun,
        'baslangic': ayAnahtar(baslangic),
        'takipten': gunAnahtar(takipten),
        if (ayAdedi != null) 'ayAdedi': ayAdedi,
        'hatirlat': hatirlat,
        if (degisken) 'degisken': true,
        if (durumlar.isNotEmpty) 'durumlar': durumlar.map((k, v) => MapEntry(k, v.toJson())),
        if (ertelenen.isNotEmpty) 'ertelenen': ertelenen.map((k, v) => MapEntry(k, gunAnahtar(v))),
      };

  factory Duzenli.fromJson(Map<String, dynamic> j) => Duzenli(
        id: j['id'] as String,
        ad: j['ad'] as String,
        tutar: (j['tutar'] as num).toInt(),
        kategori: j['kategori'] as String? ?? 'diger',
        gun: (j['gun'] as num).toInt(),
        baslangic: DateTime.parse('${j['baslangic']}-01'),
        takipten: DateTime.parse(j['takipten'] as String),
        ayAdedi: (j['ayAdedi'] as num?)?.toInt(),
        hatirlat: (j['hatirlat'] as num?)?.toInt() ?? 1,
        degisken: j['degisken'] == true,
        durumlar: ((j['durumlar'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, AyDurumu.fromJson(Map<String, dynamic>.from(v as Map)))),
        ertelenen: ((j['ertelenen'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, DateTime.parse(v as String))),
      );
}

enum TekrarHali { odendi, atlandi, onceden, gecikti, bugun, yaklasan }

/// Bir düzenli ödemenin belli bir aydaki tek ödemesi.
class Tekrar {
  Tekrar(this.duzenli, this.no, this.tarih);
  final Duzenli duzenli;
  final int no; // kaçıncı ödeme (1'den)
  final DateTime tarih;

  String get donem => ayAnahtar(tarih);
  AyDurumu? get durum => duzenli.durumlar[donem];

  /// "8. taksit / 24" ya da "Süresiz".
  String get sira {
    if (duzenli.suresiz) return L('Süresiz');
    final kredi = duzenli.kategori == 'kredi';
    return Lx('$no. ${kredi ? 'taksit' : 'ödeme'} / ${duzenli.ayAdedi}',
        '${kredi ? 'Instalment' : 'Payment'} $no of ${duzenli.ayAdedi}');
  }

  TekrarHali hal(DateTime bugun) {
    final d = durum;
    if (d != null) return d.durum == Durum.odendi ? TekrarHali.odendi : TekrarHali.atlandi;
    final g = gunBasi(bugun);
    if (tarih.isBefore(gunBasi(duzenli.takipten))) return TekrarHali.onceden;
    if (tarih.isBefore(g)) return TekrarHali.gecikti;
    if (tarih == g) return TekrarHali.bugun;
    return TekrarHali.yaklasan;
  }

  /// Ödenmesi beklenen (henüz kapanmamış) mı?
  bool acik(DateTime bugun) {
    final h = hal(bugun);
    return h == TekrarHali.gecikti || h == TekrarHali.bugun || h == TekrarHali.yaklasan;
  }

  /// Kayıtlı ödeme tutarı (ödendiyse gerçek tutar), yoksa plan.
  int tutar(List<Kayit> kayitlar) {
    final id = durum?.kayitId;
    if (id != null) {
      for (final k in kayitlar) {
        if (k.id == id) return k.tutar;
      }
    }
    return duzenli.tutar;
  }
}

/// Bir ayın özeti: Özet ekranındaki sayılar.
class AyOzeti {
  AyOzeti({
    required this.gelir,
    required this.gider,
    required this.yaklasan,
    required this.kalanGun,
    required this.acikTekrarlar,
  });
  final int gelir;
  final int gider;
  final int yaklasan; // bu ay daha ödenecek düzenli ödemeler
  final int kalanGun; // bugün dahil
  final List<Tekrar> acikTekrarlar;

  int get kalan => gelir - gider;

  /// Yaklaşan ödemeler düşüldükten sonra günde harcanabilecek (0'dan az olmaz).
  int get gunluk {
    final k = kalan - yaklasan;
    if (k <= 0 || kalanGun <= 0) return 0;
    return k ~/ kalanGun;
  }
}

AyOzeti ayOzeti(DateTime ay, DateTime bugun, List<Kayit> kayitlar, List<Duzenli> duzenliler) {
  var gelir = 0, gider = 0;
  for (final k in kayitlar) {
    if (!ayniAy(k.tarih, ay)) continue;
    if (k.tur == Tur.gelir) {
      gelir += k.tutar;
    } else {
      gider += k.tutar;
    }
  }
  final acik = <Tekrar>[];
  var yaklasan = 0;
  for (final d in duzenliler) {
    final t = d.ayda(ay);
    if (t != null && t.acik(bugun)) {
      acik.add(t);
      yaklasan += d.tutar;
    }
  }
  acik.sort((a, b) => a.tarih.compareTo(b.tarih));
  final son = ayinGunSayisi(ay.year, ay.month);
  int kalanGun;
  if (ayniAy(ay, bugun)) {
    kalanGun = son - bugun.day + 1;
  } else if (ay.isAfter(bugun)) {
    kalanGun = son;
  } else {
    kalanGun = 0;
  }
  return AyOzeti(gelir: gelir, gider: gider, yaklasan: yaklasan, kalanGun: kalanGun, acikTekrarlar: acik);
}

/// Kategori → o ayki gider toplamı.
Map<String, int> kategoriGideri(DateTime ay, List<Kayit> kayitlar) {
  final m = <String, int>{};
  for (final k in kayitlar) {
    if (k.tur == Tur.gider && ayniAy(k.tarih, ay)) m[k.kategori] = (m[k.kategori] ?? 0) + k.tutar;
  }
  return m;
}

int ayGideri(DateTime ay, List<Kayit> kayitlar) =>
    kayitlar.where((k) => k.tur == Tur.gider && ayniAy(k.tarih, ay)).fold(0, (a, k) => a + k.tutar);

// ---- Tarih yardımcıları ----

DateTime gunBasi(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime ayBasi(DateTime d) => DateTime(d.year, d.month);
DateTime ayEkle(DateTime d, int n) => DateTime(d.year, d.month + n);
int ayFarki(DateTime a, DateTime b) => (b.year - a.year) * 12 + b.month - a.month;
bool ayniAy(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;
bool ayniGun(DateTime a, DateTime b) => ayniAy(a, b) && a.day == b.day;
int ayinGunSayisi(int y, int m) => DateTime(y, m + 1, 0).day;
String _iki(int n) => n.toString().padLeft(2, '0');
String ayAnahtar(DateTime d) => '${d.year}-${_iki(d.month)}';
String gunAnahtar(DateTime d) => '${d.year}-${_iki(d.month)}-${_iki(d.day)}';

const _aylarTr = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _aylarEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _ayKisaTr = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
const _ayKisaEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _gunKisaTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _gunKisaEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
List<String> get aylar => Dil.en ? _aylarEn : _aylarTr;
List<String> get ayKisa => Dil.en ? _ayKisaEn : _ayKisaTr;
List<String> get gunKisa => Dil.en ? _gunKisaEn : _gunKisaTr;

/// "ayın 14'ünde", "ayın 6'sında".
String ayinGunu(int n) {
  const birler = ['', 'inde', 'sinde', 'ünde', 'ünde', 'inde', 'sında', 'sinde', 'inde', 'unda'];
  const onlar = ['', 'unda', 'sinde', 'unda'];
  final o = n ~/ 10;
  final ek = n % 10 != 0 ? birler[n % 10] : onlar[o > 3 ? 3 : o];
  return "ayın $n'$ek";
}

/// İngilizce sıra eki: 1st, 2nd, 14th, 22nd.
String ingSira(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return '$n${const ['th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th'][n % 10]}';
}

/// "Ekim'den": ayın ayrılma hâli.
const ayDen = ["Ocak'tan", "Şubat'tan", "Mart'tan", "Nisan'dan", "Mayıs'tan", "Haziran'dan", "Temmuz'dan",
  "Ağustos'tan", "Eylül'den", "Ekim'den", "Kasım'dan", "Aralık'tan"];

/// Bu ayın giderini önceki ayla karşılaştırır: "Ekim'den %8 az". Önceki ay boşsa null.
String? oncekiAyla(DateTime ay, List<Kayit> kayitlar) {
  final once = ayEkle(ay, -1);
  final a = ayGideri(once, kayitlar);
  if (a == 0) return null;
  final b = ayGideri(ay, kayitlar);
  final f = ((b - a) * 100 / a).round();
  if (Dil.en) {
    final m = _aylarEn[once.month - 1];
    if (f == 0) return 'Same as $m';
    return '${f.abs()}% ${f < 0 ? 'less' : 'more'} than $m';
  }
  if (f == 0) return "${ayDen[once.month - 1]} farksız";
  return "${ayDen[once.month - 1]} %${f.abs()} ${f < 0 ? 'az' : 'fazla'}";
}

String ayAdi(DateTime d) => '${aylar[d.month - 1]} ${d.year}';
String tarihYazi(DateTime d) => '${d.day} ${aylar[d.month - 1]}';

/// "Bugün", "Dün", "11 Kasım".
String gunYazi(DateTime d, DateTime bugun) {
  final f = gunBasi(bugun).difference(gunBasi(d)).inDays;
  if (f == 0) return L('Bugün');
  if (f == 1) return L('Dün');
  if (f == -1) return L('Yarın');
  return d.year == bugun.year ? tarihYazi(d) : '${tarihYazi(d)} ${d.year}';
}

/// "3 gün sonra", "Bugün", "2 gün geçti".
String kalanYazi(DateTime d, DateTime bugun) {
  final f = gunBasi(d).difference(gunBasi(bugun)).inDays;
  if (f == 0) return L('Bugün');
  if (f == 1) return L('Yarın');
  if (f > 1) return Lx('$f gün sonra', 'in $f days');
  if (f == -1) return Lx('Dün geçti', 'Was yesterday');
  return Lx('${-f} gün geçti', '${-f} days ago');
}

// ---- Para ----

/// Para birimi: yalnızca simge ve yazılış; tutarlar çevrilmez.
class ParaBirimi {
  const ParaBirimi(this.kod, this.sembol, this.ad, this.adEn, {this.sonda = false});
  final String kod;
  final String sembol;
  final String ad;
  final String adEn;
  final bool sonda; // "8.240 ₽" gibi simge sonda mı
}

const paraBirimleri = <ParaBirimi>[
  ParaBirimi('TRY', '₺', 'Türk lirası', 'Turkish lira'),
  ParaBirimi('USD', r'$', 'ABD doları', 'US dollar'),
  ParaBirimi('EUR', '€', 'Euro', 'Euro'),
  ParaBirimi('GBP', '£', 'İngiliz sterlini', 'British pound'),
  ParaBirimi('RUB', '₽', 'Rus rublesi', 'Russian rouble', sonda: true),
  ParaBirimi('AZN', '₼', 'Azerbaycan manatı', 'Azerbaijani manat', sonda: true),
  ParaBirimi('CHF', 'CHF', 'İsviçre frangı', 'Swiss franc', sonda: true),
];

ParaBirimi paraBirimi(String? kod) => paraBirimleri.firstWhere((p) => p.kod == kod, orElse: () => paraBirimleri.first);

/// Sayı biçimi ve para birimi. TeraziApp ayarlar; varsayılan Türkçe ve TL.
class Bicim {
  Bicim._();
  static ParaBirimi birim = paraBirimleri.first;
  static String get binlik => Dil.en ? ',' : '.';
  static String get ondalik => Dil.en ? '.' : ',';
}

/// 8240 → "8.240" (Türkçe) / "8,240" (İngilizce).
String binlikli(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(Bicim.binlik);
    b.write(s[i]);
  }
  return b.toString();
}

/// Sayının yanına para birimini koyar: "₺8.240", "8.240 ₽".
String sembolle(String sayi) => Bicim.birim.sonda ? '$sayi ${Bicim.birim.sembol}' : '${Bicim.birim.sembol}$sayi';

/// 64250 → "₺642,50". [kurussuz]: tam liraysa kuruşu yazma ("₺8.240").
String para(int kurus, {bool isaret = false, bool kurussuz = false}) {
  final eksi = kurus < 0;
  final m = kurus.abs();
  final k = m % 100;
  var sayi = binlikli(m ~/ 100);
  if (!(kurussuz && k == 0)) sayi += '${Bicim.ondalik}${_iki(k)}';
  final out = sembolle(sayi);
  if (eksi) return '−$out';
  if (isaret && kurus > 0) return '+$out';
  return out;
}

/// Kutuya yazmak için: 425050 → "4250,50" (Türkçe) / "4250.50"; tam sayıysa "4250".
String paraYaz(int kurus) {
  final l = kurus ~/ 100, c = kurus % 100;
  return c == 0 ? '$l' : '$l${Bicim.ondalik}${_iki(c)}';
}

/// "642,50" / "642.50" / "1.250" / "1,250.75" → kuruş. Geçersizse null.
/// İki ayırıcı da varsa sondaki ondalıktır; tek ayırıcı arkasından tam üç basamaklı gruplar geliyorsa binliktir.
int? paraOku(String s) {
  var t = s.trim().replaceAll(RegExp(r'[^0-9.,]'), '');
  if (t.isEmpty) return null;
  final sonNokta = t.lastIndexOf('.'), sonVirgul = t.lastIndexOf(',');
  if (sonNokta >= 0 && sonVirgul >= 0) {
    final ond = sonNokta > sonVirgul ? '.' : ',';
    final bin = ond == '.' ? ',' : '.';
    t = t.replaceAll(bin, '').replaceAll(ond, '.');
  } else if (sonNokta >= 0 || sonVirgul >= 0) {
    final ay = sonNokta >= 0 ? '.' : ',';
    final binlikMi = RegExp('^\\d{1,3}(\\${ay}\\d{3})+\$').hasMatch(t);
    t = binlikMi ? t.replaceAll(ay, '') : t.replaceAll(ay, '.');
  }
  if ('.'.allMatches(t).length > 1) return null;
  final v = double.tryParse(t);
  if (v == null || v < 0) return null;
  return (v * 100).round();
}

String yeniId() {
  _sayac = (_sayac + 1) % 1296;
  return DateTime.now().microsecondsSinceEpoch.toRadixString(36) + _sayac.toRadixString(36).padLeft(2, '0');
}

int _sayac = 0;
