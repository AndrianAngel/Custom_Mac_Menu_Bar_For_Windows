# 🍏 **MacOS-Style Dark Menu Bar for Windows** 🖥️

> Transform your Windows desktop with a sleek, MacOS-inspired dark menu bar!

---

## 📋 **Overview**

This AutoIt script creates a beautiful, functional dark menu bar at the top of your Windows screen that mimics the look and feel of macOS. It provides quick access to system functions, window management, and productivity tools while maintaining a professional dark theme aesthetic.

---

## ✨ **Features**

### 🎯 **Core Functionality**
- **Persistent Top Bar** - Stays visible above all windows
- **Dark Theme** - Eye-friendly dark colors throughout
- **Active App Tracking** - Shows current application name
- **System Clock** - Displays time with day/date
- **Username Display** - Shows current user

### 📂 **Quick Access Menus**

| Menu | Features |
|:-----|:---------|
| **🍎 App Name** | Open app location, Show/hide window, Toggle file extensions, Toggle hidden files |
| **⚡ Quick Actions** | Copy, Cut, Paste, Rename, New Folder, My Computer |
| **⚙️ Setting** | Windows Settings shortcuts (Display, Personalization, Security, etc.) |
| **📍 Jump To** | Quick navigation to common folders (Downloads, Documents, etc.) |
| **🛠️ Tools** | System utilities (CMD, PowerShell, Screenshot, Disk Cleanup, etc.) |
| **📐 Window Position** | Snap windows to screen edges/center |
| **📏 Resize** | Preset window sizes (640x480 to 1920x1080) |
| **ℹ️ About** | Windows version info |

---

## 🎯 **Menu Items**

| Item | Action |
|:-----|:-------|
| **Settings** | Opens Windows Settings |
| **Control Panel** | Launches classic Control Panel |
| **Uninstall Apps** | Opens Apps & Features |
| **Default Apps** | Manages default applications |
| **WinVer** | Shows Windows version |
| **All Apps** | Simulates Windows key press |
| **Everything** | Launches Everything search (configurable path) |
| **CMD** | Command Prompt (Shift+Click for admin) |
| **Display** | Opens Display Settings |
| **Device Manager** | Launches Device Manager |
| **Calculator** | Opens Windows Calculator |
| **Task Manager** | Launches Task Manager |

---

## ⚙️ **Settings Options**

| Setting | Description |
|:--------|:------------|
| **Ignore fullscreen apps** | Auto-hide bar when apps go fullscreen |
| **Use default file manager** | Open folders with your preferred file manager |
| **Reserve screen space** | Bar behaves like a taskbar (prevents windows from overlapping) |
| **Toggle Hotkey** | Customize the settings hotkey (e.g., `!m` for Alt+M) |
| **Custom Icon** | Choose your own icon file |

---

## 🚀 **Installation**

### **Method 1: Direct Download**
1. Download the appropriate zip file for your system:
   - `Mac_Menu_Bar_For_Windows_Stable_x64.zip` (64-bit)
   - `Mac_Menu_Bar_For_Windows_Stable_x86.zip` (32-bit)
2. Extract all files to a folder (e.g., `C:\Programs\MacMenuBar`)
3. Run `Mac_Menu_Bar_For_Windows_Stable_x64.exe` or `Mac_Menu_Bar_For_Windows_Stable_x86.exe`

### **Method 2: From Source**
1. Download `Mac_Menu_Bar_For_Windows_Stable.au3`
2. Download `Additional Libraries .zip` and extract to the same folder
3. Download `icons.zip` and extract to create an `icons` folder
4. Run with AutoIt3 interpreter or compile your own EXE

### **Required Files Structure**
```
YourFolder/
├── Mac_Menu_Bar_For_Windows_Stable.au3
├── _WinAPI_DPI.au3
├── GuiFlatButton_menu.au3
├── icons/
│   ├── mac.ico
│   └── a1.ico
└── settings.ini (created automatically)
```

---

## 🔧 **Usage Tips**

### **Auto-Start with Windows**
Create a shortcut in the startup folder:
1. Press `Win + R`, type `shell:startup` and press Enter
2. Right-click → New → Shortcut
3. Browse to the EXE file and complete the wizard

### **Keyboard Shortcuts in Menus**
- **Quick Actions**: Standard Windows shortcuts work (Ctrl+C, Ctrl+V, etc.)
- **Screenshot**: Available under Tools menu (Win+Shift+S)

### **Window Management**
- Position windows with one click to any screen edge
- Resize to common resolutions instantly
- Toggle app visibility from the App Name menu

---

## 📊 **Version History**

| Version | Date | Changes |
|:--------|:-----|:--------|
| **Alpha 8** | Mar 2026 | • Stable release with full feature set<br>• Improved fullscreen detection<br>• Better memory management<br>• Settings persistence |
| **Alpha 7** | Feb 2026 | • Added window position presets<br>• Fixed DPI scaling issues<br>• Enhanced menu dark mode |
| **Alpha 6** | Jan 2026 | • Introduced window resize presets<br>• Added username display<br>• Performance optimizations |
| **Alpha 5** | Dec 2025 | • GDI rendering for smoother graphics<br>• Icon rendering without white background<br>• Reduced CPU usage |
| **Alpha 4** | Nov 2025 | • Dark theme menus implemented<br>• Added system tray controls<br>• Hotkey configuration |
| **Alpha 3** | Oct 2025 | • Settings dialog added<br>• Fullscreen auto-hide feature<br>• Custom icon support |
| **Alpha 2** | Sep 2025 | • Basic menu structure<br>• Active window tracking<br>• Clock display |
| **Alpha 1** | Aug 2025 | • Initial prototype<br>• Basic bar rendering<br>• Proof of concept |

---

## 🎯 **System Requirements**

- **OS**: Windows 7/8/10/11 (32 or 64-bit)
- **Memory**: ~10-15 MB RAM
- **Disk Space**: ~2 MB
- **Dependencies**: None (standalone executable available)

---

## 📜 **License**

**Copyright © 2026 AndrianAngel**

- ✅ **Open-source** for learning and personal use
- ❌ **Non-commercial use only**
- ✨ Please credit the original author when sharing or modifying

---

## 🐛 **Known Issues & Limitations**

- May conflict with some applications that modify the Windows work area
- Fullscreen detection might not work with all games/applications
- Settings dialog requires app restart to apply some changes

---

## 🆘 **Troubleshooting**

### **Bar doesn't appear?**
- Check if it's running (look for tray icon)
- Try restarting the application
- Check if hotkey is conflicting with another app

### **White background around icon?**
- This is normal during startup; it should disappear after a moment
- If persistent, restart the application

### **Menus appear with light background?**
- Ensure Windows is set to use dark mode
- The script attempts to force dark menus, but some Windows versions may override

---

## 🔄 **Updates & Support**

- **GitHub**: [AndrianAngel/MacMenuBar](https://github.com/AndrianAngel)
- For issues, suggestions, or contributions, please visit the GitHub repository

---

## 🙏 **Acknowledgments**

- AutoIt community for the amazing scripting language
- Windows API documentation providers
- All testers who provided feedback

---

<p align="center">
  <i>Enjoy your Mac-style menu bar on Windows! 🎉</i>
</p>
