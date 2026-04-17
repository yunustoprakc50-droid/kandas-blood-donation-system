import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:bcrypt/bcrypt.dart';

class DoktorEklePage extends StatefulWidget {
  final String? bashekimId;
  const DoktorEklePage({super.key, this.bashekimId});

  @override
  State<DoktorEklePage> createState() => _DoktorEklePageState();
}


class _DoktorEklePageState extends State<DoktorEklePage> {
  
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final TextEditingController _adController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();
  String? _yeniDoktorId;
  bool _isProcessing = false;

 String hashSifre(String sifre) {
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

 bool isAdmin(String? uid) {
  return uid == "ADMIN_UID";
}

  Future<void> _doktorEkle() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final sistemDoc = await FirebaseFirestore.instance
          .collection("ayarlar")
          .doc("sistem")
          .get();

      final sistemKilitli = sistemDoc.data()?['kilit'] ?? false;

      if (sistemKilitli && !isAdmin(uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Sistem şu anda kilitli. Sadece admin işlem yapabilir!")),
        );
        return;
      }

      final ad = _adController.text.trim();
      final sifre = _sifreController.text.trim();

      if (ad.isEmpty || sifre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tüm alanları doldurun.")),
        );
        return;
      }

      if (widget.bashekimId != null &&
          !widget.bashekimId!.startsWith('admin_') &&
          !isAdmin(uid)) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));

        final query = await FirebaseFirestore.instance
            .collection('doktorlar')
            .where('bashekimId', isEqualTo: widget.bashekimId)
            .where('eklenme_tarihi',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('eklenme_tarihi',
                isLessThanOrEqualTo: Timestamp.fromDate(todayEnd))
            .get();

        if (query.docs.length >= 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Bugün en fazla 5 doktor ekleyebilirsiniz!')),
          );
          return;
        }
      }

      final collection =
          FirebaseFirestore.instance.collection('doktorlar');

      final snapshot = await collection
          .orderBy('eklenme_tarihi', descending: true)
          .limit(1)
          .get();

      int sonId = 60000000;
      if (snapshot.docs.isNotEmpty) {
        final son = int.tryParse(snapshot.docs.first.id);
        if (son != null) sonId = son;
      }

      if (!(isAdmin(uid) ||
      
          widget.bashekimId?.startsWith("034") == true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yetkisiz işlem!")),
        );
        return;
      }

      final yeniId = (sonId + 1).toString();

      if (widget.bashekimId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Başhekim ID bulunamadı!")),
        );
        return;
      }

      final String bashekimId = widget.bashekimId!;

      final payload = {
        "ad": ad,
        "sifreHash": hashSifre(sifre),
        "bashekimId": bashekimId.toString(),
      };

      final hash = uretHash(payload);


final result = await FirebaseFunctions.instance
    .httpsCallable('doktorLimitKontrol')
    .call({
  "bashekimId": widget.bashekimId,

});



if (result.data['izin'] == false) {
 

  setState(() {
    _isProcessing = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("En fazla 5 doktor ekleyebilirsiniz!")),
  );
  return;
}


      await FirebaseFunctions.instance
    .httpsCallable('doktorEkle')
    .call({
  "bashekimId": bashekimId,
  "doktorId": yeniId,
  "ad": ad,
  "sifre": sifre,
});

      setState(() {
        _yeniDoktorId = yeniId;
      });

      _adController.clear();
      _sifreController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Doktor başarıyla eklendi. ID: $yeniId")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu: $e")),
      );
    } finally {
      await Future.delayed(const Duration(seconds: 2));
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
      appBar: AppBar(title: const Text("Doktor Ekle")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_yeniDoktorId == null) ...[
              TextField(
                controller: _adController,
                decoration:
                    const InputDecoration(labelText: "Ad Soyad"),
              ),
              TextField(
                controller: _sifreController,
                decoration:
                    const InputDecoration(labelText: "Şifre"),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isProcessing ? null : _doktorEkle,
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text("Kaydet"),
              ),
            ] else ...[
              const Icon(Icons.verified_user,
                  color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text(
                "Doktor ID'niz:",
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SelectableText(
                _yeniDoktorId!,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
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
                  setState(() => _yeniDoktorId = null);
                },
                icon: const Icon(Icons.add),
                label: const Text("Yeni Doktor Ekle"),
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