import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doktor_yonet.dart';
import 'ilan_ekle.dart';

class BashekimPanel extends StatefulWidget {
  final String bashekimId;
  const BashekimPanel({super.key, required this.bashekimId});

  @override
  State<BashekimPanel> createState() => _BashekimPanelState();
}

class _BashekimPanelState extends State<BashekimPanel> {
  List<String> izinliDoktorIdList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _getIzinliDoktorlar();
  }

Future<String> _doktorAdiGetir(dynamic doktorId) async {
  final String id = doktorId.toString().trim();
  if (id.isEmpty || id == '-') return '-';

  try {
    final doc = await FirebaseFirestore.instance
        .collection('doktorlar')
        .doc(id) // 🔥 BURASI ÖNEMLİ
        .get();

    if (!doc.exists) return id;

    return doc.data()?['ad'] ?? id;
  } catch (e) {
    return id;
  }
}


 Future<void> _getIzinliDoktorlar() async {
  try {
    Query query = FirebaseFirestore.instance.collection('doktorlar');

    // 👑 ADMIN → TÜM DOKTORLAR
    if (!widget.bashekimId.startsWith('034')) {
      // admin → where YOK
    } else {
      // 🏥 Başhekim → sadece kendi doktorları
      query = query.where(
        'bashekimId',
        isEqualTo: widget.bashekimId.trim(),
      );
    }

    final doktorQuery = await query.get();

    final ids = doktorQuery.docs
        .map((e) => e.id.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    izinliDoktorIdList = ids;


    setState(() => isLoading = false);
  } catch (e) {
    debugPrint("Doktor listesi alınamadı: $e");
    setState(() => isLoading = false);
  }
}


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Liste yine boşsa korumalı davran (en azından kendi ilanlarını görebilsin)
      final bool isAdmin = !widget.bashekimId.startsWith('034');

  final stream = isAdmin
      // 👑 ADMIN → TÜM İLANLAR
      ? FirebaseFirestore.instance
          .collection('ilanlar')
          .snapshots()

      // 🏥 BAŞHEKİM → SADECE KENDİ İLANLARI
      : FirebaseFirestore.instance
          .collection('ilanlar')
          .where('bashekimId', isEqualTo: widget.bashekimId.trim())
          .snapshots();




    return Scaffold(
      appBar: AppBar(
        title: const Text('Başhekim Paneli'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.group, size: 18),
            label: const Text("Doktorları Yönet"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoktorYonetPage()),
              );
            },
          )
        ],
      ),
      
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata oluştu'));
          }
          final docs = snapshot.data?.docs ?? [];

          // debug
          // ignore: avoid_print

          if (docs.isEmpty) {
            return const Center(child: Text('İlan bulunamadı.'));
          }

          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(data['hastane']?.toString() ?? 'Hastane bilgisi yok'),
                  subtitle: FutureBuilder<String>(
  future: _doktorAdiGetir(data['doktorId'] ?? '-'),
  builder: (context, snap) {
    return Text(
      'Doktor: ${snap.data ?? 'Yükleniyor...'}',
    );
  },
),

                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IlanEklePage(
                            ilanId: doc.id,
                            mevcutIlan: data,
                            bashekimId: widget.bashekimId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IlanEklePage(bashekimId: widget.bashekimId),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
