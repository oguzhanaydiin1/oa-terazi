import 'package:flutter_test/flutter_test.dart';
import 'package:terazi/esitle.dart';

EsitlemeVerisi v(Map<String, Map<String, dynamic>> m) => m;

void main() {
  test('ilk eşitleme: iki taraf birleşir, hiçbir şey silinmez', () {
    final yerel = v({
      'kayitlar': {'a': {'t': 1}, 'b': {'t': 2}},
    });
    final uzak = v({
      'kayitlar': {'b': {'t': 2}, 'c': {'t': 3}},
    });
    final m = birlestir(null, yerel, uzak);
    expect(m['kayitlar']!.keys.toSet(), {'a', 'b', 'c'});
  });

  test('sunucuda silinen kayıt bu cihazdan da silinir', () {
    final taban = v({'kayitlar': {'a': {'t': 1}, 'b': {'t': 2}}});
    final yerel = v({'kayitlar': {'a': {'t': 1}, 'b': {'t': 2}}});
    final uzak = v({'kayitlar': {'a': {'t': 1}}});
    expect(birlestir(taban, yerel, uzak)['kayitlar']!.keys, ['a']);
  });

  test('bu cihazda silinen kayıt sunucudan geri gelmez', () {
    final taban = v({'kayitlar': {'a': {'t': 1}, 'b': {'t': 2}}});
    final yerel = v({'kayitlar': {'a': {'t': 1}}});
    final uzak = v({'kayitlar': {'a': {'t': 1}, 'b': {'t': 2}}});
    expect(birlestir(taban, yerel, uzak)['kayitlar']!.keys, ['a']);
  });

  test('yalnız bir tarafta değişen alınır; çakışmada bu cihaz kazanır; değişen silineni yener', () {
    final taban = v({'kayitlar': {'a': {'t': 1}, 'b': {'t': 2}, 'c': {'t': 3}, 'd': {'t': 4}}});
    final yerel = v({'kayitlar': {'a': {'t': 1}, 'b': {'t': 20}, 'c': {'t': 30}}});
    final uzak = v({'kayitlar': {'a': {'t': 10}, 'b': {'t': 2}, 'c': {'t': 31}, 'd': {'t': 40}}});
    final m = birlestir(taban, yerel, uzak)['kayitlar']!;
    expect(m['a'], {'t': 10}); // yalnız sunucuda değişti
    expect(m['b'], {'t': 20}); // yalnız bu cihazda değişti
    expect(m['c'], {'t': 30}); // ikisinde de: bu cihaz
    expect(m['d'], {'t': 40}); // bu cihazda silindi, sunucuda değişti: değişen kalır
  });

  test('anahtar sırası farkı değişiklik sayılmaz', () {
    expect(kanonik({'a': 1, 'b': [1, {'y': 2, 'x': 1}]}), kanonik({'b': [1, {'x': 1, 'y': 2}], 'a': 1}));
  });

  test('kutu şifrelenir, doğru anahtarla açılır, yanlışla açılmaz', () async {
    final tuz = List<int>.generate(16, (i) => i);
    final k1 = await Esitleme.anahtarTuret('dogru-parola', tuz, yineleme: 1000);
    final k2 = await Esitleme.anahtarTuret('yanlis-parola', tuz, yineleme: 1000);
    final veri = v({
      'kayitlar': {'a': {'aciklama': 'Market', 'tutar': 12550}},
      'ayar': {'paraBirimi': 'TRY'},
    });
    final kutu = await Esitleme.i.kutula(veri, anahtar: k1, tuz: 'tuz');
    expect(kutu.toString().contains('Market'), isFalse);
    expect(await Esitleme.i.kutuAc(kutu, k1), veri);
    expect(await Esitleme.i.kutuAc(kutu, k2), isNull);
  });
}
