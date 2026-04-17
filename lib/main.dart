import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kandas/pages/admin_login.dart';
import 'package:kandas/pages/bashekim_login.dart';
import 'package:kandas/pages/doktor_login.dart';
import 'package:kandas/pages/ilan_listele.dart';
import 'firebase_options.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();


const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'kandas_kan_kanali',
  'Acil Kan Bildirimleri',
  description: 'Acil durum bildirimi için yüksek öncelikli kanal',
  importance: Importance.max,
);


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 Arka planda mesaj geldi: \${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

// 🔐 APP CHECK AKTİF (GEÇİCİ KAPALI TEST İÇİN)

// await FirebaseAppCheck.instance.activate(
//   androidProvider: AndroidProvider.debug,
//   webProvider: kIsWeb
//       ? ReCaptchaV3Provider('6Lc2EGAsAAAAAGP7sElfltQXyoaQr8FEAX1d-7Ay')
//       : null,
// );



  // 🔔 Android için bildirim kanalı
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler);

  await setupFirebaseMessaging();

  runApp(const MyApp());
}

void firestoreTest() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('ilanlar')
        .doc('kan_ilani_istanbul')
        .get();

    if (doc.exists) {
    } else {
    }
  } catch (e) {
  }
}


Future<void> setupFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings;
  try {
    settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint('⚠️ Bildirim izni alınamadı');
    return;
  }

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    debugPrint('📲 Bildirim izni verildi.');
    try {
      String? token = await messaging.getToken();
      debugPrint('📱 TOKEN: alındı');
    } catch (e) {
      debugPrint('⚠️ Token alınamadı');
    }
  } else {
    debugPrint('🚫 Bildirim izni verilmedi.');
  }


  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('📬 Bildirime tıklandı, uygulama açıldı.');
  });
}

String temizSehir(String sehir) {
  return sehir.toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KANDAŞ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  Timer? _basiliTimer; 
  String? _secilenSehir;
  bool _yuklendi = false; 
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

Future<void> _bildirimAboneligiAktifEt() async {
  if (_secilenSehir == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('⚠️ Önce bir şehir seçmelisin.')),
    );
    return;
  }

  final topic = "city_${temizSehir(_secilenSehir!)}";
  await FirebaseMessaging.instance.subscribeToTopic(topic);

  ScaffoldMessenger.of(context).showSnackBar(
  );
}

  @override
  void initState() {
    super.initState();
    _sehirYukle();
  }

  void _sehirYukle() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _secilenSehir = prefs.getString("secilenSehir");
    _yuklendi = true;
  });
}

  void _sehirKaydet(String sehir) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("secilenSehir", sehir);
  }

  void _sehirSecVeGit() async {
    if (_secilenSehir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir şehir seçin')),
      );
      return;
    }

 final topic = "city_${temizSehir(_secilenSehir!)}";
if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  await FirebaseMessaging.instance.subscribeToTopic(topic);
  debugPrint("✅ Topic'e abone olundu: $topic");
}

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IlanListelePage(secilenSehir: _secilenSehir!),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: _yuklendi
    ? Column(
        children: [

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTapDown: (_) {
                    _basiliTimer = Timer(const Duration(seconds: 3), () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLogin(),
                        ),
                      );
                    });
                  },
                  onTapUp: (_) => _basiliTimer?.cancel(),
                  onTapCancel: () => _basiliTimer?.cancel(),
                  child: Image.asset(
                    'assets/images/kandas.png',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 30),

                DropdownButtonFormField<String>(
                  value: _secilenSehir,
                  items: sehirler
                      .map((sehir) => DropdownMenuItem(
                          value: sehir, child: Text(sehir)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _sehirKaydet(v);
                      setState(() => _secilenSehir = v);
                    }
                  },
                  decoration: const InputDecoration(labelText: 'Şehir Seçin'),
                ),

                const SizedBox(height: 20),

                if (_secilenSehir != null)
                  ElevatedButton.icon(
                    onPressed: _bildirimAboneligiAktifEt,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text(" Bu Şehre Bildirim Abonesi Ol"),
                  ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed:
                      _secilenSehir == null ? null : _sehirSecVeGit,
                  icon: const Icon(Icons.list),
                  label: const Text("İlanları Gör"),
                ),

                const SizedBox(height: 40),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BashekimLogin()),
                    );
                  },
                  child: const Text("Başhekim Giriş"),
                ),

                const SizedBox(height: 12),

                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DoktorLogin()),
                    );
                  },
                  child: const Text("Doktor Giriş"),
                ),
              ],
            ),
          ),

          /// 🔐 KVKK ALT YAZI (EN ALT)
          SafeArea(
  top: false,
  child: Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      "Bu uygulamada kişisel veri toplanmaz. Paylaşılan bilgiler yalnızca hastane bazlı anonim kan ihtiyaçlarını içerir.",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey[600],
      ),
    ),
  ),
),
        ],
      )
    : const Center(child: CircularProgressIndicator()),
      ),
    ),
  );
}
}