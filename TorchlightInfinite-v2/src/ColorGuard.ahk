#Requires AutoHotkey v2.0

; ==============================================================================
; ColorGuard.ahk - Pixel color monitoring that auto-pauses automation.
;
;  * 5x5 sub-sampling of the target pixel to avoid noise/particle false alarms
;  * Max-channel color distance comparison against a configurable variance
;  * Auto-recovery when the monitored color returns
;  * Interactive color picker (F12 / Pick buttons)
;  * The Auto Void color checker lives here too, since it is a color monitor;
;    it hands execution off to the VoidRoutine module.
; ==============================================================================

class ColorGuard {
    ; Debounce state: consecutive deviant/matched samples and the pause timestamp
    ColorHitStreak := 0
    ColorClearStreak := 0
    ColorPausedAt := 0

    __New(app) {
        this.App := app
        this.fnColorCheck := ObjBindMethod(this, "ColorCheckLoop")
        this.fnVoidCheck := ObjBindMethod(this, "VoidColorCheckLoop")
    }

    ; --------------------------------------------------------------------------
    ; Color guard enable/disable
    ; --------------------------------------------------------------------------
    ToggleColorGuard(fromGui := false) {
        if fromGui
            this.App.cfg.ColorGuardEnabled := this.App.ui.chkColorGuard.Value

        if this.App.cfg.ColorGuardEnabled {
            this.ColorHitStreak := 0
            this.ColorClearStreak := 0
            this.App.UpdateStatus("Monitoring: ON")
            this.App.Log("Color Guard ON")
            this.ColorCheckLoop()
            SetTimer this.fnColorCheck, Max(50, this.App.cfg.CheckInterval)
        } else {
            this.ColorHitStreak := 0
            this.ColorClearStreak := 0
            this.App.Log("Color Guard OFF")
            if this.App.isColorPaused {
                this.App.isColorPaused := false
                this.App.RestoreState()
            }
            this.App.UpdateStatus("Monitoring: OFF")
            SetTimer this.fnColorCheck, 0
        }
    }

    ; --------------------------------------------------------------------------
    ; Monitoring loop
    ; --------------------------------------------------------------------------
    ColorCheckLoop() {
        cfg := this.App.cfg
        if !cfg.ColorGuardEnabled || this.App.isMasterPaused || (A_TickCount < this.App.ColorGuardHibernationEnd)
            return

        try {
            currAvgColor := this.GetAverageColor(cfg.TargetX, cfg.TargetY, 5)
            diff := this.ColorDistanceInt(currAvgColor, Integer(cfg.TargetColor))

            if (diff > cfg.ColorVariance) {
                ; Deviant: only pause after PauseStability consecutive samples,
                ; so a single transient frame cannot trigger a false pause.
                this.ColorClearStreak := 0
                this.ColorHitStreak++
                if (this.ColorHitStreak >= cfg.PauseStability) {
                    if !this.App.isColorPaused {
                        this.App.StopAutomation(true, true)
                        this.App.isColorPaused := true
                        this.ColorPausedAt := A_TickCount
                        this.App.UpdateStatus("Color Guard: PAUSED")
                        this.App.Log("Color Guard PAUSED")
                    }
                }
            } else {
                ; Matched: only resume after ResumeStability consecutive samples
                ; and after the minimum pause duration has elapsed.
                this.ColorHitStreak := 0
                this.ColorClearStreak++
                minPauseOk := (this.ColorPausedAt = 0) || ((A_TickCount - this.ColorPausedAt) >= cfg.MinPauseMs)
                if (this.ColorClearStreak >= cfg.ResumeStability && minPauseOk) {
                    isStateChanged := false
                    if this.App.isColorPaused {
                        this.App.isColorPaused := false
                        this.ColorPausedAt := 0
                        isStateChanged := true
                    }
                    if this.App.isShopPaused {
                        this.App.isShopPaused := false
                        isStateChanged := true
                    }
                    if isStateChanged {
                        this.App.RestoreState()
                        this.App.UpdateStatus("Resumed (HUD Detected)")
                        this.App.Log("Color Guard RESUME")
                    }
                }
            }
        } catch {
            ; A transient capture failure or a malformed TargetColor must not
            ; throw an error dialog on every timer tick; skip this sample.
        }
    }

