#Requires AutoHotkey v2.0

; ==============================================================================
; WindowMonitor.ahk - Tracks game focus and drives the auto-pause/resume state
; machine.
;
;  * Every 200ms verifies the game window is active
;  * On unfocus: stops all automation and remembers the running state
;  * On refocus: restores the exact automation state that was running
;  * Owns the status dot and the logo background color
; ==============================================================================

class WindowMonitor {
    lastDotColor := ""

    __New(app) {
        this.App := app
        this.fnCheck := ObjBindMethod(this, "CheckWindowActive")
        SetTimer this.fnCheck, 200
        this.CheckWindowActive()
    }

    CheckWindowActive() {
        app := this.App

        if WinActive(Controller.TargetProcess) {
            if app.isFocusPaused {
                app.isFocusPaused := false
                app.RestoreState()
                if !app.IsAnyPaused() {
                    app.UpdateStatus("Resumed (Focused)")
                    app.Log("Focus restored")
                }
            }

            if app.IsAnyPaused()
                this.SetDotColor("F59E0B")
            else
                this.SetDotColor("10B981")
        } else {
            if !app.isFocusPaused {
                app.StopAutomation(true)
                app.isFocusPaused := true
                app.UpdateStatus("Unfocused: PAUSED")
                app.Log("Focus lost - paused")
            }
            this.SetDotColor("EF4444")
        }

    }

    SetDotColor(color) {
        if (color = this.lastDotColor)
            return
        this.lastDotColor := color

        app := this.App
        try app.ui.txtActiveDot.Opt("c" color)
        try app.ui.txtActiveDot.Redraw()
        app.CurrentStatusColor := color
        try app.ui.btnLogo.Opt("Background" color)
        try app.ui.btnLogo.Redraw()
    }

}
