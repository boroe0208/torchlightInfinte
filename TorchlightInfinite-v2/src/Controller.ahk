#Requires AutoHotkey v2.0

; ==============================================================================
; Controller.ahk - Central state machine and coordinator.
;
; Owns all shared automation state (pause flags + remembered state), the module
; instances, dynamic hotkey registration, and the toggle/save-restore logic
; that spans multiple modules.
; ==============================================================================

class Controller {
    static TargetProcess := "ahk_group TLI_Target"
    static Version := "2.5"

    ; --- State ---
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
    CurrentStatusColor := "10B981"

    ; Re-entry / capture guards
    shopToggleBusy := false
    isCapturing := false

    ; --- Remembered state for restoration ---
    memSpam := false
    memFlask := false
    memLoot := false
    memChannel := false
    memVoid := false

    __New() {
        this.cfg := Config()
        this.cfg.Load()

        this.engine := AutomationEngine(this)
        this.color := ColorGuard(this)
        this.void := VoidRoutine(this)
        this.ui := UI(this)
        this.monitor := WindowMonitor(this)

        ; Bring automation back to its remembered state from the last session
        this.RestoreToggleState()

        this.RegisterHotkeys()
        this.color.ToggleColorGuard(false)

        ; Always release held keys and save the GUI position when exiting.
        OnExit((*) => (this.ui.SavePosition(), this.ReleaseAllKeys()))

        this.Log("Script started (v" Controller.Version ")")
    }

    ; --------------------------------------------------------------------------
    ; Pause status
    ; --------------------------------------------------------------------------
    IsAnyPaused(ignoreColor := false) {
        if ignoreColor
            return this.isMasterPaused || this.isFocusPaused || this.isShopPaused
        return this.isMasterPaused || this.isColorPaused || this.isFocusPaused || this.isShopPaused
    }

    UpdateStatus(msg) {
        try this.ui.txtStatus.Value := msg
    }

    ; --------------------------------------------------------------------------
    ; Toggle state persistence
    ; --------------------------------------------------------------------------
    ; Persists the "armed" state of each automation toggle so it can be restored
    ; on the next launch. When paused, the remembered (mem*) values are saved;
    ; otherwise the live states.
    PersistToggleState() {
        paused := this.IsAnyPaused()
        cfg := this.cfg
        cfg.ToggleSpamOn := paused ? (this.memSpam ? 1 : 0) : (this.isSpamming ? 1 : 0)
        cfg.ToggleFlasksOn := paused ? (this.memFlask ? 1 : 0) : (this.isFlaskActive ? 1 : 0)
        cfg.ToggleLootOn := paused ? (this.memLoot ? 1 : 0) : (this.isAutoLooting ? 1 : 0)
        cfg.ToggleChannelOn := paused ? (this.memChannel ? 1 : 0) : (this.isChanneling ? 1 : 0)
        cfg.ToggleVoidOn := paused ? (this.memVoid ? 1 : 0) : (this.isAutoVoid ? 1 : 0)
        cfg.Save()
    }

    ; Re-applies the persisted toggle states at startup. Runs after the window
    ; monitor's first focus check so that an unfocused game simply arms the
    ; states (restored on refocus) while a focused game starts immediately.
    RestoreToggleState() {
        cfg := this.cfg
        this.ui.chkSpam.Value := cfg.ToggleSpamOn ? 1 : 0
        this.ToggleSpam(true)
        this.ui.chkFlask.Value := cfg.ToggleFlasksOn ? 1 : 0
        this.ToggleFlasks(true)
        this.ui.chkLoot.Value := cfg.ToggleLootOn ? 1 : 0
        this.ToggleLoot(true)
        this.ui.chkChannel.Value := cfg.ToggleChannelOn ? 1 : 0
        this.ToggleChannel(true)
        this.ui.chkVoid.Value := cfg.ToggleVoidOn ? 1 : 0
        this.ToggleAutoVoid(true)
    }

    ; --------------------------------------------------------------------------
    ; Toggles
    ; --------------------------------------------------------------------------
    ToggleSpam(fromGui := false) {
        this.ToggleSystem("isSpamming", "memSpam", this.ui.chkSpam, "Combat",
            () => this.engine.StartSpam(), () => this.engine.StopSpam(), fromGui)
    }

    ToggleFlasks(fromGui := false) {
        this.ToggleSystem("isFlaskActive", "memFlask", this.ui.chkFlask, "Flasks",
            () => (this.engine.StartFlasks(), this.engine.FlaskLoop()),
            () => this.engine.StopFlasks(), fromGui)
    }

    ToggleLoot(fromGui := false) {
        this.ToggleSystem("isAutoLooting", "memLoot", this.ui.chkLoot, "Loot",
            () => this.engine.StartLoot(), () => this.engine.StopLoot(), fromGui)
    }

    ToggleChannel(fromGui := false) {
        this.ToggleSystem("isChanneling", "memChannel", this.ui.chkChannel, "Channel",
            () => this.engine.HoldChannel(), () => this.engine.ReleaseChannel(), fromGui)
    }

