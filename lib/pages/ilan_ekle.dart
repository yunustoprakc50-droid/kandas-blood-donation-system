import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // pubspec.yaml'da intl ekli olmalı!
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';


const normalToReal = <String, String>{
  'adana': 'Adana',
  'adiyaman': 'Adıyaman',
  'afyonkarahisar': 'Afyonkarahisar',
  'agri': 'Ağrı',
  'amasya': 'Amasya',
  'ankara': 'Ankara',
  'antalya': 'Antalya',
  'artvin': 'Artvin',
  'aydin': 'Aydın',
  'balikesir': 'Balıkesir',
  'bilecik': 'Bilecik',
  'bingol': 'Bingöl',
  'bitlis': 'Bitlis',
  'bolu': 'Bolu',
  'burdur': 'Burdur',
  'bursa': 'Bursa',
  'canakkale': 'Çanakkale',
  'cankiri': 'Çankırı',
  'corum': 'Çorum',
  'denizli': 'Denizli',
  'diyarbakir': 'Diyarbakır',
  'edirne': 'Edirne',
  'elazig': 'Elazığ',
  'erzincan': 'Erzincan',
  'erzurum': 'Erzurum',
  'eskisehir': 'Eskişehir',
  'gaziantep': 'Gaziantep',
  'giresun': 'Giresun',
  'gumushane': 'Gümüşhane',
  'hakkari': 'Hakkâri',
  'hatay': 'Hatay',
  'isparta': 'Isparta',
  'mersin': 'Mersin',
  'istanbul': 'İstanbul',
  'izmir': 'İzmir',
  'kars': 'Kars',
  'kastamonu': 'Kastamonu',
  'kayseri': 'Kayseri',
  'kirklareli': 'Kırklareli',
  'kirsehir': 'Kırşehir',
  'kocaeli': 'Kocaeli',
  'konya': 'Konya',
  'kutahya': 'Kütahya',
  'malatya': 'Malatya',
  'manisa': 'Manisa',
  'kahramanmaras': 'Kahramanmaraş',
  'mardin': 'Mardin',
  'mugla': 'Muğla',
  'mus': 'Muş',
  'nevsehir': 'Nevşehir',
  'nigde': 'Niğde',
  'ordu': 'Ordu',
  'rize': 'Rize',
  'sakarya': 'Sakarya',
  'samsun': 'Samsun',
  'siirt': 'Siirt',
  'sinop': 'Sinop',
  'sivas': 'Sivas',
  'tekirdag': 'Tekirdağ',
  'tokat': 'Tokat',
  'trabzon': 'Trabzon',
  'tunceli': 'Tunceli',
  'sanliurfa': 'Şanlıurfa',
  'usak': 'Uşak',
  'van': 'Van',
  'yozgat': 'Yozgat',
  'zonguldak': 'Zonguldak',
  'aksaray': 'Aksaray',
  'bayburt': 'Bayburt',
  'karaman': 'Karaman',
  'kirikkale': 'Kırıkkale',
  'batman': 'Batman',
  'sirnak': 'Şırnak',
  'bartin': 'Bartın',
  'ardahan': 'Ardahan',
  'igdir': 'Iğdır',
  'yalova': 'Yalova',
  'karabuk': 'Karabük',
  'kilis': 'Kilis',
  'osmaniye': 'Osmaniye',
  'duzce': 'Düzce',
};

String? normalizeToOriginal(String sehirNorm) {
  return normalToReal[sehirNorm];
}



class IlanEklePage extends StatefulWidget {
  final String? bashekimId;   // ✅ nullable
  final String? doktorId;     // ✅ nullable
  final bool? doktorMu;       // ✅ nullable

  final String? ilanId;
  final Map<String, dynamic>? mevcutIlan;

  const IlanEklePage({
    super.key,
    this.bashekimId,
    this.doktorId,
    this.doktorMu,
    this.ilanId,
    this.mevcutIlan,
  });

  @override
  State<IlanEklePage> createState() => _IlanEklePageState();
}


String uretHash(Map<String, dynamic> data) {
  final keys = data.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final k in keys) {
    buffer.write('$k=${data[k]}|');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}
