#Requires AutoHotkey v2.0
; ==============================================================================
; TORCHLIGHT INFINITE AUTOMATION SCRIPT (STABLE & HIGH PERFORMANCE)
; ==============================================================================
; Features: Smart Auto-Pause, Combat Spam, Flask Management, Auto Loot, Auto Channel,
; Color Guard, Shop Pause, Modern Clean Floating GUI.
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

; Ensure Admin Privileges for Direct Input Simulation in Game Window
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

; Target Application Group Definition
GroupAdd "TLI_Target", "ahk_exe TorchlightInfinite.exe"
GroupAdd "TLI_Target", "Torchlight: Infinite"
GroupAdd "TLI_Target", "Torchlight Infinite Test Harness"

; ------------------------------------------------------------------------------
; 2. TORCHLIGHT AUTOMATION CORE CLASS
; ------------------------------------------------------------------------------
class TorchlightAutomation {
    ; --- Configuration Defaults ---
    static TargetProcess := "ahk_group TLI_Target"
    static IniFile := "settings.ini"

    SpamIntervalMin := 30
    SpamIntervalMax := 50
    FlaskLoopInterval := 3000
    FlaskKeyDelayMin := 50
    FlaskKeyDelayMax := 100
    LootLoopInterval := 30
    ShopPauseDelay := 1500
    KeyHoldMin := 10
    KeyHoldMax := 30
    DefaultMouseSpeed := 2
    ColorCheckInterval := 100

    ; Action Hotkeys & Bindings
    Key_Skill := "r"
    Key_Loot := "a"
    Key_Channel := "e"
    Key_Shop := "RCtrl"
    Key_Flask1 := "F6"
    Key_Flask2 := "F7"
    Key_Flask3 := "F8"

    ; Function Toggle Hotkeys
    Key_ToggleSpam := "F1"
    Key_ToggleFlasks := "F2"
    Key_ToggleLoot := "F3"
    Key_ToggleChannel := "F5"
    Key_MasterPause := "F4"

    ; Color Guard
    ColorGuardEnabled := false
    TargetX := 0
    TargetY := 0
    TargetColor := "0x000000"
    ColorVariance := 15

    ; Auto Void Color Guard
    VoidTargetX := 0
    VoidTargetY := 0
    VoidTargetColor := "0x000000"
    VoidColorVariance := 15
    VoidCheckInterval := 150

    ; --- State Management ---
    isSpamming := false
    isFlaskActive := false
    isAutoLooting := false
    isChanneling := false
    isAutoVoid := false
    isMasterPaused := false
    isFocusPaused := false
    isShopPaused := false
    isColorPaused := false
    ColorGuardHibernationEnd := 0

    ; Saved Memory for State Restoration
    memSpam := false
    memFlask := false
    memLoot := false
    memChannel := false
    memVoid := false

    ; GUI State
    isSettingsOpen := false
    isMinimized := false
    CurrentScrollOffset := 0
    CurrentHoveredHwnd := 0
    CurrentStatusColor := "10B981"
    SettingsInitY := Map()
    ButtonColors := Map()

    ; Controls Arrays
    MainControls := []
    SettingsHeaderControls := []
    SettingsControls := []

    __New() {
        ; Bound Methods for Single-Instance Timers (Prevents Timer Leaks & Freezes)
        this.fnSpam := ObjBindMethod(this, "SpamLoop")
        this.fnFlask := ObjBindMethod(this, "FlaskLoop")
        this.fnLoot := ObjBindMethod(this, "LootLoop")
        this.fnColorCheck := ObjBindMethod(this, "ColorCheckLoop")
        this.fnVoidColorCheck := ObjBindMethod(this, "VoidColorCheckLoop")
        this.fnCheckWindow := ObjBindMethod(this, "CheckWindowActive")

        this.BuildGui()
        this.LoadSettings()
        SetTimer this.fnCheckWindow, 200
    }

    IsAnyPaused(ignoreColor := false) {
        if ignoreColor
            return this.isMasterPaused || this.isFocusPaused || this.isShopPaused
        return this.isMasterPaused || this.isColorPaused || this.isFocusPaused || this.isShopPaused
    }

