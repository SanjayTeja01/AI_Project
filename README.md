# 🛡️ Campus Guard App

✨ **A comprehensive safety application with SOS alerts, emergency contacts management, live location tracking, and AI-powered chatbot assistant for college campuses.**

---

✨ **Developed by Team Campus Guard** ✨

1. **T. Sanjay Teja** - 24BDS083
2. **G. Dharmik** - 24BDS021
3. **G. Banu Vardhan Reddy** - 24BDS022
4. **B. Lokeshwara Reddy** - 24BDS011
5. **M. Santhosh** - 24BDS044

---

## 🎥 App Working Demo

**Watch the demo video to see Campus Guard in action:**

👉 [**Click here to watch the demo video**](https://drive.google.com/file/d/1RsEw6pifrM4uA2P182ylJhNSmcRM7g9R/view?usp=sharing)

---

## 📌 Overview

**Campus Guard** is an AI-powered safety application designed to help students and staff stay safe on campus. The app provides instant emergency alerts, real-time location sharing, and an intelligent voice assistant named **Chitti** for campus navigation and safety guidance.

### **How It Works:**

1. Users register and add trusted emergency contacts
2. The app continuously tracks location on Google Maps
3. When SOS is triggered:
   - Current location is captured and stored in Firestore
   - Messaging app opens with pre-filled emergency message and location link
   - Trusted contacts receive SMS alerts
   - Active SOS screen displays for monitoring
4. **Chitti** (AI assistant) provides campus information, safety tips, and can activate SOS via voice commands
5. Users can view SOS history and manage their profile

---

## 🛠 Tech Stack

* **Frontend:** Flutter (Dart)
* **Backend:** Firebase (Auth, Firestore)
* **APIs:** Google Maps, Geolocator, Speech-to-Text, Text-to-Speech, URL Launcher
* **Permissions:** Permission Handler for runtime permissions

---

## 🚀 Features

### **Core Safety**
* 🚨 **One-Tap SOS Alert** – Instant emergency alerts with automatic location sharing
* 📍 **Live Location Tracking** – Real-time GPS tracking on Google Maps
* 📱 **Automatic SMS Alerts** – Pre-filled emergency messages sent to trusted contacts
* 📊 **SOS History** – Complete history with timestamps and location links
* 👥 **Emergency Contacts** – Add and manage trusted contacts
* 🔄 **Active SOS Monitoring** – Monitor and stop active alerts

### **AI Voice Assistant (Chitti)**
* 🗣️ **Voice & Text Input** – Hands-free interaction via voice or text
* 🎯 **Campus Information** – Bus schedules, building locations, professor availability, security contacts, medical services
* 🛡️ **Safety Guidance** – Safety tips and emergency procedures
* ⚡ **Voice Commands** – Activate SOS, open profile, view contacts/history via voice
* 💬 **Chat History** – Persistent chat sessions saved in Firestore

### **User Management**
* 🔐 **Secure Authentication** – Firebase Auth with email/password
* 👤 **Profile Management** – Update username and mobile number
* 📝 **Terms & Conditions** – User agreement acceptance

---

## 🔧 Installation & Setup

### **Prerequisites**
* Flutter SDK (3.0.0+)
* Android Studio / VS Code with Flutter extensions
* Firebase Account
* Google Maps API Key

### **Setup Steps**

1. **Clone Repository**
   ```bash
   git clone https://github.com/SanjayTeja01/AI_Project.git
   cd AI_Project
   ```

2. **Firebase Setup**
   - Create Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password)
   - Create Firestore Database
   - Download `google-services.json` → place in `android/app/`

