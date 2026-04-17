import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'bashekim_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BashekimLogin extends StatefulWidget {
  const BashekimLogin({super.key});

  @override
  State<BashekimLogin> createState() => _BashekimLoginState();
}

class _BashekimLoginState extends State<BashekimLogin> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();
  bool _loading = false;

  static const String _loginUrl = 'YOUR_API_URL';

Future<void> _login() async {
  final String id = _idController.text.trim();
  final String sifre = _sifreController.text.trim();

 
  if (id.isEmpty || sifre.isEmpty) {
    debugPrint("❌ ID veya şifre boş");

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ID ve şifre boş olamaz")),
      );
    }

    return;
  }

  setState(() => _loading = true);

  try {
    debugPrint("🌍 HTTP login isteği atılıyor...");

    final response = await http.post(
      Uri.parse(_loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bashekimId': id,
        'sifre': sifre,
      }),
    );

   

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      debugPrint('✅ Başhekim giriş başarılı (Cloud Function)');

      // 🔐 Eski session temizle
      debugPrint("🔄 Eski FirebaseAuth session temizleniyor...");
      await FirebaseAuth.instance.signOut();

      debugPrint("🔐 Anonymous auth başlatılıyor...");
      final userCredential =
          await FirebaseAuth.instance.signInAnonymously();

      final user = userCredential.user;

      if (user == null) {
        debugPrint("❌ Anonymous UID alınamadı");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Firebase kimlik doğrulama hatası")),
          );
        }

        return;
      }

      final uid = user.uid;
     
      debugPrint("✍ Firestore aktifUid yazılıyor...");
      await FirebaseFirestore.instance
          .collection('bashekimler')
          .doc(id)
          .set({
        'aktifUid': uid,
        'sonGiris': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("✅ aktifUid başarıyla yazıldı");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('girisYapanBashekimId', id);

      debugPrint("➡ SharedPreferences kaydedildi");

      if (!mounted) return;

      debugPrint("➡ BashekimPanel'e yönlendiriliyor");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BashekimPanel(bashekimId: id),
        ),
      );
    } else {
  debugPrint("❌ Giriş başarısız (Cloud Function success false)");

  if (mounted) {
    final msg = data['message'] ?? "Giriş başarısız";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            msg.contains("10 dakika") ? Colors.red : Colors.orange,
      ),
    );
  }
}
  } catch (e, stack) {
    debugPrint('🔥 LOGIN ERROR: $e');
   

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Giriş hatası")),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}


  @override
  void dispose() {
    _idController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Başhekim Giriş')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _idController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Başhekim ID'),
              ),
              TextField(
                controller: _sifreController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Şifre'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Giriş Yap'),
              ),
              const SizedBox(height: 12),
Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.red.withOpacity(0.1),
    border: Border.all(color: Colors.red),
    borderRadius: BorderRadius.circular(8),
  ),
  child: const Text(
    "Bu sistem yalnızca yetkili personel içindir.\n"
    "Tüm giriş ve işlemler kayıt altına alınmaktadır.\n"
    "Yetkisiz kullanım durumunda yasal işlem uygulanır.",
    style: TextStyle(
      fontSize: 12,
      color: Colors.red,
      fontWeight: FontWeight.w500,
    ),
    textAlign: TextAlign.center,
  ),
),
            ],
          ),
        ),
      ),
    );
  }
}