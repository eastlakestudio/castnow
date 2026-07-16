# CastNow

[![Project License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform - Web](https://img.shields.io/badge/platform-Web-orange.svg)](#appsweb)
[![Platform - iOS](https://img.shields.io/badge/platform-iOS-blue.svg)](#appsmobile_pro)

**CastNow** is a high-performance, native P2P screen sharing engine. It allows instant screen casting directly from your browser or mobile device to any receiver with zero installation, zero sign-up, and 4K support.

## 🚀 Key Features

- **No Installation Required**: Cast directly from any modern web browser.
- **Secure P2P Encrypted**: Your stream data never touches our servers.
- **Instant Sharing**: 6-digit access codes for quick connection.
- **4K Support**: High-fidelity screen mirroring powered by WebRTC.
- **Multi-platform**: Native mobile apps and a full-featured web client.

---

## 📂 Project Structure

This is a monorepo containing both the web and mobile implementations:

```
castnow/
├── apps/
│   ├── web/        # Vue 3 + Vite + TailwindCSS web application
│   └── mobile_pro/ # Flutter-based mobile application (iOS)
├── package.json    # Monorepo configuration and helper scripts
└── README.md
```

### 💻 [apps/web](./apps/web)
The web client built with **Vue 3**, **Vite**, and **TailwindCSS**. It serves as both a sender (screen/camera casting) and a receiver.

### 📱 [apps/mobile](./apps/mobile)
The native mobile application built with **Flutter**. It uses **flutter_webrtc** and **peerdart** to provide a high-performance, native casting experience on iOS.

---

## 🛠 Tech Stack

- **Core**: WebRTC (P2P), PeerJS (Signaling)
- **Web**: Vue.js 3, Vite, TailwindCSS
- **Mobile**: Flutter, Dart
- **Infrastructure**: Vercel (Hosting), Redis (Signaling helper)

---

## 🏁 Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v18+)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable)

### Web Development

1. Navigate to the web app directory:
   ```bash
   cd apps/web
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start the development server:
   ```bash
   npm run dev
   ```

### Mobile Development

1. Navigate to the mobile app directory:
   ```bash
   cd apps/mobile_pro
   ```
2. Get packages:
   ```bash
   flutter pub get
   ```
3. Run on a connected device:
   ```bash
   flutter run
   ```

---

## 🛡 License

This project is licensed under the MIT License.

---
*Made with ❤️ by Eastlake Studio*
