import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bashekim_ekle.dart';

class BashekimYonetPage extends StatefulWidget {
  const BashekimYonetPage({super.key});

  @override
  State<BashekimYonetPage> createState() => _BashekimYonetPageState();
}

class _BashekimYonetPageState extends State<BashekimYonetPage> {

  Future<void> _bashekimSil(BuildContext context, String id, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Silme Onayı"),
        content: Text("“$ad” adlı başhekimi silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Sil", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (onay != true) return;

    // 🔥 YÜKLENİYOR EKRANI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('bashekimler')
          .doc(id)
          .delete();

      // ✅ DOĞRU KAPATMA
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Başhekim silindi: $ad")),
      );
    } catch (e) {
      // ✅ DOĞRU KAPATMA
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Başhekimleri Yönet"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BashekimEklePage()),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bashekimler')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Hata oluştu"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("Hiç başhekim bulunamadı."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final bashekim = docs[index];
              final data = bashekim.data() as Map<String, dynamic>;
              final ad = data['ad'] ?? 'İsimsiz';
              final id = bashekim.id;

              return ListTile(
                title: Text(ad),
                subtitle: Text('ID: $id'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _bashekimSil(context, id, ad),
                ),
              );
            },
          );
        },
      ),
    );
  }
}