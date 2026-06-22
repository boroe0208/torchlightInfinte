# ☄️ Torchlight: Infinite Automation Suite - Capabilities & Technical Specifications

This document outlines the features, system architecture, capabilities, and configurations of the **Torchlight: Infinite Automation Script** (`TorchlightInfinite.ahk`).

---

## 🌟 Core Capabilities & Features

### 1. Smart Active Window Detection & Focus Guard
* **Process Focus Awareness:** The script binds to the active process group `ahk_group TLI_Target`, targeting:
  * `TorchlightInfinite.exe`
  * Window Title: `Torchlight: Infinite`
  * Test Harness: `Torchlight Infinite Test Harness`
* **Auto-Pause on Alt-Tab:** If the game window loses focus, all active loops (Combat Spam, Flasks, Auto Loot) are immediately suspended to prevent typing into other applications or backgrounds.
* **Auto-Resume on Refocus:** As soon as the game window becomes active again, the script restores the exact automation state (Combat, Flasks, Loot) that was running before the window lost focus.

### 2. Humanized Input Simulation
To minimize detection risks and prevent botting flag triggers, the script implements human-like input dynamics:
* **Variable Key Press Hold Times:** Keys are not pressed instantaneously. They are held down (`SendInput {key down}`) and released (`SendInput {key up}`) after a randomized duration (configurable, defaults to `1ms` to `5ms`).
* **Gaussian Combat Interval Distribution:** Rather than a flat random range, the combat skill spam uses a three-sample Central Limit Theorem (Gaussian) approximation to generate a natural bell-curve distribution of clicks, mimicking human fatigue and reaction times.
* **Randomized Loop Offsets:** Loop intervals include dynamic micro-offsets (e.g., Loot Loop runs at `Interval +/- 20ms` randomized per iteration).

### 3. Combat Skill Spam (`F1`)
* Rapidly fires the configured combat skill key (default: `r`).
* Fully adjustable min/max delay boundaries (defaults: `30ms` to `50ms`) using the Gaussian distribution.
* Real-time GUI status checkmark and toggle functionality.

### 4. Flask Management Loop (`F2`)
* Cycles through three designated flask keys (defaults: `F6`, `F7`, `F8`) sequentially.
* Uses customizable inter-key humanization delays (defaults: `50ms` to `100ms`) between each flask keypress.
* Fills the loop interval (default: `3000ms`) before starting the next sequence, triggering the first cast immediately upon toggle.

### 5. High-Frequency Auto Loot (`F3`)
* Rapidly presses the game's loot key (default: `a`).
* Features custom rate tuning with dynamic jitter to prevent rapid machine-like spam signatures.

### 6. Intelligent "Color Guard" Auto-Pause System
An integrated color monitoring system designed to watch a specific pixel location (e.g., health bar, shield bar, or boss health state) and pause all automation if the color changes beyond a specified threshold:
* **5x5 Pixel Sub-Sampling:** Instead of reading a single pixel, it samples a 5x5 grid around the target coordinates and calculates the average RGB values to avoid false triggers caused by screen noise or particle effects.
* **Max Channel Variance Comparison:** Compares the difference between target color and current sub-sampled color. If any color channel (R, G, or B) exceeds the defined variance limit, it triggers a pause.
* **Auto-Recovery:** If the monitored color returns to within the variance limit, the automation loops automatically resume.
* **Interactive Color Picker:** A global tool (hotkey `F12`) that lets you click anywhere on your screen to capture coordinates (`X`, `Y`) and color values in hex (`0xRRGGBB`) automatically.

---

## 🕹️ User Interface (GUI Overlay)

The script features a borderless, semi-transparent, dark-themed control panel designed to float on top of the game:
* **Status Indicator Dot:** 
  * 🟢 **Green (Lime):** Automation is running and active.
  * 🟡 **Yellow:** Script is active, but currently paused (by Master Pause or Color Guard).
  * 🔴 **Red:** Script is inactive or the game is currently out of focus.
* **Minimize to Logo ("Ghost Mode"):** Collapse the control panel into a tiny `TL` button to clear screen space.
* **Hover Tooltips:** Moving the mouse over checkboxes or buttons displays context-sensitive descriptions.
* **Draggable Window:** Easily reposition the UI overlay by clicking and dragging anywhere on its background.

---

## ⚙️ Configuration File (`settings.ini`)

Settings are persisted in a local `settings.ini` configuration file under the following sections:

### `[Settings]`
* `SpamIntervalMin` / `SpamIntervalMax`: Timing boundaries for combat spam.
* `FlaskLoopInterval`: Total wait time between flask cycles.
* `LootLoopInterval`: Base delay for loot spam.
* `KeyHoldMin` / `KeyHoldMax`: Duration range (in ms) for physical key holding.

### `[KeyBindings]`
* `Key_Skill`: Combat skill button.
* `Key_Loot`: Ground pickup button.
* `Key_Flask1` / `Key_Flask2` / `Key_Flask3`: Hotkeys for flask slots.
* `Key_ToggleSpam` (`F1`): Toggle combat spam.
* `Key_ToggleFlasks` (`F2`): Toggle flask loop.
* `Key_ToggleLoot` (`F3`): Toggle auto loot.
* `Key_MasterPause` (`F4`): Manually pause/resume all active automation.

### `[ColorGuard]`
* `Enabled`: Toggle Color Guard monitoring (`1` = ON, `0` = OFF).
* `TargetX` / `TargetY`: Monitored screen pixel coordinates.
* `TargetColor`: Expected hex color.
* `ColorVariance`: Allowed variance threshold.
