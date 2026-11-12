import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'i18n.dart';
import 'kategoriler.dart';
import 'models.dart';
import 'store.dart';

/// Ödeme günü bildirimleri (Android). Windows'ta uygulama açılınca Özet'teki "Ödendi mi?" kartı sorar.
class Bildirim {
  Bildirim._();

  static final _p = FlutterLocalNotificationsPlugin();
  static bool _hazir = false;
  static Timer? _bekle;

  /// Bildirime ya da düğmesine dokunulunca: (düzenli ödeme id, dönem, eylem: 'odendi' / 'ertele' / null).
  static void Function(String duzenliId, String donem, String? eylem)? dokunulunca;

  /// Uygulama bir bildirime dokunularak açıldıysa o bildirim.
  static ({String id, String donem, String? eylem})? acilis;

  static bool get destekli => Platform.isAndroid;

  static Future<void> baslat() async {
    if (!destekli) return;
    try {
      tzdata.initializeTimeZones();
      const init = InitializationSettings(android: AndroidInitializationSettings('ic_bildirim'));
      await _p.initialize(init, onDidReceiveNotificationResponse: (r) {
        final y = _coz(r.payload);
        if (y != null) dokunulunca?.call(y.$1, y.$2, r.actionId);
      });
      final l = await _p.getNotificationAppLaunchDetails();
      if (l != null && l.didNotificationLaunchApp) {
        final y = _coz(l.notificationResponse?.payload);
        if (y != null) acilis = (id: y.$1, donem: y.$2, eylem: l.notificationResponse?.actionId);
      }
      _hazir = true;
    } catch (e) {
      debugPrint('Bildirimler başlatılamadı: $e');
    }
  }

  static (String, String)? _coz(String? p) {
    if (p == null) return null;
    final i = p.indexOf('|');
    if (i <= 0) return null;
    return (p.substring(0, i), p.substring(i + 1));
  }

  /// Android 13+ bildirim izni (düzenli ödeme eklenince sorulur).
  static Future<void> izinIste() async {
    if (!_hazir) return;
    try {
      await _p
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  /// Veri değişince çağrılır; art arda değişikliklerde bir kez planlar.
  static void yenidenPlanla() {
    _bekle?.cancel();
    _bekle = Timer(const Duration(milliseconds: 800), planla);
  }

  /// Önümüzdeki iki ayın hatırlatmalarını baştan kurar.
  static Future<void> planla() async {
    if (!_hazir) return;
    final s = Store.i;
    try {
      await _p.cancelAll();
      if (!s.bildirim) return;
      final simdi = DateTime.now();
      final bugun = gunBasi(simdi);
      var id = 1;
      for (final d in s.duzenliler) {
        for (final ay in [ayBasi(bugun), ayEkle(bugun, 1)]) {
          final t = d.ayda(ay);
          if (t == null || !t.acik(bugun)) continue;
          final k = kategori(d.kategori);
          final tutar = d.degisken ? '~${para(d.tutar, kurussuz: true)}' : para(d.tutar, kurussuz: true);
          final yuk = '${d.id}|${t.donem}';

          if (d.hatirlat > 0) {
            final once = DateTime(t.tarih.year, t.tarih.month, t.tarih.day - d.hatirlat, 9);
            if (once.isAfter(simdi)) {
              await _kur(id++, once, Lx('${d.ad} ${d.hatirlat == 1 ? 'yarın' : '${d.hatirlat} gün sonra'}',
                      '${d.ad} ${d.hatirlat == 1 ? 'tomorrow' : 'in ${d.hatirlat} days'}'),
                  '$tutar · ${k.ad} · ${tarihYazi(t.tarih)}', yuk, eylemli: false);
            }
          }
          final ertelenen = d.ertelenen[t.donem];
          final gun = ertelenen != null && ertelenen.isAfter(t.tarih) ? ertelenen : t.tarih;
          final an = DateTime(gun.year, gun.month, gun.day, 9);
          if (an.isAfter(simdi)) {
            final baslik = gun == t.tarih
                ? Lx('Bugün ödeme günü: ${d.ad}', 'Payment due today: ${d.ad}')
                : Lx('${d.ad} ödendi mi?', '${d.ad}: paid yet?');
            await _kur(id++, an, baslik, Lx('$tutar · Ödediysen tek dokunuşla kaydet.', '$tutar · Paid it? Record it in one tap.'), yuk, eylemli: true);
          }
        }
      }
    } catch (e) {
      debugPrint('Bildirimler planlanamadı: $e');
    }
  }

  static Future<void> _kur(int id, DateTime an, String baslik, String metin, String yuk, {required bool eylemli}) {
    final ayrinti = NotificationDetails(
      android: AndroidNotificationDetails(
        'odemeler',
        L('Ödeme hatırlatmaları'),
        channelDescription: L('Düzenli ödemelerin günü yaklaşınca ve geldiğinde'),
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFF2A541),
        actions: eylemli
            ? [
                AndroidNotificationAction('odendi', L('Ödendi'), showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('ertele', L('Yarın hatırlat'), showsUserInterface: true, cancelNotification: true),
              ]
            : null,
      ),
    );
    return _p.zonedSchedule(
      id,
      baslik,
      metin,
      tz.TZDateTime.from(an, tz.UTC),
      ayrinti,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: yuk,
    );
  }
}
