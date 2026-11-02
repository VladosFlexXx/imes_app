<div align="center">

# 🎓 My IMES

### Your personal study assistant in your pocket

[![Latest Release](https://img.shields.io/github/v/release/VladosFlexXx/imes_app?color=4CAF50&logo=android&logoColor=white&style=for-the-badge)](https://github.com/VladosFlexXx/imes_app/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](LICENSE)

<img src="assets/icon/icon.png" alt="App Icon" width="120" height="120" style="border-radius: 20px; box-shadow: 0 4px 20px rgba(0,0,0,0.2);">

**Cross-platform mobile application for IMES Students (Android & iOS)**  
Schedule • Grades • Home • Notifications

[📥 Download APK](https://github.com/VladosFlexXx/imes_app/releases/latest) • [🍏 iPhone (iOS) Guide](docs/IOS_INSTALL_EN.md) • [📖 Features](#-features) • [🐛 Report a Bug](#-report-an-issue)

</div>

---

## ✨ Features

<table>
<tr>
<td width="50%">

### 📅 **Smart Schedule**
- ✅ Fast search across 45 days by subject, classroom, and teacher
- ✅ Export & share schedule (day / week) tailored for Telegram and messengers
- ✅ Automatic odd/even week detection
- ✅ Filtering by dates and week types
- ✅ Only relevant classes and schedules
- ✅ Clean calendar UI

</td>
<td width="50%">

### 🎯 **Grades & Progress**
- ✅ Modern grade cards by subject
- ✅ Automatic GPA calculation
- ✅ Element breakdown and grade details
- ✅ Direct sync with IMES portal

</td>
</tr>
<tr>
<td width="50%">

### 🏠 **Home Dashboard**
- ✅ Real-time upcoming class widget
- ✅ Smart evening mode ("All done for today 🎉", finish times and tomorrow overview)
- ✅ Quick jump to schedule and grades
- ✅ Semester progress and status overview
- ✅ Responsive dynamic cards

</td>
<td width="50%">

### 🔔 **Push Notifications & Themes**
- ✅ Schedule changes and new grade alerts
- ✅ Themes: Light, Dark, AMOLED, Liquid Glass
- ✅ Dynamic Material You colors & accents
- ✅ Launcher icon switcher (Light / Dark)

</td>
</tr>
</table>

---

## 🚀 Quick Start

### 📱 Android
1. **Download APK:**  
   Head to [GitHub Releases](https://github.com/VladosFlexXx/imes_app/releases/latest) and download `vuz_app-release.apk`.
2. **Allow installation from unknown sources** in your device's security settings.
3. **Install & sign in:**  
   Use your IMES portal credentials. Passwords are saved only locally in encrypted secure storage.

### 🍏 Apple iPhone (iOS)
1. **Download IPA:**  
   Download the `MyIMES-*.ipa` bundle from [GitHub Releases](https://github.com/VladosFlexXx/imes_app/releases/latest).
2. **Install via Sideload:**  
   Follow our detailed step-by-step beginner guide:  
   👉 **[iOS Sideload Installation Guide (Sideloadly, Scarlet, TrollStore)](docs/IOS_INSTALL_EN.md)**.

> ⚠️ **Warning:** The app is currently in **BETA**. It is under active continuous development.

---

## 📸 Screenshots

<div align="center">

| Schedule | Grades | Home |
|:----------:|:------:|:-------:|
| <img src="docs/screenshots/schedule.jpg" width="240" alt="Schedule" /> | <img src="docs/screenshots/marks.jpg" width="240" alt="Grades" /> | <img src="docs/screenshots/main.jpg" width="240" alt="Home" /> |

</div>

---

## 🛠 Technology Stack

<div align="center">

| Category | Technologies |
|:---------:|:-----------|
| **Frontend** | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white) ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white) ![Material3](https://img.shields.io/badge/Material_3-757575?style=flat-square&logo=materialdesign&logoColor=white) |
| **Backend** | ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black) ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white) |
| **CI/CD** | ![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat-square&logo=githubactions&logoColor=white) |

</div>

---

## 📊 Project Status

```yaml
Version: 0.4.1 (beta)
Platform: Android / iOS (Sideload)
Status: Active Development
Last Update: November 2026
```

<div align="center">

### 🔥 Development Activity

![GitHub commit activity](https://img.shields.io/github/commit-activity/m/VladosFlexXx/imes_app?style=flat-square&color=4CAF50)
![GitHub last commit](https://img.shields.io/github/last-commit/VladosFlexXx/imes_app?style=flat-square&color=2196F3)
![GitHub issues](https://img.shields.io/github/issues/VladosFlexXx/imes_app?style=flat-square&color=FF9800)

</div>

---

## 🐞 Report an Issue

Found a bug? Help us improve the app!

### Reporting Steps:

1. 📱 Navigate to **Settings → Diagnostics**
2. 📦 Export a bug report (sanitized logs + cache + state)
3. 📤 Attach the report file and open an [Issue](https://github.com/VladosFlexXx/imes_app/issues/new)

> 💡 **Tip:** Diagnostic reports help us isolate and patch issues rapidly!

---

## 🗺 Roadmap

### ✅ Implemented (v0.3.x — v0.4.5)
- [x] Core schedule and grading engine
- [x] Web PWA client for iPhone and desktop without sideloading (works in RU without VPN)
- [x] Redesigned grades interface (modern cards, GPA, detail breakdown)
- [x] AppHaptics tactile feedback
- [x] Material You, AMOLED, Liquid Glass, custom theme accents
- [x] Native light/dark app icon switching on Android
- [x] GitHub Actions automated iOS `.ipa` packaging
- [x] Comprehensive iOS Sideload installation guides
- [x] Secure silent relogin with instant credential cleanup on logout

### 🔨 In Progress (v0.5.x)
- [ ] Offline caching and background sync optimizations
- [ ] Offline schedule viewing
- [ ] Migration to 1C API backend instead of HTML scraping
- [ ] Full university ecosystem integration

### 🚀 Future Plans (v1.0+)
- [ ] RuStore / Google Play store distribution
- [ ] System calendar integration
- [ ] Schedule export (ICS)

---

## 🔐 Security & Privacy

<table>
<tr>
<td width="33%" align="center">

### 🔒 **Authentication**
Direct authentication with IMES portal  
Encrypted secure credential store

</td>
<td width="33%" align="center">

### 🛡 **Data Privacy**
No third-party server data transmission  
Strict on-device sandboxing

</td>
<td width="33%" align="center">

### 🔍 **Diagnostics**
No credentials or passwords collected  
Technical logs only

</td>
</tr>
</table>

---

## 🤝 Contributing

Contributions are welcome!

1. 🍴 Fork the repository
2. 🌿 Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. 💾 Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. 📤 Push to your branch (`git push origin feature/AmazingFeature`)
5. 🎉 Open a Pull Request

---

## 📄 License

This project is distributed **without an open-source license**.  

**Use at your own risk** — intended for educational and testing purposes.

---

## 👨‍💻 Author

<div align="center">

**VladosFlexXx**

[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/VladosFlexXx)

### Support the Project

⭐ **Leave a star** if you found this project helpful!

</div>

---

<div align="center">

### 📱 Download Now

[![Download APK](https://img.shields.io/badge/Download-APK-4CAF50?style=for-the-badge&logo=android&logoColor=white)](https://github.com/VladosFlexXx/imes_app/releases/latest)
[![Download IPA](https://img.shields.io/badge/Download-IPA%20(iOS)-gray?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/VladosFlexXx/imes_app/releases/latest)

**Crafted with ❤️ for IMES Students**

</div>