    ToggleAutoVoid(fromGui := false) {
        this.ToggleSystem("isAutoVoid", "memVoid", this.ui.chkVoid, "Auto Void",
            () => this.StartVoidAutomation(), () => this.color.StopVoidCheck(), fromGui)
        this.monitor.UpdateVoidDot()
    }

    ; Auto Void on: begin the void color checks and force Auto Loot on so loot
    ; keeps running while the void sequence executes.
    StartVoidAutomation() {
        this.color.StartVoidCheck()
        if !this.isAutoLooting {
            this.isAutoLooting := true
            this.ui.chkLoot.Value := 1
            this.engine.StartLoot()
        }
    }

    ; --------------------------------------------------------------------------
    ; Toggle driver
    ; --------------------------------------------------------------------------
    ; Shared pause-armed + live toggle logic. Each automation system is
    ; described by its live flag name, remembered flag name, checkbox control,
    ; display label, and start/stop actions; the five toggles above are thin
    ; wrappers around it.
    ToggleSystem(live, mem, chk, label, startFn, stopFn, fromGui) {
        if this.isCapturing
            return
        if this.IsAnyPaused() {
            if fromGui
                this.%mem% := chk.Value
            else {
                this.%mem% := !this.%mem%
                chk.Value := this.%mem%
            }
            state := this.%mem%
            this.UpdateStatus(label (state ? " Armed" : " Disarmed"))
            this.Log(label (state ? " Armed" : " Disarmed"))
            this.PersistToggleState()
            return
        }

        this.%live% := fromGui ? chk.Value : !this.%live%
        state := this.%live%
        chk.Value := state

        if state {
            this.UpdateStatus(label ": ON")
            startFn()
        } else {
            this.UpdateStatus(label ": OFF")
            stopFn()
        }
        this.Log(label (state ? " ON" : " OFF"))
        this.PersistToggleState()
    }

    ToggleMasterPause(fromGui := false) {
        if this.isCapturing
            return
        targetState := fromGui ? this.ui.chkPause.Value : !this.isMasterPaused
        this.ui.chkPause.Value := targetState

        if targetState {
            this.StopAutomation(true)
            this.isMasterPaused := true
            this.UpdateStatus("Master Paused")
            this.Log("Master Paused")
        } else {
            this.isMasterPaused := false
            this.RestoreState()
            this.UpdateStatus("Resumed")
            this.Log("Resumed (Master)")
        }
    }

    ToggleShopPause() {
        if this.isCapturing || this.shopToggleBusy
            return

        ; The shop key is itself a hotkey; sending it below would re-trigger this
        ; method. The busy flag makes that re-entry a no-op.
        this.shopToggleBusy := true
        try {
            if !this.isShopPaused {
                this.StopAutomation(true)
                this.isShopPaused := true
                this.UpdateStatus("Shop Paused")
                this.Log("Shop Pause")

                this.ColorGuardHibernationEnd := A_TickCount + this.cfg.ShopPauseDelay
                Sleep 100
                SendInput "{" this.cfg.Key_Shop "}"
            } else {
                SendInput "{" this.cfg.Key_Shop "}"
                this.ColorGuardHibernationEnd := A_TickCount + this.cfg.ShopPauseDelay
                this.isShopPaused := false

                Sleep 100
                this.RestoreState()
                this.UpdateStatus("Resumed (Shop Closed)")
                this.Log("Shop Resumed")
            }
        } finally {
            this.shopToggleBusy := false
        }
    }

    ; --------------------------------------------------------------------------
    ; State save / restore / cleanup
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

        this.isSpamming := false
        this.isFlaskActive := false
        this.isChanneling := false
        this.ui.chkSpam.Value := 0
        this.ui.chkFlask.Value := 0
        this.ui.chkChannel.Value := 0
        this.engine.StopSpam()
        this.engine.StopFlasks()

        ; Auto Void keeps Auto Loot alive, so loot continues while voiding.
        if !this.isAutoVoid {
            this.isAutoLooting := false
            this.ui.chkLoot.Value := 0
            this.engine.StopLoot()
        }

        if !exceptVoid {
            this.isAutoVoid := false
            this.ui.chkVoid.Value := 0
            this.color.StopVoidCheck()
        }

