# ☄️ Torchlight: Infinite Automation Suite - Capabilities & Technical Specifications

This document outlines the features, system architecture, capabilities, and
configurations of the **Torchlight: Infinite Automation Script v2**
(`TorchlightInfinite.ahk`), a modular rebuild of the original automation suite.

---

## 🌟 Core Capabilities & Features

### 1. Smart Active Window Detection & Focus Guard
- **Process Focus Awareness:** The script binds to the active process group
  `ahk_group TLI_Target`, targeting:
  - `TorchlightInfinite.exe`
  - Window Title: `Torchlight: Infinite`
  - Test Harness: `Torchlight Infinite Test Harness`
- **Auto-Pause on Alt-Tab:** If the game window loses focus, all active loops
  (Combat Spam, Flasks, Auto Loot) are immediately suspended to prevent typing
  into other applications or backgrounds.
- **Auto-Resume on Refocus:** As soon as the game window becomes active again,
  the script restores the exact automation state (Combat, Flasks, Loot) that
  was running before the window lost focus.

### 2. Humanized Input Simulation
To minimize detection risks and prevent botting flag triggers, the script
implements human-like input dynamics:
- **Variable Key Press Hold Times:** Keys are not pressed instantaneously. They
  are held down (`SendInput {key down}`) and released (`SendInput {key up}`)
  after a randomized duration (configurable, defaults to `3ms` to `10ms`).
- **Gaussian Combat Interval Distribution:** Rather than a flat random range,
  the combat skill spam uses a three-sample Central Limit Theorem (Gaussian)
  approximation to generate a natural bell-curve distribution of clicks,
  mimicking human fatigue and reaction times.
- **Randomized Loop Offsets:** Loop intervals include dynamic micro-offsets
  (e.g., Loot Loop runs at `Interval ± 20%` randomized per iteration).

### 3. Combat Skill Spam (`F1`)
- Rapidly fires the configured combat skill key (default: `q`).
- Fully adjustable min/max delay boundaries (defaults: `400ms` to `400ms`)
  using the Gaussian distribution.
- Real-time GUI status checkmark and toggle functionality.

### 4. Flask Management Loop (`F2`)
- Cycles through three designated flask keys (defaults: `F6`, `F7`, `F8`)
  sequentially.
- Uses customizable inter-key humanization delays (defaults: `50ms` to `100ms`)
  between each flask keypress.
- Fills the loop interval (default: `3000ms`) before starting the next
  sequence, triggering the first cast immediately upon toggle.

### 5. High-Frequency Auto Loot (`F3`)
- Rapidly presses the game's loot key (default: `f3`).
- Features custom rate tuning with dynamic jitter (±20%) to prevent rapid
  machine-like spam signatures.

### 6. Auto Channeling Skill (`F5`)
- Holds down the configured move toward cursor / channeling skill key
  (default: `s`).
- Continuously channels movement/skills while active.
- Fully integrated into the auto-pause architecture: releases the held key
  immediately when paused (Window Unfocus, Color Guard, Master Pause `F4`,
  Shop `RCtrl`), and restores key hold when automation resumes.

### 7. Intelligent "Color Guard" Auto-Pause System
An integrated color monitoring system designed to watch a specific pixel
location (e.g., health bar, shield bar, or boss health state) and pause all
automation if the color changes beyond a specified threshold:
- **5x5 Pixel Sub-Sampling:** Instead of reading a single pixel, it samples a
  5x5 grid around the target coordinates and calculates the average RGB values
  to avoid false triggers caused by screen noise or particle effects.
- **Max Channel Variance Comparison:** Compares the difference between target
  color and current sub-sampled color. If any color channel (R, G, or B)
  exceeds the defined variance limit, it triggers a pause.
- **Auto-Recovery:** If the monitored color returns to within the variance
  limit, the automation loops automatically resume.
- **Interactive Color Picker:** A global tool (hotkey `F12`) that lets you click
  anywhere on your screen to capture coordinates (`X`, `Y`) and color values in
  hex (`0xRRGGBB`) automatically.

### 8. Auto Void (`Auto Void` checkbox / Color Guard dot)
- Monitors a second pixel target (the void trigger color) at
  `[AutoVoidGuard]` coordinates.