class _IlanEklePageState extends State<IlanEklePage> {
  final TextEditingController _hastaneController = TextEditingController();
  String? _secilenSehir;
  String? _secilenIlce;
  List<Map<String, dynamic>> kanTalepleri = [];
  
  String? doktoruEkleyenBashekimId;
final List<String> sehirler = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin',
  'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale',
  'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum',
  'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin',
  'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli',
  'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
  'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat',
  'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray',
  'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır',
  'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
];
  final Map<String, List<String>> ilceler = {
  'Adana': ['Seyhan', 'Yüreğir', 'Çukurova'],
  'Adıyaman': ['Merkez', 'Kahta'],
  'Afyonkarahisar': ['Merkez', 'Sandıklı'],
  'Ağrı': ['Merkez', 'Patnos'],
  'Aksaray': ['Merkez'],
  'Amasya': ['Merkez'],
  'Ankara': ['Çankaya', 'Keçiören', 'Sincan', 'Yenimahalle', 'Mamak'],
  'Antalya': ['Muratpaşa', 'Kepez', 'Alanya'],
  'Artvin': ['Merkez'],
  'Ardahan': ['Merkez'],
  'Aydın': ['Efeler', 'Nazilli', 'Söke'],
  'Balıkesir': ['Karesi', 'Altıeylül', 'Bandırma'],
  'Bartın': ['Merkez'],
  'Batman': ['Merkez'],
  'Bayburt': ['Merkez'],
  'Bilecik': ['Merkez'],
  'Bingöl': ['Merkez'],
  'Bitlis': ['Merkez'],
  'Bolu': ['Merkez'],
  'Burdur': ['Merkez'],
  'Bursa': ['Osmangazi', 'Yıldırım', 'Nilüfer', 'İnegöl'],
  'Çanakkale': ['Merkez', 'Biga'],
  'Çankırı': ['Merkez'],
  'Çorum': ['Merkez'],
  'Denizli': ['Pamukkale', 'Merkezefendi'],
  'Diyarbakır': ['Bağlar', 'Kayapınar', 'Yenişehir'],
  'Düzce': ['Merkez'],
  'Edirne': ['Merkez'],
  'Elazığ': ['Merkez'],
  'Erzincan': ['Merkez'],
  'Erzurum': ['Yakutiye', 'Palandöken'],
  'Eskişehir': ['Odunpazarı', 'Tepebaşı'],
  'Gaziantep': ['Şahinbey', 'Şehitkamil'],
  'Giresun': ['Merkez'],
  'Gümüşhane': ['Merkez'],
  'Hakkari': ['Merkez'],
  'Hatay': ['Antakya', 'İskenderun'],
  'Iğdır': ['Merkez'],
  'Isparta': ['Merkez'],
  'İstanbul': ['Kadıköy', 'Beşiktaş', 'Üsküdar', 'Şişli', 'Fatih', 'Bakırköy'],
  'İzmir': ['Konak', 'Karşıyaka', 'Bornova', 'Buca', 'Çiğli'],
  'Kahramanmaraş': ['Dulkadiroğlu', 'Onikişubat'],
  'Karabük': ['Merkez'],
  'Karaman': ['Merkez'],
  'Kars': ['Merkez'],
  'Kastamonu': ['Merkez'],
  'Kayseri': ['Kocasinan', 'Melikgazi'],
  'Kırıkkale': ['Merkez'],
  'Kırklareli': ['Merkez'],
  'Kırşehir': ['Merkez'],
  'Kilis': ['Merkez'],
  'Kocaeli': ['İzmit', 'Gebze'],
  'Konya': ['Selçuklu', 'Meram', 'Karatay'],
  'Kütahya': ['Merkez'],
  'Malatya': ['Yeşilyurt', 'Battalgazi'],
  'Manisa': ['Şehzadeler', 'Yunusemre'],
  'Mardin': ['Artuklu', 'Kızıltepe'],
  'Mersin': ['Toroslar', 'Yenişehir', 'Mezitli'],
  'Muğla': ['Menteşe', 'Bodrum', 'Fethiye'],
  'Muş': ['Merkez'],
  'Nevşehir': ['Merkez'],
  'Niğde': ['Merkez'],
  'Ordu': ['Altınordu'],
  'Osmaniye': ['Merkez'],
  'Rize': ['Merkez'],
  'Sakarya': ['Adapazarı', 'Serdivan'],
  'Samsun': ['İlkadım', 'Atakum'],
  'Siirt': ['Merkez'],
  'Sinop': ['Merkez'],
  'Sivas': ['Merkez'],
  'Şanlıurfa': ['Haliliye', 'Eyyübiye'],
  'Şırnak': ['Merkez'],
  'Tekirdağ': ['Süleymanpaşa', 'Çorlu'],
  'Tokat': ['Merkez'],
  'Trabzon': ['Ortahisar'],
  'Tunceli': ['Merkez'],
  'Uşak': ['Merkez'],
  'Van': ['İpekyolu'],
  'Yalova': ['Merkez'],
  'Yozgat': ['Merkez'],
  'Zonguldak': ['Merkez'],
};
  final List<String> kanGruplari = [
    'A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', 'AB Rh+', 'AB Rh-', '0 Rh+', '0 Rh-',
  ];
