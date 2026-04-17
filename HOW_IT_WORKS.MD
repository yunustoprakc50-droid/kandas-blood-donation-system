# 🧠 How KANDAS Works

KANDAS is designed as a simple and structured emergency blood request system.

---

## 🔄 System Flow

1. **Authorized Login**
   - Only doctors or authorized personnel can access the system.

2. **Create Request**
   - A blood request is created with:
     - City
     - Hospital
     - Blood types needed
     - Emergency flag

3. **Validation**
   - System checks:
     - Daily limits
     - User authorization
     - Data format

4. **Publish**
   - Request is stored in the database.
   - If marked as *urgent*, a notification is triggered.

5. **Notification**
   - Citizens in the same city receive push notifications.

6. **Expiration**
   - Requests automatically expire after 24 hours.

---

## 🔐 Security Model

- Role-based access (Admin / Başhekim / Doctor)
- Request limits per user
- Login attempt restrictions
- Firestore rules enforced
- No personal data stored

---

## ⚙️ Backend

- Firebase Firestore (database)
- Firebase Functions (logic)
- Firebase Messaging (notifications)
- Scheduled jobs (cleanup & backups)

---

## 🎯 Goal

To provide a structured alternative to informal blood request sharing methods
and improve response speed in emergency situations.

---

## ⚠️ Note

This project is a prototype.
Anyone who wants to use it in production must implement
advanced security and validation layers.