    ; --------------------------------------------------------------------------
    ; Interactive color picker
    ; --------------------------------------------------------------------------
    PickColorCoord(isVoid := false) {
        this.App.UpdateStatus("Click Target Point...")
        Tooltip "LEFT-CLICK on the point/color you want to monitor`nPress ESC to cancel."

        KeyWait "LButton"

        loop {
            if GetKeyState("LButton", "P") {
                MouseGetPos(&mX, &mY)
                mColor := this.GetAverageColor(mX, mY, 5)

                if isVoid {
                    this.App.cfg.VoidTargetX := mX
                    this.App.cfg.VoidTargetY := mY
                    this.App.cfg.VoidTargetColor := Format("0x{:06X}", mColor)
                    this.App.UpdateStatus("Void Point Picked!")
                } else {
                    this.App.cfg.TargetX := mX
                    this.App.cfg.TargetY := mY
                    this.App.cfg.TargetColor := Format("0x{:06X}", mColor)
                    this.App.UpdateStatus("Point Picked!")
                }

                this.App.cfg.Save()
                this.App.ui.SyncFromConfig()
                break
            }

            if GetKeyState("Esc", "P") {
                this.App.UpdateStatus("Pick Cancelled")
                break
            }

            Sleep 50
        }

        Tooltip()
        Sleep 200
    }

    ; --------------------------------------------------------------------------
    ; Auto Void color checker
    ; --------------------------------------------------------------------------
    StartVoidCheck() {
        ; Periodic (not self-re-armed): the timer keeps firing even when a
        ; paused run early-returns, so the check cannot die permanently after
        ; a pause/resume cycle.
        SetTimer this.fnVoidCheck, this.App.cfg.VoidCheckInterval
    }

    StopVoidCheck() {
        SetTimer this.fnVoidCheck, 0
    }

    VoidColorCheckLoop() {
        cfg := this.App.cfg
        if !this.App.isAutoVoid || this.App.IsAnyPaused(true) || (A_TickCount < this.App.ColorGuardHibernationEnd)
            return

        try {
            currAvgColor := this.GetAverageColor(cfg.VoidTargetX, cfg.VoidTargetY, 5)
            if (this.ColorDistanceInt(currAvgColor, Integer(cfg.VoidTargetColor)) <= cfg.VoidColorVariance)
                this.App.void.Execute()
        } catch {
            ; Same transient-failure guard as the color check loop.
        }
    }

    ; --------------------------------------------------------------------------
    ; Color sampling helpers
    ; --------------------------------------------------------------------------
    ; Averages the size x size region around (cX, cY). Client coords are
    ; translated to screen space via the active window's client origin, then
    ; the whole region is captured with one BitBlt grab (instead of size^2
    ; individual PixelGetColor calls) and averaged in memory.
    ; Returns a packed 0xRRGGBB integer, or 0 when the coordinate is invalid.
    GetAverageColor(cX, cY, size := 5) {
        if (cX <= 0 || cY <= 0)
            return 0

        ; WinGetClientPos always returns screen coords; on failure the outputs
        ; come back empty, so treat that as a (0,0) client origin.
        WinGetClientPos(&winX, &winY, , , "A")
        sx := cX + (IsNumber(winX) ? winX : 0)
        sy := cY + (IsNumber(winY) ? winY : 0)

        try return this.GrabAverageColor(sx, sy, size)
        return this.GetAverageColorSlow(cX, cY, size)
    }

