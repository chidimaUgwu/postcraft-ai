# PostCraft AI – Firebase Edition
## Complete Setup Guide (Beginner Friendly)

---

## WHAT CHANGED FROM THE OLD VERSION

| Old (Node.js)         | New (Firebase)               |
|-----------------------|------------------------------|
| Express backend       | Firebase Cloud Functions     |
| MySQL database        | Cloud Firestore              |
| JWT auth              | Firebase Authentication      |
| Manual file server    | Firebase Storage             |
| .env file             | Firebase Console             |
| School DB required    | No school DB needed ✅        |

You no longer need the school database at all.
Firebase gives you everything in the cloud, for free.

---

## WHAT YOU NEED BEFORE STARTING

1. A Google account (Gmail)
2. Node.js installed (https://nodejs.org — choose LTS)
3. Flutter installed (https://flutter.dev/docs/get-started/install)
4. VS Code or Android Studio

---

## PART 1 — CREATE YOUR FIREBASE PROJECT (15 minutes)

### Step 1: Go to the Firebase Console
Open your browser and go to:
```
https://console.firebase.google.com
```
Sign in with your Google/Gmail account.

### Step 2: Create a new project
1. Click **"Add project"**
2. Name it: `postcraft-ai`
3. Disable Google Analytics (not needed) → Click **"Create project"**
4. Wait about 30 seconds → Click **"Continue"**

### Step 3: Enable Firebase Authentication
1. In the left menu → Click **"Authentication"**
2. Click **"Get started"**
3. Click **"Email/Password"**
4. Toggle the first switch to **ON**
5. Click **Save**

You now have email/password login. Done.

### Step 4: Create the Firestore Database
1. In the left menu → Click **"Firestore Database"**
2. Click **"Create database"**
3. Choose **"Start in production mode"** → Click **Next**
4. Choose a location closest to your users:
   - If in Africa: choose `europe-west1` (closest to Nigeria)
   - If in USA: choose `us-central1`
5. Click **Enable**

### Step 5: Enable Firebase Storage
1. In the left menu → Click **"Storage"**
2. Click **"Get started"**
3. Choose **"Start in production mode"** → Click **Next**
4. Keep the same region → Click **Done**

### Step 6: Add a Web App (needed for flutterfire setup)
1. On the main Firebase Console page, click the **</>** (Web) icon
2. Name it: `postcraft-web`
3. Click **"Register app"**
4. You will see a config block — **don't copy it yet**, the `flutterfire` tool will do this automatically

---

## PART 2 — CONNECT FLUTTER TO FIREBASE (10 minutes)

### Step 1: Install the Firebase CLI
Open a terminal (Command Prompt or PowerShell on Windows):
```bash
npm install -g firebase-tools
```

Verify it worked:
```bash
firebase --version
# Should print something like: 13.x.x
```

### Step 2: Login to Firebase
```bash
firebase login
```
A browser window will open. Sign in with your Google account.

### Step 3: Install the FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

If you get a PATH warning, follow the instructions it shows to add it to your PATH.

### Step 4: Navigate to your Flutter project
```bash
cd postcraft_firebase/flutter_app
```

### Step 5: Connect Flutter to your Firebase project
```bash
flutterfire configure
```

This command will:
- Ask you which Firebase project to use → Select `postcraft-ai`
- Ask which platforms → Select **Android** and **iOS**
- **Automatically generate** `lib/firebase_options.dart` with your real values

That's it! The `firebase_options.dart` template file is now replaced with your actual credentials.

### Step 6: Install Flutter packages
```bash
flutter pub get
```

---

## PART 3 — DEPLOY FIRESTORE RULES AND STORAGE RULES (5 minutes)

### Step 1: Navigate to project root
```bash
cd postcraft_firebase
```

### Step 2: Initialize Firebase in this folder
```bash
firebase use --add
```
Select your `postcraft-ai` project.

### Step 3: Deploy the security rules
```bash
firebase deploy --only firestore:rules,storage
```

This uploads `firestore.rules` and `storage.rules` to Firebase.
Your data is now protected — users can only access their own posts.

---

## PART 4 — DEPLOY THE CLOUD FUNCTION (AI BACKEND)

### Step 1: Set your OpenAI API key in Firebase
```bash
firebase functions:config:set openai.key="sk-YOUR_ACTUAL_OPENAI_KEY_HERE"
```

Replace `sk-YOUR_ACTUAL_OPENAI_KEY_HERE` with your real OpenAI key.
Get one at: https://platform.openai.com/api-keys

### Step 2: Install function dependencies
```bash
cd functions
npm install
cd ..
```

### Step 3: Deploy the Cloud Functions
```bash
firebase deploy --only functions
```

This will take 2–3 minutes. When done you will see:
```
✔  functions[generateCaption]: Successful create
✔  functions[deletePost]: Successful create
```

Your AI backend is now live on Google's servers.

---

## PART 5 — ADD ANDROID PERMISSIONS

Open the file:
```
flutter_app/android/app/src/main/AndroidManifest.xml
```

Add these lines **inside the `<manifest>` tag**, before `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

Also open `android/app/build.gradle` and confirm:
```gradle
android {
    defaultConfig {
        minSdkVersion 21    // must be 21 or higher
        targetSdkVersion 34
    }
}
```

---

## PART 6 — RUN THE APP

```bash
cd flutter_app
flutter run
```

Select your Android emulator or connected phone.

The app will start, show the splash screen, and take you to the login page.

---

## PART 7 — HOW FIRESTORE WORKS (Explained Simply)

Firestore is Google's cloud database. Instead of SQL tables, it uses **Collections** and **Documents**.

```
Firestore
├── users/                          ← Collection
│   └── {userId}/                   ← Document (one per user)
│       ├── name: "Chidima"
│       └── email: "chidima@..."
│
├── posts/                          ← Collection
│   └── {postId}/                   ← Document (one per property listing)
│       ├── userId: "abc123"
│       ├── title: "3 Bedroom Flat"
│       ├── price: 250000
│       ├── status: "draft"
│       ├── bedrooms: 3
│       ├── imageUrls: ["https://..."]
│       └── ...other fields
│
├── caption_versions/               ← Collection
│   └── {captionId}/                ← Document (one per AI generation)
│       ├── postId: "post123"
│       ├── platform: "instagram"
│       ├── captionText: "🏠 FOR RENT..."
│       ├── generationNum: 3
│       └── isSelected: true
│
└── settings/                       ← Collection
    └── {userId}/                   ← Document (one per user)
        ├── openaiApiKey: "sk-..."
        └── defaultPlatform: "whatsapp"
```

**Key difference from SQL:**
- SQL: `SELECT * FROM posts WHERE user_id = 1`
- Firestore: `.collection('posts').where('userId', isEqualTo: uid).snapshots()`

Firestore also supports **real-time listeners** — when data changes in the cloud, the app updates automatically without refreshing. That's why your caption versions appear instantly.

---

## PART 8 — HOW THE AI CAPTION GENERATION WORKS

Here is the full flow when a user taps "Generate":

```
Flutter App                Cloud Function              OpenAI
     │                          │                        │
     │──generateCaption()──────►│                        │
     │  (postId, platform,      │                        │
     │   propertyData)          │                        │
     │                          │──Build AI prompt───────►│
     │                          │  (platform rules +      │
     │                          │   property details)     │
     │                          │                        │
     │                          │◄──Caption text─────────│
     │                          │                        │
     │                          │──Save to Firestore     │
     │                          │  caption_versions/     │
     │                          │  (never deletes old)   │
     │                          │                        │
     │◄──{ captionText }────────│                        │
     │                          │                        │
     │ (Firestore stream        │                        │
     │  auto-updates UI)        │                        │
```

**Why each platform gives a different caption:**

The Cloud Function includes specific instructions per platform:

| Platform  | What the AI is told |
|-----------|---------------------|
| WhatsApp  | Short, direct, *bold* with asterisks, clear CTA |
| Instagram | Emojis, lifestyle hook, 5–8 hashtags |
| Facebook  | Detailed, 3–4 paragraphs, community feel |
| Twitter   | Max 280 chars, extremely punchy |
| LinkedIn  | Professional, investor ROI angle |

Same property → 5 completely different captions.

---

## PART 9 — HOW CAPTION VERSION HISTORY WORKS

Every time you tap Regenerate:
1. A **new document** is created in `caption_versions` with `generationNum + 1`
2. The old documents are **never deleted**
3. The new version gets `isSelected: true`
4. All older versions get `isSelected: false`

The Flutter app listens to this collection with a real-time stream. As soon as the Cloud Function writes, the app updates automatically.

You can tap any old version to set it as selected again.

---

## PART 10 — FULL SCREEN FLOW

```
App Launch
    │
    ▼
Splash Screen
Checks Firebase Auth state automatically
    │
    ├── User logged in ──────────► Home Dashboard
    │                                   │
    └── Not logged in ──► Login         │
              │           Register      │
              │                    [Tabs: Drafts / Saved / Favorites]
              │                    (Real-time Firestore stream)
              │
                              [+ New Post]
                                   │
                           Step 1: Image Selection
                           (Camera or Gallery)
                           (Upload → Firebase Storage)
                                   │
                           Step 2: Property Details
                           (Structured form, validated)
                           (Title, Price, Bedrooms...)
                                   │
                           Step 3: Platform Selection
                           (WhatsApp / Instagram / Facebook
                            Twitter / LinkedIn)
                                   │
                           Step 4: AI Generation
                           (Cloud Function called)
                           (Caption appears)
                           (Can switch platforms)
                           (Regenerate = new version, keeps old)
                                   │
                              Save Post
                           (Stored in Firestore)
```

---

## PART 11 — COMMON ERRORS AND FIXES

### "firebase_options.dart has wrong credentials"
Run `flutterfire configure` again — it will regenerate the file with your project's correct values.

### "FirebaseException: PERMISSION_DENIED"
Your Firestore rules are not deployed. Run:
```bash
firebase deploy --only firestore:rules
```

### "Cloud Function timeout" or no caption appears
1. Check that you set your OpenAI key:
   ```bash
   firebase functions:config:get
   ```
   Should show `{ "openai": { "key": "sk-..." } }`
2. Or add your key in the app's Settings screen instead.

### "MissingPluginException" on Flutter run
Run these in the flutter_app folder:
```bash
flutter clean
flutter pub get
flutter run
```

### Images not uploading
Check `storage.rules` is deployed:
```bash
firebase deploy --only storage
```

### App crashes on startup
Make sure you ran `flutterfire configure` — the `firebase_options.dart` template file will not work until you replace it with your real values.

---

## PART 12 — PROJECT FILE STRUCTURE

```
postcraft_firebase/
│
├── firebase.json              ← Firebase project config
├── firestore.rules            ← Database security rules
├── storage.rules              ← Storage security rules
│
├── functions/                 ← AI backend (Cloud Functions)
│   ├── package.json
│   └── index.js               ← generateCaption() + deletePost()
│
└── flutter_app/
    ├── pubspec.yaml            ← Flutter + Firebase dependencies
    └── lib/
        ├── main.dart           ← App entry point
        ├── firebase_options.dart ← Generated by flutterfire configure
        │
        ├── models/
        │   └── models.dart     ← PostModel, CaptionVersionModel
        │
        ├── services/
        │   └── firebase_service.dart  ← ALL Firebase calls in one place
        │
        ├── providers/
        │   └── providers.dart  ← AuthProvider, PostsProvider, AiProvider
        │
        ├── utils/
        │   └── app_theme.dart  ← Colors, theme, AppConstants
        │
        ├── widgets/
        │   └── common_widgets.dart  ← Reusable UI components
        │
        └── screens/
            ├── splash_screen.dart
            ├── auth/
            │   ├── login_screen.dart
            │   └── register_screen.dart
            ├── home/
            │   └── home_screen.dart
            ├── create/
            │   ├── image_selection_screen.dart
            │   ├── property_details_screen.dart
            │   ├── platform_selection_screen.dart
            │   └── generation_screen.dart  ← Version history lives here
            ├── history/
            │   └── history_screen.dart
            ├── post_detail/
            │   └── post_detail_screen.dart
            └── settings/
                └── settings_screen.dart
```

---

## QUICK START CHECKLIST

```
[ ] 1. Create Firebase project at console.firebase.google.com
[ ] 2. Enable Email/Password Authentication
[ ] 3. Create Firestore Database (production mode)
[ ] 4. Enable Firebase Storage
[ ] 5. npm install -g firebase-tools
[ ] 6. firebase login
[ ] 7. dart pub global activate flutterfire_cli
[ ] 8. cd flutter_app → flutterfire configure
[ ] 9. flutter pub get
[ ] 10. cd .. → firebase deploy --only firestore:rules,storage
[ ] 11. firebase functions:config:set openai.key="sk-..."
[ ] 12. cd functions → npm install → cd ..
[ ] 13. firebase deploy --only functions
[ ] 14. Add Android permissions to AndroidManifest.xml
[ ] 15. flutter run  ← App is live!
```

Total setup time: approximately 30–45 minutes.
After step 15, the app is fully working with real Firebase backend.
