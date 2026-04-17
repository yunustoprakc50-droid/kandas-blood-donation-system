import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_panel.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  Future<void> _googleLogin() async {
    try {
      final googleSignIn = kIsWeb
          ? GoogleSignIn(
              clientId:
                  "REMOVED_CLIENT_ID",
            )
          : GoogleSignIn();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Giriş iptal edildi ❌")),
        );
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      final uid = user?.uid;

      if (uid == null) {
        throw Exception("UID alınamadı.");
      }

      // 🔍 Firestore'dan admin kontrolü
      final adminDoc = await FirebaseFirestore.instance
          .collection('adminler')
          .doc(uid)
          .get();

      if (adminDoc.exists) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('girisYapanBashekimId', uid); // UID artık admin ID

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Giriş başarılı ✅")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminPanel(adminId: uid),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu kullanıcı yetkili değil ❌")),
        );
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
debugPrint("🚨 Giriş hatası");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bir hata oluştu ❗")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Giriş')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text(
              'Sadece Yetkili Kullanıcı Girebilir',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text("Google ile Giriş Yap"),
              onPressed: _googleLogin,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