final List<String> aciklamalar = [
  'Acil ihtiyaç',                // 🔴 Anında müdahale gerek
  'Depo seviyesi kritik',        // 🧪 Stoklar alarm veriyor
  'Rutin kontrol ihtiyacı',      // 🔄 Düzenli kan temini
  'Planlı ameliyat öncesi',      // 🛏️ Operasyon hazırlığı
  'Kaza sonrası ihtiyaç',        // 🚑 Trafik/iş kazası sonrası
  'Çocuk hastası için gerekli',  // 👶 Özel durum
  'Nadir kan grubu arayışı',     // 🧬 Zor bulunan grup
  'Hasta nakli öncesi gerekli',  // 🚁 Transfer öncesi
  'Teyit amaçlı duyuru',         // ✅ Bilgilendirme
];


String normalize(String input) {
  return input.toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9_-]'), ''); // sadece geçerli karakterlere izin ver
}

@override
void initState() {
  super.initState();


if (_secilenSehir != null) {
  final fixed = sehirler.firstWhere(
    (s) => normalize(s) == normalize(_secilenSehir!),
    orElse: () => _secilenSehir!,
  );
  _secilenSehir = fixed;
}
for (var s in sehirler) {
}



  if (widget.doktorMu == true && widget.doktorId != null) {


  FirebaseFirestore.instance
      .collection('doktorlar')
      .doc(widget.doktorId)
      .get()
      .then((doc) {


    final data = doc.data();

    if (data != null && data['bashekimId'] != null) {
      doktoruEkleyenBashekimId = data['bashekimId'];
    } else {
      doktoruEkleyenBashekimId = null;
    }


    if (mounted) setState(() {});

  }).catchError((e) {
  });

} else {

  doktoruEkleyenBashekimId = widget.bashekimId;

}

  // 🔄 Güncelleme modundaysa mevcut ilanı yükle
  if (widget.mevcutIlan != null) {
    final ilan = widget.mevcutIlan!;

    final match = sehirler.where(
  (s) => normalize(s) == normalize(ilan['sehir']),
).toList();

if (match.isNotEmpty) {
  _secilenSehir = match.first;
} else {
  _secilenSehir = null;
}
    _secilenIlce = ilan['ilce'];
    _hastaneController.text = ilan['hastane'] ?? '';

    if (ilan['kanTalepleri'] is List) {
      kanTalepleri =
          List<Map<String, dynamic>>.from(ilan['kanTalepleri']);
    } else {
      kanTalepleri = [
        {
          'kanGrubu': ilan['kanGrubu'],
          'aciklama': ilan['aciklama'],
          'acil': ilan['acil'] ?? false,
        }
      ];
    }
  } else {
    kanTalepleri = [
      {'kanGrubu': null, 'aciklama': null, 'acil': false}
    ];
  }
}

void _talepEkle() {
  if (kanTalepleri.length >= 3) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bir ilanda en fazla 3 kan talebi olabilir!')),
    );
    return;
  }
  setState(() {
    kanTalepleri.add({'kanGrubu': null, 'aciklama': null, 'acil': false});
  });
  debugPrint("✅ Yeni talep eklendi. Toplam: ${kanTalepleri.length}");
}


