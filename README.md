# emina-weiv (AnimeView)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)](https://python.org)
[![Database](https://img.shields.io/badge/Database-Isar%20%2F%20SQLite-blue)](https://isar.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-green?logo=android)](https://github.com/jirayusgoodlife/emina-weiv/releases)

**emina-weiv (AnimeView)** is a self-hosted personal anime streaming, catalog management, and offline playback ecosystem. It consists of a modern **Flutter Android application** and an AI-powered companion backend server (**Anime Studio**).

---

## 🌟 Key Features

### 📱 Flutter Mobile App
- **High-Performance Streaming**: Smooth playback of direct MP4 and HLS (`.m3u8`) video streams.
- **Offline Download Manager**: Download episodes with multi-threaded downloads (via Dio) for offline watching anytime.
- **Embedded In-App Stream Proxy**: Runs an internal proxy on `127.0.0.1` inside your device to strip obfuscated headers (e.g., fake PNG/WebP wrappers around MPEG-TS chunks) and bypass anti-hotlinking protections seamlessly.
- **Picture-in-Picture (PiP)**: Keep watching in a floating window while multitasking across other apps.
- **Smart Next Episode & Watch Progress**: Automatically tracks watch timestamps via local [Isar Database](https://isar.dev) and surfaces a 1-tap "Next Episode" button near the end of playback.
- **Instant Local Sync via QR Code**: Quickly pair and sync the entire catalog from your PC server across local Wi-Fi by scanning a QR code.
- **In-App Auto Update**: Automatic background check and in-app installer for new APK releases directly from GitHub Releases.
- **Dual Audio Support**: Clean separation and dedicated tabs for Sub (ซับไทย) and Dub (พากย์ไทย) tracks when available.

### 🖥️ Anime Studio (Backend Server & Web UI)
- **Web Dashboard**: Intuitive web interface running on `http://localhost:8800` to manage your library.
- **Automated Metadata & Stream Extractor**: Modular scraping engine supporting WordPress DooPlay themes, custom streaming engines (Ani*** / ayN), and generic fallback heuristics.
- **AI-Powered Scraper Integration**: Optional integration with local LLMs (via Ollama or LM Studio) to inspect and extract video links and metadata from unsupported page structures.
- **HLS Segment Stripper Proxy**: Rewrites HLS manifests and strips obfuscated image headers from video fragments on the fly.
- **QR Code Pairing**: Displays local network IP addresses and a QR code for 1-click synchronization with your mobile client.

---

## 🏗️ Architecture & Workflow

```text
  [ Anime Website ]
         │
         ▼
[ Anime Studio Server (FastAPI :8800) ] ◄── (Optional Local LLM: Ollama / LM Studio)
   - Metadata & Stream Extraction
   - SQLite Catalog Storage (anime_studio.db)
   - QR Code & Local Sync API (/api/sync)
         │
         │  (Local Wi-Fi Sync via QR Scanner)
         ▼
[ Mobile App (Flutter / Android) ]
   - Local Cache & Watch History (Isar DB)
   - In-App Stream Proxy (127.0.0.1)
   - Native Video Player (Chewie / ExoPlayer + PiP)
   - Background Downloader (Dio)
```

---

## 📋 Prerequisites

- **Mobile Client**:
  - Android device running Android 7.0 (API level 24) or newer.
- **Anime Studio Server**:
  - Python 3.10 or higher.
  - Recommended package manager: [`uv`](https://github.com/astral-sh/uv) (or standard `pip`).
- **For Building Flutter from Source (Optional)**:
  - Flutter SDK 3.x with Dart SDK `>=3.0.0 <4.0.0`.
  - Android SDK and Java 17+.

---

## 🚀 Quick Start Guide

### Step 1: Start the Anime Studio Server

1. Open your terminal and navigate to the project directory:
   ```bash
   cd /path/to/emina-weiv
   ```
2. Run the startup script (automatically configures the virtual environment and dependencies using `uv`):
   ```bash
   chmod +x run_server.sh
   ./run_server.sh
   ```
   *Alternatively, run manually:*
   ```bash
   cd server
   python3 -m venv .venv
   source .venv/bin/activate
   pip install fastapi uvicorn httpx beautifulsoup4 pydantic
   python run.py
   ```
3. Open your browser and navigate to:
   ```text
   http://localhost:8800
   ```

---

### Step 2: Extract & Add Anime to Catalog

1. In the **Anime Studio Web UI**, paste any supported anime page URL into the **"Anime URL"** input field.
2. *(Optional)* If connected to Ollama or LM Studio, toggle **"Use AI Extractor"** for intelligent parsing.
3. Click **"Extract Anime"**.
4. Review the extracted title, synopsis, cover image, and episode list.
5. Click **"Save to Catalog"**.

---

### Step 3: Install & Sync with Mobile App

#### A. Install the App
- **From Releases**: Download the latest `.apk` from [GitHub Releases](https://github.com/jirayusgoodlife/emina-weiv/releases) and install it on your Android device.
- **Or Build Locally**:
  ```bash
  flutter pub get
  flutter build apk --release
  # Output file located at: build/app/outputs/flutter-apk/app-release.apk
  ```

#### B. Automated Version Bump & GitHub Release
A helper script [`release.sh`](file:///home/jirayus/Projects/emina-weiv/release.sh) is provided to automate version bumping, testing, building APK, git tagging, and GitHub Releases:
```bash
# Interactive mode (prompts for patch, minor, or major bump):
./release.sh

# Or directly specify bump type:
./release.sh patch   # e.g., 1.0.1 -> 1.0.2
./release.sh minor   # e.g., 1.0.1 -> 1.1.0
./release.sh major   # e.g., 1.0.1 -> 2.0.0
```

#### C. Sync Your Library
1. Make sure your phone and your computer running the server are connected to the **same Wi-Fi / Local Network**.
2. Open the **Anime Studio** web UI on your computer and switch to the **"Sync & Mobile"** tab to view your server's QR code.
3. On your Android app:
   - Tap the **QR Code Scanner** icon in the top app bar.
   - Point your camera at the QR code on your computer screen.
   - *Alternatively, tap "Manual URL" and enter: `http://<YOUR_COMPUTER_IP>:8800/api/sync`.*
4. Your complete catalog will sync instantly into the app's local offline database!

---

## 🎮 Using the Mobile Application

| Feature | How to Use |
| :--- | :--- |
| **Browse & Search** | Use the search bar on the home screen to filter anime by title. |
| **Watch Episodes** | Tap an anime card to open details, select Sub or Dub tab, and tap an episode to start playback. |
| **Picture-in-Picture (PiP)** | Tap the PiP button on the player controls or press your phone's Home gesture/button to enter floating window mode. |
| **Download for Offline** | Tap the download icon next to any episode. Monitor progress under the **Downloads** screen. |
| **Watch Offline** | Go to the **Downloads** screen from the home app bar and tap any completed episode to play without an internet connection. |
| **Smart Next Episode** | A "Next Episode" prompt appears when nearing the end of an episode, allowing seamless transitions. |
| **Check for Updates** | Access settings from the top bar or let the app automatically notify you when a new GitHub release is published. |

---

## ⚙️ Adding New Websites (Scraper Configuration)

Anime Studio supports adding custom website parsing rules without modifying Python code:

### Method 1: Edit `server/custom_sites.json`
Add a configuration entry specifying CSS selectors and regular expressions:

```json
[
  {
    "name": "MyAnimeSite",
    "domains": ["my-anime-site.com"],
    "title_selector": "h1.entry-title",
    "title_clean_regex": "\\s*ตอนที่\\s*\\d+.*$",
    "cover_selector": ".poster img",
    "synopsis_selector": ".entry-content p",
    "episodes_selector": ".episode-list a",
    "episode_number_regex": "(?:ตอนที่|ep(?:isode)?)[-_.\\s]*(\\d+(?:\\.\\d+)?)",
    "stream_regex": "https?://[^\\s\"'<>]+(?:\\.m3u8|\\.mp4)[^\\s\"'<>]*(?:\\?.*)?"
  }
]
```

### Method 2: Custom Python Handler
For complex sites requiring specialized decryption or custom AJAX calls, create a new handler in `server/handlers/` extending `BaseSiteHandler`. Refer to [server/README_SITES.md](server/README_SITES.md) for full instructions.

---

## 🛠️ Tech Stack

### Mobile App (Flutter)
- **State Management**: `provider`
- **Local Database**: `isar_community` (High-performance NoSQL local database)
- **Video Player**: `chewie` & `video_player` (with custom headers and native Android PiP)
- **Networking & Downloads**: `dio`, `http`, `path_provider`
- **QR Scanner**: `mobile_scanner`
- **Display & Styling**: Custom Dark Glassmorphism Material Theme with Google Sans typography

### Server (Python)
- **Framework**: `FastAPI` with `uvicorn`
- **HTTP Client**: `httpx` (async)
- **HTML Parsing**: `BeautifulSoup4`
- **Database**: `SQLite3` (zero-config local storage)
- **Local AI Support**: Compatible with `Ollama` and `LM Studio` (OpenAI-compatible `/v1/chat/completions`)

---

## 📄 License & Disclaimer

This project is developed for **educational, research, and personal media backup purposes only**. All video streams, images, and trademarks belong to their respective copyright holders. Please support official anime releases and authorized streaming services.
