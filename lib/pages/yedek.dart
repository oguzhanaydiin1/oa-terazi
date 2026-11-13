import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../belge.dart';
import '../i18n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Belgeler ve kayıtlar için parolalı yedek; cihazdan cihaza aktarım (yakında).
Future<void> yedekAc(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: OA.bg,
          title: Text(Lx('Yedek ve aktarım', 'Backup and transfer'), style: oaDisplay(20)),
        ),
        body: const YedekSayfasi(),
      ),
    ));

class YedekSayfasi extends StatefulWidget {
  const YedekSayfasi({super.key});

  @override
  State<YedekSayfasi> createState() => _YedekSayfasiState();
}

class _YedekSayfasiState extends State<YedekSayfasi> {
  bool calisiyor = false;
  String? durum;

  void _mesaj(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  /// Parola sorar; [yeni] ise iki kez ister.
  Future<String?> _parola({required bool yeni}) async {
    final p1 = TextEditingController(), p2 = TextEditingController();
    String? hata;
    final sonuc = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: OA.surface,
          title: Text(yeni ? Lx('Yedek parolası', 'Backup password') : Lx('Yedeğin parolası', 'Backup password'),
              style: oaDisplay(20)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              yeni
                  ? Lx('Yedek bu parolayla şifrelenir. Parolayı unutursan yedek açılamaz; biz de açamayız.',
                      'The backup is encrypted with this password. If you forget it, the backup can’t be opened, not even by us.')
                  : Lx('Yedeği oluştururken belirlediğin parolayı yaz.', 'Enter the password you set when making the backup.'),
              style: oaBody(14, color: OA.text2),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: p1,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(hintText: Lx('Parola (en az 8 karakter)', 'Password (at least 8 characters)')),
            ),
            if (yeni) ...[
              const SizedBox(height: 10),
              TextField(
                controller: p2,
                obscureText: true,
                decoration: InputDecoration(hintText: Lx('Parolayı tekrar yaz', 'Repeat the password')),
              ),
            ],
            if (hata != null) ...[
              const SizedBox(height: 10),
              Text(hata!, style: oaBody(13, color: OA.danger)),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(L('Vazgeç'))),
            TextButton(
              onPressed: () {
                if (p1.text.length < 8) {
                  set(() => hata = Lx('Parola en az 8 karakter olmalı.', 'The password must be at least 8 characters.'));
                } else if (yeni && p1.text != p2.text) {
                  set(() => hata = Lx('Parolalar aynı değil.', 'The passwords don’t match.'));
                } else {
                  Navigator.pop(c, p1.text);
                }
              },
              child: Text(Lx('Devam', 'Continue')),
            ),
          ],
        ),
      ),
    );
    return sonuc;
  }

  Future<void> olustur() async {
    final parola = await _parola(yeni: true);
    if (parola == null) return;
    setState(() {
      calisiyor = true;
      durum = Lx('Yedek hazırlanıyor…', 'Preparing backup…');
    });
    try {
      final s = Store.i;
      final paket = await Yedek.paketle(s.toJson(), await s.belgeDosyalari(), parola);
      final ad = 'terazi-yedek-${gunAnahtar(DateTime.now())}.terazi';
      final yol = await FilePicker.platform.saveFile(
        dialogTitle: Lx('Yedeği kaydet', 'Save backup'),
        fileName: ad,
        bytes: paket,
      );
      if (yol == null) return; // vazgeçildi
      // Android'de dosyayı eklenti yazar; masaüstünde yalnızca yolu döndürür.
      if (!Platform.isAndroid) await File(yol).writeAsBytes(paket, flush: true);
      s.yedekAlindi();
      _mesaj(Lx('Yedek kaydedildi (${boyutYazi(paket.length)}).', 'Backup saved (${boyutYazi(paket.length)}).'));
    } catch (e) {
      _mesaj(Lx('Yedek oluşturulamadı: $e', 'Couldn’t create backup: $e'));
    } finally {
      if (mounted) {
        setState(() {
          calisiyor = false;
          durum = null;
        });
      }
    }
  }

  Future<void> geriYukle() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    final b = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (b == null || !mounted) return;
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: OA.surface,
        title: Text(Lx('Yedekten geri yüklensin mi?', 'Restore from backup?'), style: oaDisplay(20)),
        content: Text(
            Lx('Bu cihazdaki kayıtlar, düzenli ödemeler, bütçeler ve belgeler yedektekilerle değiştirilir.',
                'Entries, regular payments, budgets and documents on this device will be replaced with the backup.'),
            style: oaBody(15, color: OA.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(Lx('Geri yükle', 'Restore'))),
        ],
      ),
    );
    if (evet != true) return;
    final parola = await _parola(yeni: false);
    if (parola == null) return;
    setState(() {
      calisiyor = true;
      durum = Lx('Yedek açılıyor…', 'Opening backup…');
    });
    try {
      final y = await Yedek.ac(b, parola);
      await Store.i.geriYukle(y.veri, y.dosyalar);
      _mesaj(Lx('Yedek geri yüklendi.', 'Backup restored.'));
    } on YedekHatasi catch (e) {
      _mesaj(e.neden == 'parola'
          ? Lx('Parola yanlış.', 'Wrong password.')
          : Lx('Bu dosya bir Terazi yedeği değil.', 'This file isn’t a Terazi backup.'));
    } catch (e) {
      _mesaj(Lx('Geri yüklenemedi: $e', 'Couldn’t restore: $e'));
    } finally {
      if (mounted) {
        setState(() {
          calisiyor = false;
          durum = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Store.i,
        builder: (context, _) {
          final s = Store.i;
          final toplam = s.belgeler.fold<int>(0, (a, b) => a + b.boyut);
          final son = s.sonYedek;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: OA.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: OA.green.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      Icon(Icons.lock_outline, color: OA.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          Lx('${s.belgeler.length} belge · ${boyutYazi(toplam)}, yalnızca bu cihazda. Şifreli saklanır; sunucumuza hiç gönderilmez.',
                              '${s.belgeler.length} documents · ${boyutYazi(toplam)}, only on this device. Stored encrypted; never sent to our servers.'),
                          style: oaBody(14, color: OA.text2),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  OACard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(Lx('Yedek', 'Backup'), style: oaDisplay(19)),
                      const SizedBox(height: 6),
                      Text(
                        Lx('Kayıtların, düzenli ödemelerin, bütçelerin ve bütün belgelerin parolanla şifrelenmiş tek bir dosyaya konur. Google Drive’a, bilgisayarına ya da bir belleğe kaydet; yedek senin elinde kalır.',
                            'Your entries, regular payments, budgets and all documents go into a single file encrypted with your password. Save it to Google Drive, your computer or a USB stick; the backup stays with you.'),
                        style: oaBody(14, color: OA.muted),
                      ),
                      const SizedBox(height: 14),
                      if (calisiyor) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(durum ?? '', style: oaBody(14, color: OA.text2)),
                      ] else ...[
                        OAButton(Lx('Şifreli yedek oluştur', 'Create encrypted backup'), kind: OAButtonKind.primary, onPressed: olustur),
                        const SizedBox(height: 10),
                        OAButton(Lx('Yedekten geri yükle', 'Restore from backup'), onPressed: geriYukle),
                      ],
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: Text(Lx('Son yedek', 'Last backup'), style: oaBody(14, color: OA.muted))),
                        Text(son == null ? Lx('Hiç alınmadı', 'Never') : '${tarihYazi(son)} ${son.year}',
                            style: oaBody(14, weight: FontWeight.w600, color: son == null ? OA.amber : null)),
                      ]),
                      SwitchListTile(
                        value: s.yedekHatirlat,
                        onChanged: s.yedekHatirlatAyarla,
                        contentPadding: EdgeInsets.zero,
                        title: Text(Lx('Ayda bir yedek almayı hatırlat', 'Remind me to back up monthly'),
                            style: oaBody(15, weight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  OACard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(Lx('Bilgisayarımla eşitle', 'Sync with my computer'), style: oaDisplay(19))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: OA.surface2, borderRadius: BorderRadius.circular(99)),
                          child: Text(Lx('Yakında', 'Coming soon'), style: oaBody(12, color: OA.muted, weight: FontWeight.w600)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        Lx('Telefonun ve bilgisayarın aynı Wi-Fi’dayken belgeler birbirine doğrudan aktarılacak; internete ve sunucuya uğramadan. Şimdilik yedek dosyasını öbür cihazda geri yükleyebilirsin.',
                            'When your phone and computer are on the same Wi-Fi, documents will move directly between them, without going through the internet or a server. For now, you can restore the backup file on the other device.'),
                        style: oaBody(14, color: OA.muted),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

/// Özet'te gösterilen "yedek alma zamanı" kartı.
class YedekHatirlatKarti extends StatelessWidget {
  const YedekHatirlatKarti({super.key});

  @override
  Widget build(BuildContext context) {
    final son = Store.i.sonYedek;
    return OACard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(Icons.backup_outlined, color: OA.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            son == null
                ? Lx('Belgelerin yalnızca bu cihazda. Kaybolmasınlar diye bir yedek al.',
                    'Your documents are only on this device. Make a backup so you don’t lose them.')
                : Lx('Son yedeğin üzerinden bir ay geçti.', 'It’s been a month since your last backup.'),
            style: oaBody(14, color: OA.text2),
          ),
        ),
        const SizedBox(width: 8),
        OAButton(Lx('Yedekle', 'Back up'), onPressed: () => yedekAc(context)),
      ]),
    );
  }
}