    ; --------------------------------------------------------------------------
    ; 3. GUI BUILDER & CONTROLS SETUP
    ; --------------------------------------------------------------------------
    BuildGui() {
        this.TLGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner", "TL Control")
        this.TLGui.SetFont("s9", "Segoe UI")
        this.TLGui.BackColor := "0F172A" ; Slate 900
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", this.TLGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)

        ; --- Header Section (Main Page) ---
        this.TLGui.SetFont("s10 Bold", "Segoe UI")
        this.txtTitle := this.TLGui.Add("Text", "x15 y8 w80 h20 +0x200 cE2E8F0", "TL Control")
        this.TLGui.SetFont("s12 Bold c10B981")
        this.txtActiveDot := this.TLGui.Add("Text", "x100 y8 w14 h20 Center +0x200", "●")
        this.TLGui.SetFont("s12 Bold c475569")
        this.txtVoidActiveDot := this.TLGui.Add("Text", "x116 y8 w14 h20 Center +0x200", "●")
        this.TLGui.SetFont("s10 Bold c94A3B8")
        this.btnMin := this.TLGui.Add("Text", "x142 y7 w18 h18 Center +0x200 Background1E293B", "—")

        ; --- Header Section (Settings Page) ---
        this.TLGui.SetFont("s10 Bold", "Segoe UI")
        this.txtSettingsTitle := this.TLGui.Add("Text", "x15 y8 w120 h20 +0x200 cE2E8F0 Hidden", "⚙️ Settings")
        this.TLGui.SetFont("s9 Bold cF8FAFC")
        this.btnBack := this.TLGui.Add("Text", "x145 y7 w60 h20 Center +0x200 Background1E293B Hidden", "Back ↩")

        ; --- Controls Section (Main Page) ---
        this.TLGui.SetFont("s9 w600", "Segoe UI")
        this.chkSpam := this.TLGui.Add("Checkbox", "x15 y38 w140 vSpam cF8FAFC", "Combat (" this.Key_ToggleSpam ")")
        this.chkFlask := this.TLGui.Add("Checkbox", "x15 y+10 w140 vFlask cF8FAFC", "Flasks (" this.Key_ToggleFlasks ")"
        )
        this.chkLoot := this.TLGui.Add("Checkbox", "x15 y+10 w140 vLoot cF8FAFC", "Auto Loot (" this.Key_ToggleLoot ")"
        )
        this.chkChannel := this.TLGui.Add("Checkbox", "x15 y+10 w140 vChannel cF8FAFC", "Auto Channel (" this.Key_ToggleChannel ")"
        )
        this.chkVoid := this.TLGui.Add("Checkbox", "x15 y+10 w140 vVoid cF8FAFC", "Auto Void")
        this.sepLine1 := this.TLGui.Add("Text", "x12 y+10 w146 h1 Background334155")
        this.chkPause := this.TLGui.Add("Checkbox", "x15 y+10 w140 vPause cF8FAFC", "Pause All (" this.Key_MasterPause ")"
        )
        this.sepLine2 := this.TLGui.Add("Text", "x12 y+10 w146 h1 Background334155")

        ; --- Footer / Status (Main Page) ---
        this.TLGui.SetFont("s8 w600 cE2E8F0")
        this.txtStatus := this.TLGui.Add("Text", "x15 y+8 w140 h20 Center +0x200 Background1E293B", "Status: Idle")
        this.TLGui.SetFont("s9 w600 cF8FAFC")
        this.btnSettings := this.TLGui.Add("Text", "x15 y+8 w140 h22 Center +0x200 Background4F46E5", "Settings ⚙️")

        ; --- Settings Panel Controls ---
        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secTiming := this.TLGui.Add("Text", "x15 y38 w190 h16 +0x200 Hidden", "TIMING & DELAYS")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblSpam := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Combat Delay Min / Max (ms):")
        this.edtSpamMin := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200",
            this.SpamIntervalMin)
        this.edtSpamMax := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200",
            this.SpamIntervalMax)

        this.lblHuman := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Key Hold Min / Max (ms):")
        this.edtHoldMin := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200",
            this.KeyHoldMin)
        this.edtHoldMax := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200",
            this.KeyHoldMax)

        this.lblFlaskDelay := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Flask Key Delay Min / Max (ms):")
        this.edtFlaskDelayMin := this.TLGui.Add("Edit",
            "x15 y+2 w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200", this.FlaskKeyDelayMin)
        this.edtFlaskDelayMax := this.TLGui.Add("Edit",
            "x115 yp w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200", this.FlaskKeyDelayMax)

        this.lblFlask := this.TLGui.Add("Text", "x15 y+6 w90 h14 Hidden", "Flask Loop (ms):")
        this.lblLoot := this.TLGui.Add("Text", "x115 yp w90 h14 Hidden", "Loot Loop (ms):")
        this.edtFlask := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200", this.FlaskLoopInterval
        )
        this.edtLoot := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200", this.LootLoopInterval
        )

        this.lblShopDelay := this.TLGui.Add("Text", "x15 y+6 w90 h14 Hidden", "Shop Pause (ms):")
        this.lblMouseSpeed := this.TLGui.Add("Text", "x115 yp w90 h14 Hidden", "Mouse Speed (0-100):")
        this.edtShopDelay := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200",
            this.ShopPauseDelay)
        this.edtMouseSpeed := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Hidden Background1E293B cF8FAFC -E0x200",
            this.DefaultMouseSpeed)

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secKeys := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "ACTION KEY BINDINGS")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblKeys := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Skill / Loot / Channel Key:")
        this.edtKeySkill := this.TLGui.Add("Edit", "x15 y+2 w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_Skill
        )
        this.edtKeyLoot := this.TLGui.Add("Edit", "x80 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_Loot
        )
        this.edtKeyChannel := this.TLGui.Add("Edit", "x145 yp w60 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_Channel
        )

        this.lblFlaskKeys := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Flask Slot Keys (1 / 2 / 3):")
        this.edtKeyF1 := this.TLGui.Add("Edit", "x15 y+2 w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_Flask1
        )
        this.edtKeyF2 := this.TLGui.Add("Edit", "x80 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_Flask2
        )
        this.edtKeyF3 := this.TLGui.Add("Edit", "x145 yp w60 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_Flask3
        )

        this.lblShopKey := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Shop Auto-Pause Key:")
        this.edtKeyShop := this.TLGui.Add("Edit", "x15 y+2 w190 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_Shop
        )

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secTglKeys := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "TOGGLE HOTKEYS")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblTglSpamFlask := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Combat / Flasks / Loot Toggle:")
        this.edtKeyTglSpam := this.TLGui.Add("Edit", "x15 y+2 w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_ToggleSpam
        )
        this.edtKeyTglFlasks := this.TLGui.Add("Edit", "x80 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_ToggleFlasks
        )
        this.edtKeyTglLoot := this.TLGui.Add("Edit", "x145 yp w60 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_ToggleLoot
        )

        this.lblTglChanPause := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Channel / Pause All Hotkeys:")
        this.edtKeyTglChannel := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Hidden Background1E293B cF8FAFC -E0x200", this
            .Key_ToggleChannel)
        this.edtKeyTglPause := this.TLGui.Add("Edit", "x115 yp w90 h20 Hidden Background1E293B cF8FAFC -E0x200", this.Key_MasterPause
        )

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secColor := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "COLOR GUARD")

        this.TLGui.SetFont("s8 c94A3B8")
        this.chkColorGuard := this.TLGui.Add("Checkbox", "x15 y+4 w190 Hidden vEnableColor cF8FAFC",
            "Enable HUD Monitoring")
        this.lblColorInterval := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Color Check Interval (ms):")
        this.edtColorInterval := this.TLGui.Add("Edit",
            "x15 y+2 w190 h20 Number Hidden Background1E293B cF8FAFC -E0x200", this.ColorCheckInterval)

        this.lblColorCoords := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "X / Y / Color / Var:")
        this.edtTargetX := this.TLGui.Add("Edit", "x15 y+2 w40 h20 Hidden Background1E293B cF8FAFC -E0x200", this.TargetX
        )
        this.edtTargetY := this.TLGui.Add("Edit", "x60 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", this.TargetY
        )
        this.edtTargetColor := this.TLGui.Add("Edit", "x105 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.TargetColor
        )
        this.edtVariance := this.TLGui.Add("Edit", "x165 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", this.ColorVariance
        )

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secVoidColor := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "AUTO VOID COLOR GUARD")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblVoidColorCoords := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Void X / Y / Color / Var:")
        this.edtVoidTargetX := this.TLGui.Add("Edit", "x15 y+2 w40 h20 Hidden Background1E293B cF8FAFC -E0x200", this.VoidTargetX
        )
        this.edtVoidTargetY := this.TLGui.Add("Edit", "x60 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", this.VoidTargetY
        )
        this.edtVoidTargetColor := this.TLGui.Add("Edit", "x105 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200",
            this.VoidTargetColor)
        this.edtVoidVariance := this.TLGui.Add("Edit", "x165 yp w40 h20 Hidden Background1E293B cF8FAFC -E0x200", this.VoidColorVariance
        )
        this.btnPickVoidColor := this.TLGui.Add("Text", "x15 y+6 w190 h20 Center +0x200 Hidden Background6366F1",
            "Pick Void Color")

        this.TLGui.SetFont("s9 w600 cF8FAFC")
        this.btnPickColor := this.TLGui.Add("Text", "x15 y+6 w190 h20 Center +0x200 Hidden Background6366F1",
            "Pick Screen Color (F12)")
        this.btnApply := this.TLGui.Add("Text", "x15 y+12 w190 h22 Center +0x200 Hidden Background10B981",
            "Apply Settings ✓")
        this.btnReload := this.TLGui.Add("Text", "x15 y+6 w190 h22 Center +0x200 Hidden Background4B5563",
            "Reload Script 🔄")
        this.btnExit := this.TLGui.Add("Text", "x15 y+6 w190 h22 Center +0x200 Hidden BackgroundEF4444", "Exit App ✕")

        ; --- Minimized Logo ---
        this.TLGui.SetFont("s14", "Segoe UI Emoji")
        this.btnLogo := this.TLGui.Add("Text", "x0 y0 w40 h40 Center +0x200 Hidden Background4F46E5", "🔥")

        ; --- Control Collections ---
        this.MainControls := [
            this.txtTitle, this.txtActiveDot, this.txtVoidActiveDot, this.btnMin, this.chkSpam, this.chkFlask,
            this.chkLoot, this.chkChannel, this.chkVoid, this.sepLine1, this.chkPause, this.sepLine2,
            this.txtStatus, this.btnSettings
        ]

        this.SettingsHeaderControls := [this.txtSettingsTitle, this.btnBack]

        this.SettingsControls := [
            this.secTiming, this.lblSpam, this.edtSpamMin, this.edtSpamMax, this.lblHuman,
            this.edtHoldMin, this.edtHoldMax, this.lblFlaskDelay, this.edtFlaskDelayMin,
            this.edtFlaskDelayMax, this.lblFlask, this.lblLoot, this.edtFlask, this.edtLoot,
            this.lblShopDelay, this.lblMouseSpeed, this.edtShopDelay, this.edtMouseSpeed, this.secKeys, this.lblKeys,
            this.edtKeySkill,
            this.edtKeyLoot, this.edtKeyChannel, this.lblFlaskKeys, this.edtKeyF1, this.edtKeyF2,
            this.edtKeyF3, this.lblShopKey, this.edtKeyShop, this.secTglKeys, this.lblTglSpamFlask,
            this.edtKeyTglSpam, this.edtKeyTglFlasks, this.edtKeyTglLoot, this.lblTglChanPause,
            this.edtKeyTglChannel, this.edtKeyTglPause, this.secColor, this.chkColorGuard,
            this.lblColorInterval, this.edtColorInterval, this.lblColorCoords, this.edtTargetX,
            this.edtTargetY, this.edtTargetColor, this.edtVariance, this.secVoidColor,
            this.lblVoidColorCoords, this.edtVoidTargetX, this.edtVoidTargetY, this.edtVoidTargetColor,
            this.edtVoidVariance, this.btnPickVoidColor, this.btnPickColor, this.btnApply, this.btnReload, this.btnExit
        ]

        for ctrl in this.SettingsControls {
            ctrl.GetPos(, &cy)
            this.SettingsInitY[ctrl.Hwnd] := cy
        }

        this.ButtonColors := Map(
            this.btnSettings.Hwnd, { normal: "4F46E5", hover: "6366F1", ctrl: this.btnSettings },
            this.btnBack.Hwnd, { normal: "1E293B", hover: "334155", ctrl: this.btnBack },
            this.btnApply.Hwnd, { normal: "10B981", hover: "34D399", ctrl: this.btnApply },
            this.btnReload.Hwnd, { normal: "4B5563", hover: "6B7280", ctrl: this.btnReload },
            this.btnExit.Hwnd, { normal: "EF4444", hover: "F87171", ctrl: this.btnExit },
            this.btnPickColor.Hwnd, { normal: "6366F1", hover: "818CF8", ctrl: this.btnPickColor },
            this.btnPickVoidColor.Hwnd, { normal: "6366F1", hover: "818CF8", ctrl: this.btnPickVoidColor },
            this.btnMin.Hwnd, { normal: "1E293B", hover: "334155", ctrl: this.btnMin },
            this.btnLogo.Hwnd, { normal: "", hover: "6366F1", ctrl: this.btnLogo }
        )

        ; --- Event Binds ---
        this.chkSpam.OnEvent("Click", (*) => this.ToggleSpam(true))
        this.chkFlask.OnEvent("Click", (*) => this.ToggleFlasks(true))
        this.chkLoot.OnEvent("Click", (*) => this.ToggleLoot(true))
        this.chkChannel.OnEvent("Click", (*) => this.ToggleChannel(true))
        this.chkVoid.OnEvent("Click", (*) => this.ToggleAutoVoid(true))
        this.chkPause.OnEvent("Click", (*) => this.ToggleMasterPause(true))
        this.btnMin.OnEvent("Click", (*) => this.ToggleGuiMode(true))
        this.btnSettings.OnEvent("Click", (*) => this.ToggleSettings())
        this.btnBack.OnEvent("Click", (*) => this.ToggleSettings(false))
        this.btnApply.OnEvent("Click", (*) => this.ApplySettings())
        this.btnReload.OnEvent("Click", (*) => Reload())
        this.btnExit.OnEvent("Click", (*) => ExitApp())
        this.btnPickColor.OnEvent("Click", (*) => this.PickColorCoord(false))
        this.btnPickVoidColor.OnEvent("Click", (*) => this.PickColorCoord(true))
        this.chkColorGuard.OnEvent("Click", (*) => this.ToggleColorGuard(true))

        ; Window Messages
        OnMessage(0x0201, (wParam, lParam, msg, hwnd) => this.WM_LBUTTONDOWN(wParam, lParam, msg, hwnd))
        OnMessage(0x0200, (*) => this.WM_MOUSEMOVE())
        OnMessage(0x020A, (wParam, lParam, msg, hwnd) => this.WM_MOUSEWHEEL(wParam, lParam, msg, hwnd))

        this.TLGui.Show("x50 y150 w170 h270 NoActivate")
        WinSetTransparent(180, "ahk_id " this.TLGui.Hwnd)
    }

    ; --------------------------------------------------------------------------
    ; 4. VIEW & SCROLLING MANAGEMENT
    ; --------------------------------------------------------------------------
    ToggleSettings(openState := "") {
        if (openState !== "")
            this.isSettingsOpen := openState
        else
            this.isSettingsOpen := !this.isSettingsOpen

        if this.isSettingsOpen {
            for ctrl in this.MainControls
                ctrl.Visible := false

            for ctrl in this.SettingsHeaderControls
                ctrl.Visible := true

            this.ScrollSettings(0)
            this.TLGui.Show("w220 h460")
            WinSetTransparent(248, "ahk_id " this.TLGui.Hwnd)
        } else {
            for ctrl in this.SettingsHeaderControls
                ctrl.Visible := false

            for ctrl in this.SettingsControls
                ctrl.Visible := false

            for ctrl in this.MainControls
                ctrl.Visible := true

            this.ScrollSettings(0)
            this.TLGui.Show("w170 h270")
            WinSetTransparent(180, "ahk_id " this.TLGui.Hwnd)
        }

        WinRedraw("ahk_id " this.TLGui.Hwnd)
    }

    ToggleGuiMode(minimize) {
        this.isMinimized := minimize
        if minimize {
            this.ToggleSettings(false)
            for ctrl in this.MainControls
                ctrl.Visible := false

            try this.btnLogo.Opt("Background" this.CurrentStatusColor)
            this.btnLogo.Visible := true
            try this.btnLogo.Redraw()

            this.TLGui.Show("w40 h40")
            WinSetTransparent(100, "ahk_id " this.TLGui.Hwnd)
        } else {
            this.btnLogo.Visible := false
            for ctrl in this.MainControls
                ctrl.Visible := true

            this.TLGui.Show("w170 h270")
            WinSetTransparent(180, "ahk_id " this.TLGui.Hwnd)
        }
        WinRedraw("ahk_id " this.TLGui.Hwnd)
    }

    ScrollSettings(targetOffset) {
        targetOffset := Max(0, Min(520, targetOffset))
        this.CurrentScrollOffset := targetOffset

        for ctrl in this.SettingsControls {
            initY := this.SettingsInitY[ctrl.Hwnd]
            newY := initY - this.CurrentScrollOffset

            ctrl.Move(, newY)
            if (newY < 35) {
                ctrl.Visible := false
            } else if (this.isSettingsOpen) {
                ctrl.Visible := true
            }
        }
        WinRedraw("ahk_id " this.TLGui.Hwnd)
    }

    WM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
        if !this.isSettingsOpen
            return

        delta := (wParam >> 16) & 0xFFFF
        step := (delta > 0x7FFF) ? 40 : -40
        this.ScrollSettings(this.CurrentScrollOffset + step)
    }

    WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
        if this.btnLogo.Visible {
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
                PostMessage 0xA1, 2, , , "ahk_id " this.TLGui.Hwnd
            else
                this.ToggleGuiMode(false)
            return 0
        }

        MouseGetPos(, , , &hControl, 2)
        if (hControl && hControl != this.TLGui.Hwnd && hControl != this.txtTitle.Hwnd && hControl != this.txtSettingsTitle
            .Hwnd && hControl != this.sepLine1.Hwnd && hControl != this.sepLine2.Hwnd) {
            return
        }

        PostMessage 0xA1, 2, , , "ahk_id " this.TLGui.Hwnd
    }

    WM_MOUSEMOVE() {
        static PrevControl := ""
        CurrControl := ""
        MouseGetPos(, , , &hControl, 2)

        if (hControl != this.CurrentHoveredHwnd) {
            if this.CurrentHoveredHwnd
                this.ResetButtonColor(this.CurrentHoveredHwnd)

            if this.ButtonColors.Has(hControl) {
                this.ApplyButtonHoverColor(hControl)
                this.CurrentHoveredHwnd := hControl
                SetTimer () => this.CheckMouseLeave(), 50
            } else {
                this.CurrentHoveredHwnd := 0
                SetTimer () => this.CheckMouseLeave(), 0
            }
        }

        if (hControl) {
            if (hControl = this.chkSpam.Hwnd)
                CurrControl := "Spam " StrUpper(this.Key_Skill) " (" this.SpamIntervalMin "-" this.SpamIntervalMax "ms)"
            else if (hControl = this.chkFlask.Hwnd)
                CurrControl := "Spam " StrUpper(this.Key_Flask1) "-" StrUpper(this.Key_Flask3) " (" Round(this.FlaskLoopInterval /
                    1000, 1) "s)"
            else if (hControl = this.chkLoot.Hwnd)
                CurrControl := "Spam " StrUpper(this.Key_Loot) " (" this.LootLoopInterval "ms)"
            else if (hControl = this.chkChannel.Hwnd)
                CurrControl := "Hold " StrUpper(this.Key_Channel) " (Auto Channel)"
            else if (hControl = this.chkPause.Hwnd)
                CurrControl := "Master Pause (Saves State)"
            else if (hControl = this.txtActiveDot.Hwnd)
                CurrControl := "Green: Active`nYellow: Paused`nRed: Inactive (Game Unfocused)"
            else if (hControl = this.btnSettings.Hwnd)
                CurrControl := "Open Settings Page"
            else if (hControl = this.btnBack.Hwnd)
                CurrControl := "Return to Main Controls"
            else if (hControl = this.btnApply.Hwnd)
                CurrControl := "Update Timer Values"
            else if (hControl = this.btnReload.Hwnd)
                CurrControl := "Restart Script"
            else if (hControl = this.btnExit.Hwnd)
                CurrControl := "Terminate Script"
            else if (hControl = this.btnMin.Hwnd)
                CurrControl := "Minimize to Logo"
            else if (hControl = this.btnPickColor.Hwnd)
                CurrControl := "Pick coordinates and average color from screen"
        }

        if (CurrControl != PrevControl) {
            ToolTip CurrControl
            PrevControl := CurrControl
            if (CurrControl)
                SetTimer () => ToolTip(), -2000
        }
    }

    CheckMouseLeave() {
        if !this.CurrentHoveredHwnd
            return

        MouseGetPos(, , , &hControl, 2)
        if (hControl != this.CurrentHoveredHwnd) {
            this.ResetButtonColor(this.CurrentHoveredHwnd)
            this.CurrentHoveredHwnd := 0
            SetTimer () => this.CheckMouseLeave(), 0
        }
    }

    ResetButtonColor(hwnd) {
        if (hwnd == this.btnLogo.Hwnd) {
            this.btnLogo.Opt("Background" this.CurrentStatusColor)
            this.btnLogo.Redraw()
        } else if this.ButtonColors.Has(hwnd) {
            info := this.ButtonColors[hwnd]
            info.ctrl.Opt("Background" info.normal)
            info.ctrl.Redraw()
        }
    }

    ApplyButtonHoverColor(hwnd) {
        if this.ButtonColors.Has(hwnd) {
            info := this.ButtonColors[hwnd]
            info.ctrl.Opt("Background" info.hover)
            info.ctrl.Redraw()
        }
    }

    ; --------------------------------------------------------------------------
    ; 5. CONFIGURATION INI MANAGEMENT
    ; --------------------------------------------------------------------------
    LoadSettings() {
        if FileExist(TorchlightAutomation.IniFile) {
            try {
                this.SpamIntervalMin := IniRead(TorchlightAutomation.IniFile, "Settings", "SpamIntervalMin", this.SpamIntervalMin
                )
                this.SpamIntervalMax := IniRead(TorchlightAutomation.IniFile, "Settings", "SpamIntervalMax", this.SpamIntervalMax
                )
                this.FlaskLoopInterval := IniRead(TorchlightAutomation.IniFile, "Settings", "FlaskLoopInterval", this.FlaskLoopInterval
                )
                this.FlaskKeyDelayMin := IniRead(TorchlightAutomation.IniFile, "Settings", "FlaskKeyDelayMin", this.FlaskKeyDelayMin
                )
                this.FlaskKeyDelayMax := IniRead(TorchlightAutomation.IniFile, "Settings", "FlaskKeyDelayMax", this.FlaskKeyDelayMax
                )
                this.LootLoopInterval := IniRead(TorchlightAutomation.IniFile, "Settings", "LootLoopInterval", this.LootLoopInterval
                )
                this.ShopPauseDelay := IniRead(TorchlightAutomation.IniFile, "Settings", "ShopPauseDelay", this.ShopPauseDelay
                )
                this.DefaultMouseSpeed := IniRead(TorchlightAutomation.IniFile, "Settings", "DefaultMouseSpeed", this.DefaultMouseSpeed
                )
                this.KeyHoldMin := IniRead(TorchlightAutomation.IniFile, "Settings", "KeyHoldMin", this.KeyHoldMin)
                this.KeyHoldMax := IniRead(TorchlightAutomation.IniFile, "Settings", "KeyHoldMax", this.KeyHoldMax)

                this.Key_Skill := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_Skill", this.Key_Skill)
                this.Key_Loot := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_Loot", this.Key_Loot)
                this.Key_Channel := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_Channel", this.Key_Channel
                )
                this.Key_Shop := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_Shop", this.Key_Shop)
                this.Key_Flask1 := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_Flask1", this.Key_Flask1)
                this.Key_Flask2 := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_Flask2", this.Key_Flask2)
                this.Key_Flask3 := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_Flask3", this.Key_Flask3)

                this.Key_ToggleSpam := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleSpam", this.Key_ToggleSpam
                )
                this.Key_ToggleFlasks := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleFlasks", this.Key_ToggleFlasks
                )
                this.Key_ToggleLoot := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleLoot", this.Key_ToggleLoot
                )
                this.Key_ToggleChannel := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleChannel",
                    this.Key_ToggleChannel)
                this.Key_MasterPause := IniRead(TorchlightAutomation.IniFile, "KeyBindings", "Key_MasterPause", this.Key_MasterPause
                )

                this.ColorGuardEnabled := IniRead(TorchlightAutomation.IniFile, "ColorGuard", "Enabled", this.ColorGuardEnabled
                )
                this.ColorCheckInterval := IniRead(TorchlightAutomation.IniFile, "ColorGuard", "CheckInterval", this.ColorCheckInterval
                )
                this.TargetX := IniRead(TorchlightAutomation.IniFile, "ColorGuard", "TargetX", this.TargetX)
                this.TargetY := IniRead(TorchlightAutomation.IniFile, "ColorGuard", "TargetY", this.TargetY)
                this.TargetColor := IniRead(TorchlightAutomation.IniFile, "ColorGuard", "TargetColor", this.TargetColor
                )
                this.ColorVariance := IniRead(TorchlightAutomation.IniFile, "ColorGuard", "ColorVariance", this.ColorVariance
                )

                this.edtSpamMin.Value := this.SpamIntervalMin
                this.edtSpamMax.Value := this.SpamIntervalMax
                this.edtHoldMin.Value := this.KeyHoldMin
                this.edtHoldMax.Value := this.KeyHoldMax
                this.edtFlaskDelayMin.Value := this.FlaskKeyDelayMin
                this.edtFlaskDelayMax.Value := this.FlaskKeyDelayMax
                this.edtFlask.Value := this.FlaskLoopInterval
                this.edtLoot.Value := this.LootLoopInterval
                this.edtShopDelay.Value := this.ShopPauseDelay
                this.edtMouseSpeed.Value := this.DefaultMouseSpeed

                this.edtKeySkill.Value := this.Key_Skill
                this.edtKeyLoot.Value := this.Key_Loot
                this.edtKeyChannel.Value := this.Key_Channel
                this.edtKeyShop.Value := this.Key_Shop
                this.edtKeyF1.Value := this.Key_Flask1
                this.edtKeyF2.Value := this.Key_Flask2
                this.edtKeyF3.Value := this.Key_Flask3

                this.edtKeyTglSpam.Value := this.Key_ToggleSpam
                this.edtKeyTglFlasks.Value := this.Key_ToggleFlasks
                this.edtKeyTglLoot.Value := this.Key_ToggleLoot
                this.edtKeyTglChannel.Value := this.Key_ToggleChannel
                this.edtKeyTglPause.Value := this.Key_MasterPause

                this.chkColorGuard.Value := this.ColorGuardEnabled
                this.edtColorInterval.Value := this.ColorCheckInterval
                this.edtTargetX.Value := this.TargetX
                this.edtTargetY.Value := this.TargetY
                this.edtTargetColor.Value := this.TargetColor
                this.edtVariance.Value := this.ColorVariance

                this.VoidTargetX := IniRead(TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetX", this.VoidTargetX)
                this.VoidTargetY := IniRead(TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetY", this.VoidTargetY)
                this.VoidTargetColor := IniRead(TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetColor", this.VoidTargetColor
                )
                this.VoidColorVariance := IniRead(TorchlightAutomation.IniFile, "AutoVoidGuard", "ColorVariance", this.VoidColorVariance
                )
                this.VoidCheckInterval := IniRead(TorchlightAutomation.IniFile, "AutoVoidGuard", "CheckInterval", this.VoidCheckInterval
                )

                this.edtVoidTargetX.Value := this.VoidTargetX
                this.edtVoidTargetY.Value := this.VoidTargetY
                this.edtVoidTargetColor.Value := this.VoidTargetColor
                this.edtVoidVariance.Value := this.VoidColorVariance

                this.isAutoVoid := Integer(IniRead(TorchlightAutomation.IniFile, "Settings", "AutoVoid", 0))
                this.chkVoid.Value := this.isAutoVoid

                this.chkSpam.Text := "Combat (" this.Key_ToggleSpam ")"
                this.chkFlask.Text := "Flasks (" this.Key_ToggleFlasks ")"
                this.chkLoot.Text := "Auto Loot (" this.Key_ToggleLoot ")"
                this.chkChannel.Text := "Auto Channel (" this.Key_ToggleChannel ")"
                this.chkPause.Text := "Pause All (" this.Key_MasterPause ")"
            }
        }
        this.RegisterHotkeys()
        this.ToggleColorGuard(false)
    }

    ApplySettings() {
        try {
            this.SpamIntervalMin := Integer(this.edtSpamMin.Value)
            this.SpamIntervalMax := Integer(this.edtSpamMax.Value)
            this.KeyHoldMin := Integer(this.edtHoldMin.Value)
            this.KeyHoldMax := Integer(this.edtHoldMax.Value)
            this.FlaskKeyDelayMin := Integer(this.edtFlaskDelayMin.Value)
            this.FlaskKeyDelayMax := Integer(this.edtFlaskDelayMax.Value)
            this.FlaskLoopInterval := Integer(this.edtFlask.Value)
            this.LootLoopInterval := Integer(this.edtLoot.Value)
            this.ShopPauseDelay := Integer(this.edtShopDelay.Value)
            this.DefaultMouseSpeed := Integer(this.edtMouseSpeed.Value)

            this.Key_Skill := this.edtKeySkill.Value
            this.Key_Loot := this.edtKeyLoot.Value
            this.Key_Channel := this.edtKeyChannel.Value
            this.Key_Shop := this.edtKeyShop.Value
            this.Key_Flask1 := this.edtKeyF1.Value
            this.Key_Flask2 := this.edtKeyF2.Value
            this.Key_Flask3 := this.edtKeyF3.Value

            this.Key_ToggleSpam := this.edtKeyTglSpam.Value
            this.Key_ToggleFlasks := this.edtKeyTglFlasks.Value
            this.Key_ToggleLoot := this.edtKeyTglLoot.Value
            this.Key_ToggleChannel := this.edtKeyTglChannel.Value
            this.Key_MasterPause := this.edtKeyTglPause.Value

            this.ColorGuardEnabled := this.chkColorGuard.Value
            this.ColorCheckInterval := Integer(this.edtColorInterval.Value)
            this.TargetX := Integer(this.edtTargetX.Value)
            this.TargetY := Integer(this.edtTargetY.Value)
            this.TargetColor := this.edtTargetColor.Value
            this.ColorVariance := Integer(this.edtVariance.Value)

            try {
                IniWrite(this.SpamIntervalMin, TorchlightAutomation.IniFile, "Settings", "SpamIntervalMin")
                IniWrite(this.SpamIntervalMax, TorchlightAutomation.IniFile, "Settings", "SpamIntervalMax")
                IniWrite(this.FlaskLoopInterval, TorchlightAutomation.IniFile, "Settings", "FlaskLoopInterval")
                IniWrite(this.FlaskKeyDelayMin, TorchlightAutomation.IniFile, "Settings", "FlaskKeyDelayMin")
                IniWrite(this.FlaskKeyDelayMax, TorchlightAutomation.IniFile, "Settings", "FlaskKeyDelayMax")
                IniWrite(this.LootLoopInterval, TorchlightAutomation.IniFile, "Settings", "LootLoopInterval")
                IniWrite(this.ShopPauseDelay, TorchlightAutomation.IniFile, "Settings", "ShopPauseDelay")
                IniWrite(this.DefaultMouseSpeed, TorchlightAutomation.IniFile, "Settings", "DefaultMouseSpeed")
                IniWrite(this.KeyHoldMin, TorchlightAutomation.IniFile, "Settings", "KeyHoldMin")
                IniWrite(this.KeyHoldMax, TorchlightAutomation.IniFile, "Settings", "KeyHoldMax")

                IniWrite(this.Key_Skill, TorchlightAutomation.IniFile, "KeyBindings", "Key_Skill")
                IniWrite(this.Key_Loot, TorchlightAutomation.IniFile, "KeyBindings", "Key_Loot")
                IniWrite(this.Key_Channel, TorchlightAutomation.IniFile, "KeyBindings", "Key_Channel")
                IniWrite(this.Key_Shop, TorchlightAutomation.IniFile, "KeyBindings", "Key_Shop")
                IniWrite(this.Key_Flask1, TorchlightAutomation.IniFile, "KeyBindings", "Key_Flask1")
                IniWrite(this.Key_Flask2, TorchlightAutomation.IniFile, "KeyBindings", "Key_Flask2")
                IniWrite(this.Key_Flask3, TorchlightAutomation.IniFile, "KeyBindings", "Key_Flask3")

                IniWrite(this.Key_ToggleSpam, TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleSpam")
                IniWrite(this.Key_ToggleFlasks, TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleFlasks")
                IniWrite(this.Key_ToggleLoot, TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleLoot")
                IniWrite(this.Key_ToggleChannel, TorchlightAutomation.IniFile, "KeyBindings", "Key_ToggleChannel")
                IniWrite(this.Key_MasterPause, TorchlightAutomation.IniFile, "KeyBindings", "Key_MasterPause")

                IniWrite(this.ColorGuardEnabled ? 1 : 0, TorchlightAutomation.IniFile, "ColorGuard", "Enabled")
                IniWrite(this.ColorCheckInterval, TorchlightAutomation.IniFile, "ColorGuard", "CheckInterval")
                IniWrite(this.TargetX, TorchlightAutomation.IniFile, "ColorGuard", "TargetX")
                IniWrite(this.TargetY, TorchlightAutomation.IniFile, "ColorGuard", "TargetY")
                IniWrite(this.TargetColor, TorchlightAutomation.IniFile, "ColorGuard", "TargetColor")
                IniWrite(this.ColorVariance, TorchlightAutomation.IniFile, "ColorGuard", "ColorVariance")

                this.VoidTargetX := Integer(this.edtVoidTargetX.Value)
                this.VoidTargetY := Integer(this.edtVoidTargetY.Value)
                this.VoidTargetColor := this.edtVoidTargetColor.Value
                this.VoidColorVariance := Integer(this.edtVoidVariance.Value)

                IniWrite(this.VoidTargetX, TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetX")
                IniWrite(this.VoidTargetY, TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetY")
                IniWrite(this.VoidTargetColor, TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetColor")
                IniWrite(this.VoidColorVariance, TorchlightAutomation.IniFile, "AutoVoidGuard", "ColorVariance")
                IniWrite(this.VoidCheckInterval, TorchlightAutomation.IniFile, "AutoVoidGuard", "CheckInterval")

                IniWrite(this.chkVoid.Value ? 1 : 0, TorchlightAutomation.IniFile, "Settings", "AutoVoid")

                this.chkSpam.Text := "Combat (" this.Key_ToggleSpam ")"
                this.chkFlask.Text := "Flasks (" this.Key_ToggleFlasks ")"
                this.chkLoot.Text := "Auto Loot (" this.Key_ToggleLoot ")"
                this.chkChannel.Text := "Auto Channel (" this.Key_ToggleChannel ")"
                this.chkPause.Text := "Pause All (" this.Key_MasterPause ")"

                this.ToggleColorGuard(false)
                this.RegisterHotkeys()

                this.UpdateStatus("Settings Saved!")
                SetTimer () => this.UpdateStatus("Status: Idle"), -2000
                this.ToggleSettings(false)
            } catch as err {
                this.UpdateStatus("Error Saving INI: " err.Message)
            }
        } catch as err {
            this.UpdateStatus("Error Reading GUI: " err.Message)
        }
    }

    ; --------------------------------------------------------------------------
    ; 6. HOTKEYS & WINDOW MONITORING
    ; --------------------------------------------------------------------------
    RegisterHotkeys() {
        try Hotkey(this.Key_ToggleSpam, "Off")
        try Hotkey(this.Key_ToggleFlasks, "Off")
        try Hotkey(this.Key_ToggleLoot, "Off")
        try Hotkey(this.Key_ToggleChannel, "Off")
        try Hotkey(this.Key_MasterPause, "Off")
        try Hotkey(this.Key_Shop, "Off")
        try Hotkey("F12", "Off")

        HotIf (*) => WinActive(TorchlightAutomation.TargetProcess) && (A_TickCount >= this.ColorGuardHibernationEnd)
        Hotkey(this.Key_ToggleSpam, (*) => this.ToggleSpam())
        Hotkey(this.Key_ToggleFlasks, (*) => this.ToggleFlasks())
        Hotkey(this.Key_ToggleLoot, (*) => this.ToggleLoot())
        Hotkey(this.Key_ToggleChannel, (*) => this.ToggleChannel())
        Hotkey(this.Key_MasterPause, (*) => this.ToggleMasterPause())
        HotIf

        HotIf (*) => WinActive(TorchlightAutomation.TargetProcess)
        Hotkey(this.Key_Shop, (*) => this.ToggleShopPause())
        HotIf

        Hotkey("F12", (*) => this.PickColorCoord())
    }

    CheckWindowActive() {
        if WinActive(TorchlightAutomation.TargetProcess) {
            if this.isFocusPaused {
                this.isFocusPaused := false
                this.RestoreState()
                if !this.IsAnyPaused()
                    this.UpdateStatus("Resumed (Focused)")
            }
            if this.IsAnyPaused() {
                try this.txtActiveDot.Opt("cF59E0B")
                try this.txtActiveDot.Redraw()
                this.CurrentStatusColor := "F59E0B"
                try this.btnLogo.Opt("Background" this.CurrentStatusColor)
                try this.btnLogo.Redraw()
            } else {
                try this.txtActiveDot.Opt("c10B981")
                try this.txtActiveDot.Redraw()
                this.CurrentStatusColor := "10B981"
                try this.btnLogo.Opt("Background" this.CurrentStatusColor)
                try this.btnLogo.Redraw()
            }
        } else {
            if !this.isFocusPaused {
                this.StopAutomation(true)
                this.isFocusPaused := true
                this.UpdateStatus("Unfocused: PAUSED")
            }
            try this.txtActiveDot.Opt("cEF4444")
            try this.txtActiveDot.Redraw()
            this.CurrentStatusColor := "EF4444"
            try this.btnLogo.Opt("Background" this.CurrentStatusColor)
            try this.btnLogo.Redraw()
        }
        this.UpdateVoidDot()
    }

    UpdateVoidDot() {
        if !HasProp(this, "txtVoidActiveDot") || !this.txtVoidActiveDot
            return
        try {
            if (this.isMasterPaused || this.isFocusPaused || this.isShopPaused) {
                this.txtVoidActiveDot.Opt("cF59E0B")
            } else if (this.isAutoVoid) {
                this.txtVoidActiveDot.Opt("c818CF8")
            } else {
                this.txtVoidActiveDot.Opt("c475569")
            }
            this.txtVoidActiveDot.Redraw()
        }
    }

    UpdateStatus(msg) {
        try this.txtStatus.Value := msg
    }

    ; --------------------------------------------------------------------------
    ; 7. AUTOMATION TOGGLES & LOOPS
    ; --------------------------------------------------------------------------
    ToggleSpam(fromGui := false) {
        if this.IsAnyPaused() {
            if fromGui {
                this.memSpam := this.chkSpam.Value
            } else {
                this.memSpam := !this.memSpam
                this.chkSpam.Value := this.memSpam
            }
            this.UpdateStatus(this.memSpam ? "Combat Armed" : "Combat Disarmed")
            return
        }

        this.isSpamming := fromGui ? this.chkSpam.Value : !this.isSpamming
        this.chkSpam.Value := this.isSpamming

        if this.isSpamming {
            this.UpdateStatus("Combat: ON")
            SetTimer this.fnSpam, 10
        } else {
            this.UpdateStatus("Combat: OFF")
            SetTimer this.fnSpam, 0
        }
    }

    ToggleFlasks(fromGui := false) {
        if this.IsAnyPaused() {
            if fromGui {
                this.memFlask := this.chkFlask.Value
            } else {
                this.memFlask := !this.memFlask
                this.chkFlask.Value := this.memFlask
            }
            this.UpdateStatus(this.memFlask ? "Flasks Armed" : "Flasks Disarmed")
            return
        }

        this.isFlaskActive := fromGui ? this.chkFlask.Value : !this.isFlaskActive
        this.chkFlask.Value := this.isFlaskActive

        if this.isFlaskActive {
            this.UpdateStatus("Flasks: ON")
            SetTimer this.fnFlask, this.FlaskLoopInterval
            this.FlaskLoop()
        } else {
            this.UpdateStatus("Flasks: OFF")
            SetTimer this.fnFlask, 0
        }
    }

    ToggleLoot(fromGui := false) {
        if this.IsAnyPaused() {
            if fromGui {
                this.memLoot := this.chkLoot.Value
            } else {
                this.memLoot := !this.memLoot
                this.chkLoot.Value := this.memLoot
            }
            this.UpdateStatus(this.memLoot ? "Loot Armed" : "Loot Disarmed")
            return
        }

        this.isAutoLooting := fromGui ? this.chkLoot.Value : !this.isAutoLooting
        this.chkLoot.Value := this.isAutoLooting

        if this.isAutoLooting {
            this.UpdateStatus("Loot: ON")
            SetTimer this.fnLoot, Max(30, this.LootLoopInterval)
        } else {
            this.UpdateStatus("Loot: OFF")
            SetTimer this.fnLoot, 0
        }
    }

    ToggleChannel(fromGui := false) {
        if this.IsAnyPaused() {
            if fromGui {
                this.memChannel := this.chkChannel.Value
            } else {
                this.memChannel := !this.memChannel
                this.chkChannel.Value := this.memChannel
            }
            this.UpdateStatus(this.memChannel ? "Channel Armed" : "Channel Disarmed")
            return
        }

        this.isChanneling := fromGui ? this.chkChannel.Value : !this.isChanneling
        this.chkChannel.Value := this.isChanneling

        if this.isChanneling {
            this.UpdateStatus("Channel: ON")
            SendInput "{" this.Key_Channel " down}"
        } else {
            this.UpdateStatus("Channel: OFF")
            try SendInput "{" this.Key_Channel " up}"
        }
    }

    ToggleAutoVoid(fromGui := false) {
        if this.IsAnyPaused() {
            if fromGui {
                this.memVoid := this.chkVoid.Value
            } else {
                this.memVoid := !this.memVoid
                this.chkVoid.Value := this.memVoid
            }
            this.UpdateStatus(this.memVoid ? "Auto Void Armed" : "Auto Void Disarmed")
            return
        }

        this.isAutoVoid := fromGui ? this.chkVoid.Value : !this.isAutoVoid
        this.chkVoid.Value := this.isAutoVoid

        if this.isAutoVoid {
            this.UpdateStatus("Auto Void: ON")
            ; Force Auto Loot on when Auto Void is turned on
            if !this.isAutoLooting {
                this.isAutoLooting := true
                this.chkLoot.Value := 1
                SetTimer this.fnLoot, Max(30, this.LootLoopInterval)
            }
            SetTimer this.fnVoidColorCheck, Max(50, this.VoidCheckInterval)
        } else {
            this.UpdateStatus("Auto Void: OFF")
            SetTimer this.fnVoidColorCheck, 0
        }
        this.UpdateVoidDot()
    }

    ToggleMasterPause(fromGui := false) {
        targetState := fromGui ? this.chkPause.Value : !this.isMasterPaused
        this.chkPause.Value := targetState

        if targetState {
            this.StopAutomation(true)
            this.isMasterPaused := true
            this.UpdateStatus("Master Paused")
        } else {
            this.isMasterPaused := false
            this.RestoreState()
            this.UpdateStatus("Resumed")
        }
    }

    ToggleShopPause() {
        if !this.isShopPaused {
            this.StopAutomation(true)
            this.isShopPaused := true
            this.UpdateStatus("Shop Paused")

            this.ColorGuardHibernationEnd := A_TickCount + this.ShopPauseDelay
            Sleep 100
            SendInput "{" this.Key_Shop "}"
        } else {
            SendInput "{" this.Key_Shop "}"
            this.ColorGuardHibernationEnd := A_TickCount + this.ShopPauseDelay
            this.isShopPaused := false

            Sleep 100
            this.RestoreState()
            this.UpdateStatus("Resumed (Shop Closed)")
        }
    }

    SpamLoop() {
        if not this.isSpamming or this.IsAnyPaused()
            return
        if WinActive(TorchlightAutomation.TargetProcess) {
            this.SendHuman(this.Key_Skill)
        }
        nextDelay := Max(10, TorchlightAutomation.RandomGaussian(this.SpamIntervalMin, this.SpamIntervalMax))
        SetTimer this.fnSpam, -nextDelay
    }

    FlaskLoop() {
        if not this.isFlaskActive or this.IsAnyPaused() or !WinActive(TorchlightAutomation.TargetProcess)
            return

        this.SendHuman(this.Key_Flask1)
        Sleep Random(this.FlaskKeyDelayMin, this.FlaskKeyDelayMax)
        if !this.isFlaskActive or this.IsAnyPaused() or !WinActive(TorchlightAutomation.TargetProcess)
            return
        this.SendHuman(this.Key_Flask2)
        Sleep Random(this.FlaskKeyDelayMin, this.FlaskKeyDelayMax)
        if !this.isFlaskActive or this.IsAnyPaused() or !WinActive(TorchlightAutomation.TargetProcess)
            return
        this.SendHuman(this.Key_Flask3)
    }

    LootLoop() {
        ; If Auto Void is active, bypass normal pause checks for Auto Loot
        if not this.isAutoLooting or (this.IsAnyPaused() and not this.isAutoVoid)
            return
        if WinActive(TorchlightAutomation.TargetProcess) {
            this.SendHuman(this.Key_Loot)
        }
        baseInt := Max(30, this.LootLoopInterval)
        minInterval := Max(25, Integer(baseInt * 0.8))
        maxInterval := Max(35, Integer(baseInt * 1.2))
        SetTimer this.fnLoot, -Random(minInterval, maxInterval)
    }

    SendHuman(key) {
        SendInput "{" key " down}"
        holdTime := Random(this.KeyHoldMin, this.KeyHoldMax)
        ReleaseKey() {
            try SendInput "{" key " up}"
        }
        SetTimer ReleaseKey, -Max(1, holdTime)
    }

    static RandomGaussian(minVal, maxVal) {
        rand := (Random(minVal, maxVal) + Random(minVal, maxVal) + Random(minVal, maxVal)) / 3
        return Integer(rand)
    }

    ; --------------------------------------------------------------------------
    ; 8. COLOR GUARD SUB-SAMPLING & RECOVERY
    ; --------------------------------------------------------------------------
    ToggleColorGuard(fromGui := false) {
        if fromGui {
            this.ColorGuardEnabled := this.chkColorGuard.Value
            try IniWrite(this.ColorGuardEnabled ? 1 : 0, TorchlightAutomation.IniFile, "ColorGuard", "Enabled")
        }

        if this.ColorGuardEnabled {
            this.UpdateStatus("Monitoring: ON")
            this.ColorCheckLoop()
            SetTimer this.fnColorCheck, Max(50, this.ColorCheckInterval)
        } else {
            if this.isColorPaused {
                this.isColorPaused := false
                this.RestoreState()
            }
            this.UpdateStatus("Monitoring: OFF")
            SetTimer this.fnColorCheck, 0
        }
    }

    ColorCheckLoop() {
        if not this.ColorGuardEnabled or this.isMasterPaused or (A_TickCount < this.ColorGuardHibernationEnd)
            return

        try {
            currAvgColor := this.GetAverageColor(this.TargetX, this.TargetY, 5)
            diff := this.ColorDistance(currAvgColor, this.TargetColor)

            if (diff > this.ColorVariance) {
                if !this.isColorPaused {
                    this.StopAutomation(true, true)
                    this.isColorPaused := true
                    this.UpdateStatus("Color Guard: PAUSED")
                }
            } else {
                isStateChanged := false
                if this.isColorPaused {
                    this.isColorPaused := false
                    isStateChanged := true
                }
                if this.isShopPaused {
                    this.isShopPaused := false
                    isStateChanged := true
                }
                if isStateChanged {
                    this.RestoreState()
                    this.UpdateStatus("Resumed (HUD Detected)")
                }
            }
        }
    }

    PickColorCoord(isVoid := false) {
        this.UpdateStatus("Click Target Point...")
        Tooltip "LEFT-CLICK on the point/color you want to monitor`nPress ESC to cancel."

        KeyWait "LButton"

        loop {
            if GetKeyState("LButton", "P") {
                MouseGetPos(&mX, &mY)
                mColor := this.GetAverageColor(mX, mY, 5)

                if isVoid {
                    this.VoidTargetX := mX
                    this.VoidTargetY := mY
                    this.VoidTargetColor := mColor

                    this.edtVoidTargetX.Value := this.VoidTargetX
                    this.edtVoidTargetY.Value := this.VoidTargetY
                    this.edtVoidTargetColor.Value := this.VoidTargetColor

                    this.UpdateStatus("Void Point Picked!")

                    try {
                        IniWrite(this.VoidTargetX, TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetX")
                        IniWrite(this.VoidTargetY, TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetY")
                        IniWrite(this.VoidTargetColor, TorchlightAutomation.IniFile, "AutoVoidGuard", "TargetColor")
                        IniWrite(this.VoidColorVariance, TorchlightAutomation.IniFile, "AutoVoidGuard", "ColorVariance"
                        )
                    }
                } else {
                    this.TargetX := mX
                    this.TargetY := mY
                    this.TargetColor := mColor

                    this.edtTargetX.Value := this.TargetX
                    this.edtTargetY.Value := this.TargetY
                    this.edtTargetColor.Value := this.TargetColor

                    this.UpdateStatus("Point Picked!")

                    try {
                        IniWrite(this.TargetX, TorchlightAutomation.IniFile, "ColorGuard", "TargetX")
                        IniWrite(this.TargetY, TorchlightAutomation.IniFile, "ColorGuard", "TargetY")
                        IniWrite(this.TargetColor, TorchlightAutomation.IniFile, "ColorGuard", "TargetColor")
                        IniWrite(this.ColorVariance, TorchlightAutomation.IniFile, "ColorGuard", "ColorVariance")
                        IniWrite(this.ColorGuardEnabled ? 1 : 0, TorchlightAutomation.IniFile, "ColorGuard", "Enabled")
                    }
                }
                break
            }

            if GetKeyState("Esc", "P") {
                this.UpdateStatus("Pick Cancelled")
                break
            }

            Sleep 50
        }

        Tooltip()
        Sleep 200
    }

    VoidColorCheckLoop() {
        if not this.isAutoVoid or this.IsAnyPaused(true) or (A_TickCount < this.ColorGuardHibernationEnd)
            return

        try {
            currAvgColor := this.GetAverageColor(this.VoidTargetX, this.VoidTargetY, 5)
            diff := this.ColorDistance(currAvgColor, this.VoidTargetColor)

            if (diff <= this.VoidColorVariance) {
                this.ExecuteAutoVoidRoutine()
            }
        }

        if this.isAutoVoid {
            nextDelay := Max(100, this.VoidCheckInterval)
            SetTimer this.fnVoidColorCheck, -nextDelay
        }
    }

    ExecuteAutoVoidRoutine() {
        if !WinActive(TorchlightAutomation.TargetProcess)
            return

        ; Perform click with mouse move and press hold duration
        Sleep 1000
        MouseMove 900, 400, this.DefaultMouseSpeed
        sleep 550
        Click "Down"
        Sleep Random(this.KeyHoldMin, this.KeyHoldMax)
        Click "Up"
        Sleep 550
        MouseMove 900, 780, this.DefaultMouseSpeed
        Sleep 550
        Click "Down"
        Sleep Random(this.KeyHoldMin, this.KeyHoldMax)
        Click "Up"
        Sleep 550
        MouseMove 970, 780, this.DefaultMouseSpeed
        Sleep 550
        Click "Down"
        Sleep Random(this.KeyHoldMin, this.KeyHoldMax)
        Click "Up"
        Sleep 4000
        Send "{esc}"
        Sleep 1000
        MouseMove 970, 200, this.DefaultMouseSpeed
        Sleep 1000
        this.SendHuman("s")
        Sleep 27000
        MouseMove 970, 85, this.DefaultMouseSpeed
        Sleep 1500
        this.SendHuman("s")
        Sleep 1500
        this.SendHuman("s")
        Sleep 1500
        this.SendHuman("s")
        MouseMove 580, 135, this.DefaultMouseSpeed
        this.SendHuman("s")
        Sleep 1200
        Click "Right Down"
        Sleep Random(this.KeyHoldMin, this.KeyHoldMax)
        Click "Right Up"
        Sleep 1000
        MouseMove 950, 480, this.DefaultMouseSpeed
        this.SendHuman("s")
        Sleep 2500
        this.SendHuman("b")
        Sleep 3000
        Click "Right Down"
        Sleep Random(this.KeyHoldMin, this.KeyHoldMax)
        Click "Right Up"
        sleep 6900
        Click "Right Down"
        Sleep Random(this.KeyHoldMin, this.KeyHoldMax)
        Click "Right Up"

        this.UpdateStatus("Auto Void Active")
    }

    GetAverageColor(cX, cY, size := 5) {
        if (cX <= 0 or cY <= 0)
            return "0x000000"

        offset := size // 2
        totalR := 0, totalG := 0, totalB := 0, count := 0

        loop size {
            dx := A_Index - 1 - offset
            loop size {
                dy := A_Index - 1 - offset
                px := cX + dx
                py := cY + dy
                if (px > 0 && py > 0) {
                    try {
                        colorStr := PixelGetColor(px, py, "RGB")
                        num := Integer(colorStr)
                        totalR += (num >> 16) & 0xFF
                        totalG += (num >> 8) & 0xFF
                        totalB += num & 0xFF
                        count++
                    }
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

    ; --------------------------------------------------------------------------
    ; 9. STATE SAVE, RESTORE & CLEANUP
    ; --------------------------------------------------------------------------
    StopAutomation(saveState := false, exceptVoid := false) {
        if saveState {
            if !this.IsAnyPaused() {
                this.memSpam := this.isSpamming
                this.memFlask := this.isFlaskActive
                this.memChannel := this.isChanneling
                if !exceptVoid
                    this.memLoot := this.isAutoLooting
                if !exceptVoid
                    this.memVoid := this.isAutoVoid
            }
        }

        ; If Auto Void is active, we preserve Auto Loot status and timer
        if this.isAutoVoid {
            this.isSpamming := false
            this.isFlaskActive := false
            this.isChanneling := false

            this.chkSpam.Value := 0
            this.chkFlask.Value := 0
            this.chkChannel.Value := 0

            SetTimer this.fnSpam, 0
            SetTimer this.fnFlask, 0
        } else {
            this.isSpamming := false
            this.isFlaskActive := false
            this.isAutoLooting := false
            this.isChanneling := false

            this.chkSpam.Value := 0
            this.chkFlask.Value := 0
            this.chkLoot.Value := 0
            this.chkChannel.Value := 0

            SetTimer this.fnSpam, 0
            SetTimer this.fnFlask, 0
            SetTimer this.fnLoot, 0
        }

        if !exceptVoid {
            this.isAutoVoid := false
            this.chkVoid.Value := 0
            SetTimer this.fnVoidColorCheck, 0
        }

        this.ReleaseAllKeys()
    }

    ReleaseAllKeys() {
        try SendInput "{" this.Key_Skill " up}"
        try SendInput "{" this.Key_Loot " up}"
        try SendInput "{" this.Key_Channel " up}"
        try SendInput "{" this.Key_Flask1 " up}"
        try SendInput "{" this.Key_Flask2 " up}"
        try SendInput "{" this.Key_Flask3 " up}"
    }

    RestoreState() {
        if this.IsAnyPaused()
            return

        if this.memSpam {
            this.isSpamming := true
            this.chkSpam.Value := 1
            SetTimer this.fnSpam, 10
        } else {
            this.isSpamming := false
            this.chkSpam.Value := 0
            SetTimer this.fnSpam, 0
        }

        if this.memFlask {
            this.isFlaskActive := true
            this.chkFlask.Value := 1
            SetTimer this.fnFlask, this.FlaskLoopInterval
            this.FlaskLoop()
        } else {
            this.isFlaskActive := false
            this.chkFlask.Value := 0
            SetTimer this.fnFlask, 0
        }

        if this.isAutoVoid {
            ; Ensure Auto Loot remains enabled and running during pause recovery if Auto Void is active
            this.isAutoLooting := true
            this.chkLoot.Value := 1
            SetTimer this.fnLoot, Max(30, this.LootLoopInterval)
        } else if this.memLoot {
            this.isAutoLooting := true
            this.chkLoot.Value := 1
            SetTimer this.fnLoot, Max(30, this.LootLoopInterval)
        } else {
            this.isAutoLooting := false
            this.chkLoot.Value := 0
            SetTimer this.fnLoot, 0
        }

        if this.memChannel {
            this.isChanneling := true
            this.chkChannel.Value := 1
            SetTimer () => (
                this.isChanneling && !this.IsAnyPaused() && WinActive(TorchlightAutomation.TargetProcess) && SendInput(
                    "{" this.Key_Channel " down}")
            ), -200
        } else {
            this.isChanneling := false
            this.chkChannel.Value := 0
            try SendInput "{" this.Key_Channel " up}"
        }

        if this.memVoid {
            this.isAutoVoid := true
            this.chkVoid.Value := 1
            SetTimer this.fnVoidColorCheck, Max(50, this.VoidCheckInterval)
        } else {
            this.isAutoVoid := false
            this.chkVoid.Value := 0
            SetTimer this.fnVoidColorCheck, 0
        }

        this.UpdateStatus("Automation Restored")
    }
}

; ------------------------------------------------------------------------------
; 10. APP INITIALIZATION & GLOBAL DIRECTIVES
; ------------------------------------------------------------------------------
global App := TorchlightAutomation()

#HotIf WinActive(TorchlightAutomation.TargetProcess)
~Esc:: {
    if App.isShopPaused {
        App.ColorGuardHibernationEnd := A_TickCount + App.ShopPauseDelay
        App.isShopPaused := false
        Sleep 100
        App.RestoreState()
        App.UpdateStatus("Resumed (Shop Closed)")
    }
}

End:: Reload