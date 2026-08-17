#Requires AutoHotkey v2.0

; ==============================================================================
; AutomationEngine.ahk - The input loops: combat spam, flask cycle, auto loot,
; channel hold, humanized key presses and the Gaussian interval generator.
;
; Loops are driven by single-instance timers bound in the constructor. Each loop
; re-arms itself with a negative (one-shot) timer so behavior matches the
; original script exactly.
; ==============================================================================

class AutomationEngine {
    __New(app) {
        this.App := app
        this.fnSpam := ObjBindMethod(this, "SpamLoop")
        this.fnFlask := ObjBindMethod(this, "FlaskLoop")
        this.fnLoot := ObjBindMethod(this, "LootLoop")
        this.fnChannelReassert := ObjBindMethod(this, "ReassertChannel")
        ; The key actually held for channeling (captured at hold time so a
        ; mid-hold Key_Channel change cannot release the wrong key).
        this.heldChannelKey := ""
    }

    ; --------------------------------------------------------------------------
    ; Timer control
    ; --------------------------------------------------------------------------
    StartSpam() {
        SetTimer this.fnSpam, 10
    }

    StopSpam() {
        SetTimer this.fnSpam, 0
    }

    StartFlasks() {
        SetTimer this.fnFlask, this.App.cfg.FlaskLoopInterval
    }

    StopFlasks() {
        SetTimer this.fnFlask, 0
    }

    StartLoot() {
        SetTimer this.fnLoot, Max(30, this.App.cfg.LootLoopInterval)
    }

    StopLoot() {
        SetTimer this.fnLoot, 0
    }

    ; --------------------------------------------------------------------------
    ; Combat spam loop
    ; --------------------------------------------------------------------------
    SpamLoop() {
        if !this.App.isSpamming || this.App.IsAnyPaused()
            return
        if WinActive(Controller.TargetProcess)
            this.SendHuman(this.App.cfg.Key_Skill)
        nextDelay := Max(10, Controller.RandomGaussian(this.App.cfg.SpamIntervalMin, this.App.cfg.SpamIntervalMax))
        SetTimer this.fnSpam, -nextDelay
    }

    ; --------------------------------------------------------------------------
    ; Flask cycle loop
    ; --------------------------------------------------------------------------
    FlaskLoop() {
        app := this.App
        if !app.isFlaskActive || app.IsAnyPaused() || !WinActive(Controller.TargetProcess)
            return

        this.SendHuman(app.cfg.Key_Flask1)
        Sleep Random(app.cfg.FlaskKeyDelayMin, app.cfg.FlaskKeyDelayMax)
        if !app.isFlaskActive || app.IsAnyPaused() || !WinActive(Controller.TargetProcess)
            return
        this.SendHuman(app.cfg.Key_Flask2)
        Sleep Random(app.cfg.FlaskKeyDelayMin, app.cfg.FlaskKeyDelayMax)
        if !app.isFlaskActive || app.IsAnyPaused() || !WinActive(Controller.TargetProcess)
            return
        this.SendHuman(app.cfg.Key_Flask3)
    }

    ; --------------------------------------------------------------------------
    ; Auto loot loop (with dynamic jitter)
    ; --------------------------------------------------------------------------
    LootLoop() {
        app := this.App
        if !app.isAutoLooting || app.IsAnyPaused()
            return
        if WinActive(Controller.TargetProcess)
            this.SendHuman(app.cfg.Key_Loot)

        baseInt := Max(30, app.cfg.LootLoopInterval)
        minInterval := Max(25, Integer(baseInt * 0.8))
        maxInterval := Max(35, Integer(baseInt * 1.2))
        SetTimer this.fnLoot, -Random(minInterval, maxInterval)
    }

    ; --------------------------------------------------------------------------
    ; Key state registry (sticky-key safety)
    ; --------------------------------------------------------------------------
    ; Every key press is tracked in KeyState so pending releases can be
    ; cancelled, overlapping presses suppressed, and every actually-held key
    ; released reliably on pause or exit. Maps key name -> { down, releaseFn }.
    KeyState := Map()

    ; Press a key and schedule a tracked release after a randomized hold.
    ; If the key is already held, the pending release is cancelled and the hold
    ; restarts instead of sending another "down" (no overlapping down/down).
    PressKey(key, holdMin, holdMax) {
        if this.KeyState.Has(key)
            this.CancelKey(key)

        SendInput "{" key " down}"
        holdTime := Random(holdMin, holdMax)
        releaseFn := ObjBindMethod(this, "ReleaseKeyNow", key)
        this.KeyState[key] := { down: true, releaseFn: releaseFn }
        SetTimer releaseFn, -Max(1, holdTime)
    }

    ; Timer callback: marks the key up and removes it from the registry.
    ReleaseKeyNow(key) {
        if !this.KeyState.Has(key)
            return
        this.KeyState.Delete(key)
        try SendInput "{" key " up}"
    }

    IsKeyDown(key) {
        return this.KeyState.Has(key)
    }

    ; Cancel a pending release without sending input (re-press or cleanup).
    CancelKey(key) {
        if this.KeyState.Has(key) {
            info := this.KeyState[key]
            if info.releaseFn
                SetTimer info.releaseFn, 0
            this.KeyState.Delete(key)
        }
    }

    ; Cancel all pending releases and release every currently held key.
    ReleaseAll() {
        for key in this.KeyState.Clone() {
            this.CancelKey(key)
            try SendInput "{" key " up}"
        }
    }

    ; --------------------------------------------------------------------------
    ; Humanized input simulation
    ; --------------------------------------------------------------------------
    ; Presses a key down and schedules its release after a randomized hold.
    ; Optional explicit hold range overrides the configured KeyHold bounds.
    SendHuman(key, holdMin := 0, holdMax := 0) {
        if holdMin = 0
            holdMin := this.App.cfg.KeyHoldMin
        if holdMax = 0
            holdMax := this.App.cfg.KeyHoldMax

        this.PressKey(key, holdMin, holdMax)
    }

    HoldChannel() {
        channel := this.App.cfg.Key_Channel
        this.heldChannelKey := channel
        if !this.IsKeyDown(channel) {
            SendInput "{" channel " down}"
            this.KeyState[channel] := { down: true, releaseFn: 0 }
        }
        ; Periodically re-assert the hold so the channel self-heals if the game
        ; ever sees a key-up for it (e.g. the user presses/releases the channel
        ; key manually while auto channel is on).
        SetTimer this.fnChannelReassert, 50
    }

    ReleaseChannel() {
        channel := this.heldChannelKey
        if this.IsKeyDown(channel) {
            this.KeyState.Delete(channel)
            try SendInput "{" channel " up}"
        }
        SetTimer this.fnChannelReassert, 0
    }

    ; The game stops channeling whenever it processes a key-up for the channel
    ; key. Our registry never auto-releases it, so the down must be re-sent
    ; whenever the OS key state shows the key is no longer down.
    ReassertChannel() {
        channel := this.heldChannelKey
        if !this.IsKeyDown(channel) {
            SetTimer this.fnChannelReassert, 0
            return
        }
        if !GetKeyState(channel, "P")
            try SendInput "{" channel " down}"
    }
}
