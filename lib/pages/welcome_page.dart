import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'admin_login.dart';
import 'bashekim_login.dart';
import 'doktor_login.dart';
import 'ilan_listele.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  String? _secilenSehir;
  bool _loading = true;

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

  @override
  void initState() {
    super.initState();
    _sehirYukle();
    _resetToken();
  }

  void _sehirYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _secilenSehir = prefs.getString("secilenSehir");
      _loading = false;
    });
  }

  void _sehirKaydet(String sehir) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("secilenSehir", sehir);
  }

  String temizSehir(String sehir) {
    return sehir.toLowerCase()
        .replaceAll('i̇', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _resetToken() async {
    await FirebaseMessaging.instance.deleteToken();
    final newToken = await FirebaseMessaging.instance.getToken();
  }

  Future<void> temizleTumSehirAbonelikleri() async {
    final tumSehirler = sehirler.map((s) => temizSehir(s)).toList();
    for (final sehir in tumSehirler) {
      final topic = "city_$sehir";
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    }
  }

  Future<void> _bildirimAboneligiAktifEt() async {
    if (_secilenSehir == null) return;

    final topic = "city_${temizSehir(_secilenSehir!)}";
    await FirebaseMessaging.instance.subscribeToTopic(topic);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $topic için bildirimlere abone olundu.')),
    );
  }

  void _ilanlariGor() async {
    if (_secilenSehir == null || _secilenSehir!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❗ Lütfen bir şehir seçin')),
      );
      return;
    }

    final temizTopic = "city_${temizSehir(_secilenSehir!)}";

    await temizleTumSehirAbonelikleri();
    await FirebaseMessaging.instance.subscribeToTopic(temizTopic);
    _sehirKaydet(_secilenSehir!);


    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ ${_secilenSehir!} sayfası açılıyor...')),
    );

    await Future.delayed(const Duration(milliseconds: 500));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IlanListelePage(secilenSehir: _secilenSehir!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'KANDAŞ',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 30),

                // Şehir seçimi
                DropdownButtonFormField<String>(
                  value: _secilenSehir,
                  hint: const Text("Şehir seçin"),
                  decoration: const InputDecoration(labelText: 'Şehir Seçin'),
                  items: sehirler
                      .map((sehir) => DropdownMenuItem(value: sehir, child: Text(sehir)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _secilenSehir = v);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Bildirim abone butonu sadece şehir seçilince
               if (_secilenSehir != null)
  ElevatedButton.icon(
    onPressed: _bildirimAboneligiAktifEt,
    icon: const Icon(Icons.notifications_active),
    label: const Text("🔔 Bu Şehre Bildirim Abonesi Ol"),
  ),


                const SizedBox(height: 10),

                // İlanları gör
                ElevatedButton.icon(
                  onPressed: _secilenSehir == null ? null : _ilanlariGor,
                  icon: const Icon(Icons.list),
                  label: const Text("İlanları Gör"),
                ),

                const SizedBox(height: 40),

                // Giriş butonları
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLogin()));
                  },
                  child: const Text("Admin Giriş"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BashekimLogin()));
                  },
                  child: const Text("Başhekim Giriş"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DoktorLogin()));
                  },
                  child: const Text("Doktor Giriş"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
