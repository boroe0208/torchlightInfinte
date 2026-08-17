# ☄️ Torchlight: Infinite Automation Suite (v2)

A modular, modernized rebuild of the Torchlight Infinite AutoHotkey automation
script. It preserves the exact functionality of the original single-file script
while restructuring the code into focused, maintainable modules.

Requires **AutoHotkey v2.0** or newer.

---

## Quick Start

1. Install [AutoHotkey v2](https://www.autohotkey.com).
2. Double-click `TorchlightInfinite.ahk` (or run it with the AutoHotkey v2
   interpreter). It will prompt for **admin** elevation — allow it. Pass
   `/noadmin` as a launch argument to skip elevation.
3. Launch Torchlight: Infinite and the floating `TL Control` panel will appear.
4. Toggle automation with the hotkeys below.

---

## Hotkey Reference

| Key | Action |
| --- | --- |
| `F1` | Toggle Combat Spam |
| `F2` | Toggle Flask Loop |
| `F3` | Toggle Auto Loot |
| `F4` | Master Pause (saves and restores state) |
| `F5` | Toggle Auto Channel (holds the channel key) |
| `F12` | Interactive color picker (click any point on screen) |
| `RCtrl` | Shop auto-pause (opens/closes shop while pausing automation) |
| `Esc` | While in shop pause: close shop and resume |
| `End` | Reload the script |

All toggle, action, and pause keys are configurable from **Settings ⚙️** —
click a hotkey field, then press the key you want and it fills in automatically.

> Game-scoped hotkeys only fire while the Torchlight: Infinite window is active.
> When the game loses focus, all automation auto-pauses and restores on return.
> Hovering the status dots shows what the current color means.
> Toggle states (Combat/Flasks/Loot/Channel) are remembered across restarts.

### Exiting the script

- Click the **✕** in the panel header to exit instantly (saves window position
  first).
- While ghosted (🔥 logo), **right-click** the logo to exit.
- The settings page also has an `Exit App ✕` button.

---

## Project Structure

```
TorchlightInfinite-v2/
├── TorchlightInfinite.ahk   # Entry point: admin check, window group, boot, global hotkeys
├── settings.ini             # All configuration (load/save here)
├── README.md
├── docs/
│   └── capabilities.md      # Detailed feature & technical documentation
└── src/
    ├── Config.ahk           # Defaults + INI load/save (single source of truth)
    ├── AutomationEngine.ahk # Combat/flask/loot loops, humanized input, Gaussian
    ├── ColorGuard.ahk       # Pixel sub-sampling, auto-pause, color picker
    ├── WindowMonitor.ahk    # Focus auto-pause/resume, status dots
    ├── UI.ahk               # Floating control panel + scrollable settings page
    └── Controller.ahk       # State machine, toggles, hotkey registration
```

Each module owns one concern. `Config` is the single source of truth: no module
reads or writes `settings.ini` directly except through it.

---

## Configuration

Everything lives in `settings.ini`:

> **Location:** Normally next to the script. When the script runs from a UNC /
> WSL mount path (e.g. `\\wsl.localhost\...`), the file is stored at
> `%APPDATA%\TorchlightInfinite\settings.ini` instead, because Windows INI
> write APIs fail on UNC paths. Existing config is migrated automatically.

- **`[Settings]`** — combat/flask/loot timing, key-hold ranges, shop pause delay,
  mouse speed, and `EnableLog` (opt-in activity log).
- **`[ToggleState]`** — the last automation toggle states (Combat/Flasks/Loot/
  Channel), restored automatically on launch.
- **`[KeyBindings]`** — action keys, flask slot keys, and toggle hotkeys.
- **`[ColorGuard]`** — HUD color monitoring target, variance, and interval,
  plus debounce (`PauseStability`/`ResumeStability`) and `MinPauseMs` for
  reliable menu/pause detection.
- **`[GUI]`** — the overlay's last window position (`X`/`Y`), saved
  automatically on exit/reload.

Values can be edited in the **Settings ⚙️** page and saved with **Apply ✓**,
which validates, re-registers hotkeys, and persists everything to the INI file.

---

## Safety Notes

- The script **pauses automatically** when the game window loses focus, so it
  never types into other applications.
- Input is humanized (randomized hold times, Gaussian interval distribution,
  ±20% loot jitter) to avoid machine-like spam signatures.
- **Sticky-key protection:** every key press is tracked and released reliably
  on pause/exit, overlapping presses are suppressed, and every key/button
  actually held is released if a pause or focus loss happens mid-sequence.
- **Safe key capture:** pressing a hotkey while capturing a key binding does not
  fire the automation toggle.
- **Settings are validated** before applying — duplicate/conflicting hotkeys
  are rejected with an on-screen status message instead of silently breaking.
- Use responsibly. Automated play may violate the game's terms of service.