Future<void> _talepSil(int index) async {
  if (kanTalepleri.length == 1 && widget.ilanId != null) {
    if (doktoruEkleyenBashekimId == null) {
  await FirebaseFirestore.instance
      .collection("doktorlar")
      .doc(widget.bashekimId)
      .get()
      .then((doc) {
        final data = doc.data();
        doktoruEkleyenBashekimId = data?['ekleyen'] ?? widget.bashekimId;
      });
}




    try {
  await FirebaseFunctions.instance
      .httpsCallable('deleteIlan')
      .call({
    "ilanId": widget.ilanId,
    "ekleyenId": widget.bashekimId,
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Tüm talepler silindi, ilan tamamen kaldırıldı!'),
    ),
  );

  if (mounted) Navigator.pop(context);

} catch (e) {

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Günde en fazla 5 ilan silebilirsiniz'),
      backgroundColor: Colors.black,
    ),
  );
}

return;
  }

  setState(() {
    kanTalepleri.removeAt(index);
  });
}
Future<void> _ilanKaydet() async {
  
  if (FirebaseAuth.instance.currentUser == null) {
  await FirebaseAuth.instance.signInAnonymously();
}


final String? kullaniciId =
    widget.doktorMu == true
        ? widget.doktorId
        : widget.bashekimId;

if (kullaniciId == null) {
  return;
}



  try {
    int toplamKanTalebi = kanTalepleri.length;

    // Eğer güncelleme yapılıyorsa, eski ilanın kan taleplerini say
    if (widget.ilanId != null) {

      final mevcutDoc = await FirebaseFirestore.instance
          .collection('ilanlar')
          .doc(widget.ilanId)
          .get();

      if (mevcutDoc.exists && mevcutDoc.data() != null) {
        

        final eskiTalepler = List.from(mevcutDoc['kanTalepleri'] ?? []);
       

int toplamKanTalebi = kanTalepleri.length;

      } else {
      }
    }

     if (toplamKanTalebi > 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Toplamda en fazla 5 kan talebi olabilir.')),
    );
    return;
  }

  // ✅ Buradan sonrası mevcut kaydetme işlemin

  // 🔥 YENİ İLAN / GÜNCELLEME AYRIMI

if (widget.ilanId == null) {

  final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
    .httpsCallable('addIlan');

  bool basarili = false;

try {
  await callable.call({
    "doktorId": kullaniciId,
    "bashekimId": doktoruEkleyenBashekimId ?? widget.bashekimId,
    "sehir": _secilenSehir,
    "hastane": _hastaneController.text,
    "ilce": _secilenIlce,
    "kanTalepleri": kanTalepleri,
    "acil": kanTalepleri.any((t) => t['acil'] == true),
    "not": "",
  });

  // ✅ direkt başarı
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('İlan başarıyla eklendi')),
  );

  if (mounted) Navigator.pop(context);
  return;

} catch (e) {

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Bugün en fazla 5 ilan ekleyebilirsiniz')),
  );

  return;
}

} else {

}

} catch (e) {
  // 🔥 Hata yakalama (ilk try bloğu)
}

// 🔥 LOG: İlan kaydetme/güncelleme fonksiyonu başladı

try {
  final sistemDoc = await FirebaseFirestore.instance
      .collection("ayarlar")
      .doc("sistem")
      .get();

  final sistemKilitli = sistemDoc.data()?['kilit'] ?? false;

  if (sistemKilitli && !(widget.bashekimId?.startsWith("admin_") ?? false)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Sistem şu anda kilitli. Sadece admin işlem yapabilir!"),
      ),
    );
    return;
  }



 final List<String> adminUids = [
];

final String? girisYapanUid =
    FirebaseAuth.instance.currentUser?.uid;

final bool adminMi =
    girisYapanUid != null &&
    adminUids.contains(girisYapanUid);






// 🔥 LOG: Güncelleme sayısı ve günlük limit kontrolü başlıyor
int guncellemeSayisi = 0;

if (widget.ilanId != null) {

  final ilanDoc = await FirebaseFirestore.instance
      .collection('ilanlar')
      .doc(widget.ilanId)
      .get();

  if (!ilanDoc.exists) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Güncellenmek istenen ilan bulunamadı!')),
    );
    return;
  }

