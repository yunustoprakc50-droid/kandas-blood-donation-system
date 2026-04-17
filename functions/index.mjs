

import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getStorage } from 'firebase-admin/storage';
import bcrypt from "bcryptjs";

import * as logger from 'firebase-functions/logger';

import os from 'os';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

initializeApp({
  credential: applicationDefault(),
});

const db = getFirestore();
const messaging = getMessaging();
const storage = getStorage();

function normalize(input) {
  return input
    .toLowerCase()
    .replace(/ç/g, 'c')
    .replace(/ğ/g, 'g')
    .replace(/ı/g, 'i')
    .replace(/ö/g, 'o')
    .replace(/ş/g, 's')
    .replace(/ü/g, 'u')
    .replace(/[^a-z0-9_-]/g, '_');
}

// 📢 ACİL İLAN BİLDİRİMİ
export const sendKanIlanNotification = onDocumentCreated('ilanlar/{ilanId}', async (event) => {
  const ilan = event.data?.data();
  if (!ilan || ilan.acil !== true) {
    logger.log("⏭️ Bildirim iptal: Acil değil veya veri eksik.");
    return;
  }

  const sehir = normalize(ilan.sehir || 'genel');
  const topic = `city_${sehir}`;
  const hastane = ilan.hastane || 'Hastane Bilinmiyor';
  const ilce = ilan.ilce || 'İlçe Bilinmiyor';
  const ilkTalep = ilan.kanTalepleri?.[0];
  
  const title = "Acil Kan İlanı!";
  const body = `${hastane} (${ilce}) için kan aranıyor.`;

  try {
    await messaging.send({
      topic,
      notification: { title, body },
      android: {
        notification: {
          channelId: 'kandas_kan_kanali',
          icon: 'ic_notification',
        },
      },
    });
    logger.log("📤 Bildirim gönderildi →", topic);
  } catch (error) {
    logger.error("❌ Bildirim gönderilemedi:", error);
  }
});


