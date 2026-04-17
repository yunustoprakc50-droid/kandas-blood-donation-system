import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'doktor_panel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoktorLogin extends StatefulWidget {
  const DoktorLogin({super.key});

  @override
  State<DoktorLogin> createState() => _DoktorLoginState();
}

class _DoktorLoginState extends State<DoktorLogin> {
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
      final response = await http.post(
        Uri.parse(_loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'doktorId': id,
          'sifre': sifre,
        }),
      );

      

      Map<String, dynamic> data = {};
try {
  data = jsonDecode(response.body);
} catch (_) {
  data = {"success": false, "message": "Sunucu hatası"};
}
      if (data['success'] == true) {
        debugPrint('✅ Doktor giriş başarılı: $id');

        // 🔥 Önce eski auth'u temizle
        await FirebaseAuth.instance.signOut();

        // 🔐 Yeni anonymous auth oluştur
        final userCredential =
            await FirebaseAuth.instance.signInAnonymously();

        final user = userCredential.user;

        if (user == null) {
          debugPrint("❌ UID alınamadı");

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Firebase kimlik doğrulama hatası")),
            );
          }

          return;
        }

        final uid = user.uid;
        debugPrint("🔐 Yeni UID: $uid");

        // 🔐 aktifUid bağla
        await FirebaseFirestore.instance
            .collection('doktorlar')
            .doc(id)
            .set({
          'aktifUid': uid,
          'sonGiris': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DoktorPanel(
              kullaniciId: id,
              doktorMu: true,
            ),
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
    } catch (e) {
      debugPrint("🔥 Doktor login hata: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Giriş hatası")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: const Text('Doktor Giriş')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Doktor ID'),
            ),
            TextField(
              controller: _sifreController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Şifre'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Giriş Yap'),
            ),
            // 🔥 BURAYA
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
    "Tüm işlemler kayıt altına alınmaktadır.\n"
    "Kötüye kullanımda sorumluluk kullanıcıya aittir.",
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
    );
  }
}