final data = ilanDoc.data();

guncellemeSayisi =
    (data != null && data.containsKey('guncellemeSayisi'))
        ? data['guncellemeSayisi']
        : 0;  

  // 🚨 LIMIT SADECE İLAN SAHİBİNE
  final String ilanSahibiId = ilanDoc['doktorId'].toString();

// 🔥 SADECE GÜNCELLEMEDE AKTİF KULLANICI
final String guncelleyenId =
    adminUids.contains(doktoruEkleyenBashekimId)
        ? doktoruEkleyenBashekimId!
        : (widget.doktorMu == true
            ? widget.doktorId!
            : widget.bashekimId!);


// 🔥 ROL BELİRLEME
final String ilanBashekimId =
    ilanDoc['bashekimId'].toString();

final String aktifKullaniciId =
    doktoruEkleyenBashekimId ??
    widget.bashekimId ??
    '';



// 🔥 LIMIT: Admin dışındaki herkes max 2
if (!adminMi && guncellemeSayisi >= 2) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Bu ilan en fazla 2 kez güncellenebilir!'),
    ),
  );
  return;
}




  } else {
    // 🆕 Yeni ilan ekleniyorsa

    // Admin değilse sınır kontrolü yap
    if (!(kullaniciId?.startsWith('admin_') ?? false) && !(adminUids.contains(kullaniciId))) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final query = await FirebaseFirestore.instance
    .collection('gunluk_kayitlar')
    .where('ekleyenId', isEqualTo: kullaniciId)
    .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
    .where('tarih', isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
    .get();



      if (query.docs.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bugün en fazla 5 ilan ekleyebilirsiniz!')),
        );
        return;
      }
    }
  }



// Boş alan kontrolü
if (_secilenSehir == null ||
    _secilenIlce == null ||
    _hastaneController.text.isEmpty ||
    kanTalepleri.isEmpty ||
    kanTalepleri.any((t) => t['kanGrubu'] == null || t['aciklama'] == null)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Tüm alanları ve tüm talepleri doldurun')),
  );
  for (var t in kanTalepleri) {
  }
  return;
}

 final Map<String, dynamic> veri = {
  'sehir': normalize(_secilenSehir!),
  'ilce': _secilenIlce,
  'hastane': _hastaneController.text,
  'kanTalepleri': kanTalepleri,

  // 🔥 ACİL DOĞRU HESAP
  'acil': kanTalepleri.any((t) => t['acil'] == true),

  // 🔥 KRİTİK FIX → HER ZAMAN +1
  'guncellemeSayisi': widget.ilanId == null
      ? 0
      : guncellemeSayisi + 1,

  // 🔥 RULES İÇİN ZORUNLU
  'bashekimId':
      doktoruEkleyenBashekimId ?? widget.bashekimId,

  'doktorId': widget.doktorMu == true
      ? widget.doktorId
      : null,
};



if (widget.ilanId == null) {

veri['ekleyenId'] = kullaniciId;

final bool doktorMu = widget.doktorMu == true;

if (doktorMu) {
  // 👨‍⚕️ Doktor ilan ekliyor
  veri['doktorId'] = widget.doktorId;
  veri['bashekimId'] = doktoruEkleyenBashekimId ?? widget.bashekimId;
} else {
  // 👨‍💼 Başhekim / Admin ilan ekliyor
  veri['doktorId'] = null;
  veri['bashekimId'] = widget.bashekimId;
}


  veri['eklenmeTarihi'] = FieldValue.serverTimestamp();


  final hashVeri = {
    'sehir': veri['sehir'],
    'ilce': veri['ilce'],
    'hastane': veri['hastane'],
    'kanTalepleri': veri['kanTalepleri'],
    'acil': veri['acil'],
    'doktorId': veri['doktorId'],
    'bashekimId': veri['bashekimId'],
  };

  final hash = uretHash(hashVeri);





 
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('İlan başarıyla eklendi')),
);

} else {
  // 🔄 Güncellenen ilanın mevcut doktor ve başhekim ID'leri kaybolmasın diye önce alıyoruz
  
  final mevcutDoc = await FirebaseFirestore.instance
      .collection('ilanlar')
      .doc(widget.ilanId)
      .get();

  if (mevcutDoc.exists) {
    

    veri['doktorId'] = mevcutDoc['doktorId'];
    veri['bashekimId'] = mevcutDoc['bashekimId'];
  } else {
  }

  final hashVeri = {
  'sehir': veri['sehir'],
  'ilce': veri['ilce'],
  'hastane': veri['hastane'],
  'kanTalepleri': veri['kanTalepleri'],
  'acil': veri['acil'],
  'doktorId': veri['doktorId'],
  'bashekimId': veri['bashekimId'],
};


 final hash = uretHash(hashVeri);


final callable = FirebaseFunctions.instance.httpsCallable('updateIlan');

veri['sehir'] = normalize(_secilenSehir!); // 💥 ZORLA OVERRIDE
await callable.call({
  "ilanId": widget.ilanId,
  "updates": {
    ...veri,
    "hash": hash,
  },
});


  print("✅ İlan başarıyla güncellendi");

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('İlan başarıyla güncellendi')),
  );
}

