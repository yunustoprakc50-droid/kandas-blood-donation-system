import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IlanListelePage extends StatefulWidget {
  final String? secilenSehir; // null olasılığına karşı nullable yaptık
  const IlanListelePage({this.secilenSehir, super.key});

  @override
  State<IlanListelePage> createState() => _IlanListelePageState();
}

class _IlanListelePageState extends State<IlanListelePage> {
  late String _secilenSehir;

  final List<String> sehirler = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin',
    'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale',
    'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum',
    'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin',
    'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli',
    'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir',
    'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat',
    'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray',
    'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır',
    'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
  ];

  @override
  void initState() {
    super.initState();
    _secilenSehir = widget.secilenSehir ?? ''; // null gelirse boş string
  }

  String normalize(String? input) {
    if (input == null) return '';
    return input.toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlanları Görüntüle')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _secilenSehir.isNotEmpty ? _secilenSehir : null,
              items: sehirler.map((sehir) {
                return DropdownMenuItem(
                  value: sehir,
                  child: Text(sehir),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _secilenSehir = v;
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Şehir Seçin'),
            ),
          ),
          Expanded(
            child: _secilenSehir.isEmpty
                ? const Center(
                    child: Text(
                      'Lütfen önce bir şehir seçin.',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('ilanlar')
                        .where('sehir', isEqualTo: normalize(_secilenSehir))
                        .snapshots(),
                    builder: (context, snapshot) {
                      debugPrint("🔥 SNAPSHOT GELDİ Mİ: ${snapshot.hasData}");
  debugPrint("🔥 DOC SAYISI: ${snapshot.data?.docs.length}");
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Hata: ${snapshot.error}'));
                      }

                      final ilanlar = snapshot.data?.docs ?? [];

                      if (ilanlar.isEmpty) {
                        return const Center(child: Text('Bu şehirde ilan bulunamadı.'));
                      }

                      return ListView(
                        children: ilanlar.expand((ilan) {
                          final data = ilan.data() as Map<String, dynamic>;
                          final List<dynamic> talepler = data['kanTalepleri'] ?? [];

                          return talepler.map((talep) {
                            final bool acil = talep['acil'] == true;
                            final String kanGrubu = talep['kanGrubu'] ?? 'Bilinmiyor';
                            final String hastane = data['hastane'] ?? 'Hastane belirtilmedi';
                            final String ilce = data['ilce'] ?? 'İlçe yok';
                            final String aciklama = talep['aciklama'] ?? '';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: acil ? Colors.red[50] : Colors.white,
                              child: ListTile(
                                title: Text('$kanGrubu - $hastane'),
                                subtitle: Text('$ilce • $aciklama'),
                                trailing: acil
                                    ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
                                    : null,
                              ),
                            );
                          });
                        }).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
