#Requires AutoHotkey v2.0

; ==============================================================================
; UI.ahk - The floating control panel overlay.
;
; Two views: the main page (toggles + status) and the scrollable settings page.
; Settings fields are bound declaratively to Config properties in EditFields /
; CheckFields, so loading and saving GUI state is generic instead of one
; explicit statement per field.
; ==============================================================================

class UI {
    isSettingsOpen := false
    isMinimized := false
    CurrentScrollOffset := 0
    CurrentHoveredHwnd := 0
    SettingsInitY := Map()
    ButtonColors := Map()
    MainControls := []
    SettingsHeaderControls := []
    SettingsControls := []

    ; Declarative field bindings: [control name, config property, type]
    EditFields := [
        ; --- Timing & delays ---
        ["edtSpamMin", "SpamIntervalMin", "int"],
        ["edtSpamMax", "SpamIntervalMax", "int"],
        ["edtHoldMin", "KeyHoldMin", "int"],
        ["edtHoldMax", "KeyHoldMax", "int"],
        ["edtFlaskDelayMin", "FlaskKeyDelayMin", "int"],
        ["edtFlaskDelayMax", "FlaskKeyDelayMax", "int"],
        ["edtFlask", "FlaskLoopInterval", "int"],
        ["edtLoot", "LootLoopInterval", "int"],
        ["edtShopDelay", "ShopPauseDelay", "int"],
        ["edtMouseSpeed", "DefaultMouseSpeed", "int"],
        ; --- Action keys ---
        ["edtKeySkill", "Key_Skill", "str"],
        ["edtKeyLoot", "Key_Loot", "str"],
        ["edtKeyChannel", "Key_Channel", "str"],
        ["edtKeyShop", "Key_Shop", "str"],
        ["edtKeyF1", "Key_Flask1", "str"],
        ["edtKeyF2", "Key_Flask2", "str"],
        ["edtKeyF3", "Key_Flask3", "str"],
        ; --- Toggle hotkeys ---
        ["edtKeyTglSpam", "Key_ToggleSpam", "str"],
        ["edtKeyTglFlasks", "Key_ToggleFlasks", "str"],
        ["edtKeyTglLoot", "Key_ToggleLoot", "str"],
        ["edtKeyTglChannel", "Key_ToggleChannel", "str"],
        ["edtKeyTglPause", "Key_MasterPause", "str"],
        ; --- Color guard ---
        ["edtColorInterval", "CheckInterval", "int"],
        ["edtPauseStab", "PauseStability", "int"],
        ["edtResumeStab", "ResumeStability", "int"],
        ["edtMinPause", "MinPauseMs", "int"],
        ["edtTargetX", "TargetX", "int"],
        ["edtTargetY", "TargetY", "int"],
        ["edtTargetColor", "TargetColor", "str"],
        ["edtVariance", "ColorVariance", "int"],
        ; --- Auto void color guard ---
        ["edtVoidTargetX", "VoidTargetX", "int"],
        ["edtVoidTargetY", "VoidTargetY", "int"],
        ["edtVoidTargetColor", "VoidTargetColor", "str"],
        ["edtVoidVariance", "VoidColorVariance", "int"],
        ["edtVoidSteps", "VoidRoutineSteps", "str"]
    ]

    CheckFields := [
        ["chkColorGuard", "ColorGuardEnabled", "bool"],
        ["chkVoid", "ToggleVoidOn", "bool"]
    ]

    ; Key fields that support "click then press a key" capture.
    ; Maps control name -> friendly label shown while capturing.
    CaptureFields := Map(
        "edtKeySkill", "Skill",
        "edtKeyLoot", "Loot",
        "edtKeyChannel", "Channel",
        "edtKeyShop", "Shop",
        "edtKeyF1", "Flask 1",
        "edtKeyF2", "Flask 2",
        "edtKeyF3", "Flask 3",
        "edtKeyTglSpam", "Combat toggle",
        "edtKeyTglFlasks", "Flask toggle",
        "edtKeyTglLoot", "Loot toggle",
        "edtKeyTglChannel", "Channel toggle",
        "edtKeyTglPause", "Pause all"
    )