// 💾 3 Saatte Bir YEDEKLEME
export const yedekleStorage = onSchedule('every 3 hours', async () => {
  logger.log('🕒 Yedekleme başlıyor...');

  try {
    const snapshot = await db.collection('ilanlar').get();
    const data = {};

    snapshot.forEach((doc) => {
      data[doc.id] = doc.data();
    });

    const json = JSON.stringify(data, null, 2);
    const filename = `ilanlar_${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
    const tempPath = path.join(os.tmpdir(), filename);

    fs.writeFileSync(tempPath, json);

    // 🔧 BURASI DEĞİŞTİ
    const bucket = storage.bucket('kandas-yedek');

    const destination = `yedekler/${filename}`;

    await bucket.upload(tempPath, { destination });

    logger.log(`✅ Yedekleme tamamlandı: ${destination}`);
  } catch (e) {
    logger.error('❌ Yedekleme hatası:', e);
  }
});



//İlan ekleme Fonksiyonu
export const addIlan = onCall(async (request) => {

  try {


      const data = request.data || {};

const bashekimId = data.bashekimId;
let doktorId = data.doktorId; // 🔥 SADECE BURASI LET

const sehir = normalize(data.sehir);
const hastane = data.hastane;
const ilce = data.ilce;
const kanTalepleri = data.kanTalepleri;
const acil = data.acil;
const not = data.not;
    // =========================
    // 📦 PARAM CHECK (DETAYLI)
    // =========================

    // 🛡️ SAHTE doktorId temizliği
if (!doktorId || doktorId === bashekimId) {
  doktorId = null;
}



    if (!bashekimId) {
  throw new HttpsError("invalid-argument", "bashekimId eksik");
}

if (!sehir) throw new HttpsError("invalid-argument", "sehir eksik");
if (!hastane) throw new HttpsError("invalid-argument", "hastane eksik");

if (!kanTalepleri || !Array.isArray(kanTalepleri) || kanTalepleri.length === 0) {
  throw new HttpsError("invalid-argument", "kanTalepleri eksik veya boş");
}
// 🔥 BURAYA
if (kanTalepleri.length > 3) {
  throw new HttpsError("permission-denied", "Max 3 talep");
}

    // =========================
// 🔐 YETKİ KONTROL + ADMIN BYPASS
// =========================

const bashekimDoc = await db.collection("bashekimler").doc(bashekimId).get();
let doktorDoc = null;

if (doktorId) {
  doktorDoc = await db.collection("doktorlar").doc(doktorId).get();
}
const doktorMu = doktorDoc && doktorDoc.exists; 
// 🔥 ADMIN CHECK
const adminDoc = request.auth?.uid
  ? await db.collection("adminler").doc(request.auth.uid).get()
  : null;

const adminMi = adminDoc?.exists;

// 🔐 AUTH KONTROL
if (!request.auth) {
  throw new HttpsError("unauthenticated", "Giriş gerekli");
}

// ⚠ ÖNCE: VAR MI KONTROLÜ
if (!adminMi && !bashekimDoc.exists && !doktorDoc.exists) {
  logger.warn("⛔ Yetkisiz kullanıcı:", { doktorId, bashekimId });
  throw new HttpsError("permission-denied", "Kullanıcı bulunamadı");
}

// 🔐 UID KONTROL
const doktorData = doktorDoc?.data();
const bashekimData = bashekimDoc?.data();

const doktorYetkili =
  doktorDoc?.exists &&
  doktorData?.aktifUid === request.auth.uid;

const bashekimYetkili =
  bashekimDoc?.exists &&
  bashekimData?.aktifUid === request.auth.uid;

// 🚨 GERÇEK KİLİT
if (!adminMi && !doktorYetkili && !bashekimYetkili) {
  logger.warn("⛔ UID eşleşmedi (addIlan)", {
    uid: request.auth?.uid,
    doktorId,
    bashekimId
  });

  throw new HttpsError("permission-denied", "Yetkisiz işlem");
}

// ✅ Admin bypass log
if (adminMi) {
  logger.warn("⚠️ ADMIN BYPASS - kullanıcı kontrol atlandı");
}


   // =========================
// 🔥 GÜNLÜK LİMİT + ADMIN SINIRSIZ
// =========================
const now = new Date();
const start = Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth(), now.getDate()));
const end = Timestamp.fromDate(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1));

if (!adminMi) {

// =========================
// 🔥 TRANSACTION (LIMIT + KAYDETME)
// =========================
await db.runTransaction(async (tx) => {

  if (!adminMi) {

    let query;

    if (doktorMu) {
      query = await tx.get(
        db.collection("gunluk_kayitlar")
          .where("doktorId", "==", doktorId)
          .where("tarih", ">=", start)
          .where("tarih", "<", end)
      );
    } else {
      query = await tx.get(
        db.collection("gunluk_kayitlar")
          .where("bashekimId", "==", bashekimId)
          .where("doktorId", "==", null)
          .where("tarih", ">=", start)
          .where("tarih", "<", end)
      );
    }

    if (query.size >= 5) {
      throw new HttpsError(
        "permission-denied",
        doktorMu ? "Doktor limit doldu" : "Başhekim limit doldu"
      );
    }
  }
 // =========================
    // 🕒 EXPIRES
    // =========================
   const now = Timestamp.now();

const expiresAt = Timestamp.fromMillis(
  now.toMillis() + (24 * 60 * 60 * 1000)
);

    // =========================
    // 💾 KAYDETME
    // =========================
    const veri = {
  bashekimId,
  doktorId: doktorMu ? doktorId : null,   // ✔
      sehir,
      hastane,
      ilce: ilce || "",
      kanTalepleri,
      acil: acil || false,
      not: not || "",
      eklenmeTarihi: Timestamp.now(),
      expiresAt
    };

  const ilanRef = db.collection("ilanlar").doc();

  tx.set(ilanRef, veri);

  const logRef = db.collection("gunluk_kayitlar").doc();

  tx.set(logRef, {
    ekleyenId: doktorMu ? doktorId : bashekimId,
    bashekimId,
    doktorId: doktorMu ? doktorId : null,
    tarih: Timestamp.now(),
    sehir,
    ilce: ilce || "",
    hastane,
    kanGrubuSayisi: kanTalepleri.length,
  });

});

  logger.info("✅ Limit OK");
} else {
  logger.warn("⚠️ ADMIN BYPASS - günlük limit atlandı");
}

logger.info("🧾 Günlük kayıt eklendi");

    return {
      success: true,
   
    };

  } catch (err) {
    logger.error("💥 FUNCTION HATA:", err);

    if (err instanceof HttpsError) {
      throw err;
    }

    throw new HttpsError("internal", err.message || "Bilinmeyen hata");
  }
});


//İlan Güncelleme Fonksiyonu
export const updateIlan = onCall(async (request) => {
  try {
    const {  ilanId, updates } = request.data;

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş gerekli");
    }

    

    if (!ilanId || !updates) {
      throw new HttpsError("invalid-argument", "Eksik alan var");
    }

    const ilanRef = db.collection("ilanlar").doc(ilanId);
    const ilanDoc = await ilanRef.get();

    if (!ilanDoc.exists) {
      throw new HttpsError("not-found", "İlan bulunamadı");
    }

    const ilanData = ilanDoc.data();

    const doktorId = ilanData.doktorId;
    const bashekimId = ilanData.bashekimId;

    // 👑 ADMIN
    const adminDoc = await db.collection("adminler").doc(request.auth.uid).get();
    const adminMi = adminDoc.exists;

    // 👤 USER DOCS
    let doktorYetkili = false;
    let bashekimYetkili = false;

    if (doktorId) {
      const d = await db.collection("doktorlar").doc(doktorId).get();
      doktorYetkili = d.exists && d.data().aktifUid === request.auth.uid;
    }

    if (bashekimId) {
      const b = await db.collection("bashekimler").doc(bashekimId).get();
      bashekimYetkili = b.exists && b.data().aktifUid === request.auth.uid;
    }

    if (!adminMi && !doktorYetkili && !bashekimYetkili) {
      throw new HttpsError("permission-denied", "Yetkisiz işlem");
    }

    // 🔥 WHITELIST
    const allowedFields = ["sehir", "ilce", "hastane", "kanTalepleri", "acil"];
    const safeUpdates = {};

    for (const key of allowedFields) {
      if (key in updates) {
        safeUpdates[key] = updates[key];
      }
    }

    if (safeUpdates.kanTalepleri && safeUpdates.kanTalepleri.length > 3) {
  throw new HttpsError("permission-denied", "Max 3 talep");
}

    // 🔒 ID SABİT
    safeUpdates.doktorId = doktorId;
    safeUpdates.bashekimId = bashekimId;

    // 🔢 SERVER SIDE ARTIR
    safeUpdates.guncellemeSayisi = (ilanData.guncellemeSayisi || 0) + 1;

    await ilanRef.update(safeUpdates);

    return { success: true };

  } catch (err) {
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message);
  }
});


// 🗑️ 24 SAATİ GEÇEN İLANLARI TEMİZLE (FIXED)
export const temizleSuresiDolanIlanlar = onSchedule('every 1 hours', async () => {

  const now = Timestamp.now(); // 🔥 TEK SAAT KAYNAĞI

  const limit = 200;

  let totalDeleted = 0;

  while (true) {
    const snapshot = await db
      .collection('ilanlar')
      .where('expiresAt', '<=', now)
      .limit(limit)
      .get();

    if (snapshot.empty) {
      logger.log('🟢 Silinecek ilan yok');
      break;
    }

    const batch = db.batch();

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    totalDeleted += snapshot.size;

    logger.log(`🗑️ ${snapshot.size} ilan silindi (toplam: ${totalDeleted})`);
  }

});




//doktor giriş ekranı
export const doktorLogin = onRequest(async (req, res) => {
  // 🔥 CORS AYARLARI (XHR error fix)
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  // 🔁 Preflight (çok önemli)
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

try {
  const body =
    typeof req.body === 'string' ? JSON.parse(req.body) : req.body;

  const { doktorId, sifre } = body || {};

  if (!doktorId || !sifre) {
    return res.json({
      success: false,
      message: 'Eksik bilgi',
    });
  }

  const doktorSnap = await db
    .collection('doktorlar')
    .doc(String(doktorId))
    .get();

if (!doktorSnap.exists) {
  return res.json({
    success: false,
    message: 'Geçersiz',
  });
}


    // 🔐 RATE LIMIT KONTROL
const limitRef = db.collection("login_attempts").doc(`doktor_${doktorId}`);
const limitDoc = await limitRef.get();

const now = Date.now();

if (limitDoc.exists) {
  const data = limitDoc.data();

  if (data.blockedUntil && data.blockedUntil > now) {
    return res.json({
      success: false,
      message: "10 dakika bekleyin",
    });
  }
}

 


 // 🔐 Önce hash var mı kontrol et
const doktorData = doktorSnap.data();

if (!doktorData?.sifreHash) {
  return res.json({
    success: false,
    message: "Şifre hash bulunamadı",
  });
}

const match = await bcrypt.compare(String(sifre), doktorData.sifreHash);

if (!match) {
  const current = limitDoc.exists ? limitDoc.data().count || 0 : 0;
  const newCount = current + 1;

  let blockedUntil = null;

  if (newCount >= 3) {
    blockedUntil = now + (10 * 60 * 1000);
  }

  await limitRef.set({
    count: newCount,
    blockedUntil,
  }, { merge: true });

  return res.json({
    success: false,
    message: "Geçersiz",
  });
}

await limitRef.set({
  count: 0,
  blockedUntil: null,
}, { merge: true });

return res.json({
  success: true,
  doktorId,
  bashekimId: doktorData.bashekimId || null,
});


} catch (e) {
  console.error('❌ doktorLogin hata:', e);
  return res.status(500).json({
    success: false,
    message: 'Sunucu hatası',
  });
}
});










//başhekim giriş
export const bashekimLogin = onRequest(async (req, res) => {
  // 🔥 CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    const body =
      typeof req.body === 'string' ? JSON.parse(req.body) : req.body;

    const { bashekimId, sifre } = body || {};

    if (!bashekimId || !sifre) {
      return res.json({
        success: false,
        message: 'Eksik bilgi',
      });
    }

    const snap = await db
      .collection('bashekimler')
      .doc(String(bashekimId))
      .get();

    if (!snap.exists) {
  return res.json({
    success: false,
    message: 'Geçersiz',
  });
}

    // 🔐 RATE LIMIT KONTROL (BURAYA EKLENDİ)
    const limitRef = db.collection("login_attempts").doc(`bashekim_${bashekimId}`);
    const limitDoc = await limitRef.get();

    const now = Date.now();

    if (limitDoc.exists) {
      const limitData = limitDoc.data();

      if (limitData.blockedUntil && limitData.blockedUntil > now) {
        return res.json({
          success: false,
          message: "10 dakika bekleyin",
        });
      }
    }

    const data = snap.data();

    // 🔐 HASH KONTROL
if (!data?.sifreHash) {
  return res.json({
    success: false,
    message: "Şifre alanı yok",
  });
}

const match = await bcrypt.compare(String(sifre), data.sifreHash);

// ❌ ŞİFRE YANLIŞ
if (!match) {
  const current = limitDoc.exists ? limitDoc.data().count || 0 : 0;
  const newCount = current + 1;

  let blockedUntil = null;

  if (newCount >= 3) {
    blockedUntil = now + (10 * 60 * 1000);
  }

  await limitRef.set({
    count: newCount,
    blockedUntil,
  }, { merge: true });

  return res.json({
    success: false,
    message: "Geçersiz",
  });
}

    // ✅ DOĞRU GİRİŞ → RESET
    await limitRef.set({
      count: 0,
      blockedUntil: null,
    }, { merge: true });

    return res.json({
      success: true,
      bashekimId,
    });

  } catch (e) {
    console.error('❌ bashekimLogin hata:', e);
    return res.status(500).json({
      success: false,
      message: 'Sunucu hatası',
    });
  }
});


export const sendKanIlanNotificationOnUpdate =
onDocumentUpdated('ilanlar/{ilanId}', async (event) => {

  const before = event.data?.before.data();
  const after = event.data?.after.data();

  if (!before || !after) return;

  const beforeAcil =
    Array.isArray(before.kanTalepleri) &&
    before.kanTalepleri.some(t => t && t.acil === true);

  const afterAcil =
    Array.isArray(after.kanTalepleri) &&
    after.kanTalepleri.some(t => t && t.acil === true);

  if (!beforeAcil && afterAcil) {

    const sehir = normalize(after.sehir || 'genel');
    const topic = `city_${sehir}`;
    const hastane = after.hastane || 'Hastane Bilinmiyor';
    const ilce = after.ilce || 'İlçe Bilinmiyor';

    const title = "Acil Kan İlanı!";
    const body = `${hastane} (${ilce}) için acil kan ihtiyacı var!`;

    try {
      await messaging.send({
        topic,
        notification: { title, body },
        android: {
          notification: {
            channelId: 'kandas_kan_kanali',
            icon: 'ic_notification',
          },
        },
      });

      logger.log("📤 Update sonrası bildirim gönderildi →", topic);

    } catch (error) {
      logger.error("❌ Update bildirim hatası:", error);
    }
  }
});

// 🌙 23:45 → GÜNLÜK KAYITLARI STORAGE YEDEKLE (İSTANBUL SAATİ)
export const yedekleGunlukKayitlar = onSchedule(
  {
    schedule: '45 23 * * *',
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    logger.log('🕒 Günlük kayıt yedekleme başlıyor...');

    try {
      const snapshot = await db.collection('gunluk_kayitlar').get();

      if (snapshot.empty) {
        logger.log('🟢 Yedeklenecek veri yok');
        return;
      }

      const data = {};
      snapshot.forEach((doc) => {
        data[doc.id] = doc.data();
      });

      const json = JSON.stringify(data, null, 2);
      const filename = `gunluk_${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
      const tempPath = path.join(os.tmpdir(), filename);

      fs.writeFileSync(tempPath, json);

      const bucket = storage.bucket('kandas-gunluk');
      const destination = `gunluk_kayitlar/${filename}`;

      await bucket.upload(tempPath, { destination });

      // 🧹 temp dosyayı sil
      fs.unlinkSync(tempPath);

      logger.log(`✅ Günlük kayıtlar yedeklendi: ${destination}`);
    } catch (e) {
      logger.error('❌ Günlük yedekleme hatası:', e);
    }
  }
);


// 🗑️ 00:05 → GÜNLÜK KAYITLARI SİL (İSTANBUL SAATİ)
export const silGunlukKayitlar = onSchedule(
  {
    schedule: '5 0 * * *',
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    logger.log('🗑️ Günlük kayıtlar siliniyor...');

    try {
      const snapshot = await db.collection('gunluk_kayitlar').get();

      if (snapshot.empty) {
        logger.log('🟢 Silinecek günlük kayıt yok');
        return;
      }

      const docs = snapshot.docs;

      // 🔥 500 limit fix (batch bölme)
      while (docs.length > 0) {
        const chunk = docs.splice(0, 500);
        const batch = db.batch();

        chunk.forEach((doc) => {
          batch.delete(doc.ref);
        });

        await batch.commit();
      }

      logger.log(`🗑️ ${snapshot.size} günlük kayıt silindi`);
    } catch (e) {
      logger.error('❌ Günlük silme hatası:', e);
    }
  }
);

//doktor ekle fonksiyonu
export const doktorEkle = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş gerekli");
    }

    const {
  bashekimId,
  doktorId,
  ad,
  sifre
} = request.data;

