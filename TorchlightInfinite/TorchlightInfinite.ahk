#Requires AutoHotkey v2.0
; ==============================================================================
; TORCHLIGHT INFINITE AUTOMATION SCRIPT
; ==============================================================================
; A robust, human-like automation assistant for Torchlight: Infinite.
; Features: Smart Auto-Pause, Combat Spam, Flask Management, Auto Loot.
; ==============================================================================

; ------------------------------------------------------------------------------
; 1. ENVIRONMENT & ADMIN CHECK
; ------------------------------------------------------------------------------
#SingleInstance Force
SendMode "Input"
SetWorkingDir A_ScriptDir
CoordMode "Pixel", "Client"
CoordMode "Mouse", "Client"
CoordMode "ToolTip", "Screen" ; Tooltips are better at fixed screen spots or following mouse

; Ensure Admin Privileges (Required for Game Interaction)
if not A_IsAdmin {
    try {
        if A_IsCompiled
            Run "*RunAs `"" A_ScriptFullPath "`""
        else
            Run "*RunAs `"" A_AhkPath "`" `"" A_ScriptFullPath "`""
    }
    ExitApp
}

; Target Application Definition
global TargetProcess := "ahk_group TLI_Target"
GroupAdd "TLI_Target", "ahk_exe TorchlightInfinite.exe"
GroupAdd "TLI_Target", "Torchlight: Infinite"
GroupAdd "TLI_Target", "Torchlight Infinite Test Harness"

; ------------------------------------------------------------------------------
; 2. USER CONFIGURATION
; ------------------------------------------------------------------------------
; Edit these values to tune the script to your build and preferences.
; Time is in milliseconds (1000ms = 1 second)
; ------------------------------------------------------------------------------
global SpamIntervalMin := 30    ; Combat Spam (F1): Minimum Delay
global SpamIntervalMax := 50   ; Combat Spam (F1): Maximum Delay
global FlaskLoopInterval := 3000  ; Flasks (F2): Cycle Duration (~4.8s)
global FlaskKeyDelayMin := 50    ; Flasks (F2): Min delay between key presses
global FlaskKeyDelayMax := 100   ; Flasks (F2): Max delay between key presses
global LootLoopInterval := 10   ; Auto Loot (F3): Frequency of 'A' press (Gaussian avg)
global KeyHoldMin := 1    ; Humanize: Min Key Press Duration
global KeyHoldMax := 5    ; Humanize: Max Key Press Duration

; Key Bindings
global Key_Skill := "r"
global Key_Loot := "a"
global Key_Flask1 := "F6"
global Key_Flask2 := "F7"
global Key_Flask3 := "F8"

; Function Toggles
global Key_ToggleSpam := "F1"
global Key_ToggleFlasks := "F2"
global Key_ToggleLoot := "F3"
global Key_MasterPause := "F4"

; Color Guard Variables
global ColorGuardEnabled := false
global TargetX := 0
global TargetY := 0
global TargetColor := "0x000000"
global ColorVariance := 15
global isColorPaused := false

global IniFile := "settings.ini"
LoadSettings()

; ------------------------------------------------------------------------------
; 3. GLOBAL STATE
; ------------------------------------------------------------------------------
; Logic States
global isSpamming := false
global isFlaskActive := false
global isAutoLooting := false
global isMasterPaused := false
global isFocusPaused := false
global CurrentHoveredHwnd := 0

; Memory for Resume (What was active before pause?)
global memSpam := false
global memFlask := false
global memLoot := false

; ------------------------------------------------------------------------------
; 4. GUI INTERFACE
; ------------------------------------------------------------------------------
; 4. GUI INTERFACE
; ------------------------------------------------------------------------------
; Create the Main GUI Window
global TLGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner", "TL Control")
TLGui.SetFont("s9", "Segoe UI")
TLGui.BackColor := "0F172A" ; Tailwind Slate 900 (Modern dark blue-slate background)
try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", TLGui.Hwnd, "uint", 33, "int*", 2, "uint", 4) ; Windows 11 Rounded Corners

; --- Header Section ---
TLGui.SetFont("s10 Bold", "Segoe UI")
global txtTitle := TLGui.Add("Text", "x12 y8 w75 h20 +0x200 cE2E8F0", "TL Control")
TLGui.SetFont("s12 Bold cEF4444")
global txtActiveDot := TLGui.Add("Text", "x92 y8 w15 h20 Center +0x200", "●")
TLGui.SetFont("s10 Bold c94A3B8")
global btnMin := TLGui.Add("Text", "x112 y7 w18 h18 Center +0x200 Background1E293B", "—") ; Minimize to logo (Flat style)

; --- Controls Section (Vertical Stack) ---
TLGui.SetFont("s9 Semibold", "Segoe UI")
global chkSpam := TLGui.Add("Checkbox", "x15 y38 w110 vSpam cF8FAFC", "Combat (" Key_ToggleSpam ")")
global chkFlask := TLGui.Add("Checkbox", "x15 y+10 w110 vFlask cF8FAFC", "Flasks (" Key_ToggleFlasks ")")
global chkLoot := TLGui.Add("Checkbox", "x15 y+10 w110 vLoot cF8FAFC", "Auto Loot (" Key_ToggleLoot ")")

