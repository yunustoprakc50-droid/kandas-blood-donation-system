import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ilan_ekle.dart';

class DoktorPanel extends StatelessWidget {
  final String kullaniciId;
  final bool doktorMu;

  const DoktorPanel({
    super.key,
    required this.kullaniciId,
    required this.doktorMu,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('Panel')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            doktorMu ? 'Eklediğiniz ilanlar:' : 'Sistemdeki tüm doktor ilanlarınız:',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            doktorMu
                ? 'Sadece kendi ilanlarınız listelenir.'
                : 'Başhekim olarak kendi eklediğiniz doktorların ilanları görünür.',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<dynamic>(

        stream: doktorMu
    ? FirebaseFirestore.instance
        .collection('ilanlar')
        .where('doktorId', isEqualTo: kullaniciId)
        .snapshots()
    : FirebaseFirestore.instance
        .collection('ilanlar')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<QueryDocumentSnapshot> filtered = [];

          // Başhekimin eklediği doktorları bul
          final doktorlar = await FirebaseFirestore.instance
              .collection('doktorlar')
              .where('bashekimId', isEqualTo: kullaniciId)
              .get();

          final doktorIds = doktorlar.docs.map((d) => d.id).toSet();

          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ilanDoktorId = data['doktorId'];
            final ilanBashekimId = data['bashekimId'];

            // kendi ilanları + kendi eklediği doktorların ilanları
            if (ilanBashekimId == kullaniciId ||
                (ilanDoktorId != null && doktorIds.contains(ilanDoktorId))) {
              filtered.add(doc);
            }
          }

          return {'docs': filtered, 'metadata': snapshot.metadata};
        }),


             builder: (context, snapshot) {

  if (snapshot.connectionState == ConnectionState.waiting) {
    return const Center(child: CircularProgressIndicator());
  }

  if (snapshot.hasError) {
    return const Center(child: Text('Veri alınırken hata oluştu.'));
  }

  if (!snapshot.hasData) {
    return const Center(child: Text('Veri alınamadı.'));
  }

  // 🔧 BURAYI değiştirdik:
final List<QueryDocumentSnapshot> docs;
if (doktorMu) {
  // doktor kendi ilanlarını listeliyor
  docs = (snapshot.data as QuerySnapshot).docs;
} else {
  // başhekim, asyncMap'ten gelen map yapısını alıyor
  docs = (snapshot.data['docs'] as List<QueryDocumentSnapshot>);
}



  if (docs.isEmpty) {
    return const Center(child: Text('Henüz ilan yok.'));
  }

  return ListView.builder(
    itemCount: docs.length,
    itemBuilder: (context, i) {
      final doc = docs[i];
      final veri = doc.data() as Map<String, dynamic>;
      final List<dynamic> talepler = veri['kanTalepleri'] ?? [];


final ilkTalep = (talepler.isNotEmpty && talepler[0] is Map)
    ? talepler[0] as Map<String, dynamic>
    : {};

final aciklamaHam = ilkTalep['aciklama'];
final aciklama = (aciklamaHam == null || aciklamaHam.toString().isEmpty)
    ? '-'
    : aciklamaHam.toString();

final hastane = veri['hastane']?.toString() ?? 'Hastane belirtilmedi';
final bashekimId =
    veri['bashekimId']?.toString() ?? 'Atayan başhekim: (belirtilmemiş)';
final acil = veri['acil'] == true;


return Card(
  margin: const EdgeInsets.all(8),
  child: ListTile(
    leading: acil
        ? const Icon(Icons.warning, color: Colors.red)
        : const Icon(Icons.local_hospital),
    title: Text(hastane),
    subtitle: Text(
      '$aciklama\n$bashekimId',
    ),
    trailing: IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        final String? bId = veri['bashekimId']?.toString();
        if (bId == null || bId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ Bu ilanda başhekim bilgisi eksik.')),
          );
          return;
        }
        
Navigator.push( context, MaterialPageRoute( builder: (_) => IlanEklePage( ilanId: doc.id, mevcutIlan: Map<String, dynamic>.from(veri), bashekimId: bId, ), ), );
},

    ),
  ),
);

                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IlanEklePage(
  doktorId: kullaniciId,
  doktorMu: doktorMu,
),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
