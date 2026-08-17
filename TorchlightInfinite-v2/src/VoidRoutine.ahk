#Requires AutoHotkey v2.0

; ==============================================================================
; VoidRoutine.ahk - Executes the Auto Void click/key sequence.
;
; The sequence is fully data-driven from the [AutoVoidRoutine] Steps value in
; settings.ini instead of being hardcoded in source, so it can be tuned per
; screen/resolution without touching code. Parsed once at startup.
; ==============================================================================

class VoidRoutine {
    __New(app) {
        this.App := app
        this.ParseSteps()
    }

    ; --------------------------------------------------------------------------
    ; Parsing
    ; --------------------------------------------------------------------------
    ParseSteps() {
        this.Steps := []
        encoded := this.App.cfg.VoidRoutineSteps
        encoded := StrReplace(StrReplace(encoded, "`r", ""), "`n", "")
        if (encoded = "")
            return

        for token in StrSplit(encoded, "|") {
            token := Trim(token)
            if (token = "")
                continue

            parts := StrSplit(token, ":")
            action := StrLower(parts[1])

            switch action {
                case "sleep":
                    this.Steps.Push({ action: "sleep", ms: Integer(Trim(parts[2])) })
                case "move":
                    coords := StrSplit(parts[2], ",")
                    speed := (coords.Length > 2 && Trim(coords[3]) != "")
                        ? Integer(Trim(coords[3]))
                        : this.App.cfg.DefaultMouseSpeed
                    this.Steps.Push({
                        action: "move",
                        x: Integer(Trim(coords[1])),
                        y: Integer(Trim(coords[2])),
                        speed: speed
                    })
                case "click":
                    button := (parts.Length > 1 && Trim(parts[2]) != "") ? parts[2] : "Left"
                    hold := this.ParseHoldRange(parts.Length > 2 ? parts[3] : "")
                    this.Steps.Push({ action: "click", button: button, holdMin: hold[1], holdMax: hold[2] })
                case "key":
                    hold := this.ParseHoldRange(parts.Length > 2 ? parts[3] : "")
                    this.Steps.Push({ action: "key", key: parts[2], holdMin: hold[1], holdMax: hold[2] })
                case "send":
                    this.Steps.Push({ action: "send", text: parts[2] })
            }
        }
    }

    ; Parse an optional "HoldMin-HoldMax" suffix, defaulting to the configured
    ; KeyHold bounds when absent.
    ParseHoldRange(raw) {
        holdMin := this.App.cfg.KeyHoldMin
        holdMax := this.App.cfg.KeyHoldMax
        if (raw != "") {
            range := StrSplit(raw, "-")
            holdMin := Integer(Trim(range[1]))
            holdMax := (range.Length > 1) ? Integer(Trim(range[2])) : holdMin
        }
        return [holdMin, holdMax]
    }

    ; Returns an error message for the first malformed/unknown step, or "" if the
    ; Steps value parses cleanly. Used to validate before applying settings.
    ValidateSteps() {
        encoded := this.App.cfg.VoidRoutineSteps
        encoded := StrReplace(StrReplace(encoded, "`r", ""), "`n", "")
        if (encoded = "")
            return "Steps are empty."

        idx := 0
        for token in StrSplit(encoded, "|") {
            idx++
            token := Trim(token)
            if (token = "")
                continue

            parts := StrSplit(token, ":")
            action := StrLower(parts[1])
            switch action {
                case "sleep":
                    if parts.Length < 2 || !IsNumber(Trim(parts[2]))
                        return "Step " idx ": bad sleep value '" token "'"
                case "move":
                    if parts.Length < 2
                        return "Step " idx ": missing coords '" token "'"
                    coords := StrSplit(parts[2], ",")
                    if coords.Length < 2 || !IsNumber(Trim(coords[1])) || !IsNumber(Trim(coords[2]))
                        return "Step " idx ": bad move coords '" token "'"
                case "click":
                    ; optional Button[,HoldMin-HoldMax] - structure is permissive
                case "key":
                    if parts.Length < 2 || Trim(parts[2]) = ""
                        return "Step " idx ": missing key name '" token "'"
                case "send":
                    if parts.Length < 2
                        return "Step " idx ": missing text '" token "'"
                default:
                    return "Step " idx ": unknown action '" action "'"
            }
        }
        return ""
    }

    ; --------------------------------------------------------------------------
    ; Execution
    ; --------------------------------------------------------------------------
    Execute() {
        app := this.App
        if !WinActive(Controller.TargetProcess)
            return

        app.Log("Auto Void run started")

        for step in this.Steps {
            ; Abort safely if a pause or focus loss happens mid-sequence so we
            ; never keep sending input while paused or leave keys/buttons held.
            if app.IsAnyPaused() || !WinActive(Controller.TargetProcess) {
                app.ReleaseAllKeys()
                app.UpdateStatus("Void Interrupted (Paused)")
                app.Log("Auto Void interrupted (paused)")
                return
            }

            switch step.action {
                case "sleep":
                    Sleep step.ms
                case "move":
                    MouseMove step.x, step.y, step.speed
                case "click":
                    Click(step.button " Down")
                    Sleep Random(step.holdMin, step.holdMax)
                    Click(step.button " Up")
                case "key":
                    app.engine.SendHuman(step.key, step.holdMin, step.holdMax)
                case "send":
                    Send step.text
            }
        }

        app.UpdateStatus("Auto Void Active")
        app.Log("Auto Void complete")
    }
}