; Custom Modern Horizontal Dividers (1px height slate-700)
global sepLine1 := TLGui.Add("Text", "x12 y+10 w116 h1 Background334155")

global chkPause := TLGui.Add("Checkbox", "x15 y+10 w110 vPause cF8FAFC", "Pause All (" Key_MasterPause ")")

global sepLine2 := TLGui.Add("Text", "x12 y+10 w116 h1 Background334155")

; --- Footer / Status (Pill Panel design) ---
TLGui.SetFont("s8 Semibold cE2E8F0")
global txtStatus := TLGui.Add("Text", "x15 y+8 w110 h20 Center +0x200 Background1E293B", "Status: Idle")

TLGui.SetFont("s9 Semibold cF8FAFC")
global btnSettings := TLGui.Add("Text", "x15 y+8 w110 h22 Center +0x200 Background4F46E5", "Settings ⚙️")

; --- Settings Panel (Hidden by default, dark-themed flat input styling) ---
TLGui.SetFont("s8 c94A3B8")
global lblSpam := TLGui.Add("Text", "x15 y+6 w110 h15 Hidden", "Spam (Min/Max):")
global edtSpamMin := TLGui.Add("Edit", "x15 y+2 w50 h20 Number Hidden Background1E293B cF8FAFC -E0x200", SpamIntervalMin)
global edtSpamMax := TLGui.Add("Edit", "x75 yp w50 h20 Number Hidden Background1E293B cF8FAFC -E0x200", SpamIntervalMax)

global lblFlask := TLGui.Add("Text", "x15 y+6 w110 h15 Hidden", "Flask (ms):")
global edtFlask := TLGui.Add("Edit", "x15 y+2 w110 h20 Number Hidden Background1E293B cF8FAFC -E0x200", FlaskLoopInterval)

global lblLoot := TLGui.Add("Text", "x15 y+6 w110 h15 Hidden", "Loot (ms):")
global edtLoot := TLGui.Add("Edit", "x15 y+2 w110 h20 Number Hidden Background1E293B cF8FAFC -E0x200", LootLoopInterval)

global lblHuman := TLGui.Add("Text", "x15 y+6 w110 h15 Hidden", "Hold (Min/Max):")
global edtHoldMin := TLGui.Add("Edit", "x15 y+2 w50 h20 Number Hidden Background1E293B cF8FAFC -E0x200", KeyHoldMin)
global edtHoldMax := TLGui.Add("Edit", "x75 yp w50 h20 Number Hidden Background1E293B cF8FAFC -E0x200", KeyHoldMax)

