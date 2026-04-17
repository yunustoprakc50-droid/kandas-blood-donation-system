import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ilan_ekle.dart';
import 'bashekim_yonet.dart';
import 'doktor_yonet.dart';

class AdminPanel extends StatefulWidget {
  final String adminId;
  const AdminPanel({super.key, required this.adminId});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  bool sistemKilitliMi = false;
  final String _kilitSifresi = "REMOVED_PASSWORD";

  @override
  void initState() {
    super.initState();
    _sistemKilidiniYukle();
  }

  Future<void> _sistemKilidiniYukle() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("ayarlar")
          .doc("sistem")
          .get();

      setState(() {
        sistemKilitliMi = doc.data()?['kilit'] ?? false;
      });

    } catch (e) {
    }
  }

  Future<void> _kilidiDegistir() async {
    final controller = TextEditingController();
    final sonuc = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Sistem Kilidi"),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Kilit şifresi"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () {
              final dogru = controller.text == _kilitSifresi;
              Navigator.pop(context, dogru);
            },
            child: const Text("Onayla"),
          ),
        ],
      ),
    );

    if (sonuc == true) {
      await FirebaseFirestore.instance
          .collection("ayarlar")
          .doc("sistem")
          .update({"kilit": !sistemKilitliMi});

      setState(() => sistemKilitliMi = !sistemKilitliMi);


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sistemKilitliMi
              ? "Sistem KİLİTLENDİ 🔒"
              : "Sistem AÇILDI ✅"),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şifre yanlış ya da işlem iptal edildi.")),
      );
    }
  }
Future<Map<String, String>> _isimleriGetir(
  String bashekimId,
  String doktorId,
) async {
  String bashekimAdi = bashekimId;
  String doktorAdi = doktorId;

  try {
    final bDoc = await FirebaseFirestore.instance
        .collection('bashekimler')
        .doc(bashekimId)
        .get();
    if (bDoc.exists) {
      bashekimAdi = bDoc.data()?['ad'] ?? bashekimId;
    }
  } catch (_) {}

  try {
    final dDoc = await FirebaseFirestore.instance
        .collection('doktorlar')
        .doc(doktorId)
        .get();
    if (dDoc.exists) {
      doktorAdi = dDoc.data()?['ad'] ?? doktorId;
    }
  } catch (_) {}

  return {
    'bashekim': bashekimAdi,
    'doktor': doktorAdi,
  };
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        actions: [
          IconButton(
            icon: Icon(Icons.lock,
                color: sistemKilitliMi ? Colors.red : Colors.green),
            tooltip:
                sistemKilitliMi ? "Sistem Kilitli" : "Sistem Açık - Kilitle",
            onPressed: _kilidiDegistir,
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BashekimYonetPage()),
                  );
                },
                child: const Text("Başhekimleri Yönet"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DoktorYonetPage()),
                  );
                },
                child: const Text("Doktorları Yönet"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Tüm İlanlar:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ilanlar')
                  .orderBy('eklenmeTarihi', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Henüz ilan yok.'));
                }

                final ilanlar = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: ilanlar.length,
                  itemBuilder: (context, i) {
                    final doc = ilanlar[i];
                    final data = doc.data() as Map<String, dynamic>? ?? {};
                    final bashekimId = data['bashekimId'] ?? '-';
                    final doktorId = data['doktorId'] ?? '-';

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(data['hastane'] ?? ''),
                       subtitle: FutureBuilder<Map<String, String>>(
  future: _isimleriGetir(bashekimId, doktorId),
  builder: (context, snap) {
    final bashekimAdi = snap.data?['bashekim'] ?? bashekimId;
    final doktorAdi = snap.data?['doktor'] ?? doktorId;

    return Text(
      '${data['aciklama'] ?? ''}\n'
      'Başhekim: $bashekimAdi\n'
      'Doktor: $doktorAdi',
    );
  },
),
isThreeLine: true,

                        
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IlanEklePage(
                                  ilanId: doc.id,
                                  mevcutIlan: data,
                                  bashekimId: bashekimId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IlanEklePage(bashekimId: widget.adminId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
