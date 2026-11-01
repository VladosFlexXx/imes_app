# 🍏 How to Install "My IMES" on iPhone (iOS)

> [!NOTE]
> The application is distributed as an `.ipa` file (iOS equivalent of `.apk` on Android).  
> Since we do not maintain a paid \$99/year Apple Developer membership for the App Store, you can easily install the app on your iPhone using **Sideloading**. It is completely free, safe, and does not require a jailbreak.

---

## ⚡ Mandatory Pre-requisite (iOS 16, 17, 18)
If your iPhone runs iOS 16 or newer, you **must enable Developer Mode** prior to launching sideloaded apps:
1. Open **Settings** on your iPhone.
2. Go to **Privacy & Security**.
3. Scroll to the very bottom and tap **Developer Mode**.
4. Toggle the switch to **On**.
5. Your device will prompt to restart — tap **Restart**.
6. After unlocking the screen, tap **Turn On** in the system dialog and enter your passcode.

---

## 💻 Method 1. Via PC / Mac (Sideloadly) — Recommended & Most Stable
* **Pros:** 100% reliable, immune to Apple enterprise certificate revocations, supports automatic Wi-Fi refresh.
* **Requirements:** Computer (Windows or macOS), USB/Lightning/Type-C cable, your iPhone.

### Step 1. Download Required Software
1. On your computer, download and install **[Sideloadly](https://sideloadly.io/)** (available for Windows and macOS).
2. *For Windows users:* Ensure you have **iTunes** and **iCloud** installed directly [from Apple's website](https://support.apple.com/HT210384) (**NOT** from the Microsoft Store).
3. Download the latest **`MyIMES-vX.X.X.ipa`** from [GitHub Releases](https://github.com/VladosFlexXx/imes_app/releases/latest).

### Step 2. Sideloading the App
1. Connect your iPhone to your computer using a cable. Unlock the screen and tap **"Trust This Computer"** if prompted.
2. Launch **Sideloadly** on your computer.
3. Your device should be detected under **iDevice**.
4. Drag and drop the downloaded `.ipa` file onto the IPA icon box in Sideloadly.
5. In the **Apple ID** field, type your personal Apple ID (email associated with your iPhone). Apple uses this to sign the app with your personal free 7-day developer certificate. Credentials go directly to Apple.
6. Click **Start**.
7. If Two-Factor Authentication is requested, enter the 6-digit code shown on your iPhone screen.
8. Wait until Sideloadly shows `Done.`. The app icon will now appear on your home screen!

### Step 3. Trusting the Developer Certificate
When you first attempt to open the app, iOS will display *“Untrusted Developer”*. This is standard procedure:
1. Go to iPhone **Settings** -> **General** -> **VPN & Device Management**.
2. Under "Developer App", tap your Apple ID email.
3. Tap **Trust "[Your Apple ID]"** -> tap **Trust** to confirm.
4. You are all set! "My IMES" is ready to use.

> [!TIP]
> **Automatic Refresh:** In Sideloadly settings, check the *Automatic Refresh* option. The app certificate will automatically renew every few days whenever your iPhone and computer are on the same Wi-Fi network!

---

## 📱 Method 2. Without a PC (via Scarlet)
* **Pros:** No computer required; installation takes 2 minutes in Safari.
* **Cons:** Public enterprise certificates are occasionally revoked by Apple (requires reinstalling every 2–4 weeks).

1. Open **Safari** on your iPhone and visit **[usescarlet.com](https://usescarlet.com)**.
2. Scroll down and tap the red **Install** button.
3. If an ad tab opens, close it and go back. Tap **Direct Install**.
4. Wait 10 seconds, then tap **"Open in iTunes" -> "Install"**.
5. The **Scarlet** app will appear on your home screen.
6. Open **Settings** -> **General** -> **VPN & Device Management**, find Scarlet's enterprise certificate and tap **"Trust"**.
7. Visit [GitHub Releases](https://github.com/VladosFlexXx/imes_app/releases/latest) and download the **`MyIMES-vX.X.X.ipa`** file.
8. Open **Scarlet**, tap the center icon at the bottom (Download icon), then tap the **Import** button in the top-right corner.
9. Select the downloaded `MyIMES-vX.X.X.ipa` file.
10. Wait for the progress bar to finish and tap **Install**. The app will appear on your home screen!

---

## ⚡ Method 3. For TrollStore Users (iOS 14.0 — 16.6.1)
If your device has **TrollStore** installed:
1. Download the `MyIMES-vX.X.X.ipa` file in Safari.
2. Tap the **Share** button -> select **TrollStore**.
3. Tap **Install**.
4. The application is permanently installed without 7-day limits, revokes, or need for re-signing.

---

## ❓ Troubleshooting & FAQ

### 1. "Untrusted Enterprise / Developer" Error
**Fix:** Go to *Settings -> General -> VPN & Device Management -> Tap your profile -> Trust*.

### 2. "Developer Mode Required" Error
**Fix:** On iOS 16+, go to *Settings -> Privacy & Security -> Developer Mode (at the bottom) -> Enable -> Restart iPhone*.

### 3. App crashes or won't open after 7 days (Sideloadly)
**Fix:** Free Apple ID certificates expire after 7 days. Connect your phone to your PC and click **Start** in Sideloadly again (all app data and settings will be preserved).

### 4. Scarlet stopped opening / "Unable to Verify"
**Fix:** Apple revoked the enterprise certificate. Delete Scarlet, reinstall it with a fresh certificate from usescarlet.com, or use Method 1 (Sideloadly).