const sifreHash = await bcrypt.hash(String(sifre), 10);

    if (!bashekimId || !doktorId) {
      throw new HttpsError("invalid-argument", "Eksik veri");
    }

    const db = getFirestore();

    // 📅 bugün aralığı
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);

    let result = null;

   await db.runTransaction(async (tx) => {

  // 🔥 BUGÜN KAÇ DOKTOR EKLENMİŞ
  const snap = await tx.get(
    db.collection("doktorlar")
      .where("bashekimId", "==", bashekimId)
      .where("eklenme_tarihi", ">=", Timestamp.fromDate(todayStart))
      .where("eklenme_tarihi", "<", Timestamp.fromDate(todayEnd))
  );

  if (snap.size >= 5) {
    throw new HttpsError(
      "permission-denied",
      "Günlük doktor limiti doldu"
    );
  }

  // 🔥 DOKTOR OLUŞTUR
  const ref = db.collection("doktorlar").doc(doktorId);

  tx.set(ref, {
    bashekimId,
    doktorId,
    ad,
    sifreHash,
    aktifUid: null,
    eklenme_tarihi: Timestamp.now()
  });

  // 🔥 AUDIT LOG (İŞTE BURASI 💣)
  const logRef = db.collection("doktor_ekleme_loglari").doc();

  tx.set(logRef, {
    bashekimId,
    doktorId,
    ekleyenUid: request.auth.uid,
    tarih: Timestamp.now()
  });

  result = { success: true };
});

    return result;

  } catch (err) {
    logger.error(err);

    if (err instanceof HttpsError) throw err;

    throw new HttpsError("internal", err.message || "Hata");
  }
});