    ; Populated at build time: control hwnd -> [control, friendly label]
    CaptureHwnds := Map()

    __New(app) {
        this.App := app
        this.BuildGui()
        this.SyncFromConfig()
    }

    ; --------------------------------------------------------------------------
    ; GUI construction
    ; --------------------------------------------------------------------------
    BuildGui() {
        this.TLGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner", "TL Control")
        this.TLGui.SetFont("s9", "Segoe UI")
        this.TLGui.BackColor := "0F172A"
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", this.TLGui.Hwnd, "uint", 33, "int*", 2, "uint", 4)

        ; --- Header Section (Main Page) ---
        this.TLGui.SetFont("s10 Bold", "Segoe UI")
        this.txtTitle := this.TLGui.Add("Text", "x14 y8 w72 h20 +0x200 cE2E8F0", "TL Control")
        this.TLGui.SetFont("s12 Bold c10B981")
        this.txtActiveDot := this.TLGui.Add("Text", "x92 y8 w14 h20 Center +0x200", "●")
        this.TLGui.SetFont("s12 Bold c475569")
        this.txtVoidActiveDot := this.TLGui.Add("Text", "x110 y8 w14 h20 Center +0x200", "●")
        this.TLGui.SetFont("s10 Bold c94A3B8")
        this.btnMin := this.TLGui.Add("Text", "x144 y7 w18 h18 Center +0x200 Background1E293B", "—")
        this.btnClose := this.TLGui.Add("Text", "x164 y7 w18 h18 Center +0x200 Background1E293B", "✕")

        ; --- Header Section (Settings Page) ---
        this.TLGui.SetFont("s10 Bold", "Segoe UI")
        this.txtSettingsTitle := this.TLGui.Add("Text", "x15 y8 w120 h20 +0x200 cE2E8F0 Hidden", "⚙️ Settings")
        this.TLGui.SetFont("s9 Bold cF8FAFC")
        this.btnBack := this.TLGui.Add("Text", "x145 y7 w60 h20 Center +0x200 Background1E293B Hidden", "Back ↩")

        ; --- Controls Section (Main Page) ---
        this.TLGui.SetFont("s9 w600", "Segoe UI")
        this.chkSpam := this.TLGui.Add("Checkbox", "x14 y38 w140 vSpam cF8FAFC", "Combat (" this.App.cfg.Key_ToggleSpam ")")
        this.chkFlask := this.TLGui.Add("Checkbox", "x14 y+10 w140 vFlask cF8FAFC", "Flasks (" this.App.cfg.Key_ToggleFlasks ")")
        this.chkLoot := this.TLGui.Add("Checkbox", "x14 y+10 w140 vLoot cF8FAFC", "Auto Loot (" this.App.cfg.Key_ToggleLoot ")")
        this.chkChannel := this.TLGui.Add("Checkbox", "x14 y+10 w140 vChannel cF8FAFC", "Auto Channel (" this.App.cfg.Key_ToggleChannel ")")
        this.chkVoid := this.TLGui.Add("Checkbox", "x14 y+10 w140 vVoid cF8FAFC", "Auto Void")
        this.sepLine1 := this.TLGui.Add("Text", "x11 y+10 w150 h1 Background334155")
        this.chkPause := this.TLGui.Add("Checkbox", "x14 y+10 w140 vPause cF87171", "Pause All (" this.App.cfg.Key_MasterPause ")")
        this.sepLine2 := this.TLGui.Add("Text", "x11 y+10 w150 h1 Background334155")

        ; --- Footer / Status (Main Page) ---
        this.TLGui.SetFont("s8 w600 cE2E8F0")
        this.txtStatus := this.TLGui.Add("Text", "x14 y+8 w120 h20 Center +0x200 Background1E293B", "Status: Idle")
        this.TLGui.SetFont("s8 c475569")
        this.txtVersion := this.TLGui.Add("Text", "x138 y+8 w44 h20 Right +0x200", "v" Controller.Version)
        this.TLGui.SetFont("s9 w600 cF8FAFC")
        this.btnSettings := this.TLGui.Add("Text", "x14 y+8 w150 h22 Center +0x200 Background4F46E5", "Settings ⚙️")

        ; --- Settings Panel Controls ---
        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secTiming := this.TLGui.Add("Text", "x15 y38 w190 h16 +0x200 Hidden", "TIMING & DELAYS")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblSpam := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Combat Delay Min / Max (ms):")
        this.edtSpamMin := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.SpamIntervalMin)
        this.edtSpamMax := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.SpamIntervalMax)

        this.lblHuman := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Key Hold Min / Max (ms):")
        this.edtHoldMin := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.KeyHoldMin)
        this.edtHoldMax := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.KeyHoldMax)

        this.lblFlaskDelay := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Flask Key Delay Min / Max (ms):")
        this.edtFlaskDelayMin := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.FlaskKeyDelayMin)
        this.edtFlaskDelayMax := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.FlaskKeyDelayMax)

        this.lblFlask := this.TLGui.Add("Text", "x15 y+6 w90 h14 Hidden", "Flask Loop (ms):")
        this.lblLoot := this.TLGui.Add("Text", "x115 yp w90 h14 Hidden", "Loot Loop (ms):")
        this.edtFlask := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.FlaskLoopInterval)
        this.edtLoot := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.LootLoopInterval)

        this.lblShopDelay := this.TLGui.Add("Text", "x15 y+6 w90 h14 Hidden", "Shop Pause (ms):")
        this.lblMouseSpeed := this.TLGui.Add("Text", "x115 yp w90 h14 Hidden", "Mouse Speed (0-100):")
        this.edtShopDelay := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.ShopPauseDelay)
        this.edtMouseSpeed := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.DefaultMouseSpeed)

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secKeys := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "ACTION KEY BINDINGS")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblKeys := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Skill / Loot / Channel Key:")
        this.edtKeySkill := this.TLGui.Add("Edit", "x15 y+2 w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_Skill)
        this.edtKeyLoot := this.TLGui.Add("Edit", "x80 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_Loot)
        this.edtKeyChannel := this.TLGui.Add("Edit", "x145 yp w60 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_Channel)

        this.lblFlaskKeys := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Flask Slot Keys (1 / 2 / 3):")
        this.edtKeyF1 := this.TLGui.Add("Edit", "x15 y+2 w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_Flask1)
        this.edtKeyF2 := this.TLGui.Add("Edit", "x80 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_Flask2)
        this.edtKeyF3 := this.TLGui.Add("Edit", "x145 yp w60 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_Flask3)

        this.lblShopKey := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Shop Auto-Pause Key:")
        this.edtKeyShop := this.TLGui.Add("Edit", "x15 y+2 w190 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_Shop)

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secTglKeys := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "TOGGLE HOTKEYS")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblTglSpamFlask := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Combat / Flasks / Loot Toggle:")
        this.edtKeyTglSpam := this.TLGui.Add("Edit", "x15 y+2 w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_ToggleSpam)
        this.edtKeyTglFlasks := this.TLGui.Add("Edit", "x80 yp w55 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_ToggleFlasks)
        this.edtKeyTglLoot := this.TLGui.Add("Edit", "x145 yp w60 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_ToggleLoot)

        this.lblTglChanPause := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Channel / Pause All Hotkeys:")
        this.edtKeyTglChannel := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_ToggleChannel)
        this.edtKeyTglPause := this.TLGui.Add("Edit", "x115 yp w90 h20 Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.Key_MasterPause)

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secColor := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "COLOR GUARD")

        this.TLGui.SetFont("s8 c94A3B8")
        this.chkColorGuard := this.TLGui.Add("Checkbox", "x15 y+4 w190 Hidden vEnableColor cF8FAFC", "Enable HUD Monitoring")
        this.lblColorInterval := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Color Check Interval (ms):")
        this.edtColorInterval := this.TLGui.Add("Edit", "x15 y+2 w190 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.CheckInterval)

        this.lblColorStability := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Pause / Resume Stability (checks):")
        this.edtPauseStab := this.TLGui.Add("Edit", "x15 y+2 w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.PauseStability)
        this.edtResumeStab := this.TLGui.Add("Edit", "x115 yp w90 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.ResumeStability)

        this.lblMinPause := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Min Pause Time (ms):")
        this.edtMinPause := this.TLGui.Add("Edit", "x15 y+2 w190 h20 Number Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.MinPauseMs)

        this.lblColorCoords := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "X / Y / Color / Var:")
        this.edtTargetX := this.TLGui.Add("Edit", "x15 y+2 w40 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.TargetX)
        this.edtTargetY := this.TLGui.Add("Edit", "x60 yp w40 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.TargetY)
        this.edtTargetColor := this.TLGui.Add("Edit", "x105 yp w55 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.TargetColor)
        this.edtVariance := this.TLGui.Add("Edit", "x165 yp w40 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.ColorVariance)

        this.TLGui.SetFont("s8 w700 c818CF8")
        this.secVoidColor := this.TLGui.Add("Text", "x15 y+10 w190 h16 +0x200 Hidden", "AUTO VOID COLOR GUARD")

        this.TLGui.SetFont("s8 c94A3B8")
        this.lblVoidColorCoords := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Void X / Y / Color / Var:")
        this.edtVoidTargetX := this.TLGui.Add("Edit", "x15 y+2 w40 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.VoidTargetX)
        this.edtVoidTargetY := this.TLGui.Add("Edit", "x60 yp w40 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.VoidTargetY)
        this.edtVoidTargetColor := this.TLGui.Add("Edit", "x105 yp w55 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.VoidTargetColor)
        this.edtVoidVariance := this.TLGui.Add("Edit", "x165 yp w40 h20 Center Hidden Background1E293B cF8FAFC -E0x200", this.App.cfg.VoidColorVariance)
        this.lblVoidSteps := this.TLGui.Add("Text", "x15 y+6 w190 h14 Hidden", "Void Routine Steps:")
        this.edtVoidSteps := this.TLGui.Add("Edit", "x15 y+2 w190 h60 Hidden Multi Background1E293B cF8FAFC -E0x200", this.App.cfg.VoidRoutineSteps)
        this.btnPickVoidColor := this.TLGui.Add("Text", "x15 y+6 w190 h20 Center +0x200 Hidden Background6366F1", "Pick Void Color")

        this.TLGui.SetFont("s9 w600 cF8FAFC")
        this.btnPickColor := this.TLGui.Add("Text", "x15 y+6 w190 h20 Center +0x200 Hidden Background6366F1", "Pick Screen Color (F12)")
        this.btnApply := this.TLGui.Add("Text", "x15 y+12 w190 h22 Center +0x200 Hidden Background10B981", "Apply Settings ✓")
        this.btnReload := this.TLGui.Add("Text", "x15 y+6 w190 h22 Center +0x200 Hidden Background4B5563", "Reload Script 🔄")
        this.btnExit := this.TLGui.Add("Text", "x15 y+6 w190 h22 Center +0x200 Hidden BackgroundEF4444", "Exit App ✕")

        ; --- Minimized Logo ---
        this.TLGui.SetFont("s14", "Segoe UI Emoji")
        this.btnLogo := this.TLGui.Add("Text", "x0 y0 w40 h40 Center +0x200 Hidden Background4F46E5", "🔥")

        ; --- Control Collections ---
        this.MainControls := [
            this.txtTitle, this.txtActiveDot, this.txtVoidActiveDot, this.btnMin, this.btnClose,
            this.chkSpam, this.chkFlask, this.chkLoot, this.chkChannel, this.chkVoid,
            this.sepLine1, this.chkPause, this.sepLine2, this.txtStatus, this.txtVersion, this.btnSettings
        ]

        this.SettingsHeaderControls := [this.txtSettingsTitle, this.btnBack]

        this.SettingsControls := [
            this.secTiming, this.lblSpam, this.edtSpamMin, this.edtSpamMax, this.lblHuman,
            this.edtHoldMin, this.edtHoldMax, this.lblFlaskDelay, this.edtFlaskDelayMin,
            this.edtFlaskDelayMax, this.lblFlask, this.lblLoot, this.edtFlask, this.edtLoot,
            this.lblShopDelay, this.lblMouseSpeed, this.edtShopDelay, this.edtMouseSpeed, this.secKeys, this.lblKeys,
            this.edtKeySkill, this.edtKeyLoot, this.edtKeyChannel, this.lblFlaskKeys, this.edtKeyF1, this.edtKeyF2,
            this.edtKeyF3, this.lblShopKey, this.edtKeyShop, this.secTglKeys, this.lblTglSpamFlask,
            this.edtKeyTglSpam, this.edtKeyTglFlasks, this.edtKeyTglLoot, this.lblTglChanPause,
            this.edtKeyTglChannel, this.edtKeyTglPause, this.secColor, this.chkColorGuard,
            this.lblColorInterval, this.edtColorInterval, this.lblColorStability, this.edtPauseStab,
            this.edtResumeStab, this.lblMinPause, this.edtMinPause, this.lblColorCoords, this.edtTargetX,
            this.edtTargetY, this.edtTargetColor, this.edtVariance, this.secVoidColor,
            this.lblVoidColorCoords, this.edtVoidTargetX, this.edtVoidTargetY, this.edtVoidTargetColor,
            this.edtVoidVariance, this.lblVoidSteps, this.edtVoidSteps, this.btnPickVoidColor, this.btnPickColor, this.btnApply, this.btnReload, this.btnExit
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
            this.btnClose.Hwnd, { normal: "1E293B", hover: "EF4444", ctrl: this.btnClose },
            this.btnLogo.Hwnd, { normal: "", hover: "6366F1", ctrl: this.btnLogo }
        )

        ; --- Event Binds ---
        this.chkSpam.OnEvent("Click", (*) => this.App.ToggleSpam(true))
        this.chkFlask.OnEvent("Click", (*) => this.App.ToggleFlasks(true))
        this.chkLoot.OnEvent("Click", (*) => this.App.ToggleLoot(true))
        this.chkChannel.OnEvent("Click", (*) => this.App.ToggleChannel(true))
        this.chkVoid.OnEvent("Click", (*) => this.App.ToggleAutoVoid(true))
        this.chkPause.OnEvent("Click", (*) => this.App.ToggleMasterPause(true))
        this.btnMin.OnEvent("Click", (*) => this.ToggleGuiMode(true))
        this.btnClose.OnEvent("Click", (*) => this.ExitScript())
        this.btnSettings.OnEvent("Click", (*) => this.ToggleSettings())
        this.btnBack.OnEvent("Click", (*) => this.ToggleSettings(false))
        this.btnApply.OnEvent("Click", (*) => this.ApplySettings())
        this.btnReload.OnEvent("Click", (*) => (this.SavePosition(), Reload()))
        this.btnExit.OnEvent("Click", (*) => ExitApp())
        this.btnPickColor.OnEvent("Click", (*) => this.App.color.PickColorCoord(false))
        this.btnPickVoidColor.OnEvent("Click", (*) => this.App.color.PickColorCoord(true))
        this.chkColorGuard.OnEvent("Click", (*) => this.App.color.ToggleColorGuard(true))

        ; Key capture: clicking a hotkey field then pressing a key sets it.
        ; Edit controls have no "Click" event, so we detect the click through the
        ; WM_LBUTTONDOWN handler via a hwnd -> [control, label] lookup.
        for controlName, label in this.CaptureFields {
            control := this.%controlName%
            this.CaptureHwnds[control.Hwnd] := [control, label]
        }

        ; --- Window Messages ---
        OnMessage(0x0201, (wParam, lParam, msg, hwnd) => this.WM_LBUTTONDOWN(wParam, lParam, msg, hwnd))
        OnMessage(0x0200, (*) => this.WM_MOUSEMOVE())
        OnMessage(0x020A, (wParam, lParam, msg, hwnd) => this.WM_MOUSEWHEEL(wParam, lParam, msg, hwnd))
        OnMessage(0x0204, (wParam, lParam, msg, hwnd) => this.WM_RBUTTONDOWN(wParam, lParam, msg, hwnd))

        this.TLGui.Show("x" this.App.cfg.GuiX " y" this.App.cfg.GuiY " w186 h270 NoActivate")
        WinSetTransparent(180, "ahk_id " this.TLGui.Hwnd)
    }

    ; --------------------------------------------------------------------------
    ; Config <-> GUI field sync
    ; --------------------------------------------------------------------------
    SyncFromConfig() {
        cfg := this.App.cfg
        for entry in this.EditFields {
            this.%entry[1]%.Value := cfg.%entry[2]%
        }
        for entry in this.CheckFields {
            this.%entry[1]%.Value := cfg.%entry[2]% ? 1 : 0
        }
        this.UpdateToggleLabels()
    }

    ReadToConfig() {
        cfg := this.App.cfg
        for entry in this.EditFields {
            raw := this.%entry[1]%.Value
            if (entry[3] = "int")
                cfg.%entry[2]% := Integer(raw)
            else
                cfg.%entry[2]% := Trim(raw)
        }
        for entry in this.CheckFields {
            cfg.%entry[2]% := this.%entry[1]%.Value ? 1 : 0
        }
    }

    UpdateToggleLabels() {
        cfg := this.App.cfg
        this.chkSpam.Text := "Combat (" cfg.Key_ToggleSpam ")"
        this.chkFlask.Text := "Flasks (" cfg.Key_ToggleFlasks ")"
        this.chkLoot.Text := "Auto Loot (" cfg.Key_ToggleLoot ")"
        this.chkChannel.Text := "Auto Channel (" cfg.Key_ToggleChannel ")"
        this.chkPause.Text := "Pause All (" cfg.Key_MasterPause ")"
    }

    ApplySettings() {
        try {
            this.ReadToConfig()
            this.App.cfg.Validate()

            err := this.App.ValidateHotkeys()
            if (err != "") {
                this.App.UpdateStatus("Hotkey error: " err)
                return
            }
            vErr := this.App.void.ValidateSteps()
            if (vErr != "") {
                this.App.UpdateStatus("Void steps error: " vErr)
                return
            }

            this.App.cfg.Save()
            this.App.void.ParseSteps()
            this.App.RegisterHotkeys()
            this.App.color.ToggleColorGuard(false)
            this.UpdateToggleLabels()
            this.App.UpdateStatus("Settings Saved!")
            this.App.Log("Settings applied")
            SetTimer () => this.App.UpdateStatus("Status: Idle"), -2000
            this.ToggleSettings(false)
        } catch as err {
            this.App.UpdateStatus("Error: " err.Message)
        }
    }

    ; --------------------------------------------------------------------------
    ; Status dot tooltip (dynamic)
    ; --------------------------------------------------------------------------
    GetActiveDotTooltip() {
        app := this.App
        if !WinActive(Controller.TargetProcess)
            return "Inactive: Game Unfocused`nAll automation paused"

        reasons := []
        if app.isMasterPaused
            reasons.Push("Master Pause")
        if app.isColorPaused
            reasons.Push("Color Guard")
        if app.isShopPaused
            reasons.Push("Shop Open")

        if reasons.Length {
            joined := reasons[1]
            loop reasons.Length - 1
                joined .= " / " reasons[A_Index + 1]
            return "Paused: " joined "`nYellow dot"
        }
        return "Active - all systems running`nGreen dot"
    }

    ; --------------------------------------------------------------------------
    ; Key capture: click a hotkey field, then press a key to set it
    ; --------------------------------------------------------------------------
    CaptureKey(control, label) {
        Tooltip "Press a key for " label "`n(Esc to cancel)"
        control.Enabled := false

        ; Release anything currently held so no key sticks during the blocked wait
        this.App.ReleaseAllKeys()

        captured := ""
        ih := InputHook("", "Escape")
        ih.OnKeyDown := (hook, vk, sc) => (
            captured := this.KeyFromVKSC(vk, sc),
            hook.Stop(),
            "1"
        )
        ; Suppress toggle hotkeys while waiting, so pressing e.g. F2 while
        ; capturing cannot fire the flasks toggle.
        this.App.isCapturing := true
        try {
            ih.Start()
            ih.Wait(60000)
        } finally {
            this.App.isCapturing := false
        }

        control.Enabled := true
        Tooltip()

        if (captured != "") {
            control.Value := captured
            this.App.UpdateStatus(label " -> " captured)
        } else {
            this.App.UpdateStatus("Key capture cancelled")
        }
        SetTimer () => this.App.UpdateStatus("Status: Idle"), -2000
    }

    KeyFromVKSC(vk, sc) {
        return GetKeyName("vk" Format("{:02X}", vk) "sc" Format("{:03X}", sc))
    }

    ; --------------------------------------------------------------------------
    ; Window position persistence
    ; --------------------------------------------------------------------------
    SavePosition() {
        try {
            WinGetPos(&x, &y, , , "ahk_id " this.TLGui.Hwnd)
            if (x != "" && y != "") {
                this.App.cfg.GuiX := x
                this.App.cfg.GuiY := y
                this.App.cfg.Save()
            }
        }
    }

    ; --------------------------------------------------------------------------
    ; View management
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
            this.TLGui.Show("w186 h270")
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

            try this.btnLogo.Opt("Background" this.App.CurrentStatusColor)
            this.btnLogo.Visible := true
            try this.btnLogo.Redraw()

            this.TLGui.Show("w40 h40")
            WinSetTransparent(100, "ahk_id " this.TLGui.Hwnd)
        } else {
            this.btnLogo.Visible := false
            for ctrl in this.MainControls
                ctrl.Visible := true

            this.TLGui.Show("w186 h270")
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
                if (Abs(currX - startX) > 4 || Abs(currY - startY) > 4) {
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

        ; Clicking a hotkey field starts key capture
        if this.CaptureHwnds.Has(hControl) {
            info := this.CaptureHwnds[hControl]
            this.CaptureKey(info[1], info[2])
            return 0
        }

        if (hControl && hControl != this.TLGui.Hwnd && hControl != this.txtTitle.Hwnd && hControl != this.txtSettingsTitle.Hwnd && hControl != this.sepLine1.Hwnd && hControl != this.sepLine2.Hwnd) {
            return
        }

        PostMessage 0xA1, 2, , , "ahk_id " this.TLGui.Hwnd
    }

    ; Right-click while ghosted (logo) exits the script
    WM_RBUTTONDOWN(wParam, lParam, msg, hwnd) {
        if this.btnLogo.Visible {
            this.ExitScript()
            return 0
        }
    }

    ; Seamless exit: persist position, then fully terminate
    ExitScript() {
        this.SavePosition()
        ExitApp()
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
            cfg := this.App.cfg
            if (hControl = this.chkSpam.Hwnd)
                CurrControl := "Spam " StrUpper(cfg.Key_Skill) " (" cfg.SpamIntervalMin "-" cfg.SpamIntervalMax "ms)"
            else if (hControl = this.chkFlask.Hwnd)
                CurrControl := "Spam " StrUpper(cfg.Key_Flask1) "-" StrUpper(cfg.Key_Flask3) " (" Round(cfg.FlaskLoopInterval / 1000, 1) "s)"
            else if (hControl = this.chkLoot.Hwnd)
                CurrControl := "Spam " StrUpper(cfg.Key_Loot) " (" cfg.LootLoopInterval "ms)"
            else if (hControl = this.chkChannel.Hwnd)
                CurrControl := "Hold " StrUpper(cfg.Key_Channel) " (Auto Channel)"
            else if (hControl = this.chkPause.Hwnd)
                CurrControl := "Master Pause (Saves State)"
            else if (hControl = this.txtActiveDot.Hwnd)
                CurrControl := this.GetActiveDotTooltip()
            else if (hControl = this.txtVoidActiveDot.Hwnd)
                CurrControl := "Void Dot`nIndigo: Auto Void Active`nYellow: Paused`nGrey: Idle"
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
            else if (hControl = this.btnClose.Hwnd)
                CurrControl := "Exit Script"
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
            this.btnLogo.Opt("Background" this.App.CurrentStatusColor)
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
}