3. **Google Maps Setup**
   - Get API key from [Google Cloud Console](https://console.cloud.google.com/)
   - Enable Maps SDK for Android
   - Copy `local.properties.example` to `local.properties`:
     ```bash
     cp local.properties.example local.properties
     ```
   - Edit `local.properties` and add your Google Maps API key:
     ```
     googleMapsApiKey=YOUR_ACTUAL_API_KEY_HERE
     ```
   - **Important**: `local.properties` is gitignored and will NOT be committed to the repository

4. **Install & Run**
   ```bash
   flutter pub get
   flutter run
   ```

---

## 📁 Project Structure

```
campus_gaurd_final/
├── android/                  # Android platform-specific files
│   ├── app/
│   │   ├── build.gradle      # App-level Gradle configuration
│   │   ├── google-services.json  # Firebase configuration
│   │   └── src/
│   │       └── main/
│   │           ├── AndroidManifest.xml  # Android permissions & config
│   │           ├── kotlin/              # Kotlin source files
│   │           └── res/                 # Android resources (icons, styles)
│   ├── build.gradle          # Project-level Gradle configuration
│   ├── settings.gradle       # Gradle settings
│   └── gradle/               # Gradle wrapper files
│
├── assets/                   # App assets
│   └── icon/                 # App icon source image
│       └── Campus Guard Image.png
│
├── lib/                      # Flutter source code
│   ├── main.dart             # App entry point & initialization
│   ├── auth_screen.dart      # Login/Signup screen
│   ├── home_screen.dart      # Main screen with live map & SOS button
│   ├── active_sos_screen.dart # Active SOS monitoring screen
│   ├── sos_screen.dart       # SOS history screen
│   ├── profile_screen.dart   # User profile management
│   ├── contacts_screen.dart  # Emergency contacts management
│   ├── chatbot_screen.dart   # AI voice assistant (Chitti)
│   ├── floating_chatbot.dart # Floating chatbot button widget
│   ├── app_drawer.dart       # Navigation drawer widget
│   └── termsandconditions.dart # Terms & conditions screen
│
├── ios/                      # iOS platform-specific files
├── linux/                    # Linux platform-specific files
├── macos/                    # macOS platform-specific files
├── windows/                  # Windows platform-specific files
│
├── pubspec.yaml              # Flutter dependencies & configuration
├── pubspec.lock              # Locked dependency versions
├── .gitignore                # Git ignore rules
└── README.md                 # Project documentation
```

---

## 🗄️ Firestore Database Structure

### **Collections:**

**`users/{userId}`**
- `email`, `username`, `mobileNumber`, `createdAt`
- Subcollections:
  - `trusted_contacts/{contactId}` - `name`, `phone`, `createdAt`
  - `chat_sessions/{sessionId}` - Chat history with messages

**`sos_events/{eventId}`**
- `userId`, `triggeredAt`, `cancelledAt`, `location` (GeoPoint), `locationLink`, `status` ('active' | 'cancelled')

### **Security Rules:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      match /trusted_contacts/{contactId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /chat_sessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        match /messages/{messageId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
    match /sos_events/{eventId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

---

## 📱 Permissions

**Android:**
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` - GPS tracking
- `INTERNET` - Firebase and API calls
- `RECORD_AUDIO` - Voice input

**Runtime:** Location and microphone permissions requested at runtime.

---

## 🔧 Configuration

**Dependencies (pubspec.yaml):**
- `firebase_core: ^2.24.2`, `firebase_auth: ^4.15.3`, `cloud_firestore: ^4.13.6`
- `geolocator: ^10.1.0`, `google_maps_flutter: ^2.5.0`
- `speech_to_text: ^7.0.0`, `flutter_tts: ^4.0.2`
- `permission_handler: ^11.3.0`, `url_launcher: ^6.2.2`

**Android:**
- Min SDK: 21, Target SDK: 34
- Gradle: 8.7, AGP: 8.6.0, Kotlin: 2.0.0, Java: 17

---

## 🚀 Future Improvements

* Push Notifications for contacts
* Geofencing for campus boundaries
* Emergency services integration
* Group safety features
* Incident reporting
* Offline mode support
* Multi-language support
* Dark mode
* Home screen widget

---

## 📝 Important Notes

1. **Location Permissions:** Required for SOS functionality
2. **Firebase:** Ensure `google-services.json` is configured
3. **Google Maps:** Valid API key required
4. **Speech Recognition:** Requires Google app on Android
5. **SMS:** Opens messaging app; user must manually send message

---

## 🙏 Acknowledgments

* Firebase for backend services
* Google Maps for location services
* Flutter team for the framework
* Open-source community

---

**Stay Safe! 🛡️**
