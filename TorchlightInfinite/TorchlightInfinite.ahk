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
CoordMode "ToolTip", "Screen"

; Ensure Admin Privileges (Required for Game Interaction)
hasNoAdminFlag := false
for arg in A_Args {
    if (arg = "/noadmin") {
        hasNoAdminFlag := true
        break
    }
}

if not A_IsAdmin and not hasNoAdminFlag {
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
; 2. USER CONFIGURATION (DEFAULT FALLBACKS)
; ------------------------------------------------------------------------------
global SpamIntervalMin := 30      ; Combat Spam (F1): Minimum Delay (ms)
global SpamIntervalMax := 50     ; Combat Spam (F1): Maximum Delay (ms)
global FlaskLoopInterval := 3000  ; Flasks (F2): Cycle Duration (~3.0s)
global FlaskKeyDelayMin := 50    ; Flasks (F2): Min delay between key presses
global FlaskKeyDelayMax := 100   ; Flasks (F2): Max delay between key presses
global LootLoopInterval := 10     ; Auto Loot (F3): Base Delay (ms)
global KeyHoldMin := 1           ; Humanize: Min Key Press Duration
global KeyHoldMax := 5           ; Humanize: Max Key Press Duration

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

; ------------------------------------------------------------------------------
; 3. GLOBAL STATE
; ------------------------------------------------------------------------------
global isSpamming := false
global isFlaskActive := false
global isAutoLooting := false
global isMasterPaused := false
global isFocusPaused := false
global isShopPaused := false
global ColorGuardHibernationEnd := 0
global CurrentHoveredHwnd := 0
global CurrentStatusColor := "4F46E5"

; Memory for Resume (State prior to pause)
global memSpam := false
global memFlask := false
global memLoot := false

IsAnyPaused() {
    global isMasterPaused, isColorPaused, isFocusPaused, isShopPaused
    return isMasterPaused || isColorPaused || isFocusPaused || isShopPaused
}

; ------------------------------------------------------------------------------
; 4. GUI INTERFACE
; ------------------------------------------------------------------------------
global TLGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner", "TL Control")
TLGui.SetFont("s9", "Segoe UI")
TLGui.BackColor := "0F172A" ; Tailwind Slate 900
try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", TLGui.Hwnd, "uint", 33, "int*", 2, "uint", 4) ; Windows 11 Rounded Corners

; --- Header Section ---
TLGui.SetFont("s10 Bold", "Segoe UI")
global txtTitle := TLGui.Add("Text", "x15 y8 w100 h20 +0x200 cE2E8F0", "TL Control")
TLGui.SetFont("s12 Bold cEF4444")
global txtActiveDot := TLGui.Add("Text", "x122 y8 w15 h20 Center +0x200", "●")
TLGui.SetFont("s10 Bold c94A3B8")
global btnMin := TLGui.Add("Text", "x142 y7 w18 h18 Center +0x200 Background1E293B", "—")

; --- Controls Section ---
TLGui.SetFont("s9 w600", "Segoe UI")
global chkSpam := TLGui.Add("Checkbox", "x15 y38 w140 vSpam cF8FAFC", "Combat (" Key_ToggleSpam ")")
global chkFlask := TLGui.Add("Checkbox", "x15 y+10 w140 vFlask cF8FAFC", "Flasks (" Key_ToggleFlasks ")")
global chkLoot := TLGui.Add("Checkbox", "x15 y+10 w140 vLoot cF8FAFC", "Auto Loot (" Key_ToggleLoot ")")
global sepLine1 := TLGui.Add("Text", "x12 y+10 w146 h1 Background334155")
global chkPause := TLGui.Add("Checkbox", "x15 y+10 w140 vPause cF8FAFC", "Pause All (" Key_MasterPause ")")
global sepLine2 := TLGui.Add("Text", "x12 y+10 w146 h1 Background334155")

; --- Footer / Status ---
TLGui.SetFont("s8 w600 cE2E8F0")
global txtStatus := TLGui.Add("Text", "x15 y+8 w140 h20 Center +0x200 Background1E293B", "Status: Idle")
TLGui.SetFont("s9 w600 cF8FAFC")
global btnSettings := TLGui.Add("Text", "x15 y+8 w140 h22 Center +0x200 Background4F46E5", "Settings ⚙️")

; --- Settings Panel Controls ---
TLGui.SetFont("s8 c94A3B8")
global lblSpam := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Spam (Min/Max):")
global edtSpamMin := TLGui.Add("Edit", "x15 y+2 w65 h20 Number Hidden Background1E293B cF8FAFC -E0x200", SpamIntervalMin)
global edtSpamMax := TLGui.Add("Edit", "x90 yp w65 h20 Number Hidden Background1E293B cF8FAFC -E0x200", SpamIntervalMax)

global lblFlask := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Flask (ms):")
global edtFlask := TLGui.Add("Edit", "x15 y+2 w140 h20 Number Hidden Background1E293B cF8FAFC -E0x200", FlaskLoopInterval)

global lblLoot := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Loot (ms):")
global edtLoot := TLGui.Add("Edit", "x15 y+2 w140 h20 Number Hidden Background1E293B cF8FAFC -E0x200", LootLoopInterval)

global lblHuman := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Hold (Min/Max):")
global edtHoldMin := TLGui.Add("Edit", "x15 y+2 w65 h20 Number Hidden Background1E293B cF8FAFC -E0x200", KeyHoldMin)
global edtHoldMax := TLGui.Add("Edit", "x90 yp w65 h20 Number Hidden Background1E293B cF8FAFC -E0x200", KeyHoldMax)

global lblKeys := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Keys (Combat / Loot):")
global edtKeySkill := TLGui.Add("Edit", "x15 y+2 w65 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Skill)
global edtKeyLoot := TLGui.Add("Edit", "x90 yp w65 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Loot)

global lblFlaskKeys := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Flask Keys (1/2/3):")
global edtKeyF1 := TLGui.Add("Edit", "x15 y+2 w40 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Flask1)
global edtKeyF2 := TLGui.Add("Edit", "x65 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Flask2)
global edtKeyF3 := TLGui.Add("Edit", "x115 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", Key_Flask3)

global sepColor := TLGui.Add("Text", "x12 y+10 w146 h1 Background334155 Hidden vSepColor")
global lblColorGuard := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Color Guard (Auto-Pause):")
global chkColorGuard := TLGui.Add("Checkbox", "x15 y+2 w140 Hidden vEnableColor cF8FAFC", "Enable Monitoring")
global lblColorCoords := TLGui.Add("Text", "x15 y+6 w140 h15 Hidden", "Coords, Color & Var:")
global edtTargetX := TLGui.Add("Edit", "x15 y+2 w40 h20 Hidden Background1E293B cF8FAFC -E0x200", TargetX)
global edtTargetY := TLGui.Add("Edit", "x60 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", TargetY)
global edtTargetColor := TLGui.Add("Edit", "x105 yp w50 h20 Hidden Background1E293B cF8FAFC -E0x200", TargetColor)
global edtVariance := TLGui.Add("Edit", "x15 y+5 w40 h20 Hidden Background1E293B cF8FAFC -E0x200", ColorVariance)

TLGui.SetFont("s9 w600 cF8FAFC")
global btnPickColor := TLGui.Add("Text", "x60 yp w95 h20 Center +0x200 Hidden Background6366F1", "Pick Color (F12)")
global btnApply := TLGui.Add("Text", "x15 y+12 w140 h22 Center +0x200 Hidden Background10B981", "Apply Settings ✓")
global btnReload := TLGui.Add("Text", "x15 y+6 w140 h22 Center +0x200 Hidden Background4B5563", "Reload Script 🔄")
global btnExit := TLGui.Add("Text", "x15 y+6 w140 h22 Center +0x200 Hidden BackgroundEF4444", "Exit App ✕")

; --- Minimized Logo ---
TLGui.SetFont("s10 Bold cF8FAFC")
global btnLogo := TLGui.Add("Text", "x0 y0 w40 h40 Center +0x200 Hidden Background4F46E5", "TL")

; --- Control Collections for Streamlined Display Updates ---
global MainControls := [txtTitle, txtActiveDot, btnMin, chkSpam, chkFlask, chkLoot, sepLine1, chkPause, sepLine2, txtStatus, btnSettings]
global SettingsControls := [
    lblSpam, edtSpamMin, edtSpamMax, lblFlask, edtFlask, lblLoot, edtLoot, lblHuman, edtHoldMin, edtHoldMax,
    lblKeys, edtKeySkill, edtKeyLoot, lblFlaskKeys, edtKeyF1, edtKeyF2, edtKeyF3,
    sepColor, lblColorGuard, chkColorGuard, lblColorCoords, edtTargetX, edtTargetY, edtTargetColor, edtVariance,
    btnPickColor, btnApply, btnReload, btnExit
]

global ButtonColors := Map(
    btnSettings.Hwnd,  { normal: "4F46E5", hover: "6366F1", ctrl: btnSettings },
    btnApply.Hwnd,     { normal: "10B981", hover: "34D399", ctrl: btnApply },
    btnReload.Hwnd,    { normal: "4B5563", hover: "6B7280", ctrl: btnReload },
    btnExit.Hwnd,      { normal: "EF4444", hover: "F87171", ctrl: btnExit },
    btnPickColor.Hwnd, { normal: "6366F1", hover: "818CF8", ctrl: btnPickColor },
    btnMin.Hwnd,       { normal: "1E293B", hover: "334155", ctrl: btnMin },
    btnLogo.Hwnd,      { normal: "",       hover: "6366F1", ctrl: btnLogo }
)

; --- GUI Events ---
chkSpam.OnEvent("Click", (*) => ToggleSpam(true))
chkFlask.OnEvent("Click", (*) => ToggleFlasks(true))
chkLoot.OnEvent("Click", (*) => ToggleLoot(true))
chkPause.OnEvent("Click", (*) => ToggleMasterPause(true))
btnMin.OnEvent("Click", (*) => ToggleGuiMode(true))
btnSettings.OnEvent("Click", (*) => ToggleSettings())
btnApply.OnEvent("Click", (*) => ApplySettings())
btnReload.OnEvent("Click", (*) => Reload())
btnExit.OnEvent("Click", (*) => ExitApp())
btnPickColor.OnEvent("Click", (*) => PickColorCoord())
chkColorGuard.OnEvent("Click", (*) => ToggleColorGuard(true))

; --- Window Utilities & Timers ---
OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x0200, WM_MOUSEMOVE)
SetTimer CheckWindowActive, 200

; Show Initial GUI State
TLGui.Show("x50 y150 w170 h240 NoActivate")
WinSetTransparent(180, "ahk_id " TLGui.Hwnd)
LoadSettings()

; ------------------------------------------------------------------------------
; 5. WINDOW MESSAGE & EVENT HANDLERS
; ------------------------------------------------------------------------------
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    if btnLogo.Visible {
        CoordMode "Mouse", "Screen"
        MouseGetPos(&startX, &startY)
        
        isDrag := false
        while GetKeyState("LButton", "P") {
            MouseGetPos(&currX, &currY)
            if (Abs(currX - startX) > 4 or Abs(currY - startY) > 4) {
                isDrag := true
                break
            }
            Sleep 10
        }
        
        if isDrag
            PostMessage 0xA1, 2, , , "ahk_id " TLGui.Hwnd
        else
            ToggleGuiMode(false)
        return 0
    }
    
    PostMessage 0xA1, 2, , , "ahk_id " TLGui.Hwnd
}

WM_MOUSEMOVE(*) {
    global CurrentHoveredHwnd
    static PrevControl := ""
    CurrControl := ""
    MouseGetPos(, , , &hControl, 2)

    if (hControl != CurrentHoveredHwnd) {
        if CurrentHoveredHwnd
            ResetButtonColor(CurrentHoveredHwnd)
            
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
        ToggleSettings(false)
        for ctrl in MainControls
            ctrl.Visible := false

        try btnLogo.Opt("Background" CurrentStatusColor)
        btnLogo.Visible := true
        try btnLogo.Redraw()

        TLGui.Show("w40 h40")
        WinSetTransparent(100, "ahk_id " TLGui.Hwnd)
    } else {
        btnLogo.Visible := false
        for ctrl in MainControls
            ctrl.Visible := true

        TLGui.Show("w170 h240")
        WinSetTransparent(180, "ahk_id " TLGui.Hwnd)
    }
}

ToggleSettings(forceClose := "") {
    static isOpen := false
    isOpen := (forceClose != "") ? !forceClose : !isOpen

    for ctrl in SettingsControls
        ctrl.Visible := isOpen

    TLGui.Show(isOpen ? "h725" : "h240")
}

ApplySettings() {
    global SpamIntervalMin, SpamIntervalMax, FlaskLoopInterval, LootLoopInterval, KeyHoldMin, KeyHoldMax
    global Key_Skill, Key_Loot, Key_Flask1, Key_Flask2, Key_Flask3, ColorGuardEnabled, TargetX,
        TargetY, TargetColor, ColorVariance

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

        ColorGuardEnabled := chkColorGuard.Value
        TargetX := Integer(edtTargetX.Value)
        TargetY := Integer(edtTargetY.Value)
        TargetColor := edtTargetColor.Value
        ColorVariance := Integer(edtVariance.Value)

        try {
            IniWrite(SpamIntervalMin, IniFile, "Settings", "SpamIntervalMin")
            IniWrite(SpamIntervalMax, IniFile, "Settings", "SpamIntervalMax")
            IniWrite(FlaskLoopInterval, IniFile, "Settings", "FlaskLoopInterval")
            IniWrite(LootLoopInterval, IniFile, "Settings", "LootLoopInterval")
            IniWrite(KeyHoldMin, IniFile, "Settings", "KeyHoldMin")
            IniWrite(KeyHoldMax, IniFile, "Settings", "KeyHoldMax")

            IniWrite(Key_Skill, IniFile, "KeyBindings", "Key_Skill")
            IniWrite(Key_Loot, IniFile, "KeyBindings", "Key_Loot")
            IniWrite(Key_Flask1, IniFile, "KeyBindings", "Key_Flask1")
            IniWrite(Key_Flask2, IniFile, "KeyBindings", "Key_Flask2")
            IniWrite(Key_Flask3, IniFile, "KeyBindings", "Key_Flask3")

            IniWrite(Key_ToggleSpam, IniFile, "KeyBindings", "Key_ToggleSpam")
            IniWrite(Key_ToggleFlasks, IniFile, "KeyBindings", "Key_ToggleFlasks")
            IniWrite(Key_ToggleLoot, IniFile, "KeyBindings", "Key_ToggleLoot")
            IniWrite(Key_MasterPause, IniFile, "KeyBindings", "Key_MasterPause")

            IniWrite(ColorGuardEnabled ? 1 : 0, IniFile, "ColorGuard", "Enabled")
            IniWrite(TargetX, IniFile, "ColorGuard", "TargetX")
            IniWrite(TargetY, IniFile, "ColorGuard", "TargetY")
            IniWrite(TargetColor, IniFile, "ColorGuard", "TargetColor")
            IniWrite(ColorVariance, IniFile, "ColorGuard", "ColorVariance")

            chkSpam.Text := "Combat (" Key_ToggleSpam ")"
            chkFlask.Text := "Flasks (" Key_ToggleFlasks ")"
            chkLoot.Text := "Auto Loot (" Key_ToggleLoot ")"
            chkPause.Text := "Pause All (" Key_MasterPause ")"

            ToggleColorGuard(false)
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

    try Hotkey(Key_ToggleSpam, "Off")
    try Hotkey(Key_ToggleFlasks, "Off")
    try Hotkey(Key_ToggleLoot, "Off")
    try Hotkey(Key_MasterPause, "Off")
    try Hotkey("F12", "Off")

    HotIf (*) => WinActive(TargetProcess) && (A_TickCount >= ColorGuardHibernationEnd)
    Hotkey(Key_ToggleSpam, (*) => ToggleSpam())
    Hotkey(Key_ToggleFlasks, (*) => ToggleFlasks())
    Hotkey(Key_ToggleLoot, (*) => ToggleLoot())
    Hotkey(Key_MasterPause, (*) => ToggleMasterPause())
    HotIf

    Hotkey("F12", (*) => PickColorCoord())
}

LoadSettings() {
    global SpamIntervalMin, SpamIntervalMax, FlaskLoopInterval, LootLoopInterval, KeyHoldMin, KeyHoldMax
    global Key_Skill, Key_Loot, Key_Flask1, Key_Flask2, Key_Flask3, ColorGuardEnabled, TargetX,
        TargetY, TargetColor, ColorVariance
    global Key_ToggleSpam, Key_ToggleFlasks, Key_ToggleLoot, Key_MasterPause

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

            edtSpamMin.Value := SpamIntervalMin
            edtSpamMax.Value := SpamIntervalMax
            edtFlask.Value := FlaskLoopInterval
            edtLoot.Value := LootLoopInterval
            edtHoldMin.Value := KeyHoldMin
            edtHoldMax.Value := KeyHoldMax

            edtKeySkill.Value := Key_Skill
            edtKeyLoot.Value := Key_Loot
            edtKeyF1.Value := Key_Flask1
            edtKeyF2.Value := Key_Flask2
            edtKeyF3.Value := Key_Flask3

            chkColorGuard.Value := ColorGuardEnabled
            edtTargetX.Value := TargetX
            edtTargetY.Value := TargetY
            edtTargetColor.Value := TargetColor
            edtVariance.Value := ColorVariance

            chkSpam.Text := "Combat (" Key_ToggleSpam ")"
            chkFlask.Text := "Flasks (" Key_ToggleFlasks ")"
            chkLoot.Text := "Auto Loot (" Key_ToggleLoot ")"
            chkPause.Text := "Pause All (" Key_MasterPause ")"
        }
    }
    RegisterHotkeys()
    ToggleColorGuard(false)
}

UpdateStatus(msg) {
    try txtStatus.Value := msg
}

CheckWindowActive() {
    global isMasterPaused, isColorPaused, isFocusPaused, isShopPaused, CurrentStatusColor

    if WinActive(TargetProcess) {
        if isFocusPaused {
            isFocusPaused := false
            RestoreState()
            if !IsAnyPaused()
                UpdateStatus("Resumed (Focused)")
        }
        if IsAnyPaused() {
            try txtActiveDot.Opt("cF59E0B")
            try txtActiveDot.Redraw()
            CurrentStatusColor := "F59E0B"
            try btnLogo.Opt("Background" CurrentStatusColor)
            try btnLogo.Redraw()
        } else {
            try txtActiveDot.Opt("c10B981")
            try txtActiveDot.Redraw()
            CurrentStatusColor := "10B981"
            try btnLogo.Opt("Background" CurrentStatusColor)
            try btnLogo.Redraw()
        }
    } else {
        if !isFocusPaused {
            StopAutomation(true)
            isFocusPaused := true
            UpdateStatus("Unfocused: PAUSED")
        }
        try txtActiveDot.Opt("cEF4444")
        try txtActiveDot.Redraw()
        CurrentStatusColor := "EF4444"
        try btnLogo.Opt("Background" CurrentStatusColor)
        try btnLogo.Redraw()
    }
}

ToggleColorGuard(fromGui := false) {
    global ColorGuardEnabled, isColorPaused

    if fromGui {
        ColorGuardEnabled := chkColorGuard.Value
        try IniWrite(ColorGuardEnabled ? 1 : 0, IniFile, "ColorGuard", "Enabled")
    }

    if ColorGuardEnabled {
        UpdateStatus("Monitoring: ON")
        ColorCheckLoop()
        SetTimer ColorCheckLoop, 100
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
    global ColorGuardEnabled, TargetX, TargetY, TargetColor, ColorVariance, isColorPaused, isShopPaused
    global isMasterPaused, ColorGuardHibernationEnd

    if not ColorGuardEnabled or isMasterPaused or (A_TickCount < ColorGuardHibernationEnd)
        return

    try {
        currAvgColor := GetAverageColor(TargetX, TargetY, 5)
        diff := ColorDistance(currAvgColor, TargetColor)
        
        if (diff > ColorVariance) {
            if !isColorPaused {
                StopAutomation(true)
                isColorPaused := true
                UpdateStatus("Color Guard: PAUSED")
            }
        } else {
            isStateChanged := false
            if isColorPaused {
                isColorPaused := false
                isStateChanged := true
            }
            if isShopPaused {
                isShopPaused := false
                isStateChanged := true
            }
            if isStateChanged {
                RestoreState()
                UpdateStatus("Resumed (HUD Detected)")
            }
        }
    }
}

PickColorCoord() {
    global TargetX, TargetY, TargetColor

    UpdateStatus("Click Target Point...")
    Tooltip "LEFT-CLICK on the point/color you want to monitor`nPress ESC to cancel."

    KeyWait "LButton"

    loop {
        if GetKeyState("LButton", "P") {
            MouseGetPos(&mX, &mY)
            mColor := GetAverageColor(mX, mY, 5)

            TargetX := mX
            TargetY := mY
            TargetColor := mColor

            edtTargetX.Value := TargetX
            edtTargetY.Value := TargetY
            edtTargetColor.Value := TargetColor

            UpdateStatus("Point Picked!")

            try {
                IniWrite(TargetX, IniFile, "ColorGuard", "TargetX")
                IniWrite(TargetY, IniFile, "ColorGuard", "TargetY")
                IniWrite(TargetColor, IniFile, "ColorGuard", "TargetColor")
                IniWrite(ColorVariance, IniFile, "ColorGuard", "ColorVariance")
                IniWrite(ColorGuardEnabled ? 1 : 0, IniFile, "ColorGuard", "Enabled")
            }
            break
        }

        if GetKeyState("Esc", "P") {
            UpdateStatus("Pick Cancelled")
            break
        }

        Sleep 50
    }

    Tooltip()
    Sleep 200
}

; ------------------------------------------------------------------------------
; 6. AUTOMATION LOGIC & HOTKEYS
; ------------------------------------------------------------------------------
#HotIf WinActive(TargetProcess)

RCtrl:: {
    global isShopPaused, isMasterPaused, isColorPaused, isFocusPaused, ColorGuardHibernationEnd
    
    if !isShopPaused {
        StopAutomation(true)
        isShopPaused := true
        UpdateStatus("Shop Paused")
        
        ColorGuardHibernationEnd := A_TickCount + 1500
        Sleep 100
        SendInput "{RCtrl}"
    } else {
        SendInput "{RCtrl}"
        ColorGuardHibernationEnd := A_TickCount + 1500
        isShopPaused := false
        
        Sleep 100
        RestoreState()
        UpdateStatus("Resumed (Shop Closed)")
    }
}

~Esc:: {
    global isShopPaused, ColorGuardHibernationEnd
    if isShopPaused {
        ColorGuardHibernationEnd := A_TickCount + 1500
        isShopPaused := false
        Sleep 100
        RestoreState()
        UpdateStatus("Resumed (Shop Closed)")
    }
}

End:: Reload

; --- Toggles ---

ToggleSpam(fromGui := false) {
    global isSpamming, memSpam, chkSpam

    if IsAnyPaused() {
        if fromGui {
            memSpam := chkSpam.Value
        } else {
            memSpam := !memSpam
            chkSpam.Value := memSpam
        }
        UpdateStatus(memSpam ? "Combat Armed" : "Combat Disarmed")
        return
    }

    isSpamming := fromGui ? chkSpam.Value : !isSpamming
    chkSpam.Value := isSpamming

    if isSpamming {
        UpdateStatus("Combat: ON")
        SetTimer SpamLoop, 10
    } else {
        UpdateStatus("Combat: OFF")
        SetTimer SpamLoop, 0
    }
}

ToggleFlasks(fromGui := false) {
    global isFlaskActive, memFlask, chkFlask

    if IsAnyPaused() {
        if fromGui {
            memFlask := chkFlask.Value
        } else {
            memFlask := !memFlask
            chkFlask.Value := memFlask
        }
        UpdateStatus(memFlask ? "Flasks Armed" : "Flasks Disarmed")
        return
    }

    isFlaskActive := fromGui ? chkFlask.Value : !isFlaskActive
    chkFlask.Value := isFlaskActive

    if isFlaskActive {
        UpdateStatus("Flasks: ON")
        SetTimer FlaskLoop, FlaskLoopInterval
        FlaskLoop()
    } else {
        UpdateStatus("Flasks: OFF")
        SetTimer FlaskLoop, 0
    }
}

ToggleLoot(fromGui := false) {
    global isAutoLooting, memLoot, chkLoot

    if IsAnyPaused() {
        if fromGui {
            memLoot := chkLoot.Value
        } else {
            memLoot := !memLoot
            chkLoot.Value := memLoot
        }
        UpdateStatus(memLoot ? "Loot Armed" : "Loot Disarmed")
        return
    }

    isAutoLooting := fromGui ? chkLoot.Value : !isAutoLooting
    chkLoot.Value := isAutoLooting

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

    targetState := fromGui ? chkPause.Value : !isMasterPaused
    chkPause.Value := targetState

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
    if not isSpamming
        return
    if WinActive(TargetProcess) {
        SendHuman(Key_Skill)
    }
    SetTimer SpamLoop, Max(1, RandomGaussian(SpamIntervalMin, SpamIntervalMax))
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
    if not isAutoLooting
        return
    if WinActive(TargetProcess) {
        SendHuman(Key_Loot)
    }
    minInterval := Max(10, Integer(LootLoopInterval * 0.8))
    maxInterval := Max(12, Integer(LootLoopInterval * 1.2))
    SetTimer LootLoop, Random(minInterval, maxInterval)
}

; --- Helpers ---

SendHuman(key) {
    SendInput "{" key " down}"
    Sleep Random(KeyHoldMin, KeyHoldMax)
    SendInput "{" key " up}"
}

RandomGaussian(minVal, maxVal) {
    rand := (Random(minVal, maxVal) + Random(minVal, maxVal) + Random(minVal, maxVal)) / 3
    return Integer(rand)
}

GetAverageColor(cX, cY, size := 5) {
    offset := size // 2
    totalR := 0, totalG := 0, totalB := 0, count := 0

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
        
    return Format("0x{:02X}{:02X}{:02X}", totalR // count, totalG // count, totalB // count)
}

ColorDistance(c1, c2) {
    n1 := Integer(c1), n2 := Integer(c2)
    diffR := Abs(((n1 >> 16) & 0xFF) - ((n2 >> 16) & 0xFF))
    diffG := Abs(((n1 >> 8) & 0xFF) - ((n2 >> 8) & 0xFF))
    diffB := Abs((n1 & 0xFF) - (n2 & 0xFF))
    return Max(diffR, diffG, diffB)
}

; ------------------------------------------------------------------------------
; 7. PAUSE / RESUME LOGIC (SMART SYSTEM)
; ------------------------------------------------------------------------------

StopAutomation(saveState := false) {
    global

    if saveState {
        if !IsAnyPaused() {
            memSpam := isSpamming
            memFlask := isFlaskActive
            memLoot := isAutoLooting
        }
    }

    isSpamming := false
    isFlaskActive := false
    isAutoLooting := false

    chkSpam.Value := 0
    chkFlask.Value := 0
    chkLoot.Value := 0

    SetTimer SpamLoop, 0
    SetTimer FlaskLoop, 0
    SetTimer LootLoop, 0

    ReleaseAllKeys()
}

ReleaseAllKeys() {
    global Key_Skill, Key_Loot, Key_Flask1, Key_Flask2, Key_Flask3
    try SendInput "{" Key_Skill " up}"
    try SendInput "{" Key_Loot " up}"
    try SendInput "{" Key_Flask1 " up}"
    try SendInput "{" Key_Flask2 " up}"
    try SendInput "{" Key_Flask3 " up}"
}

RestoreState() {
    global

    if IsAnyPaused()
        return

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
    if (hwnd == btnLogo.Hwnd) {
        btnLogo.Opt("Background" CurrentStatusColor)
        btnLogo.Redraw()
    } else if ButtonColors.Has(hwnd) {
        info := ButtonColors[hwnd]
        info.ctrl.Opt("Background" info.normal)
        info.ctrl.Redraw()
    }
}

ApplyButtonHoverColor(hwnd) {
    if ButtonColors.Has(hwnd) {
        info := ButtonColors[hwnd]
        info.ctrl.Opt("Background" info.hover)
        info.ctrl.Redraw()
    }
}

IsHoverableButton(hwnd) => ButtonColors.Has(hwnd)

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
