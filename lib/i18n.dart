// Dil: Türkçe (varsayılan) ve İngilizce. Flutter'a bağlı değil (models.dart da kullanır).
//
// L('Türkçe metin')      → sabit metinler; İngilizcesi aşağıdaki sözlükte.
// Lx('Türkçe', 'English') → içine değer giren metinler.

class Dil {
  Dil._();

  /// Uygulama İngilizce mi? TeraziApp açılırken ve dil değişince ayarlar.
  static bool en = false;
}

String L(String s) => Dil.en ? (_en[s] ?? s) : s;
String Lx(String tr, String en) => Dil.en ? en : tr;

const _en = <String, String>{
  // Kategoriler
  'Market': 'Groceries',
  'Dışarıda yemek': 'Eating out',
  'Kira': 'Rent',
  'Faturalar': 'Bills',
  'Kredi': 'Loan',
  'Ulaşım': 'Transport',
  'Eğlence': 'Fun',
  'Abonelik': 'Subscriptions',
  'Sağlık': 'Health',
  'Giyim': 'Clothing',
  'Eğitim': 'Education',
  'Diğer': 'Other',
  'Maaş': 'Salary',
  'Ek gelir': 'Side income',
  'Kira geliri': 'Rental income',

  // Genel
  'Özet': 'Summary',
  'Hareketler': 'Activity',
  'Takvim': 'Calendar',
  'Raporlar': 'Reports',
  'Ayarlar': 'Settings',
  'Bütçeler': 'Budgets',
  'Ödeme takvimi': 'Payment calendar',
  'Ekle': 'Add',
  'Aç': 'Open',
  'Ctrl+N: yeni kayıt': 'Ctrl+N: new entry',
  'Verilerin bu bilgisayarda saklanır': 'Your data stays on this computer',
  'Gelir': 'Income',
  'Gider': 'Spending',
  'Kalan': 'Left',
  'Net': 'Net',
  'Tümü': 'All',
  'Kategori': 'Category',
  'Açıklama': 'Description',
  'Tarih': 'Date',
  'Tutar': 'Amount',
  'Sil': 'Delete',
  'Kapat': 'Close',
  'Vazgeç': 'Cancel',
  'Kaydet': 'Save',
  'Düzenle': 'Edit',
  'Geri al': 'Undo',
  'Azalt': 'Decrease',
  'Artır': 'Increase',
  'Önceki ay': 'Previous month',
  'Sonraki ay': 'Next month',
  'Bugün': 'Today',
  'Dün': 'Yesterday',
  'Yarın': 'Tomorrow',
  'Süresiz': 'Ongoing',

  // Bildirim
  'Ödeme hatırlatmaları': 'Payment reminders',
  'Düzenli ödemelerin günü yaklaşınca ve geldiğinde': 'When a regular payment is due soon or today',
  'Ödendi': 'Paid',
  'Yarın hatırlat': 'Remind me tomorrow',

  // Ekle
  'Yeni kayıt': 'New entry',
  'Kaydı düzenle': 'Edit entry',
  'Önce tutarı yaz.': 'Enter the amount first.',
  'Kayıt silinsin mi?': 'Delete this entry?',
  'Bu, bir düzenli ödemenin "ödendi" kaydı. Silersen o ayın ödemesi yeniden açık görünür.':
      'This is the “paid” entry of a regular payment. If you delete it, that month’s payment shows as open again.',
  'Açıklama (ör. Migros)': 'Description (e.g. Tesco)',

  // Hareketler
  'Ara: açıklama ya da kategori': 'Search: description or category',
  'Bu ay için kayıt yok': 'No entries this month',
  'Aramana uyan kayıt bulunamadı.': 'No entries match your search.',
  'Eklediğin gelir ve giderler burada gün gün listelenir.': 'Your income and spending are listed here day by day.',

  // Ödendi mi
  'Ödenen tutar': 'Amount paid',
  'Ödenen tutarı yaz.': 'Enter the amount paid.',
  'Bu ödemenin tutarı her ay değişebiliyor; bu ay ödediğin tutarı yaz.':
      'This payment’s amount can change each month; enter what you paid this month.',
  'Farklıysa düzelt; bu ay için kaydedilir, sonraki aylar değişmez.':
      'Correct it if it’s different; it’s saved for this month only, later months stay the same.',
  'Ödendi, gider olarak kaydet': 'Paid, record as spending',
  'Yarın yeniden soracağım.': 'I’ll ask again tomorrow.',
  'Bu ay ödenmeyecek': 'Not paying this month',
  'Ödendi mi?': 'Paid yet?',
  'Bu ay yok': 'Skipped',
  'Önceden': 'Earlier',

  // Düzenli ödeme
  'Düzenli ödeme': 'Regular payment',
  'Düzenli ödemeyi düzenle': 'Edit regular payment',
  'Ne ödüyorsun?': 'What are you paying?',
  'Kredi taksiti, kira, internet…': 'Loan instalment, rent, internet…',
  'Aylık tutar': 'Monthly amount',
  'Her ayın': 'Day of the month',
  'Kaç ay sürecek?': 'How many months?',
  'Belli bir süre': 'Fixed term',
  'Kira, abonelik ve fatura gibi; sen durdurana kadar her ay eklenir.':
      'Like rent, subscriptions and bills; added every month until you stop it.',
  'Hatırlat': 'Remind me',
  'Aynı gün': 'On the day',
  '1 gün önce': '1 day before',
  '3 gün önce': '3 days before',
  'Tutar her ay değişebilir': 'Amount may vary',
  'Fatura gibi; ödeme günü gerçek tutarı sorar.': 'Like a bill; asks for the real amount on the day.',
  'Takvime ekle': 'Add to calendar',
  'Tutarı yazınca özet burada görünecek.': 'A summary appears here once you enter the amount.',
  'Ödemenin adını ve aylık tutarını yaz.': 'Enter the payment’s name and monthly amount.',
  'Düzenli ödeme silinsin mi?': 'Delete this regular payment?',
  'Takvimden kalkar. Daha önce "ödendi" dediğin aylar hareketlerinde kalır.':
      'It’s removed from the calendar. Months you marked as paid stay in your activity.',

  // Özet
  'Terazi\'ye hoş geldin': 'Welcome to Terazi',
  'İlk gelirini ya da giderini ekle; ay sonuna kadar günde ne kadar harcayabileceğini hesaplayayım.':
      'Add your first income or spending and I’ll work out how much you can spend per day until month end.',
  'İlk kaydı ekle': 'Add your first entry',
  'Son hareketler': 'Recent activity',
  'Henüz kayıt yok.': 'No entries yet.',
  'Henüz kayıt yok': 'No entries yet',
  'Ayın son günü': 'Last day of the month',
  'Dışa aktar': 'Export',
  'Günde harcayabileceğin': 'You can spend per day',
  'Yaklaşan ödemeler düşüldü': 'Upcoming payments deducted',
  'Tümünü gör': 'See all',
  'Gelir ve giderlerin burada listelenir.': 'Your income and spending are listed here.',
  'Yaklaşan ödemeler': 'Upcoming payments',
  'Kredi, kira, abonelik gibi her ay tekrar eden ödemelerini ekle.':
      'Add payments that repeat every month, like loans, rent and subscriptions.',
  'Düzenli ödeme ekle': 'Add regular payment',
  'Bu ay kalan': 'Left this month',
  'Gelirini ekleyince günde ne kadar harcayabileceğini hesaplarım.':
      'Add your income and I’ll work out how much you can spend per day.',
  'Yanıtla': 'Answer',
  'Kredi, kira, abonelik gibi ödemelerini bir kez ekle; her ay kendiliğinden takvime düşsün.':
      'Add loans, rent and subscriptions once; they land in the calendar every month.',
  'Market, eğlence gibi kategorilere aylık sınır koy; aşınca haber vereyim.':
      'Set monthly limits for categories like groceries and fun; I’ll tell you when you go over.',
  '"Ödendi" kararını geri al': 'Undo “Paid”',
  '"Bu ay ödenmeyecek" kararını geri al': 'Undo “Not paying this month”',

  // Raporlar
  'Nereye gitti?': 'Where did it go?',
  'Bu ay gider yok.': 'No spending this month.',

  // Takvim
  'Bu güne düzenli ödeme yok.': 'No regular payments on this day.',
  'Bu ay kalan düzenli ödemeler': 'Regular payments left this month',
  'Düzenli ödeme yok': 'No regular payments',
  'Kredi taksiti, kira, internet, abonelik… Bir kez ekle; kaç ay süreceğini seç, her ay kendiliğinden gelsin.':
      'Loan instalments, rent, internet, subscriptions… Add once, choose how many months, and they come back every month.',
  'İpucu: bir ödemeye basılı tutarak düzenleyebilirsin.': 'Tip: press and hold a payment to edit it.',

  // Ayarlar
  'Kategorilere aylık sınır koy': 'Set monthly limits for categories',
  'Dışa aktar (CSV)': 'Export (CSV)',
  'Tüm hareketler; Excel ile açılır': 'All activity; opens in Excel',
  'Bize ulaş': 'Contact us',
  'Diğer OA Labs uygulamaları': 'Other OA Labs apps',
  'Tüm verileri sil': 'Delete all data',
  'Kayıtlar, düzenli ödemeler ve bütçeler': 'Entries, regular payments and budgets',
  'Terazi: Gelir Gider Takibi': 'Terazi: Income & Expense Tracker',
  'Verilerin yalnızca bu cihazda saklanır.': 'Your data is stored only on this device.',
  'Tüm veriler silinsin mi?': 'Delete all data?',
  'Bütün kayıtların, düzenli ödemelerin ve bütçelerin bu cihazdan silinir. Geri alınamaz.':
      'All your entries, regular payments and budgets will be deleted from this device. This can’t be undone.',
  'Hepsini sil': 'Delete everything',
  'Bir kategoriye aylık sınır koy; harcadıkça dolar, aşınca kırmızıya döner.':
      'Set a monthly limit for a category; it fills as you spend and turns red when you go over.',
  'Sınır ekle': 'Add a limit',
  'Sınırı kaldır': 'Remove limit',
  'Ödeme günü sabah 9\'da ve seçtiğin gün önce bildirim': 'A notification at 9 a.m. on the day and the days before you chose',
  'Dil': 'Language',
  'Tema': 'Theme',
  'Para birimi': 'Currency',
  'Sistem': 'System',
  'Koyu': 'Dark',
  'Açık': 'Light',
  'Tutarlar çevrilmez; yalnızca simge ve sayı biçimi değişir.':
      'Amounts aren’t converted; only the symbol and number format change.',
  'Görünüm': 'Appearance',
};