- When the void color is detected, executes a fully **data-driven routine**
  (see below) to navigate and interact automatically.
- Forcing Auto Loot on while Auto Void is active, and preserving loot state
  through pause/resume cycles.
- **Abort on pause:** if a master/focus/shop/color pause (or focus loss)
  happens mid-sequence, the routine aborts at the next step and releases any
  held keys/buttons, so it never runs while paused or leaves input stuck.

### 9. Sticky-Key Protection
- Every key press is tracked through a **key-state registry** with its pending
  release timer. Re-pressing a key that is still held cancels the previous
  release and restarts the hold instead of sending overlapping presses.
- All held keys and mouse buttons are released on pause, exit, reload, and when
  the Auto Void routine aborts, so keys cannot be left stuck.

### 10. Settings Validation & Diagnostics
- **Hotkey validation:** Before applying settings, duplicate toggle/shop
  bindings, collisions with the reserved `F12` color-picker key, and action
  keys that equal a toggle hotkey are rejected with a status message.
- **Void steps validation:** Malformed or unknown steps in `[AutoVoidRoutine]`
  are reported on Apply instead of failing silently.
- **Activity log:** Optional `EnableLog` writes a timestamped event trail to
  `%APPDATA%\TorchlightInfinite\activity.log` for debugging.
- **Safe key capture:** Toggle hotkeys are suppressed while a key binding is
  being captured, so pressing e.g. `F2` during capture cannot fire flasks.

---

## 🕹️ User Interface (GUI Overlay)

The script features a borderless, semi-transparent, dark-themed control panel
designed to float on top of the game:
- **Status Indicator Dots:**
  - 🟢 **Green (Lime):** Automation is running and active.
  - 🟡 **Yellow:** Script is active, but currently paused (by Master Pause or
    Color Guard).
  - 🔴 **Red:** Script is inactive or the game is currently out of focus.
  - **Void dot:** Indicates Auto Void armed (indigo) / paused (yellow) / idle
    (grey).
  - **Hover tooltips:** Hovering the dots shows what the current color means.
    The main dot reports the live state (active / specific pause reason /
    unfocused); the void dot shows its color legend.
- **Minimize to Logo ("Ghost Mode"):** Collapse the control panel into a tiny
  `🔥` button to clear screen space. **Right-click** the logo to exit.
- **Header controls:** A **Minimize `—`** and **Exit `✕`** button in the panel
  header. `✕` fully exits the script (saving the window position first). A
  small version tag is shown in the footer.
- **Hover Tooltips:** Moving the mouse over checkboxes or buttons displays
  context-sensitive descriptions.
- **Draggable Window:** Easily reposition the UI overlay by clicking and
  dragging anywhere on its background. The window position is remembered across
  sessions.
- **Key Capture:** Clicking any hotkey field in the settings page switches to
  capture mode — press a key and it fills in the field (Esc cancels).
- **Scrollable Settings Page:** A dedicated settings view with a mouse-wheel
  scrollable list of timing, key-binding, color-guard, void-options, and void
  routine steps fields.

---

## ⚙️ Configuration File (`settings.ini`)

Settings are persisted in a local `settings.ini` configuration file. It lives
next to the script normally; when the script runs from a UNC/WSL mount
(`\\wsl.localhost\...`), it is stored at
`%APPDATA%\TorchlightInfinite\settings.ini` because Windows INI APIs cannot
write to UNC paths. Existing config is migrated automatically on first run.

The file is organized under the following sections:

### `[Settings]`
- `SpamIntervalMin` / `SpamIntervalMax`: Timing boundaries for combat spam.
- `FlaskLoopInterval`: Total wait time between flask cycles.
- `FlaskKeyDelayMin` / `FlaskKeyDelayMax`: Inter-key delays between flask
  keypresses.
- `LootLoopInterval`: Base delay for loot spam.
- `ShopPauseDelay`: Hibernation delay (in ms) when opening shop/menu to allow
  state stabilization.