        this.ReleaseAllKeys()
    }

    ReleaseAllKeys() {
        this.engine.ReleaseAll()
        try SendInput "{LButton up}"
        try SendInput "{RButton up}"
        try SendInput "{MButton up}"
    }

    RestoreState() {
        if this.IsAnyPaused()
            return

        if this.memSpam {
            this.isSpamming := true
            this.ui.chkSpam.Value := 1
            this.engine.StartSpam()
        } else {
            this.isSpamming := false
            this.ui.chkSpam.Value := 0
            this.engine.StopSpam()
        }

        if this.memFlask {
            this.isFlaskActive := true
            this.ui.chkFlask.Value := 1
            this.engine.StartFlasks()
            this.engine.FlaskLoop()
        } else {
            this.isFlaskActive := false
            this.ui.chkFlask.Value := 0
            this.engine.StopFlasks()
        }

        ; Ensure Auto Loot remains enabled and running during recovery if Auto Void is active
        if this.isAutoVoid || this.memLoot {
            this.isAutoLooting := true
            this.ui.chkLoot.Value := 1
            this.engine.StartLoot()
        } else {
            this.isAutoLooting := false
            this.ui.chkLoot.Value := 0
            this.engine.StopLoot()
        }

        if this.memChannel {
            this.isChanneling := true
            this.ui.chkChannel.Value := 1
            SetTimer () => (
                this.isChanneling && !this.IsAnyPaused() && WinActive(Controller.TargetProcess) && (this.engine.HoldChannel(), true)
            ), -200
        } else {
            this.isChanneling := false
            this.ui.chkChannel.Value := 0
            this.engine.ReleaseChannel()
        }

        if this.memVoid {
            this.isAutoVoid := true
            this.ui.chkVoid.Value := 1
            this.color.StartVoidCheck()
        } else {
            this.isAutoVoid := false
            this.ui.chkVoid.Value := 0
            this.color.StopVoidCheck()
        }

        this.UpdateStatus("Automation Restored")
    }

    ; --------------------------------------------------------------------------
    ; Hotkeys
    ; --------------------------------------------------------------------------
    RegisterHotkeys() {
        try Hotkey(this.cfg.Key_ToggleSpam, "Off")
        try Hotkey(this.cfg.Key_ToggleFlasks, "Off")
        try Hotkey(this.cfg.Key_ToggleLoot, "Off")
        try Hotkey(this.cfg.Key_ToggleChannel, "Off")
        try Hotkey(this.cfg.Key_MasterPause, "Off")
        try Hotkey(this.cfg.Key_Shop, "Off")
        try Hotkey("F12", "Off")

        HotIf (*) => WinActive(Controller.TargetProcess) && (A_TickCount >= this.ColorGuardHibernationEnd)
        Hotkey(this.cfg.Key_ToggleSpam, (*) => this.ToggleSpam())
        Hotkey(this.cfg.Key_ToggleFlasks, (*) => this.ToggleFlasks())
        Hotkey(this.cfg.Key_ToggleLoot, (*) => this.ToggleLoot())
        Hotkey(this.cfg.Key_ToggleChannel, (*) => this.ToggleChannel())
        Hotkey(this.cfg.Key_MasterPause, (*) => this.ToggleMasterPause())
        HotIf

        HotIf (*) => WinActive(Controller.TargetProcess)
        Hotkey(this.cfg.Key_Shop, (*) => this.ToggleShopPause())
        HotIf

        Hotkey("F12", (*) => this.color.PickColorCoord())
    }

    ; --------------------------------------------------------------------------
    ; Helpers
    ; --------------------------------------------------------------------------
    ; Three-sample Central Limit Theorem approximation of a normal distribution,
    ; giving a natural bell curve of intervals rather than a flat range.
    static RandomGaussian(minVal, maxVal) {
        rand := (Random(minVal, maxVal) + Random(minVal, maxVal) + Random(minVal, maxVal)) / 3
        return Integer(rand)
    }

    ; --------------------------------------------------------------------------
    ; Activity log (opt-in via [Settings] EnableLog=1)
    ; --------------------------------------------------------------------------
    Log(event) {
        if !this.cfg.EnableLog
            return
        try {
            FileAppend FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") "  " event "`n", this.LogPath()
        }
    }

    LogPath() {
        base := A_AppData "\TorchlightInfinite"
        try DirCreate base
        return base "\activity.log"
    }

    ; --------------------------------------------------------------------------
    ; Hotkey conflict validation (called before applying settings)
    ; Returns an error message, or "" if everything is valid.
    ; --------------------------------------------------------------------------
    ValidateHotkeys() {
        cfg := this.cfg
        toggles := [cfg.Key_ToggleSpam, cfg.Key_ToggleFlasks, cfg.Key_ToggleLoot, cfg.Key_ToggleChannel,
            cfg.Key_MasterPause, cfg.Key_Shop]

        seen := Map()
        for key in toggles {
            k := StrLower(Trim(key))
            if (k = "" || k = "off")
                return "Hotkey '" key "' is not a valid binding."
            if seen.Has(k)
                return "Duplicate hotkey: " key
            seen[k] := true
        }

        for key in toggles {
            if (StrLower(Trim(key)) = "f12")
                return "F12 is reserved for the color picker."
        }

        sendKeys := [cfg.Key_Skill, cfg.Key_Loot, cfg.Key_Channel, cfg.Key_Flask1, cfg.Key_Flask2, cfg.Key_Flask3]
        for key in sendKeys {
            k := StrLower(Trim(key))
            if (k != "" && seen.Has(k))
                return "Action key '" key "' conflicts with a toggle hotkey."
        }

        return ""
    }
}
