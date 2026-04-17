import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_panel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GoogleSignInPage extends StatefulWidget {
  const GoogleSignInPage({super.key});

  @override
  State<GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  bool _isSigningIn = false;

  final String izinliUid = "REMOVED_UID"; // 🔐 Yetkili UID
  final String adminId = "admin_0001";
  final String _webClientId = "REMOVED_CLIENT_ID";

  Future<void> _handleSignIn() async {
    setState(() => _isSigningIn = true);

    try {
      User? user;

     if (kIsWeb) {
  final googleUser = await GoogleSignIn(clientId: _webClientId).signIn();

  if (googleUser == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Giriş iptal edildi")),
    );
    return;
  }

  final googleAuth = await googleUser.authentication;
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );

  final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
  user = userCredential.user;
}
 else {
        // 📱 ANDROID GİRİŞİ
        final googleUser = await GoogleSignIn().signIn();

        if (googleUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Giriş iptal edildi")),
          );
          return;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        user = userCredential.user;
      }


      if (user?.uid == izinliUid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('girisYapanBashekimId', adminId);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Giriş başarılı ✅")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => AdminPanel(adminId: adminId)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu kullanıcı yetkili değil ❌")),
        );
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bir hata oluştu ❗")),
      );
    } finally {
      setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: _isSigningIn
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("Google ile Giriş Yap"),
                onPressed: _handleSignIn,
              ),
      ),
    );
  }
}
