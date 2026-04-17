import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:bcrypt/bcrypt.dart';

class BashekimEklePage extends StatefulWidget {
  const BashekimEklePage({super.key});

  @override
  State<BashekimEklePage> createState() => _BashekimEklePageState();
}

String sifreHashle(String sifre) {
  return BCrypt.hashpw(sifre, BCrypt.gensalt());
}

String uretHash(Map<String, dynamic> data) {
  final keys = data.keys.toList()..sort();
  final buffer = StringBuffer();
  for (final k in keys) {
    buffer.write('$k=${data[k]}|');
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

class _BashekimEklePageState extends State<BashekimEklePage> {
  final TextEditingController _isimController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();

  String? _yeniBashekimId;
  bool _isProcessing = false; // 🔥 Spam engelleme

  Future<void> _bashekimEkle() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      
      final isim = _isimController.text.trim();
      final sifre = _sifreController.text.trim();

      if (isim.isEmpty || sifre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tüm alanları doldurun.")),
        );
        return;
      }

      final collection =
          FirebaseFirestore.instance.collection('bashekimler');

      final querySnapshot = await collection
          .orderBy('eklenme_tarihi', descending: true)
          .limit(1)
          .get();

      int sonIdNumarasi = 0;
      if (querySnapshot.docs.isNotEmpty) {
        final sonId = querySnapshot.docs.first.id;
        sonIdNumarasi = int.tryParse(sonId.substring(3)) ?? 0;
      }

      final yeniId =
          "034${(sonIdNumarasi + 1).toString().padLeft(6, '0')}";

      final payload = {
        "ad": isim,
        "sifreHash": sifreHashle(sifre),
      };

      final hash = uretHash(payload);

      await collection.doc(yeniId).set({
        ...payload,
        "eklenme_tarihi": FieldValue.serverTimestamp(),
        "hash": hash,
      });

      setState(() {
        _yeniBashekimId = yeniId;
      });

      _isimController.clear();
      _sifreController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Başhekim başarıyla eklendi. ID: $yeniId")),
      );
    } catch (e) {
      debugPrint("Hata oluştu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu")),
      );
    } finally {
      await Future.delayed(const Duration(seconds: 2)); // 🔥 2 sn kilit
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Başhekim Ekle")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_yeniBashekimId == null) ...[
              TextField(
                controller: _isimController,
                decoration: const InputDecoration(labelText: "İsim"),
              ),
              TextField(
                controller: _sifreController,
                decoration: const InputDecoration(labelText: "Şifre"),
                obscureText: true,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isProcessing ? null : _bashekimEkle,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Kaydet"),
              ),
            ] else ...[
              const Icon(Icons.verified_user,
                  color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text(
                "Başhekim ID'niz:",
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SelectableText(
                _yeniBashekimId!,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Lütfen bu numarayı kaydedin!",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _yeniBashekimId = null);
                },
                icon: const Icon(Icons.add),
                label: const Text("Yeni Başhekim Ekle"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(180, 48),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}