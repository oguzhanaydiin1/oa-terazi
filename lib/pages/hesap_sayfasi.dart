import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../esitle.dart';
import '../hesap.dart';
import '../i18n.dart';
import '../theme.dart';

/// Hesap ve eşitleme sayfası (Ayarlar'dan açılır).
Future<void> hesapAc(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          backgroundColor: OA.bg,
          title: Text(Lx('Hesap ve eşitleme', 'Account and sync'), style: oaDisplay(20)),
        ),
        body: const HesapSayfasi(),
      ),
    ));

/// Ayarlar'daki satırın alt yazısı.
String hesapOzeti() {
  final h = Hesap.i, e = Esitleme.i;
  if (!h.girisli) {
    return h.oturumVar
        ? Lx('Hesap bilgisi alınamadı (bağlantı yok)', 'Couldn’t load your account (offline)')
        : Lx('İsteğe bağlı: kayıtların cihazlar arasında eşitlensin', 'Optional: sync your entries across devices');
  }
  if (!e.kurulu) return Lx('${h.eposta} · eşitleme kapalı', '${h.eposta} · sync is off');
  if (e.calisiyor) return Lx('Eşitleniyor…', 'Syncing…');
  if (e.hata != null) return Lx('Eşitlenemedi: dokun ve bak', 'Couldn’t sync: tap to see why');
  return e.son == null
      ? Lx('Eşitleme açık', 'Sync is on')
      : Lx('Eşitlendi · ${sonYazi(e.son!)}', 'Synced · ${sonYazi(e.son!)}');
}

String sonYazi(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return Lx('az önce', 'just now');
  if (d.inMinutes < 60) return Lx('${d.inMinutes} dk önce', '${d.inMinutes} min ago');
  if (d.inHours < 24) return Lx('${d.inHours} saat önce', '${d.inHours} h ago');
  return Lx('${d.inDays} gün önce', '${d.inDays} days ago');
}

String esitlemeHatasi(String? kod) {
  switch (kod) {
    case 'kisa':
      return Lx('Parola en az 8 karakter olmalı.', 'The password must be at least 8 characters.');
    case 'parola':
      return Lx('Parola yanlış. Öbür cihazında belirlediğin eşitleme parolasını yaz.',
          'Wrong password. Enter the sync password you set on your other device.');
    case 'tuz':
      return Lx('Eşitleme başka bir cihazda yeni bir parolayla kuruldu. Bu cihazda yeni parolayı yaz.',
          'Sync was set up again with a new password on another device. Enter the new password here.');
    default:
      return hesapHatasi(kod);
  }
}

class HesapSayfasi extends StatelessWidget {
  const HesapSayfasi({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([Hesap.i, Esitleme.i]),
        builder: (context, _) {
          final h = Hesap.i;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  if (!h.girisli && !h.oturumVar)
                    const _GirisFormu()
                  else if (!Esitleme.i.kurulu)
                    const _EsitlemeKur()
                  else
                    const _Durum(),
                  const SizedBox(height: 18),
                  const _NasilCalisir(),
                ],
              ),
            ),
          );
        },
      );
}

class _NasilCalisir extends StatelessWidget {
  const _NasilCalisir();