if (mounted) Navigator.pop(context);

  } catch (e, stack) {
    

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Hata oluştu: ${e.toString()}")), // Hata mesajını daha okunur yapalım
    );
  }
}

bool _isSubmitting = false;

    Future<void> _submitIlan() async {
  if (_isSubmitting) return;

  setState(() => _isSubmitting = true);

  try {
    await _ilanKaydet();
  } catch (e) {
    debugPrint('İlan kaydetme hatası: $e');
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.ilanId == null ? 'Yeni İlan Ekle' : 'İlanı Güncelle'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          DropdownButtonFormField<String>(
   value: _secilenSehir != null &&
        sehirler.contains(_secilenSehir)
    ? _secilenSehir
    : null,
            items: sehirler
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              setState(() {
                _secilenSehir = v;
                _secilenIlce = null;
              });
            },
            decoration: const InputDecoration(labelText: 'Şehir'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _secilenIlce,
            items: _secilenSehir == null
                ? []
                : ilceler[_secilenSehir!]!
                    .map((i) =>
                        DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
            onChanged: (v) => setState(() => _secilenIlce = v),
            decoration: const InputDecoration(labelText: 'İlçe'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hastaneController,
            decoration: const InputDecoration(labelText: 'Hastane Adı'),
          ),
          const SizedBox(height: 20),
          const Divider(),

          /// 🔽 KAN TALEPLERİ
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kanTalepleri.length,
            itemBuilder: (ctx, i) {
              final talep = kanTalepleri[i];
              return Card(
                color:
                    talep['acil'] == true ? Colors.red[50] : Colors.white,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: talep['kanGrubu'],
                              items: kanGruplari
                                  .map((k) => DropdownMenuItem(
                                      value: k, child: Text(k)))
                                  .toList(),
                              onChanged: (v) => setState(() =>
                                  kanTalepleri[i]['kanGrubu'] = v),
                              decoration: const InputDecoration(
                                  labelText: 'Kan Grubu'),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _talepSil(i),
                            icon: const Icon(Icons.delete,
                                color: Colors.red),
                          ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: talep['aciklama'],
                        items: aciklamalar
                            .map((a) => DropdownMenuItem(
                                value: a, child: Text(a)))
                            .toList(),
                        onChanged: (v) => setState(() =>
                            kanTalepleri[i]['aciklama'] = v),
                        decoration: const InputDecoration(
                            labelText: 'Açıklama'),
                      ),
                      SwitchListTile(
                        value: talep['acil'] ?? false,
                        onChanged: (v) => setState(() =>
                            kanTalepleri[i]['acil'] = v),
                        title: const Text('Acil mi?'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed:
                kanTalepleri.length < 3 ? _talepEkle : null,
            icon: const Icon(Icons.health_and_safety,
                color: Colors.red),
            label: const Text("Yeni Kan Talebi Ekle"),
          ),

          const SizedBox(height: 16),

          /// 🔒 SPAM KİLİTLİ SUBMIT
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitIlan,
            child: Text(
              _isSubmitting
                  ? 'Lütfen bekleyin...'
                  : (widget.ilanId == null
                      ? 'İlanı Ekle'
                      : 'Güncelle'),
            ),
          ),
        ],
      ),
    ),
  );
}
}