    ; One-shot GDI screen grab of the region; throws on any capture failure so
    ; the caller can fall back to per-pixel reads.
    GrabAverageColor(sx, sy, size) {
        offset := size // 2
        left := sx - offset
        top := sy - offset

        hDC := DllCall("GetDC", "ptr", 0, "ptr")
        if !hDC
            throw Error("GetDC failed")
        hMem := 0
        hBmp := 0
        hOld := 0
        try {
            hMem := DllCall("CreateCompatibleDC", "ptr", hDC, "ptr")
            hBmp := DllCall("CreateCompatibleBitmap", "ptr", hDC, "int", size, "int", size, "ptr")
            if !hMem || !hBmp
                throw Error("CreateCompatible failed")
            hOld := DllCall("SelectObject", "ptr", hMem, "ptr", hBmp, "ptr")
            if !DllCall("BitBlt", "ptr", hMem, "int", 0, "int", 0, "int", size, "int", size,
                    "ptr", hDC, "int", left, "int", top, "uint", 0x00CC0020)  ; SRCCOPY
                throw Error("BitBlt failed")

            ; 32bpp top-down DIB: 4 bytes per pixel, byte order B, G, R, X
            bmi := Buffer(40)
            NumPut("uint", 40, bmi, 0)      ; biSize
            NumPut("int", size, bmi, 4)     ; biWidth
            NumPut("int", -size, bmi, 8)    ; biHeight (negative = top-down)
            NumPut("ushort", 1, bmi, 12)    ; biPlanes
            NumPut("ushort", 32, bmi, 14)   ; biBitCount
            NumPut("uint", 0, bmi, 16)      ; biCompression = BI_RGB

            pixels := Buffer(size * size * 4)
            if !DllCall("gdi32\GetDIBits", "ptr", hMem, "ptr", hBmp, "uint", 0, "uint", size,
                    "ptr", pixels, "ptr", bmi, "uint", 0)
                throw Error("GetDIBits failed")

            totalR := 0
            totalG := 0
            totalB := 0
            loop size * size {
                off := (A_Index - 1) * 4
                totalB += NumGet(pixels, off, "uchar")
                totalG += NumGet(pixels, off + 1, "uchar")
                totalR += NumGet(pixels, off + 2, "uchar")
            }
            count := size * size
            return ((totalR // count) << 16) | ((totalG // count) << 8) | (totalB // count)
        } finally {
            ; Restore the original bitmap before deleting, so DeleteObject
            ; cannot fail on a bitmap still selected into the DC.
            try DllCall("SelectObject", "ptr", hMem, "ptr", hOld)
            try DllCall("DeleteObject", "ptr", hBmp)
            try DllCall("DeleteDC", "ptr", hMem)
            try DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)
        }
    }

    ; Per-pixel fallback (original behavior), returning a packed 0xRRGGBB int.
    GetAverageColorSlow(cX, cY, size) {
        offset := size // 2
        totalR := 0
        totalG := 0
        totalB := 0
        count := 0

        loop size {
            dx := A_Index - 1 - offset
            loop size {
                dy := A_Index - 1 - offset
                px := cX + dx
                py := cY + dy
                if (px > 0 && py > 0) {
                    try {
                        num := Integer(PixelGetColor(px, py, "RGB"))
                        totalR += (num >> 16) & 0xFF
                        totalG += (num >> 8) & 0xFF
                        totalB += num & 0xFF
                        count++
                    }
                }
            }
        }

        if (count == 0)
            return 0
        return ((totalR // count) << 16) | ((totalG // count) << 8) | (totalB // count)
    }

    ; Max-channel color distance between two packed 0xRRGGBB integers.
    ColorDistanceInt(n1, n2) {
        diffR := Abs(((n1 >> 16) & 0xFF) - ((n2 >> 16) & 0xFF))
        diffG := Abs(((n1 >> 8) & 0xFF) - ((n2 >> 8) & 0xFF))
        diffB := Abs((n1 & 0xFF) - (n2 & 0xFF))
        return Max(diffR, diffG, diffB)
    }
}
