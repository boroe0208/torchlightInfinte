# AutoHotkey & Python Gaming Scripts

A collection of utility and automation scripts for ARPGs (Torchlight: Infinite, Path of Exile).

---

## 📂 Repository Contents

| Script | Language | Game Target | Description |
| :--- | :--- | :--- | :--- |
| [**TorchlightInfinite.ahk**](file:///c:/Users/ed2/My%20Programs/auto%20hotkey/TorchlightInfinite/TorchlightInfinite.ahk) | AutoHotkey v2 | Torchlight: Infinite | GUI-controlled multi-feature automation suite (Combat, Flasks, Auto Loot, Color Guard auto-pause). |
| [**poe.ahk**](file:///c:/Users/ed2/My%20Programs/auto%20hotkey/poe.ahk) | AutoHotkey v2 | Path of Exile | Regex search string copier for stash/map screening. |
| [**AwakenedAlterationSpam.py**](file:///c:/Users/ed2/My%20Programs/auto%20hotkey/AwakenedAlterationSpam.py) | Python 3 | General/PoE | Automated crafting roller using Regex matching and safety limits. |

---

## ☄️ Torchlight: Infinite Automation Suite (`TorchlightInfinite/TorchlightInfinite.ahk`)

A fully-featured, GUI-driven automation assistant designed specifically for Torchlight: Infinite. It features humanized mouse/keyboard inputs, smart window focus monitoring, and color-based auto-pausing.

### 🌟 Key Features

1. **Combat Skill Spam (`F1`)**
   - Spams a skill key (default `r`) with randomized, human-like delays.
   - Uses a Gaussian distribution (Central Limit Theorem) to avoid unnatural, perfectly repetitive click patterns.
2. **Flask Management (`F2`)**
   - Automatically cycles through three flask slots (default `F6`, `F7`, `F8`) at regular, configurable intervals.
   - Humanized with random micro-delays between flask activations.
3. **Auto Loot (`F3`)**
   - Rapidly spams the loot key (default `a`) to gather drops.
4. **Color Guard (Screen Monitor & Auto-Pause)**
   - Monitors a specific screen coordinate (X, Y) for a target color.
   - If the color shifts beyond a defined variance (e.g., health drops, shield breaks, or a specific UI state triggers), the script immediately pauses automation.
   - Automatically resumes once the color returns to normal.
   - Includes a graphical point-and-click color picker utility.
5. **Smart Auto-Pause & Resume**
   - Automatically pauses all loops if the game window loses focus.
   - Seamlessly restores execution state when the game is refocused.
   - Handles nested pauses (e.g., Master Pause and Window Focus) without losing the original state memory.
6. **GUI Overlay**
   - Borderless, semi-transparent, dark-themed GUI that sits on top of your game window.
   - Expandable **Settings** panel to customize intervals, keybinds, and color guard parameters.
   - Status indicators (Red = Unfocused/Off, Green = Active, Yellow = Paused).

---

### 🕹️ Hotkeys & Control Map

| Key | Action | Context |
| :--- | :--- | :--- |
| **`F1`** | Toggle Combat Spam | Only in-game |
| **`F2`** | Toggle Flask Loop | Only in-game |
| **`F3`** | Toggle Auto Loot | Only in-game |
| **`F4`** | Master Pause / Resume | Only in-game |
| **`F12`** | Pick Coordinate & Color | Global (when Color Guard picker active) |
| **`End`** | Reload Script | Global / In-Game |

---

### ⚙️ Settings & Configuration (`TorchlightInfinite/settings.ini`)

All configurations are saved automatically to `TorchlightInfinite/settings.ini` when applying changes in the GUI. You can also edit it directly when the script is not running:

* **Combat Spam**: Adjust min/max intervals (in milliseconds).
* **Flask Management**: Cycle loop time (in milliseconds) and inter-key delay.
* **Auto Loot**: Set click frequency.
* **Humanization**: Customize key press duration (min/max hold times).
* **Key Bindings**: Define custom keys for combat, loot, and flasks.
* **Color Guard**: Configure target X/Y coordinates, hexadecimal color values (`0xRRGGBB`), and allowable color variance.

---

### 🚀 Getting Started

#### Prerequisites
- **AutoHotkey v2.0** or newer.
- Run the script with **Administrator privileges** (it automatically attempts self-elevation upon execution).

#### Steps
1. Double-click `TorchlightInfinite/TorchlightInfinite.ahk` to run it.
2. The UI window (`TL Control`) will appear on the screen.
3. Drag it by clicking and holding the background.
4. Click **Settings** to customize keys or click durations if needed.
5. Launch Torchlight: Infinite.
6. Use the hotkeys (`F1`-`F4`) to activate or pause the corresponding features.

---

## 🔍 Path of Exile Search Script (`poe.ahk`)

A lightweight script that simplifies stash tab or map screening in Path of Exile by automatically pasting regex search queries.

### 🕹️ Hotkeys
* **`Ctrl + G`**
  - Copies a regex search string (`r"monsters: .+: .+ ([8-9]\d|[1-9]\d{2,})"`) to the clipboard.
  - Automatically activates the PoE search bar (`Ctrl + F`), clears existing input, and pastes the regex pattern to match map mods (e.g. 80%+ monster pack size/quantities).

---

## 🎲 Crafting Roller (`AwakenedAlterationSpam.py`)

A Python script that automates currency rolling (like Alteration Orbs in PoE) by clicking items, copying their details, and checking the text against a regular expression.

### 🌟 Features
- **Regex Checking**: Looks for target mods in the item text copied via the game's `Ctrl + C` hover function.
- **Safety Limit**: Auto-terminates after a user-specified number of attempts to prevent wasting currency.
- **Hotkeys**:
  - `Shift + =`: Start automation loop.
  - `Shift + -`: Stop/Abort.
  - `Ctrl + C` (in terminal): Force close application.

### 📦 Setup & Requirements
Install dependencies using pip:
```bash
pip install keyboard pyautogui pyperclip
```
*Note: Run Python as administrator so the script has system-level permissions to hook keys and inject clicks.*