; --- Key Bindings ---
global lblKeys := TLGui.Add("Text", "x15 y+6 w110 h15 Hidden", "Keys (Combat / Loot):")
global edtKeySkill := TLGui.Add("Edit", "x15 y+2 w50 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Skill)
global edtKeyLoot := TLGui.Add("Edit", "x75 yp w50 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Loot)

global lblFlaskKeys := TLGui.Add("Text", "x15 y+6 w110 h15 Hidden", "Flask Keys (1/2/3):")
global edtKeyF1 := TLGui.Add("Edit", "x15 y+2 w30 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Flask1)
global edtKeyF2 := TLGui.Add("Edit", "x55 yp w30 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Flask2)
global edtKeyF3 := TLGui.Add("Edit", "x95 yp w30 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Flask3)

; --- Color Guard Section ---
global sepColor := TLGui.Add("Text", "x12 y+10 w116 h1 Background334155 Hidden vSepColor")
global lblColorGuard := TLGui.Add("Text", "x15 y+6 w110 h15 Hidden", "Color Guard (Auto-Pause):")
global chkColorGuard := TLGui.Add("Checkbox", "x15 y+2 w110 Hidden vEnableColor cF8FAFC", "Enable Monitoring")
global lblColorCoords := TLGui.Add("Text", "x15 y+6 w120 h15 Hidden", "Coords, Color & Var:")
global edtTargetX := TLGui.Add("Edit", "x15 y+2 w35 h20 Hidden Background1E293B cF8FAFC -E0x200", TargetX)
global edtTargetY := TLGui.Add("Edit", "x55 yp w35 h20 Hidden Background1E293B cF8FAFC -E0x200", TargetY)
global edtTargetColor := TLGui.Add("Edit", "x95 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", TargetColor)
global edtVariance := TLGui.Add("Edit", "x15 y+5 w35 h20 Hidden Background1E293B cF8FAFC -E0x200", ColorVariance)

TLGui.SetFont("s9 Semibold cF8FAFC")
global btnPickColor := TLGui.Add("Text", "x55 yp w80 h20 Center +0x200 Hidden Background6366F1", "Pick Color (F12)")

global btnApply := TLGui.Add("Text", "x15 y+12 w110 h22 Center +0x200 Hidden Background10B981", "Apply Settings ✓")
global btnReload := TLGui.Add("Text", "x15 y+6 w110 h22 Center +0x200 Hidden Background4B5563", "Reload Script 🔄")
global btnExit := TLGui.Add("Text", "x15 y+6 w110 h22 Center +0x200 Hidden BackgroundEF4444", "Exit App ✕")

; --- Minimized Logo (Hidden by default, custom styled icon button) ---
TLGui.SetFont("s10 Bold cF8FAFC")
global btnLogo := TLGui.Add("Text", "x0 y0 w40 h40 Center +0x200 Hidden Background4F46E5", "TL")

; --- GUI Events ---
chkSpam.OnEvent("Click", (*) => ToggleSpam(true))
chkFlask.OnEvent("Click", (*) => ToggleFlasks(true))
chkLoot.OnEvent("Click", (*) => ToggleLoot(true))
chkPause.OnEvent("Click", (*) => ToggleMasterPause(true))
btnMin.OnEvent("Click", (*) => ToggleGuiMode(true))
btnLogo.OnEvent("Click", (*) => ToggleGuiMode(false))
btnSettings.OnEvent("Click", (*) => ToggleSettings())
btnApply.OnEvent("Click", (*) => ApplySettings())
btnReload.OnEvent("Click", (*) => Reload())
btnExit.OnEvent("Click", (*) => ExitApp())
btnPickColor.OnEvent("Click", (*) => PickColorCoord())
chkColorGuard.OnEvent("Click", (*) => ToggleColorGuard(true))

; --- Window Utilities ---
; Draggable Background
OnMessage(0x0201, WM_LBUTTONDOWN)
; Tooltips and hover colors
OnMessage(0x0200, WM_MOUSEMOVE)

; Active Window Check Timer
SetTimer CheckWindowActive, 200

; Show Initial State
TLGui.Show("x50 y150 w140 h240 NoActivate")
WinSetTransparent(180, "ahk_id " TLGui.Hwnd)

; ------------------------------------------------------------------------------
; 5. WINDOW MESSAGE HANDLERS
; ------------------------------------------------------------------------------
WM_LBUTTONDOWN(*) {
    PostMessage 0xA1, 2, , , "ahk_id " TLGui.Hwnd
}

WM_MOUSEMOVE(*) {
    global CurrentHoveredHwnd
    static PrevControl := ""
    CurrControl := ""
    MouseGetPos(, , , &hControl, 2)

    ; Hover state transitions
    if (hControl != CurrentHoveredHwnd) {
        if CurrentHoveredHwnd {
            ResetButtonColor(CurrentHoveredHwnd)
        }
        if IsHoverableButton(hControl) {
            ApplyButtonHoverColor(hControl)
            CurrentHoveredHwnd := hControl
            SetTimer CheckMouseLeave, 50
        } else {
            CurrentHoveredHwnd := 0
            SetTimer CheckMouseLeave, 0
        }
    }

    if (hControl) {
        if (hControl = chkSpam.Hwnd)
            CurrControl := "Spam " StrUpper(Key_Skill) " (" SpamIntervalMin "-" SpamIntervalMax "ms)"
        else if (hControl = chkFlask.Hwnd)
            CurrControl := "Spam " StrUpper(Key_Flask1) "-" StrUpper(Key_Flask3) " (" Round(FlaskLoopInterval / 1000, 1) "s)"
        else if (hControl = chkLoot.Hwnd)
            CurrControl := "Spam " StrUpper(Key_Loot) " (" LootLoopInterval "ms)"
        else if (hControl = chkPause.Hwnd)
            CurrControl := "Master Pause (Saves State)"
        else if (hControl = txtActiveDot.Hwnd)
            CurrControl := "Green: Active`nYellow: Paused`nRed: Inactive (Game Unfocused)"
        else if (hControl = btnSettings.Hwnd)
            CurrControl := "Expand/Collapse Settings"
        else if (hControl = btnApply.Hwnd)
            CurrControl := "Update Timer Values"
        else if (hControl = btnReload.Hwnd)
            CurrControl := "Restart Script"
        else if (hControl = btnExit.Hwnd)
            CurrControl := "Terminate Script"
        else if (hControl = btnMin.Hwnd)
            CurrControl := "Minimize to Logo"
        else if (hControl = btnPickColor.Hwnd)
            CurrControl := "Pick coordinates and average color from screen"
    }

    if (CurrControl != PrevControl) {
        ToolTip CurrControl
        PrevControl := CurrControl
        if (CurrControl)
            SetTimer () => ToolTip(), -2000
    }
}

ToggleGuiMode(minimize) {
    if minimize {
        ; Hide Controls
        txtTitle.Visible := false
        txtActiveDot.Visible := false ; Hide dot
        btnMin.Visible := false
        chkSpam.Visible := false
        chkFlask.Visible := false
        chkLoot.Visible := false
        chkPause.Visible := false
        txtStatus.Visible := false
        btnSettings.Visible := false
        ; Ensure settings are closed when minimizing
        ToggleSettings(false) ; Force close controls

        ; Show Logo
        btnLogo.Visible := true

        ; Shrink Window (Ghost Mode)
        TLGui.Show("w40 h40")
        WinSetTransparent(100, "ahk_id " TLGui.Hwnd)
    } else {
        ; Hide Logo
        btnLogo.Visible := false

        ; Show Controls
        txtTitle.Visible := true
        txtActiveDot.Visible := true ; Show dot
        btnMin.Visible := true
        chkSpam.Visible := true
        chkFlask.Visible := true
        chkLoot.Visible := true
        chkPause.Visible := true
        txtStatus.Visible := true
        btnSettings.Visible := true

        ; Expand Window (Reset settings view to closed)
        TLGui.Show("w140 h240")
        WinSetTransparent(180, "ahk_id " TLGui.Hwnd)
    }
}

ToggleSettings(forceClose := "") {
    static isOpen := false

    if (forceClose != "")
        isOpen := !forceClose ; If forceClose is true, isOpen becomes false
    else
        isOpen := !isOpen

    if isOpen {
        ; Show Timing Controls
        lblSpam.Visible := true
        edtSpamMin.Visible := true
        edtSpamMax.Visible := true
        lblFlask.Visible := true
        edtFlask.Visible := true
        lblLoot.Visible := true
        edtLoot.Visible := true
        lblHuman.Visible := true
        edtHoldMin.Visible := true
        edtHoldMax.Visible := true

        ; Show Key Controls
        lblKeys.Visible := true
        edtKeySkill.Visible := true
        edtKeyLoot.Visible := true
        lblFlaskKeys.Visible := true
        edtKeyF1.Visible := true
        edtKeyF2.Visible := true
        edtKeyF3.Visible := true

        ; Show Color Guard Controls
        TLGui["SepColor"].Visible := true
        lblColorGuard.Visible := true
        chkColorGuard.Visible := true
        lblColorCoords.Visible := true
        edtTargetX.Visible := true
        edtTargetY.Visible := true
        edtTargetColor.Visible := true
        edtVariance.Visible := true
        btnPickColor.Visible := true

        btnApply.Visible := true
        btnReload.Visible := true
        btnExit.Visible := true
        TLGui.Show("h725") ; Expanded height for full menu
    } else {
        ; Hide Timing Controls
        lblSpam.Visible := false
        edtSpamMin.Visible := false
        edtSpamMax.Visible := false
        lblFlask.Visible := false
        edtFlask.Visible := false
        lblLoot.Visible := false
        edtLoot.Visible := false
        lblHuman.Visible := false
        edtHoldMin.Visible := false
        edtHoldMax.Visible := false

        ; Hide Key Controls
        lblKeys.Visible := false
        edtKeySkill.Visible := false
        edtKeyLoot.Visible := false
        lblFlaskKeys.Visible := false
        edtKeyF1.Visible := false
        edtKeyF2.Visible := false
        edtKeyF3.Visible := false

        ; Hide Color Guard Controls
        TLGui["SepColor"].Visible := false
        lblColorGuard.Visible := false
        chkColorGuard.Visible := false
        lblColorCoords.Visible := false
        edtTargetX.Visible := false
        edtTargetY.Visible := false
        edtTargetColor.Visible := false
        edtVariance.Visible := false
        btnPickColor.Visible := false

        btnApply.Visible := false
        btnReload.Visible := false
        btnExit.Visible := false
        TLGui.Show("h240") ; Restore height
    }
}

ApplySettings() {
    global SpamIntervalMin, SpamIntervalMax, FlaskLoopInterval, LootLoopInterval, KeyHoldMin, KeyHoldMax
    global Key_Skill, Key_Loot, Key_Flask1, Key_Flask2, Key_Flask3, ColorGuardEnabled, TargetX,
        TargetY, TargetColor, ColorVariance

    ; Read and clean values
    try {
        nSpamMin := Integer(edtSpamMin.Value)
        nSpamMax := Integer(edtSpamMax.Value)
        nFlask := Integer(edtFlask.Value)
        nLoot := Integer(edtLoot.Value)
        nHoldMin := Integer(edtHoldMin.Value)
        nHoldMax := Integer(edtHoldMax.Value)

        sSkill := edtKeySkill.Value
        sLoot := edtKeyLoot.Value
        sF1 := edtKeyF1.Value
        sF2 := edtKeyF2.Value
        sF3 := edtKeyF3.Value

        ; 1. Update Runtime Variables
        SpamIntervalMin := nSpamMin
        SpamIntervalMax := nSpamMax
        FlaskLoopInterval := nFlask
        LootLoopInterval := nLoot
        KeyHoldMin := nHoldMin
        KeyHoldMax := nHoldMax

        Key_Skill := sSkill
        Key_Loot := sLoot
        Key_Flask1 := sF1
        Key_Flask2 := sF2
        Key_Flask3 := sF3

        bEnableColor := chkColorGuard.Value
        nTargetX := Integer(edtTargetX.Value)
        nTargetY := Integer(edtTargetY.Value)
        sTargetColor := edtTargetColor.Value
        nVariance := Integer(edtVariance.Value)

        ColorGuardEnabled := bEnableColor
        TargetX := nTargetX
        TargetY := nTargetY
        TargetColor := sTargetColor
        ColorVariance := nVariance

        ; 2. Persist to INI
        try {
            IniWrite(nSpamMin, IniFile, "Settings", "SpamIntervalMin")
            IniWrite(nSpamMax, IniFile, "Settings", "SpamIntervalMax")
            IniWrite(nFlask, IniFile, "Settings", "FlaskLoopInterval")
            IniWrite(nLoot, IniFile, "Settings", "LootLoopInterval")
            IniWrite(nHoldMin, IniFile, "Settings", "KeyHoldMin")
            IniWrite(nHoldMax, IniFile, "Settings", "KeyHoldMax")

            IniWrite(sSkill, IniFile, "KeyBindings", "Key_Skill")
            IniWrite(sLoot, IniFile, "KeyBindings", "Key_Loot")
            IniWrite(sF1, IniFile, "KeyBindings", "Key_Flask1")
            IniWrite(sF2, IniFile, "KeyBindings", "Key_Flask2")
            IniWrite(sF3, IniFile, "KeyBindings", "Key_Flask3")

            IniWrite(Key_ToggleSpam, IniFile, "KeyBindings", "Key_ToggleSpam")
            IniWrite(Key_ToggleFlasks, IniFile, "KeyBindings", "Key_ToggleFlasks")
            IniWrite(Key_ToggleLoot, IniFile, "KeyBindings", "Key_ToggleLoot")
            IniWrite(Key_MasterPause, IniFile, "KeyBindings", "Key_MasterPause")

            IniWrite(bEnableColor, IniFile, "ColorGuard", "Enabled")
            IniWrite(nTargetX, IniFile, "ColorGuard", "TargetX")
            IniWrite(nTargetY, IniFile, "ColorGuard", "TargetY")
            IniWrite(sTargetColor, IniFile, "ColorGuard", "TargetColor")
            IniWrite(nVariance, IniFile, "ColorGuard", "ColorVariance")

            ; Refresh GUI Labels
            chkSpam.Text := "Combat (" Key_ToggleSpam ")"
            chkFlask.Text := "Flasks (" Key_ToggleFlasks ")"
            chkLoot.Text := "Auto Loot (" Key_ToggleLoot ")"
            chkPause.Text := "Pause All (" Key_MasterPause ")"

            ; Sync Color Guard State
            ToggleColorGuard(false) ; Refresh loop state without manual toggle override

            ; Re-register Hotkeys
            RegisterHotkeys()

            UpdateStatus("Settings Saved!")
            SetTimer () => UpdateStatus("Status: Idle"), -2000
        } catch as err {
            UpdateStatus("Error Saving INI: " err.Message)
        }
    } catch as err {
        UpdateStatus("Error Reading GUI: " err.Message)
    }
}

RegisterHotkeys() {
    global Key_ToggleSpam, Key_ToggleFlasks, Key_ToggleLoot, Key_MasterPause
    global TargetProcess

    ; Remove existing (if any) to avoid duplicates or conflicts
    try Hotkey(Key_ToggleSpam, "Off")
    try Hotkey(Key_ToggleFlasks, "Off")
    try Hotkey(Key_ToggleLoot, "Off")
    try Hotkey(Key_MasterPause, "Off")
    try Hotkey("F12", "Off")

    ; Register new hotkeys within the game's context using HotIf (v2 function)
    HotIf (*) => WinActive(TargetProcess)
    Hotkey(Key_ToggleSpam, (*) => ToggleSpam())
    Hotkey(Key_ToggleFlasks, (*) => ToggleFlasks())
    Hotkey(Key_ToggleLoot, (*) => ToggleLoot())
    Hotkey(Key_MasterPause, (*) => ToggleMasterPause())
    HotIf ; Reset hotkey context to global

    ; F12 is global for picking color while script is running (if settings open)
    Hotkey("F12", (*) => PickColorCoord())
}

LoadSettings() {
    global SpamIntervalMin, SpamIntervalMax, FlaskLoopInterval, LootLoopInterval, KeyHoldMin, KeyHoldMax
    global Key_Skill, Key_Loot, Key_Flask1, Key_Flask2, Key_Flask3, ColorGuardEnabled, TargetX,
        TargetY, TargetColor, ColorVariance

    if FileExist(IniFile) {
        try {
            SpamIntervalMin := IniRead(IniFile, "Settings", "SpamIntervalMin", SpamIntervalMin)
            SpamIntervalMax := IniRead(IniFile, "Settings", "SpamIntervalMax", SpamIntervalMax)
            FlaskLoopInterval := IniRead(IniFile, "Settings", "FlaskLoopInterval", FlaskLoopInterval)
            LootLoopInterval := IniRead(IniFile, "Settings", "LootLoopInterval", LootLoopInterval)
            KeyHoldMin := IniRead(IniFile, "Settings", "KeyHoldMin", KeyHoldMin)
            KeyHoldMax := IniRead(IniFile, "Settings", "KeyHoldMax", KeyHoldMax)

            Key_Skill := IniRead(IniFile, "KeyBindings", "Key_Skill", Key_Skill)
            Key_Loot := IniRead(IniFile, "KeyBindings", "Key_Loot", Key_Loot)
            Key_Flask1 := IniRead(IniFile, "KeyBindings", "Key_Flask1", Key_Flask1)
            Key_Flask2 := IniRead(IniFile, "KeyBindings", "Key_Flask2", Key_Flask2)
            Key_Flask3 := IniRead(IniFile, "KeyBindings", "Key_Flask3", Key_Flask3)

            Key_ToggleSpam := IniRead(IniFile, "KeyBindings", "Key_ToggleSpam", Key_ToggleSpam)
            Key_ToggleFlasks := IniRead(IniFile, "KeyBindings", "Key_ToggleFlasks", Key_ToggleFlasks)
            Key_ToggleLoot := IniRead(IniFile, "KeyBindings", "Key_ToggleLoot", Key_ToggleLoot)
            Key_MasterPause := IniRead(IniFile, "KeyBindings", "Key_MasterPause", Key_MasterPause)

            ColorGuardEnabled := IniRead(IniFile, "ColorGuard", "Enabled", ColorGuardEnabled)
            TargetX := IniRead(IniFile, "ColorGuard", "TargetX", TargetX)
            TargetY := IniRead(IniFile, "ColorGuard", "TargetY", TargetY)
            TargetColor := IniRead(IniFile, "ColorGuard", "TargetColor", TargetColor)
            ColorVariance := IniRead(IniFile, "ColorGuard", "ColorVariance", ColorVariance)

            ; Sync GUI
            chkColorGuard.Value := ColorGuardEnabled
            edtTargetX.Value := TargetX
            edtTargetY.Value := TargetY
            edtTargetColor.Value := TargetColor
            edtVariance.Value := ColorVariance
        }
    }
    RegisterHotkeys()
    ToggleColorGuard(false) ; Start loop if enabled
}

UpdateStatus(msg) {
    try {
        txtStatus.Value := msg
    }
}

CheckWindowActive() {
    global isMasterPaused, isColorPaused, isFocusPaused

    if WinActive(TargetProcess) {
        if isFocusPaused {
            isFocusPaused := false
            RestoreState()
            if (!isMasterPaused && !isColorPaused)
                UpdateStatus("Resumed (Focused)")
        }
        if (isMasterPaused || isColorPaused) {
            try txtActiveDot.Opt("cF59E0B") ; Yellow/Amber (Paused)
        } else {
            try txtActiveDot.Opt("c10B981") ; Emerald Green (Active)
        }
    } else {
        if !isFocusPaused {
            StopAutomation(true)
            isFocusPaused := true
            UpdateStatus("Unfocused: PAUSED")
        }
        try txtActiveDot.Opt("cEF4444")    ; Crimson Red (Unfocused/Inactive)
    }
}

ToggleColorGuard(fromGui := false) {
    global ColorGuardEnabled, isColorPaused

    if fromGui {
        ColorGuardEnabled := chkColorGuard.Value
    }

    if ColorGuardEnabled {
        UpdateStatus("Monitoring: ON")
        ColorCheckLoop() ; Check immediately
        SetTimer ColorCheckLoop, 100 ; Increased frequency to 100ms for constant checking
    } else {
        if isColorPaused {
            isColorPaused := false
            RestoreState()
        }
        UpdateStatus("Monitoring: OFF")
        SetTimer ColorCheckLoop, 0
    }
}

ColorCheckLoop() {
    global ColorGuardEnabled, TargetX, TargetY, TargetColor, ColorVariance, isColorPaused
    global isMasterPaused

    if not ColorGuardEnabled or isMasterPaused
        return

    try {
        ; Calculate the average color of a 5x5 region around TargetX, TargetY
        currAvgColor := GetAverageColor(TargetX, TargetY, 5)
        
        ; Compare variance distance
        diff := ColorDistance(currAvgColor, TargetColor)
        
        if (diff > ColorVariance) {
            if !isColorPaused {
                StopAutomation(true) ; Save state and stop
                isColorPaused := true
                UpdateStatus("Color Guard: PAUSED")
            }
        } else {
            if isColorPaused {
                isColorPaused := false
                RestoreState()
                UpdateStatus("Color Guard: RESUMED")
            }
        }
    }
}

PickColorCoord() {
    global TargetX, TargetY, TargetColor

    UpdateStatus("Click Target Point...")
    Tooltip "LEFT-CLICK on the point/color you want to monitor`nPress ESC to cancel."

    ; Wait for the user to release the current button click first
    KeyWait "LButton"

    ; Loop until LButton or Esc is pressed
    loop {
        if GetKeyState("LButton", "P") {
            ; Get Mouse Position and Color
            MouseGetPos(&mX, &mY)
            mColor := GetAverageColor(mX, mY, 5)

            ; Update Variables
            TargetX := mX
            TargetY := mY
            TargetColor := mColor

            ; Update GUI
            edtTargetX.Value := TargetX
            edtTargetY.Value := TargetY
            edtTargetColor.Value := TargetColor

            UpdateStatus("Point Picked!")

            ; Auto-save to INI for persistence
            try {
                IniWrite(TargetX, IniFile, "ColorGuard", "TargetX")
                IniWrite(TargetY, IniFile, "ColorGuard", "TargetY")
                IniWrite(TargetColor, IniFile, "ColorGuard", "TargetColor")
            }
            break
        }

        if GetKeyState("Esc", "P") {
            UpdateStatus("Pick Cancelled")
            break
        }

        Sleep 50 ; Prevent CPU hogging
    }

    Tooltip()
    ; Brief sleep to prevent the pickup click from triggering other GUI elements
    Sleep 200
}

; ------------------------------------------------------------------------------
; 6. AUTOMATION LOGIC
; ------------------------------------------------------------------------------

; --- Context Guard ---
#HotIf WinActive(TargetProcess)

; --- Hotkeys ---
; Dynamic: Registered via RegisterHotkeys()

; Non-toggle hotkeys
End:: Reload

; --- Toggles ---

ToggleSpam(fromGui := false) {
    global isSpamming, isMasterPaused, isColorPaused, isFocusPaused, memSpam
    global chkSpam, chkPause

    if (isMasterPaused || isColorPaused || isFocusPaused) {
        ; If paused, we just update the memory of what to do when it resumes
        if fromGui {
            memSpam := chkSpam.Value
        } else {
            memSpam := !memSpam
            chkSpam.Value := memSpam
        }
        UpdateStatus(memSpam ? "Combat Armed" : "Combat Disarmed")
        return
    }

    if fromGui {
        isSpamming := chkSpam.Value
    } else {
        isSpamming := !isSpamming
        chkSpam.Value := isSpamming
    }

    if isSpamming {
        UpdateStatus("Combat: ON")
        SetTimer SpamLoop, 10
    } else {
        UpdateStatus("Combat: OFF")
        SetTimer SpamLoop, 0
    }
}

ToggleFlasks(fromGui := false) {
    global isFlaskActive, isMasterPaused, isColorPaused, isFocusPaused, memFlask
    global chkFlask, chkPause

    if (isMasterPaused || isColorPaused || isFocusPaused) {
        if fromGui {
            memFlask := chkFlask.Value
        } else {
            memFlask := !memFlask
            chkFlask.Value := memFlask
        }
        UpdateStatus(memFlask ? "Flasks Armed" : "Flasks Disarmed")
        return
    }

    if fromGui {
        isFlaskActive := chkFlask.Value
    } else {
        isFlaskActive := !isFlaskActive
        chkFlask.Value := isFlaskActive
    }

    if isFlaskActive {
        UpdateStatus("Flasks: ON")
        SetTimer FlaskLoop, FlaskLoopInterval
        FlaskLoop() ; Fire immediately
    } else {
        UpdateStatus("Flasks: OFF")
        SetTimer FlaskLoop, 0
    }
}

ToggleLoot(fromGui := false) {
    global isAutoLooting, isMasterPaused, isColorPaused, isFocusPaused, memLoot
    global chkLoot, chkPause

    if (isMasterPaused || isColorPaused || isFocusPaused) {
        if fromGui {
            memLoot := chkLoot.Value
        } else {
            memLoot := !memLoot
            chkLoot.Value := memLoot
        }
        UpdateStatus(memLoot ? "Loot Armed" : "Loot Disarmed")
        return
    }

    if fromGui {
        isAutoLooting := chkLoot.Value
    } else {
        isAutoLooting := !isAutoLooting
        chkLoot.Value := isAutoLooting
    }

    if isAutoLooting {
        UpdateStatus("Loot: ON")
        SetTimer LootLoop, LootLoopInterval
    } else {
        UpdateStatus("Loot: OFF")
        SetTimer LootLoop, 0
    }
}

ToggleMasterPause(fromGui := false) {
    global isMasterPaused, chkPause
    local targetState

    if fromGui {
        targetState := chkPause.Value
    } else {
        targetState := !isMasterPaused
        chkPause.Value := targetState
    }

    if targetState {
        StopAutomation(true)
        isMasterPaused := true
        UpdateStatus("Master Paused")
    } else {
        isMasterPaused := false
        RestoreState()
        UpdateStatus("Resumed")
    }
}

; --- Loops ---

SpamLoop() {
    if WinActive(TargetProcess) {
        SendHuman(Key_Skill)
        ; Use Gaussian distribution for more natural rhythm, ensure at least 1ms
        SetTimer SpamLoop, Max(1, RandomGaussian(SpamIntervalMin, SpamIntervalMax))
    }
}

FlaskLoop() {
    if WinActive(TargetProcess) {
        SendHuman(Key_Flask1)
        Sleep Random(FlaskKeyDelayMin, FlaskKeyDelayMax)
        SendHuman(Key_Flask2)
        Sleep Random(FlaskKeyDelayMin, FlaskKeyDelayMax)
        SendHuman(Key_Flask3)
    }
}

LootLoop() {
    if WinActive(TargetProcess) {
        SendHuman(Key_Loot)
        ; Slight variation in check frequency, ensure at least 1ms to prevent turning off
        SetTimer LootLoop, Max(1, Random(LootLoopInterval - 20, LootLoopInterval + 20))
    }
}

; --- Humanization Helpers ---

SendHuman(key) {
    SendInput "{" key " down}"
    Sleep Random(KeyHoldMin, KeyHoldMax)
    SendInput "{" key " up}"
}

RandomGaussian(minVal, maxVal) {
    ; Simple approximation of Gaussian distribution (Central Limit Theorem)
    ; Sum of 3 random numbers favors the center
    rand := (Random(minVal, maxVal) + Random(minVal, maxVal) + Random(minVal, maxVal)) / 3
    return Integer(rand)
}

; --- Color Helpers ---

GetAverageColor(cX, cY, size := 5) {
    offset := size // 2
    totalR := 0
    totalG := 0
    totalB := 0
    count := 0

    loop size {
        dx := A_Index - 1 - offset
        loop size {
            dy := A_Index - 1 - offset
            try {
                colorStr := PixelGetColor(cX + dx, cY + dy)
                num := Integer(colorStr)
                totalR += (num >> 16) & 0xFF
                totalG += (num >> 8) & 0xFF
                totalB += num & 0xFF
                count++
            }
        }
    }
    
    if (count == 0)
        return "0x000000"
        
    avgR := totalR // count
    avgG := totalG // count
    avgB := totalB // count
    
    return Format("0x{:02X}{:02X}{:02X}", avgR, avgG, avgB)
}

ColorDistance(c1, c2) {
    n1 := Integer(c1)
    n2 := Integer(c2)
    
    r1 := (n1 >> 16) & 0xFF
    g1 := (n1 >> 8) & 0xFF
    b1 := n1 & 0xFF
    
    r2 := (n2 >> 16) & 0xFF
    g2 := (n2 >> 8) & 0xFF
    b2 := n2 & 0xFF
    
    diffR := Abs(r1 - r2)
    diffG := Abs(g1 - g2)
    diffB := Abs(b1 - b2)
    
    return Max(diffR, diffG, diffB)
}

; ------------------------------------------------------------------------------
; 7. PAUSE / RESUME LOGIC (SMART SYSTEM)
; ------------------------------------------------------------------------------


StopAutomation(saveState := false) {
    global

    if saveState {
        ; Only save memory if we aren't ALREADY in a paused state
        ; This prevents nested pauses (e.g. Master Pause while Color Paused) from wiping memory
        if (!isMasterPaused && !isColorPaused && !isFocusPaused) {
            memSpam := isSpamming
            memFlask := isFlaskActive
            memLoot := isAutoLooting
        }
    }

    isSpamming := false
    isFlaskActive := false
    isAutoLooting := false

    ; GUI Sync
    chkSpam.Value := 0
    chkFlask.Value := 0
    chkLoot.Value := 0

    SetTimer SpamLoop, 0
    SetTimer FlaskLoop, 0
    SetTimer LootLoop, 0
}

RestoreState() {
    global

    if (isMasterPaused || isColorPaused || isFocusPaused)
        return

    ; Directly apply stored state to avoid logic loops
    if memSpam {
        isSpamming := true
        chkSpam.Value := 1
        SetTimer SpamLoop, 10
    } else {
        isSpamming := false
        chkSpam.Value := 0
        SetTimer SpamLoop, 0
    }

    if memFlask {
        isFlaskActive := true
        chkFlask.Value := 1
        SetTimer FlaskLoop, FlaskLoopInterval
        FlaskLoop()
    } else {
        isFlaskActive := false
        chkFlask.Value := 0
        SetTimer FlaskLoop, 0
    }

    if memLoot {
        isAutoLooting := true
        chkLoot.Value := 1
        SetTimer LootLoop, LootLoopInterval
    } else {
        isAutoLooting := false
        chkLoot.Value := 0
        SetTimer LootLoop, 0
    }

    UpdateStatus("Automation Restored")
}

ResetButtonColor(hwnd) {
    if (hwnd == btnSettings.Hwnd)
        btnSettings.Opt("Background4F46E5")
    else if (hwnd == btnApply.Hwnd)
        btnApply.Opt("Background10B981")
    else if (hwnd == btnReload.Hwnd)
        btnReload.Opt("Background4B5563")
    else if (hwnd == btnExit.Hwnd)
        btnExit.Opt("BackgroundEF4444")
    else if (hwnd == btnPickColor.Hwnd)
        btnPickColor.Opt("Background6366F1")
    else if (hwnd == btnMin.Hwnd)
        btnMin.Opt("Background1E293B")
    else if (hwnd == btnLogo.Hwnd)
        btnLogo.Opt("Background4F46E5")
}

ApplyButtonHoverColor(hwnd) {
    if (hwnd == btnSettings.Hwnd)
        btnSettings.Opt("Background6366F1")
    else if (hwnd == btnApply.Hwnd)
        btnApply.Opt("Background34D399")
    else if (hwnd == btnReload.Hwnd)
        btnReload.Opt("Background6B7280")
    else if (hwnd == btnExit.Hwnd)
        btnExit.Opt("BackgroundF87171")
    else if (hwnd == btnPickColor.Hwnd)
        btnPickColor.Opt("Background818CF8")
    else if (hwnd == btnMin.Hwnd)
        btnMin.Opt("Background334155")
    else if (hwnd == btnLogo.Hwnd)
        btnLogo.Opt("Background6366F1")
}

IsHoverableButton(hwnd) {
    return (hwnd == btnSettings.Hwnd || hwnd == btnApply.Hwnd || hwnd == btnReload.Hwnd 
         || hwnd == btnExit.Hwnd || hwnd == btnPickColor.Hwnd || hwnd == btnMin.Hwnd || hwnd == btnLogo.Hwnd)
}

CheckMouseLeave() {
    global CurrentHoveredHwnd
    if !CurrentHoveredHwnd
        return
        
    MouseGetPos(, , , &hControl, 2)
    if (hControl != CurrentHoveredHwnd) {
        ResetButtonColor(CurrentHoveredHwnd)
        CurrentHoveredHwnd := 0
        SetTimer CheckMouseLeave, 0
    }
}
