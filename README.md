# 🔐 Smart Door Security System

A complete IoT smart door system with face recognition (runs on Linux or Raspberry Pi) and a Flutter mobile app for remote control.

**100% Free — No Firebase — No Paid APIs — Self-hosted**

---

## 📁 Project Structure

```text
Smart Door Security System/
├── backend/          ← FastAPI server (runs on Linux or Raspberry Pi)
└── smart_door_app/   ← Flutter app (Android + iOS)
```

---

## 🖥️ Backend Setup (Linux & Raspberry Pi)

### 1. Install Python dependencies

```bash
cd backend
cp .env.example .env
# Edit .env with your settings (SECRET_KEY, admin email/password, etc.)
nano .env

# Install general requirements
pip install -r requirements.txt
```

### 2. Platform-Specific Packages

**For Raspberry Pi:**
Install packages required for hardware GPIO and Pi Camera:
```bash
pip install RPi.GPIO picamera2 face_recognition numpy
```

**For standard Linux (PC/Server):**
You can run the backend without hardware locking/camera by using the simulation scripts, or install standard OpenCV for USB webcams:
```bash
pip install opencv-python face_recognition numpy
```

### 3. Run the backend server

```bash
# Development
python main.py

# Or with uvicorn directly
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 4. Access the API docs

Open: `http://<your-server-ip>:8000/docs`

### 5. Start the face watcher (in a separate terminal)

**On Raspberry Pi:**
```bash
python face_recognition_module/face_watcher.py
```

**On standard Linux (Testing/Simulation):**
If you don't have a physical camera/door connected, you can run the camera simulator:
```bash
python simulate_camera.py
```

---

## 🌐 Cloudflare Tunnel (Remote Access — Free)

This gives you a public HTTPS URL so the app works anywhere, not just on local Wi-Fi.

### Install cloudflared (Linux & Raspberry Pi)

**For Raspberry Pi (ARM64):**
```bash
curl -L --output cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared.deb
```

**For standard Linux (x86_64 PC):**
```bash
curl -L --output cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
```

### Start a quick tunnel (no account needed — URL changes on restart)

```bash
cloudflared tunnel --url http://localhost:8000
```

Copy the URL shown (e.g. `https://abc123.trycloudflare.com`).

### For a permanent tunnel (free Cloudflare account)

```bash
cloudflared tunnel login
cloudflared tunnel create smart-door
cloudflared tunnel run --url http://localhost:8000 smart-door
```

---

## 📱 Flutter App Setup

### 1. Install Flutter SDK

Download from: https://docs.flutter.dev/get-started/install

```bash
# Verify installation
flutter doctor
```

### 2. Set your server URL

Edit `smart_door_app/lib/config/api_config.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://your-tunnel-url.trycloudflare.com',  // ← change this
);
```

Or pass it at build time:

```bash
flutter run --dart-define=API_BASE_URL=https://your-tunnel.trycloudflare.com
flutter build apk --dart-define=API_BASE_URL=https://your-tunnel.trycloudflare.com
```

### 3. Create the Flutter project scaffolding

Since the Flutter SDK creates boilerplate files, run this first:

```bash
cd smart_door_app
flutter create . --org com.smartdoor --project-name smart_door_app
# This overwrites the default lib/ — our files are already in place
```

### 4. Get dependencies

```bash
flutter pub get
```

### 5. Add the Inter font

Download Inter font from: https://fonts.google.com/specimen/Inter

Place files in: `smart_door_app/assets/fonts/`
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

### 6. Run the app

```bash
# Android device / emulator
flutter run

# Build APK
flutter build apk --release
# APK location: build/app/outputs/flutter-apk/app-release.apk
```

---

## 👥 User Roles

| Role | Access |
|---|---|
| **Admin** | Full control: approve/reject, lock/unlock, manage persons & users |
| **Member** | Approve/reject alerts, lock/unlock door, view everything |
| **Viewer** | Read-only: view alerts, history, persons (for mentor/team) |

### Inviting team members / mentor

1. Open the app → Menu → Manage Users
2. Tap **Invite** button
3. Select role: choose **Viewer** for mentor/team
4. Copy the invite link and send via WhatsApp/Email
5. They open the link → create their account → can view the system

---

## 🔑 PIN & OTP Setup

### PIN (4-6 digit backup access)
- App: Menu → PIN & OTP Setup → Set a 6-digit PIN

### OTP via Google Authenticator
1. Open browser → `https://your-server.com/auth/setup-totp` (login required)
2. Scan the QR code with Google Authenticator
3. Use the 6-digit rotating code for backup access

---

## 🔌 GPIO Wiring (Raspberry Pi 4)

*Note: Skip this section if running on a standard Linux PC for testing.*

```text
RPi GPIO Pin 18 (BCM) → Relay IN
Relay COM → Door Lock +
Relay NC → 12V Power
GND → Common Ground

Door Lock: 12V electric strike/magnetic lock (any)
```

Change pin in `.env`:
```text
DOOR_GPIO_PIN=18
```

---

## 🏗️ Tech Stack (All Free)

| Component | Technology |
|---|---|
| Mobile App | Flutter (Dart) |
| Backend API | FastAPI (Python) |
| Database | SQLite |
| Real-time | WebSockets |
| Auth | JWT + bcrypt |
| Fallback Auth | PIN + TOTP |
| Remote Access | Cloudflare Tunnel (free) |
| Face Recognition | dlib + face_recognition |
| Camera | picamera2 (RPi 4) / OpenCV (Linux) |
| Door Control | RPi.GPIO |

---

## 🚀 Quick Start Summary

```text
1. Clone/copy project to Linux PC or Raspberry Pi
2. pip install -r backend/requirements.txt (and platform specific packages)
3. Copy .env.example to .env and configure
4. python backend/main.py  ← starts the server
5. python backend/face_recognition_module/face_watcher.py (or simulate_camera.py)  ← starts camera
6. cloudflared tunnel --url http://localhost:8000  ← gets public URL
7. Put URL in Flutter app api_config.dart
8. flutter build apk --release  ← build the Android APK
9. Install APK on phone, login with admin credentials from .env
10. Invite your team via the Users screen
```

---

*Built for Smart Door Security System Project — Self-hosted, 100% free resources*
