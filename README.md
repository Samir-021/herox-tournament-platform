# HeroX Esports Tournament Platform

HeroX is a Flutter-based esports tournament management platform designed to handle tournament creation, player registration, matchmaking, wallet management, and reward distribution.

---

## 🚀 Project Overview

HeroX allows users to:
- Register and authenticate using Google or Email
- Join esports tournaments
- Manage wallet balance and winnings
- View leaderboards and player stats
- Receive rewards based on tournament performance
- Access admin-controlled tournament management tools

---

## 🧱 Tech Stack

- Flutter (Frontend)
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Functions (Node.js)
- Google Sign-In

---

## 📁 Project Structure

- `lib/` → Main Flutter application code
- `android/` → Android native configuration
- `ios/` → iOS configuration (if applicable)
- `functions/` → Firebase Cloud Functions backend
- `assets/` → Images, icons, and static resources
- `firestore.rules` → Firestore security rules
- `storage.rules` → Firebase Storage rules

---

## 🔐 Security Notes

- User authentication is handled via Firebase Auth
- Role-based access control is implemented using Firestore (`role: player/admin`)
- Sensitive credentials and keys are excluded from version control via `.gitignore`

---

## ⚙️ Setup Instructions

### 1. Clone Repository
```bash
git clone https://github.com/your-username/heroX.git
cd heroX
2. Install Dependencies
flutter pub get
3. Run Application
flutter run
📦 Firebase Setup

Ensure you have:

google-services.json placed in android/app/
Firebase project configured via FlutterFire
firebase_options.dart generated using FlutterFire CLI

👨‍💻 Developer
---------------
Samir Adhikari

Project: HeroX Esports Platform
Role: Full Stack Mobile Developer (Flutter + Firebase)
📌 Notes

This project is actively under development. Some features such as payment gateway integration and production-grade wallet system may be added in future updates.

------

