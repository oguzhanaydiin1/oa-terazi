import 'package:flutter_test/flutter_test.dart';
import 'package:terazi/models.dart';
import 'package:terazi/store.dart';

void main() {
  test('para biçimi', () {
    expect(para(64250), '₺642,50');
    expect(para(824000, kurussuz: true), '₺8.240');
    expect(para(3200000, isaret: true, kurussuz: true), '+₺32.000');
    expect(para(-2376000, kurussuz: true), '−₺23.760');
    expect(para(123456789), '₺1.234.567,89');
    expect(para(5), '₺0,05');
  });

  test('tutar okuma', () {
    expect(paraOku('642,50'), 64250);
    expect(paraOku('642.5'), 64250);
    expect(paraOku('1.250'), 125000);
    expect(paraOku('1.250,75'), 125075);
    expect(paraOku('₺ 4250'), 425000);
    expect(paraOku(''), null);
    expect(paraOku('abc'), null);
  });

  test('ayın günü eki', () {
    expect(ayinGunu(14), "ayın 14'ünde");
    expect(ayinGunu(6), "ayın 6'sında");
    expect(ayinGunu(20), "ayın 20'sinde");
    expect(ayinGunu(1), "ayın 1'inde");
    expect(ayinGunu(30), "ayın 30'unda");
  });

  Duzenli kredi() => Duzenli(
        id: 'k',
        ad: 'Kredi taksiti',
        tutar: 425000,
        kategori: 'kredi',
        gun: 14,
        baslangic: DateTime(2026, 4), // 1. taksit Nisan 2026
        takipten: DateTime(2026, 11, 11),
        ayAdedi: 24,
      );

  test('düzenli ödeme ayları ve sırası', () {
    final d = kredi();
    expect(d.ayda(DateTime(2026, 3)), isNull);
    final t = d.ayda(DateTime(2026, 11))!;
    expect(t.no, 8);
    expect(t.sira, '8. taksit / 24');
    expect(t.tarih, DateTime(2026, 11, 14));
    expect(d.ayda(DateTime(2028, 3))!.no, 24);
    expect(d.ayda(DateTime(2028, 4)), isNull);
    expect(d.bitis, DateTime(2028, 3));
  });

  test('kısa ayda ayın son günü', () {
    final d = Duzenli(
      id: 'x',
      ad: 'Kira',
      tutar: 800000,
      kategori: 'kira',
      gun: 31,
      baslangic: DateTime(2026, 1),
      takipten: DateTime(2026, 1, 1),
    );
    expect(d.ayda(DateTime(2027, 2))!.tarih, DateTime(2027, 2, 28));
    expect(d.ayda(DateTime(2028, 2))!.tarih, DateTime(2028, 2, 29));
    expect(d.ayda(DateTime(2030, 7))!.sira, 'Süresiz');
  });

  test('hal: önceden, yaklaşan, bugün, gecikti', () {
    final d = kredi();
    final bugun = DateTime(2026, 11, 11);
    expect(d.ayda(DateTime(2026, 10))!.hal(bugun), TekrarHali.onceden);
    expect(d.ayda(DateTime(2026, 11))!.hal(bugun), TekrarHali.yaklasan);
    expect(d.ayda(DateTime(2026, 11))!.hal(DateTime(2026, 11, 14)), TekrarHali.bugun);
    expect(d.ayda(DateTime(2026, 11))!.hal(DateTime(2026, 11, 20)), TekrarHali.gecikti);
  });

  test('ödendi, geri al ve sorulacaklar', () {
    final s = Store.bellekte();
    final d = kredi();
    s.duzenliKaydet(d);
    final gun = DateTime(2026, 11, 14);
    expect(s.sorulacaklar(DateTime(2026, 11, 13)), isEmpty);
    final sor = s.sorulacaklar(gun);
    expect(sor.length, 1);
    s.odendi(sor.first, 430000, simdi: gun);
    expect(s.kayitlar.single.tutar, 430000);
    expect(s.kayitlar.single.duzenliId, 'k');
    expect(s.sorulacaklar(gun), isEmpty);
    expect(d.ayda(DateTime(2026, 11))!.tutar(s.kayitlar), 430000);
    s.geriAl(d.ayda(DateTime(2026, 11))!);
    expect(s.kayitlar, isEmpty);
    expect(s.sorulacaklar(gun).length, 1);
  });

  test('yarın hatırlat ertesi güne kadar sormaz', () {
    final s = Store.bellekte();
    final d = kredi();
    s.duzenliKaydet(d);
    final gun = DateTime(2026, 11, 14);
    s.ertele(s.sorulacaklar(gun).first, simdi: gun);
    expect(s.sorulacaklar(gun), isEmpty);
    expect(s.sorulacaklar(DateTime(2026, 11, 15)).length, 1);
  });

  test('kaydı silmek ödemeyi yeniden açar', () {
    final s = Store.bellekte();
    final d = kredi();
    s.duzenliKaydet(d);
    final gun = DateTime(2026, 11, 14);
    final id = s.odendi(s.sorulacaklar(gun).first, 425000, simdi: gun);
    s.kayitSil(id);
    expect(d.durumlar, isEmpty);
    expect(s.sorulacaklar(gun).length, 1);
  });

  test('ay özeti ve günlük harcanabilir', () {
    final bugun = DateTime(2026, 11, 11);
    final kayitlar = [
      Kayit(id: '1', tur: Tur.gelir, tutar: 3200000, kategori: 'maas', tarih: DateTime(2026, 11, 1)),
      Kayit(id: '2', tur: Tur.gider, tutar: 2376000, kategori: 'kira', tarih: DateTime(2026, 11, 5)),
      Kayit(id: '3', tur: Tur.gider, tutar: 99900, kategori: 'market', tarih: DateTime(2026, 10, 30)),
    ];
    final o = ayOzeti(DateTime(2026, 11), bugun, kayitlar, [kredi()]);
    expect(o.gelir, 3200000);
    expect(o.gider, 2376000);
    expect(o.kalan, 824000);
    expect(o.yaklasan, 425000);
    expect(o.kalanGun, 20);
    expect(o.gunluk, (824000 - 425000) ~/ 20);
  });

  test('önceki ayla karşılaştırma', () {
    final k = [
      Kayit(id: '1', tur: Tur.gider, tutar: 10000, kategori: 'market', tarih: DateTime(2026, 10, 3)),
      Kayit(id: '2', tur: Tur.gider, tutar: 9200, kategori: 'market', tarih: DateTime(2026, 11, 3)),
    ];
    expect(oncekiAyla(DateTime(2026, 11), k), "Ekim'den %8 az");
    expect(oncekiAyla(DateTime(2026, 10), k), isNull);
  });

  test('JSON gidiş dönüş', () {
    final d = kredi()..durumlar['2026-11'] = AyDurumu(Durum.odendi, kayitId: 'a');
    final j = Duzenli.fromJson(d.toJson());
    expect(j.ayAdedi, 24);
    expect(j.baslangic, DateTime(2026, 4));
    expect(j.durumlar['2026-11']!.kayitId, 'a');
    final k = Kayit(id: '1', tur: Tur.gelir, tutar: 5, kategori: 'maas', tarih: DateTime(2026, 1, 2), aciklama: 'x');
    final k2 = Kayit.fromJson(k.toJson());
    expect(k2.tarih, DateTime(2026, 1, 2));
    expect(k2.tur, Tur.gelir);
  });
}
