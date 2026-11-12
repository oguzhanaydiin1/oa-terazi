import 'package:flutter/material.dart';

import 'i18n.dart';
import 'models.dart';

class Kategori {
  const Kategori(this.id, this._ad, this.ikon, this.renk, this.tur);
  final String id;
  final String _ad;
  String get ad => L(_ad);
  final IconData ikon;
  final Color renk;
  final Tur tur;
}

const giderKategorileri = <Kategori>[
  Kategori('market', 'Market', Icons.shopping_basket_outlined, Color(0xFF5BC48C), Tur.gider),
  Kategori('yemek', 'Dışarıda yemek', Icons.restaurant_outlined, Color(0xFFF08A7E), Tur.gider),
  Kategori('kira', 'Kira', Icons.home_outlined, Color(0xFF6EA8FE), Tur.gider),
  Kategori('faturalar', 'Faturalar', Icons.bolt_outlined, Color(0xFFF2A541), Tur.gider),
  Kategori('kredi', 'Kredi', Icons.account_balance_outlined, Color(0xFFC79BF2), Tur.gider),
  Kategori('ulasim', 'Ulaşım', Icons.directions_bus_outlined, Color(0xFF4FC3D9), Tur.gider),
  Kategori('eglence', 'Eğlence', Icons.local_activity_outlined, Color(0xFFF27BB4), Tur.gider),
  Kategori('abonelik', 'Abonelik', Icons.subscriptions_outlined, Color(0xFF9FA8DA), Tur.gider),
  Kategori('saglik', 'Sağlık', Icons.favorite_border, Color(0xFFE57373), Tur.gider),
  Kategori('giyim', 'Giyim', Icons.checkroom_outlined, Color(0xFFBCAAA4), Tur.gider),
  Kategori('egitim', 'Eğitim', Icons.school_outlined, Color(0xFF81C784), Tur.gider),
  Kategori('diger', 'Diğer', Icons.more_horiz, Color(0xFF9EA2B3), Tur.gider),
];

const gelirKategorileri = <Kategori>[
  Kategori('maas', 'Maaş', Icons.work_outline, Color(0xFF5BC48C), Tur.gelir),
  Kategori('ek_gelir', 'Ek gelir', Icons.add_card_outlined, Color(0xFF4FC3D9), Tur.gelir),
  Kategori('kira_geliri', 'Kira geliri', Icons.home_work_outlined, Color(0xFF6EA8FE), Tur.gelir),
  Kategori('diger_gelir', 'Diğer', Icons.more_horiz, Color(0xFF9EA2B3), Tur.gelir),
];

List<Kategori> kategoriler(Tur t) => t == Tur.gelir ? gelirKategorileri : giderKategorileri;

Kategori kategori(String id) {
  for (final k in giderKategorileri) {
    if (k.id == id) return k;
  }
  for (final k in gelirKategorileri) {
    if (k.id == id) return k;
  }
  return giderKategorileri.last;
}

/// Renkli yuvarlak kategori simgesi.
class KategoriIkon extends StatelessWidget {
  const KategoriIkon(this.k, {super.key, this.size = 40});
  final Kategori k;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: k.renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(size * 0.32)),
        child: Icon(k.ikon, size: size * 0.5, color: k.renk),
      );
}
