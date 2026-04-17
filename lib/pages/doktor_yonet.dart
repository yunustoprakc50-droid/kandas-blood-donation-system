import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'doktor_ekle.dart';
import 'package:cloud_functions/cloud_functions.dart';

class DoktorYonetPage extends StatefulWidget {
  const DoktorYonetPage({super.key});

  @override
  State<DoktorYonetPage> createState() => _DoktorYonetPageState();
}

class _DoktorYonetPageState extends State<DoktorYonetPage> {
  String? _girisYapanId;
  bool _adminMi = false;
  bool _yetkiliMi = false;
  bool _yetkiYukleniyor = true;

  @override
  void initState() {
    super.initState();
    _loadKullanici();
  }
bool _siliniyor = false;
bool _isLoading = false;
  Future<void> _loadKullanici() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString("girisYapanBashekimId");

      if (id == null) {
        setState(() {
          _yetkiYukleniyor = false;
          _yetkiliMi = false;
        });
        return;
      }

      bool adminMi = false;
      bool bashekimMi = false;

      const adminUidList = [
      ];

      if (adminUidList.contains(id)) {
        adminMi = true;
      }

      // 🏥 BAŞHEKİM kontrol
      final bashekimDoc = await FirebaseFirestore.instance
          .collection('bashekimler')
          .doc(id)
          .get();

      if (bashekimDoc.exists) {
        bashekimMi = true;
      }

      setState(() {
        _girisYapanId = id;
        _adminMi = adminMi;
        _yetkiliMi = adminMi || bashekimMi;
        _yetkiYukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _yetkiYukleniyor = false;
        _yetkiliMi = false;
      });
    }
  }

Future<void> _doktorSil(String doktorId, String doktorBashekimId) async {
  if (_siliniyor) return;

  // 🔥 ÖNCE DIALOG
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Emin misiniz?"),
      content: const Text("Bu doktor kalıcı olarak silinecek."),
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

  // 🔥 SONRA KİLİTLE
  setState(() {
    _siliniyor = true;
    _isLoading = true;
  });

  try {
    final sistemDoc = await FirebaseFirestore.instance
        .collection("ayarlar")
        .doc("sistem")
        .get();

    final sistemKilitli = sistemDoc.data()?['kilit'] ?? false;

    if (sistemKilitli && !_adminMi) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sistem kilitli. Sadece admin işlem yapabilir!")),
      );
      return;
    }

    if (!_adminMi && doktorBashekimId != _girisYapanId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⛔ Bu doktoru silme yetkiniz yok.")),
      );
      return;
    }

    final result = await FirebaseFunctions.instance
        .httpsCallable('doktorSil')
        .call({
      "doktorId": doktorId,
      "bashekimId": _girisYapanId,

    });

    if (result.data['izin'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Bugün en fazla 3 doktor silebilirsiniz!"),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Doktor ID: $doktorId silindi.")),
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Hata oluştu")),
    );
  } finally {
    if (!mounted) return;
    setState(() {
      _siliniyor = false;
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    // ⏳ Yetki yükleniyor
    if (_yetkiYukleniyor) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ⛔ Yetkisiz
    if (!_yetkiliMi || _girisYapanId == null) {
      return const Scaffold(
        body: Center(child: Text("⛔ Yetkisiz erişim")),
      );
    }

    // 🔥 RULE UYUMLU STREAM
    final doktorStream = FirebaseFirestore.instance
        .collection('doktorlar')
        .snapshots();

       return Stack(
  children: [
    Scaffold(
      appBar: AppBar(
        title: const Text("Doktorları Yönet"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoktorEklePage(bashekimId: _girisYapanId!),
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: doktorStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Hata oluştu"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tumDocs = snapshot.data!.docs;

          final docs = _adminMi
              ? tumDocs
              : tumDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['bashekimId'] == _girisYapanId;
                }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("Henüz doktor eklenmemiş."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doktor = docs[index];
              final data = doktor.data() as Map<String, dynamic>;
              final ad = data['ad'] ?? 'İsimsiz';
              final doktorId = doktor.id;
              final doktorBashekimId = data['bashekimId'];

              final silmeYetkisi =
                  _adminMi || doktorBashekimId == _girisYapanId;

              return ListTile(
                title: Text(ad),
                subtitle: Text('ID: $doktorId'),
                trailing: silmeYetkisi
                    ? IconButton(
                        icon: _siliniyor
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete, color: Colors.red),
                        onPressed: _siliniyor
                            ? null
                            : () => _doktorSil(doktorId, doktorBashekimId),
                      )
                    : null,
              );
            },
          );
        },
      ),
    ),

    // 🔥 EKRANI KİLİTLEYEN OVERLAY
    if (_isLoading)
      Container(
        color: Colors.black.withOpacity(0.3),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
  ],
);
  }
}