//Doktor Silme
export const doktorSil = onCall(async (request) => {
  const { doktorId, bashekimId,  } = request.data;

  

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Giriş yapılmamış");
  }

  const db = getFirestore();
  const uid = request.auth.uid;

  const adminDoc = await db.collection("adminler").doc(uid).get();
  const adminMi = adminDoc.exists;

  if (!adminMi) {
    const bashekimDoc = await db.collection("bashekimler").doc(bashekimId).get();

    if (!bashekimDoc.exists ||
        bashekimDoc.data().aktifUid !== uid) {
      throw new HttpsError("permission-denied", "Yetkin yok");
    }
  }

  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const todayEnd = new Date(todayStart);
  todayEnd.setDate(todayEnd.getDate() + 1);

  // 🔥 TRANSACTION
  return await db.runTransaction(async (tx) => {

    const silmeQuery = await tx.get(
      db.collection("doktor_silme_loglari")
        .where("bashekimId", "==", bashekimId)
        .where("silinme_tarihi", ">=", todayStart)
        .where("silinme_tarihi", "<", todayEnd)
    );

    if (!adminMi && silmeQuery.size >= 3) {
      return { izin: false };
    }

    const doktorRef = db.collection("doktorlar").doc(doktorId);
    const doktorDoc = await tx.get(doktorRef);

    if (!doktorDoc.exists) {
      throw new HttpsError("not-found", "Doktor bulunamadı");
    }

    // 🔥 silme
    tx.delete(doktorRef);

    // 🔥 log
    const logRef = db.collection("doktor_silme_loglari").doc();
    tx.set(logRef, {
      bashekimId,
      doktorId,
      silinme_tarihi: FieldValue.serverTimestamp(),
      silenUid: uid,
    });

    return { izin: true };
  });
});