- `KeyHoldMin` / `KeyHoldMax`: Duration range (in ms) for physical key holding.
- `DefaultMouseSpeed`: Mouse movement speed used by automation routines.
- `EnableLog`: Opt-in activity log (`1` = ON). When enabled, timestamped events
  (start, toggles, pauses, void runs, settings applied) are appended to
  `%APPDATA%\TorchlightInfinite\activity.log`.

### `[ToggleState]`
- `Spam` / `Flasks` / `Loot` / `Channel` / `Void`: The armed on/off state of each
  automation toggle from the previous session, restored automatically on launch.

### `[KeyBindings]`
- `Key_Skill`: Combat skill button.
- `Key_Loot`: Ground pickup button.
- `Key_Channel`: Auto Channeling skill button (move toward cursor key).- `Key_Shop`: Shop / Menu toggle hotkey (default `RCtrl`).
- `Key_Flask1` / `Key_Flask2` / `Key_Flask3`: Hotkeys for flask slots.
- `Key_ToggleSpam` (`F1`): Toggle combat spam.
- `Key_ToggleFlasks` (`F2`): Toggle flask loop.
- `Key_ToggleLoot` (`F3`): Toggle auto loot.
- `Key_ToggleChannel` (`F5`): Toggle auto channel skill.
- `Key_MasterPause` (`F4`): Manually pause/resume all active automation.

> **Note:** `Key_Loot` must not equal the loot toggle hotkey (`Key_ToggleLoot`).
> The script sends `Key_Loot` to pick up loot, and a script-sent key can re-trigger
> its own toggle, causing loot to toggle on/off. Keep them on different keys.
> Applied values are validated and clamped on save.

### `[ColorGuard]`
- `Enabled`: Toggle Color Guard monitoring (`1` = ON, `0` = OFF).
- `CheckInterval`: How often (ms) the monitored pixel is sampled.
- `PauseStability`: Consecutive deviant samples required before pausing
  (debounce, default `2`).
- `ResumeStability`: Consecutive matched samples required before resuming
  (debounce, default `2`).
- `MinPauseMs`: Minimum time the guard must stay paused before it may resume,
  preventing rapid pause/resume churn (default `300`).
- `TargetX` / `TargetY`: Monitored screen pixel coordinates.
- `TargetColor`: Expected hex color.
- `ColorVariance`: Allowed variance threshold.

### `[AutoVoidGuard]`
- `TargetX` / `TargetY` / `TargetColor` / `ColorVariance`: Void trigger pixel
  and tolerance.
- `CheckInterval`: Sampling rate (ms) for the void color.

### `[AutoVoidRoutine]`
- `Steps`: The **data-driven** Auto Void click/key sequence, as a pipe-
  separated list of tokens (editable in-app via the settings page):
  - `Sleep:MS` — pause for `MS` milliseconds.
  - `Move:X,Y[,Speed]` — move the mouse (speed defaults to `DefaultMouseSpeed`).
  - `Click:Button[,HoldMin-HoldMax]` — press, hold, release (default `Left`).
  - `Key:Name[,HoldMin-HoldMax]` — humanized key press (hold defaults to
    `KeyHoldMin`/`KeyHoldMax`).
  - `Send:Text` — raw `Send` (e.g. `Send:{esc}`).

### `[GUI]`
- `X` / `Y`: Last overlay window position, written automatically on exit or
  reload and used on next launch.

---

## 🏗️ Architecture (v2)

The v2 rebuild splits the original single-file script into focused modules:

| Module | Responsibility |
| ------ | -------------- |
| `src/Config.ahk` | Defaults + typed INI load/save. Single source of truth. |
| `src/AutomationEngine.ahk` | Combat/flask/loot loops, humanized input, Gaussian generator. |
| `src/ColorGuard.ahk` | Pixel sub-sampling, color distance, pause logic, picker, void color check. |
| `src/VoidRoutine.ahk` | Parses and executes the data-driven Auto Void sequence. |
| `src/WindowMonitor.ahk` | Focus auto-pause/resume, status dots. |
| `src/UI.ahk` | Floating GUI, scroll, hover/tooltips, drag, minimize. |
| `src/Controller.ahk` | Central state machine, toggles, hotkey registration. |

Behavior is identical to the original; the code is simply organized by concern
and the Auto Void routine is configurable instead of hardcoded.
