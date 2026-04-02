# ✂️ OBS LiveCut 
**The "Zero-Editing" plugin for OBS Studio.**

Stop spending hours cutting out mistakes. **OBS LiveCut** allows you to trim bad takes and **Pause / Resume** your recording "edits" using simple hotkeys. When you hit stop, your edited video is already waiting for you.

---

## 🔒 Privacy & Transparency
We believe in user privacy and security.
* **Audit the Code:** The setup script is provided as a transparent `.bat` file. You can open it in any text editor (like Notepad) to see exactly what it does before running it.
* **Custom Setup:** For maximum privacy, we provide the `setup_instructions.txt` file. You can copy the code from there into your own `.bat` file to ensure you know exactly what is running on your machine.
* **No Hidden Actions:** The script only performs three tasks: downloads FFmpeg from the official source, moves it to your C: drive, and updates your Windows Path.

---

## 💎 Why OBS LiveCut?
* **Zero Data Loss (Safety First):** The plugin **never** touches your original file. It creates a brand new `_FinalTrimmed` version. If anything goes wrong, your raw footage is 100% safe.
* **Pro Hotkeys:** Bind **Cut 10s**, **Cut 30s**, and **Pause / Resume** to any key or mouse button. It works even while you are tabbed into a game.
* **Frame-Perfect Sync:** Uses a high-end FFmpeg filter engine to ensure your audio and video stay perfectly aligned with zero lag.

---

## 🚀 Easy Setup (Recommended)
1. Download `setup_livecut.bat` from this repo.
2. **Right-click** the file and select **"Run as Administrator"**.
3. Restart OBS Studio. 

---

## 🛠️ Manual Setup
If you prefer to configure Windows yourself, follow these steps:

### 1. Install FFmpeg
* Download the "Essentials" zip from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip).
* Create a folder named `C:\ffmpeg`.
* Open the downloaded zip and extract the contents so that the `bin` folder is located at `C:\ffmpeg\bin`.

### 2. Set Windows Environment Variables
* Press the **Windows Key** and type **"Environment Variables"**, then select **"Edit the system environment variables"**.
* Click the **Environment Variables** button at the bottom right.
* Under **System variables**, find the one named **Path** and click **Edit**.
* Click **New** and paste: `C:\ffmpeg\bin`.
* Click **OK** on all windows to save and restart OBS Studio.

---

## 📖 How to Use

### 1. Load the Script
Open OBS and go to **Tools** ➔ **Scripts**. Click the **+** button and select `obs_livecut.lua`.

*(Insert Screenshot 1: The + Button)*
*(Insert Screenshot 2: Selecting the file)*
*(Insert Screenshot 3: Script appearing in the list)*

### 2. Set Your Hotkeys
Go to **Settings** ➔ **Hotkeys**. Search for "Auto-Stitch" and bind your keys:
* **Cut Last 10s / 30s:** Instantly removes the last segment of time from the final edit.
* **Pause / Resume:** Stop the "edit" timer while you take a break, then resume when you're ready.

### 3. The Result
In your recording folder, you will see two files:
1. `Original_Video.mp4` — Your full, original recording.
2. `Original_Video_FinalTrimmed.mp4` — Your clean, edited version.

---

## 📜 License
Licensed under the **MIT License**. Created with 🦾 for the creator community.