//İlan Silme
export const deleteIlan = onCall(async (request) => {
  try {
    const { ilanId } = request.data;

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş yok");
    }

   

    if (!ilanId) {
      throw new HttpsError("invalid-argument", "ilanId gerekli");
    }

    const ilanRef = db.collection("ilanlar").doc(ilanId);
    const ilanDoc = await ilanRef.get();

    if (!ilanDoc.exists) {
      throw new HttpsError("not-found", "İlan bulunamadı");
    }

    const ilanData = ilanDoc.data();
    const doktorId = ilanData.doktorId;
    const bashekimId = ilanData.bashekimId;

    // 👑 ADMIN
    const adminDoc = await db.collection("adminler").doc(request.auth.uid).get();
    const isAdmin = adminDoc.exists;

    // 👤 YETKİ KONTROLÜ
    let doktorYetkili = false;
    let bashekimYetkili = false;

    if (doktorId) {
      const d = await db.collection("doktorlar").doc(doktorId).get();
      doktorYetkili = d.exists && d.data().aktifUid === request.auth.uid;
    }

    if (bashekimId) {
      const b = await db.collection("bashekimler").doc(bashekimId).get();
      bashekimYetkili = b.exists && b.data().aktifUid === request.auth.uid;
    }

    if (!isAdmin && !doktorYetkili && !bashekimYetkili) {
      throw new HttpsError("permission-denied", "Yetkisiz silme");
    }

    // 📊 LIMIT (server-side ID)
    const ekleyenId = doktorYetkili ? doktorId : bashekimId;

    const now = new Date();
    const startOfDay = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate()
    );

    const snapshot = await db
      .collection("silme_kayitlari")
      .where("ekleyenId", "==", ekleyenId)
      .where("tarih", ">=", startOfDay)
      .get();

    if (!isAdmin && snapshot.size >= 5) {
      throw new HttpsError("permission-denied", "Günlük limit doldu");
    }

    // 🗑️ DELETE
    await ilanRef.delete();

    // 🧾 LOG
    await db.collection("silme_kayitlari").add({
      ekleyenId,
      ilanId,
      tarih: FieldValue.serverTimestamp()
    });

    return { success: true };

  } catch (err) {
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err.message);
  }
});