  @override
  Widget build(BuildContext context) {
    Widget madde(IconData i, String yazi) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 20, color: OA.amber),
            const SizedBox(width: 12),
            Expanded(child: Text(yazi, style: oaBody(14, color: OA.text2))),
          ]),
        );
    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Lx('Nasıl çalışır?', 'How does it work?'), style: oaBody(16, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        madde(Icons.devices_outlined,
            Lx('Kayıtların, düzenli ödemelerin ve bütçelerin telefonun ile bilgisayarın arasında eşitlenir. Cihaz değiştirsen de kaybolmaz.',
                'Your entries, recurring payments and budgets sync between your phone and computer, and survive a device change.')),
        madde(Icons.lock_outline,
            Lx('Veriler cihazından eşitleme parolanla şifrelenmiş olarak çıkar. Sunucuda biz dahil kimse içini göremez.',
                'Data leaves your device encrypted with your sync password. No one on the server, us included, can read it.')),
        madde(Icons.description_outlined,
            Lx('Belge dosyaları hiç gönderilmez; yalnızca belgenin adı ve bitiş tarihi eşitlenir. Dosyalar çekildiği cihazda kalır.',
                'Document files are never sent; only a document’s name and end date sync. Files stay on the device they were added on.')),
        madde(Icons.key_outlined,
            Lx('Eşitleme parolasını unutursan sunucudaki kopya açılamaz. Cihazdaki verilerin silinmez, yedek dosyası da almaya devam edebilirsin.',
                'If you forget the sync password, the server copy can’t be opened. The data on your device stays, and you can keep making backup files.')),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Giriş / üyelik

class _GirisFormu extends StatefulWidget {
  const _GirisFormu();

  @override
  State<_GirisFormu> createState() => _GirisFormuState();
}

class _GirisFormuState extends State<_GirisFormu> {
  bool uye = false; // false: giriş yap, true: üye ol
  bool kodBekleniyor = false;
  bool calisiyor = false;
  bool onay = false;
  String? hata;
  final eposta = TextEditingController();
  final ad = TextEditingController();
  final kod = TextEditingController();

  Future<void> _kodGonder() async {
    setState(() {
      calisiyor = true;
      hata = null;
    });
    String? h;
    if (uye && !onay) {
      h = 'onay';
    } else {
      h = await Hesap.i.kodGonder(eposta.text, ad: uye ? ad.text : null);
    }
    if (!mounted) return;
    setState(() {
      calisiyor = false;
      hata = h == null ? null : hesapHatasi(h);
      if (h == null) kodBekleniyor = true;
    });
  }

  Future<void> _dogrula() async {
    setState(() {
      calisiyor = true;
      hata = null;
    });
    final h = await Hesap.i.dogrula(eposta.text, kod.text);
    if (!mounted) return;
    setState(() {
      calisiyor = false;
      hata = h == null ? null : hesapHatasi(h);
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget sekme(String yazi, bool deger) => Expanded(
          child: GestureDetector(
            onTap: calisiyor
                ? null
                : () => setState(() {
                      uye = deger;
                      kodBekleniyor = false;
                      hata = null;
                    }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: uye == deger ? OA.surface2 : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(yazi,
                  style: oaBody(15, weight: FontWeight.w600, color: uye == deger ? OA.text : OA.muted)),
            ),
          ),
        );

    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const TeraziMark(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Text(Lx('OA Labs hesabınla gir', 'Sign in with your OA Labs account'),
                style: oaBody(17, weight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
            Lx('Giriş isteğe bağlı. oalabs.dev, OA Labs Center ve Pusula ile aynı hesap; şifre yok, e-postana kod gelir.',
                'Signing in is optional. It’s the same account as oalabs.dev, OA Labs Center and Pusula. No password: we email you a code.'),
            style: oaBody(14, color: OA.muted)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(border: Border.all(color: OA.border), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [sekme(Lx('Giriş yap', 'Sign in'), false), sekme(Lx('Üye ol', 'Sign up'), true)]),
        ),
        const SizedBox(height: 16),
        if (uye) ...[
          TextField(
            controller: ad,
            enabled: !kodBekleniyor,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: Lx('Adın', 'Your name')),
          ),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: eposta,
          enabled: !kodBekleniyor,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(labelText: Lx('E-posta', 'Email')),
        ),
        if (uye && !kodBekleniyor) ...[
          const SizedBox(height: 8),
          CheckboxListTile(
            value: onay,
            onChanged: (v) => setState(() => onay = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
                Lx('Kullanım koşullarını ve gizlilik politikasını okudum, kabul ediyorum.',
                    'I’ve read and accept the terms of use and the privacy policy.'),
                style: oaBody(14, color: OA.text2)),
          ),
          Wrap(spacing: 4, children: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse(Dil.en ? 'https://oalabs.dev/en/kosullar/' : 'https://oalabs.dev/kosullar/'),
                  mode: LaunchMode.externalApplication),
              child: Text(Lx('Koşullar', 'Terms')),
            ),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(Dil.en ? 'https://oalabs.dev/en/gizlilik/' : 'https://oalabs.dev/gizlilik/'),
                  mode: LaunchMode.externalApplication),
              child: Text(Lx('Gizlilik', 'Privacy')),
            ),
          ]),
        ],
        if (kodBekleniyor) ...[
          const SizedBox(height: 14),
          Text(Lx('${eposta.text.trim()} adresine 6 haneli bir kod gönderdik.', 'We sent a 6-digit code to ${eposta.text.trim()}.'),
              style: oaBody(14, color: OA.text2)),
          const SizedBox(height: 10),
          TextField(
            controller: kod,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(labelText: Lx('Kod', 'Code'), counterText: ''),
            onSubmitted: (_) => _dogrula(),
          ),
        ],
        if (hata != null) ...[
          const SizedBox(height: 10),
          Text(hata!, style: oaBody(14, color: OA.danger)),
        ],
        const SizedBox(height: 16),
        Row(children: [
          if (calisiyor)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          else if (!kodBekleniyor)
            OAButton(Lx('Kod gönder', 'Send code'), kind: OAButtonKind.primary, onPressed: _kodGonder)
          else ...[
            OAButton(uye ? Lx('Üyeliği aç', 'Create account') : Lx('Giriş yap', 'Sign in'),
                kind: OAButtonKind.primary, onPressed: _dogrula),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => setState(() {
                kodBekleniyor = false;
                kod.clear();
                hata = null;
              }),
              child: Text(Lx('E-postayı değiştir', 'Change email')),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Eşitleme kurulumu

class _EsitlemeKur extends StatefulWidget {
  const _EsitlemeKur();

  @override
  State<_EsitlemeKur> createState() => _EsitlemeKurState();
}

class _EsitlemeKurState extends State<_EsitlemeKur> {
  bool yukleniyor = true;
  bool calisiyor = false;
  Map? uzak;
  String? hata;
  final p1 = TextEditingController();
  final p2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    hata = Esitleme.i.hata == null ? null : esitlemeHatasi(Esitleme.i.hata);
    _bak();
  }

  Future<void> _bak() async {
    setState(() => yukleniyor = true);
    final r = await Esitleme.i.sunucudakiKutu();
    if (!mounted) return;
    setState(() {
      yukleniyor = false;
      uzak = r.kutu;
      if (r.hata != null) hata = hesapHatasi(r.hata);
    });
  }

  Future<void> _ac() async {
    if (p1.text.length < 8) {
      setState(() => hata = esitlemeHatasi('kisa'));
      return;
    }
    if (uzak == null && p1.text != p2.text) {
      setState(() => hata = Lx('Parolalar aynı değil.', 'The passwords don’t match.'));
      return;
    }
    setState(() {
      calisiyor = true;
      hata = null;
    });
    final h = await Esitleme.i.kur(p1.text, uzak);
    if (!mounted) return;
    setState(() {
      calisiyor = false;
      hata = h == null ? null : esitlemeHatasi(h);
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = Hesap.i;
    return Column(children: [
      _HesapKarti(),
      const SizedBox(height: 14),
      OACard(
        child: yukleniyor
            ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Lx('Eşitlemeyi aç', 'Turn on sync'), style: oaBody(17, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  uzak == null
                      ? Lx('Bir eşitleme parolası belirle. Verilerin bu parolayla şifrelenir; öbür cihazında da aynı parolayı yazacaksın. Bu parola hesabının girişinden ayrıdır ve hiçbir yere gönderilmez.',
                          'Choose a sync password. Your data is encrypted with it, and you’ll enter the same password on your other device. It’s separate from your sign-in and never leaves your device.')
                      : Lx('Öbür cihazında eşitleme açık. Orada belirlediğin eşitleme parolasını yaz; bu cihazdaki kayıtlar oradakilerle birleşir, hiçbiri silinmez.',
                          'Sync is on for your other device. Enter the sync password you set there; the entries on this device will be merged with those, nothing is deleted.'),
                  style: oaBody(14, color: OA.text2),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: p1,
                  obscureText: true,
                  decoration: InputDecoration(labelText: Lx('Eşitleme parolası (en az 8 karakter)', 'Sync password (at least 8 characters)')),
                ),
                if (uzak == null) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: p2,
                    obscureText: true,
                    decoration: InputDecoration(labelText: Lx('Parolayı tekrar yaz', 'Repeat the password')),
                  ),
                ],
                if (hata != null) ...[
                  const SizedBox(height: 10),
                  Text(hata!, style: oaBody(14, color: OA.danger)),
                ],
                const SizedBox(height: 16),
                if (calisiyor)
                  Row(children: [
                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 12),
                    Text(Lx('Anahtar hazırlanıyor ve eşitleniyor…', 'Preparing the key and syncing…'),
                        style: oaBody(14, color: OA.muted)),
                  ])
                else
                  OAButton(Lx('Eşitlemeyi aç', 'Turn on sync'), kind: OAButtonKind.primary, onPressed: h.oturumVar ? _ac : null),
              ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------- Durum

class _HesapKarti extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final h = Hesap.i;
    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: OA.amber,
            child: Text(h.basHarf, style: oaBody(18, weight: FontWeight.w700, color: OA.amberInk)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.ad ?? Lx('OA Labs hesabı', 'OA Labs account'), style: oaBody(16, weight: FontWeight.w700)),
              Text(h.eposta ?? Lx('Bağlantı bekleniyor', 'Waiting for connection'), style: oaBody(14, color: OA.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        OAButton(Lx('Çıkış yap', 'Sign out'), onPressed: () => _cikis(context)),
      ]),
    );
  }

  Future<void> _cikis(BuildContext context) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: OA.surface,
        title: Text(Lx('Çıkış yapılsın mı?', 'Sign out?'), style: oaDisplay(20)),
        content: Text(
            Lx('Eşitleme bu cihazda durur. Bu cihazdaki kayıtların silinmez; sunucudaki şifreli kopya da kalır.',
                'Sync stops on this device. Your entries here aren’t deleted, and the encrypted copy on the server stays.'),
            style: oaBody(15, color: OA.text2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(L('Vazgeç'))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(Lx('Çıkış yap', 'Sign out'))),
        ],
      ),
    );
    if (evet != true) return;
    await Esitleme.i.kapat();
    await Hesap.i.cikis();
  }
}

class _Durum extends StatelessWidget {
  const _Durum();

  @override
  Widget build(BuildContext context) {
    final e = Esitleme.i;
    return Column(children: [
      _HesapKarti(),
      const SizedBox(height: 14),
      OACard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(e.hata == null ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                color: e.hata == null ? OA.green : OA.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                e.calisiyor
                    ? Lx('Eşitleniyor…', 'Syncing…')
                    : e.hata != null
                        ? Lx('Eşitlenemedi', 'Couldn’t sync')
                        : Lx('Eşitleme açık', 'Sync is on'),
                style: oaBody(16, weight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            e.hata != null
                ? esitlemeHatasi(e.hata)
                : e.son == null
                    ? Lx('Henüz eşitlenmedi.', 'Not synced yet.')
                    : Lx('Son eşitleme ${sonYazi(e.son!)}. Değişiklikler birkaç saniye içinde öbür cihazlarına gider.',
                        'Last synced ${sonYazi(e.son!)}. Changes reach your other devices within seconds.'),
            style: oaBody(14, color: OA.text2),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OAButton(Lx('Şimdi eşitle', 'Sync now'), kind: OAButtonKind.primary, onPressed: e.calisiyor ? null : e.esitle),
            OAButton(Lx('Bu cihazda kapat', 'Turn off on this device'), onPressed: () => e.kapat()),
          ]),
        ]),
      ),
    ]);
  }
}
