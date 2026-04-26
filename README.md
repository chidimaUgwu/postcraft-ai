# PostCraft AI 🏠✨
### Smart Social Media Content Studio for Real Estate

A cross-platform mobile app built with Flutter that helps real estate agents in Nigeria and across Africa generate professional, platform-specific social media captions using Google Gemini AI — in under 15 seconds.

Built for **CS441 Mobile Web Programming — Final Project**
**Student:** Chidima Ugwu | **Year:** 2026

---

## 🔗 Links

| | |
|---|---|
| 🎥 Video Demo | https://youtu.be/LLf3ilRiuHo |
| 📦 Download APK | https://drive.google.com/your-apk-link |
| 📄 Project Report | https://drive.google.com/your-report-link |
| 🎨 Figma Prototype | https://figma.com/your-prototype-link |

---

## 🚀 The Problem

Real estate agents in Nigeria waste 30+ minutes manually writing the same property listing for WhatsApp, Instagram, and Facebook separately — and the quality is always inconsistent. PostCraft AI fixes this.

- You fill in the property details once
- You pick a social media platform
- The app generates a professional caption in under 15 seconds
- Same property → 6 completely different captions, each following the rules of its platform

---

## ✨ Features

**Create a post**
- Take property photos and videos (up to 5 items) from camera or gallery
- Structured guided form — no free typing, everything has a proper input
- GPS auto-fill and interactive map picker (OpenStreetMap, no API key needed)
- Optional property description used as a seed by the AI

**AI Caption Generation**
- Google Gemini Flash API with a 9-section structured prompt
- Supports 6 platforms: WhatsApp, Instagram, Facebook, Twitter/X, LinkedIn, TikTok
- Each platform has its own formatting rules, character limits, and tone
- Every generation saved permanently — version history never deleted
- Edit any caption and save it back instantly

**Scheduling and Sharing**
- Schedule posts with date and time picker
- Pre-reminder local notifications (5 min to 1 day before)
- Calendar export — generates an ICS file for Google/Apple/Outlook Calendar
- Native share sheet — sends images, video, and caption together in one tap

**Settings and Personalisation**
- Business branding — company name, phone, WhatsApp, address, website embedded in every CTA
- 7 languages — English, French, Pidgin, Portuguese, Spanish, Swahili, Arabic
- 9 currencies — NGN, GHS, KES, USD, EUR, GBP, ZAR, XAF, XOF
- Dark mode — full dark theme across every screen

**Security**
- Biometric App Lock — fingerprint, Face ID, or PIN
- Firebase Auth with live password strength checklist
- Firestore security rules — users can only access their own data

---

## 🛠️ Tech Stack

| Category | Technology |
|---|---|
| Mobile framework | Flutter 3 (Dart) |
| Authentication | Firebase Auth |
| Database | Cloud Firestore |
| AI engine | Google Gemini Flash API |
| Map | flutter_map + OpenStreetMap |
| GPS | geolocator + geocoding |
| Notifications | flutter_local_notifications |
| Biometric auth | local_auth |
| State management | Provider |
| Video playback | video_player |
| Share | share_plus |
| Local storage | path_provider |

---

---

## ⚙️ Getting Started

### 1. Clone the repo

```bash
git clone https://github.com/your-username/postcraft-ai.git
cd postcraft-ai/flutter_app
```

### 2. Connect your own Firebase project

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and `android/app/google-services.json` for your project.

### 3. Install packages

```bash
flutter pub get
```

### 4. Add Android permissions

In `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

Also update `android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
// Change this:
class MainActivity: FlutterActivity()

// To this (required by local_auth):
class MainActivity: FlutterFragmentActivity()
```

### 5. Run the app

```bash
flutter run
```

### 6. Add your Gemini API key

Open the app → Settings → paste your free Gemini API key.
Get one at: https://aistudio.google.com/apikey

---

## 🔑 Files Not in This Repo

These files contain private credentials and are excluded via `.gitignore`:


---

## 📱 Local Device Features Used

| Feature | Package |
|---|---|
| Camera and gallery | image_picker |
| GPS | geolocator |
| Reverse geocoding | geocoding |
| Interactive map | flutter_map |
| Local notifications | flutter_local_notifications |
| Biometric auth | local_auth |
| File system | path_provider |
| Video playback | video_player |
| Native share | share_plus |
| Web API — Google Gemini | http |

---

*CS441 MobileApplication — Final Project — Chidima Ugwu — 2026*