//silinen ilanların yedekleri
export const yedekleSilmeKayitlari = onSchedule(
  {
    schedule: '55 23 * * *',
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    logger.log('🕒 Silme kayıtları yedekleniyor...');

    try {
      const snapshot = await db.collection('silme_kayitlari').get();

      if (snapshot.empty) {
        logger.log('🟢 Veri yok');
        return;
      }

      const data = {};
      snapshot.forEach((doc) => {
        data[doc.id] = doc.data();
      });

      const json = JSON.stringify(data);
      const filename = `silme_${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
      const tempPath = path.join(os.tmpdir(), filename);

      fs.writeFileSync(tempPath, json);

      const bucket = storage.bucket('kandas-silme'); // 🔥 BURASI
      const destination = `silme_kayitlari/${filename}`;

      await bucket.upload(tempPath, { destination });

      fs.unlinkSync(tempPath);

      logger.log('✅ Silme kayıtları yedeklendi');
    } catch (e) {
      logger.error('❌ Hata:', e);
    }
  }
);



//silinen ilanların yedek alındıktan sonra silme işlemi
export const silSilmeKayitlari = onSchedule(
  {
    schedule: '15 0 * * *',
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    logger.log('🗑️ Silme kayıtları temizleniyor...');

    try {
      const snapshot = await db.collection('silme_kayitlari').get();

      if (snapshot.empty) {
        logger.log('🟢 Silinecek veri yok');
        return;
      }

      const docs = snapshot.docs;

      while (docs.length > 0) {
        const chunk = docs.splice(0, 500);
        const batch = db.batch();

        chunk.forEach((doc) => batch.delete(doc.ref));

        await batch.commit();
      }

      logger.log(`🗑️ ${snapshot.size} kayıt silindi`);
    } catch (e) {
      logger.error('❌ Silme hatası:', e);
    }
  }
);









export const yedekleDoktorSilmeLoglari = onSchedule(
  {
    schedule: '0 23 * * 0', // Pazar 23:00
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    logger.log('🕒 Doktor silme logları yedekleniyor...');

    try {
      const snapshot = await db.collection('doktor_silme_loglari').get();

      if (snapshot.empty) {
        logger.log('🟢 Veri yok');
        return;
      }

      const data = {};
      snapshot.forEach((doc) => {
        data[doc.id] = doc.data();
      });

      const json = JSON.stringify(data, null, 2);
      const filename = `doktor_silme_${new Date().toISOString().replace(/[:.]/g, '-')}.json`;
      const tempPath = path.join(os.tmpdir(), filename);

      fs.writeFileSync(tempPath, json);

      const bucket = storage.bucket('kandas-doktor-silme');
      const destination = `yedekler/${filename}`;

      await bucket.upload(tempPath, { destination });

      fs.unlinkSync(tempPath);

      logger.log('✅ Doktor silme logları yedeklendi');
    } catch (e) {
      logger.error('❌ Hata:', e);
    }
  }
);





export const silDoktorSilmeLoglari = onSchedule(
  {
    schedule: '30 23 * * 0',
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    logger.log('🗑️ Doktor silme logları siliniyor...');

    try {
      const snapshot = await db.collection('doktor_silme_loglari').get();

      if (snapshot.empty) {
        logger.log('🟢 Silinecek veri yok');
        return;
      }

      const docs = snapshot.docs;

      while (docs.length > 0) {
        const chunk = docs.splice(0, 500);
        const batch = db.batch();

        chunk.forEach((doc) => batch.delete(doc.ref));

        await batch.commit();
      }

      logger.log(`🗑️ ${snapshot.size} log silindi`);
    } catch (e) {
      logger.error('❌ Silme hatası:', e);
    }
  }
);








export const yedekleDoktorEklemeLoglari = onSchedule(
  {
    schedule: "0 23 * * 0", // Pazar 23:00
    timeZone: "Europe/Istanbul",
  },
  async () => {
    logger.log("🕒 Doktor ekleme logları yedekleniyor...");

    try {
      const snapshot = await db.collection("doktor_ekleme_loglari").get();

      if (snapshot.empty) {
        logger.log("🟢 Veri yok");
        return;
      }

      const data = {};
      snapshot.forEach((doc) => {
        data[doc.id] = doc.data();
      });

      const json = JSON.stringify(data, null, 2);

      const filename = `doktor_ekleme_${new Date()
        .toISOString()
        .replace(/[:.]/g, "-")}.json`;

      const tempPath = path.join(os.tmpdir(), filename);

      fs.writeFileSync(tempPath, json);

      const bucket = storage.bucket("kandas-doktor-ekleme");
      const destination = `yedekler/${filename}`;

      await bucket.upload(tempPath, { destination });

      fs.unlinkSync(tempPath);

      logger.log("✅ Backup tamam");
    } catch (e) {
      logger.error("❌ Backup hatası:", e);
    }
  }
);



export const silDoktorEklemeLoglari = onSchedule(
  {
    schedule: "30 23 * * 0", // Pazar 23:30
    timeZone: "Europe/Istanbul",
  },
  async () => {
    logger.log("🗑️ Doktor ekleme logları siliniyor...");

    try {
      const limit = 500;
      let totalDeleted = 0;

      while (true) {
        const snapshot = await db
          .collection("doktor_ekleme_loglari")
          .limit(limit)
          .get();

        if (snapshot.empty) {
          logger.log("🟢 Silinecek veri yok");
          break;
        }

        const batch = db.batch();

        snapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });

        await batch.commit();

        totalDeleted += snapshot.size;

        logger.log(`🗑️ ${snapshot.size} silindi (toplam: ${totalDeleted})`);
      }
    } catch (e) {
      logger.error("❌ Silme hatası:", e);
    }
  }
);







export const temizleLoginAttempts = onSchedule(
  {
    schedule: "0 3 * * 0", // Pazar 03:00
    timeZone: "Europe/Istanbul",
  },
  async () => {
    logger.log("🧹 login_attempts temizleniyor...");

    try {
      const threeDaysAgo = Timestamp.fromDate(
        new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)
      );

      const limit = 500;
      let totalDeleted = 0;

      while (true) {
        const snapshot = await db
          .collection("login_attempts")
          .where("lastAttempt", "<", threeDaysAgo)
          .limit(limit)
          .get();

        if (snapshot.empty) {
          logger.log("🟢 Silinecek veri yok");
          break;
        }

        const batch = db.batch();

        snapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });

        await batch.commit();

        totalDeleted += snapshot.size;

        logger.log(`🗑️ ${snapshot.size} silindi (toplam: ${totalDeleted})`);
      }
    } catch (e) {
      logger.error("❌ login_attempts silme hatası:", e);
    }
  }
);