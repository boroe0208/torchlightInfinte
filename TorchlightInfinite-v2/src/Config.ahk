#Requires AutoHotkey v2.0

; ==============================================================================
; Config.ahk - Single source of truth for all script settings.
;
; Owns the defaults and loads/saves settings.ini. Every other module
; reads/writes through this class so nothing else touches the INI file
; directly.
; ==============================================================================

; Resolves where settings.ini lives. Windows INI APIs (IniRead/IniWrite) fail
; on UNC paths (e.g. \\wsl.localhost\... when the script runs from the WSL
; mount), so when the script directory is a UNC path we fall back to a stable
; drive-letter location under the user's AppData instead.
ResolveIniFile() {
    dir := A_ScriptDir
    if (SubStr(dir, 1, 2) != "\\")
        return dir "\settings.ini"
    base := A_AppData "\TorchlightInfinite"
    try DirCreate base
    return base "\settings.ini"
}

class Config {
    static IniFile := ResolveIniFile()

    ; --------------------------------------------------------------------------
    ; [Settings]
    ; --------------------------------------------------------------------------
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
    EnableLog := 0

    ; --------------------------------------------------------------------------
    ; [ToggleState] - remembered automation toggle states, restored on launch
    ; Auto Loot and Auto Channel start enabled by default.
    ; --------------------------------------------------------------------------
    ToggleSpamOn := 0
    ToggleFlasksOn := 0
    ToggleLootOn := 1
    ToggleChannelOn := 1

    ; --------------------------------------------------------------------------
    ; [KeyBindings]
    ; --------------------------------------------------------------------------
    Key_Skill := "r"
    Key_Loot := "a"
    Key_Channel := "e"
    Key_Shop := "RCtrl"
    Key_Flask1 := "F6"
    Key_Flask2 := "F7"
    Key_Flask3 := "F8"
    Key_ToggleSpam := "F1"
    Key_ToggleFlasks := "F2"
    Key_ToggleLoot := "F3"
    Key_ToggleChannel := "F5"
    Key_MasterPause := "F4"

    ; --------------------------------------------------------------------------
    ; [ColorGuard]
    ; --------------------------------------------------------------------------
    ColorGuardEnabled := 0
    CheckInterval := 100
    PauseStability := 2
    ResumeStability := 2
    MinPauseMs := 300
    TargetX := 0
    TargetY := 0
    TargetColor := "0x000000"
    ColorVariance := 15

    ; --------------------------------------------------------------------------
    ; [GUI]
    ; --------------------------------------------------------------------------
    GuiX := 50
    GuiY := 150

    ; --------------------------------------------------------------------------
    ; Loading
    ; --------------------------------------------------------------------------
    Load() {
        this.MigrateLegacyIni()
        if !FileExist(Config.IniFile)
            return

        try {
            ; [Settings]
            this.SpamIntervalMin := this.ReadInt("Settings", "SpamIntervalMin", this.SpamIntervalMin)
            this.SpamIntervalMax := this.ReadInt("Settings", "SpamIntervalMax", this.SpamIntervalMax)
            this.FlaskLoopInterval := this.ReadInt("Settings", "FlaskLoopInterval", this.FlaskLoopInterval)
            this.FlaskKeyDelayMin := this.ReadInt("Settings", "FlaskKeyDelayMin", this.FlaskKeyDelayMin)
            this.FlaskKeyDelayMax := this.ReadInt("Settings", "FlaskKeyDelayMax", this.FlaskKeyDelayMax)
            this.LootLoopInterval := this.ReadInt("Settings", "LootLoopInterval", this.LootLoopInterval)
            this.ShopPauseDelay := this.ReadInt("Settings", "ShopPauseDelay", this.ShopPauseDelay)
            this.KeyHoldMin := this.ReadInt("Settings", "KeyHoldMin", this.KeyHoldMin)
            this.KeyHoldMax := this.ReadInt("Settings", "KeyHoldMax", this.KeyHoldMax)
            this.DefaultMouseSpeed := this.ReadInt("Settings", "DefaultMouseSpeed", this.DefaultMouseSpeed)
            this.EnableLog := this.ReadInt("Settings", "EnableLog", this.EnableLog)

            ; [ToggleState]
            this.ToggleSpamOn := this.ReadInt("ToggleState", "Spam", this.ToggleSpamOn)
            this.ToggleFlasksOn := this.ReadInt("ToggleState", "Flasks", this.ToggleFlasksOn)
            this.ToggleLootOn := this.ReadInt("ToggleState", "Loot", this.ToggleLootOn)
            this.ToggleChannelOn := this.ReadInt("ToggleState", "Channel", this.ToggleChannelOn)

            ; [KeyBindings]
            this.Key_Skill := this.ReadStr("KeyBindings", "Key_Skill", this.Key_Skill)
            this.Key_Loot := this.ReadStr("KeyBindings", "Key_Loot", this.Key_Loot)
            this.Key_Channel := this.ReadStr("KeyBindings", "Key_Channel", this.Key_Channel)
            this.Key_Shop := this.ReadStr("KeyBindings", "Key_Shop", this.Key_Shop)
            this.Key_Flask1 := this.ReadStr("KeyBindings", "Key_Flask1", this.Key_Flask1)
            this.Key_Flask2 := this.ReadStr("KeyBindings", "Key_Flask2", this.Key_Flask2)
            this.Key_Flask3 := this.ReadStr("KeyBindings", "Key_Flask3", this.Key_Flask3)
            this.Key_ToggleSpam := this.ReadStr("KeyBindings", "Key_ToggleSpam", this.Key_ToggleSpam)
            this.Key_ToggleFlasks := this.ReadStr("KeyBindings", "Key_ToggleFlasks", this.Key_ToggleFlasks)
            this.Key_ToggleLoot := this.ReadStr("KeyBindings", "Key_ToggleLoot", this.Key_ToggleLoot)
            this.Key_ToggleChannel := this.ReadStr("KeyBindings", "Key_ToggleChannel", this.Key_ToggleChannel)
            this.Key_MasterPause := this.ReadStr("KeyBindings", "Key_MasterPause", this.Key_MasterPause)

            ; [ColorGuard]
            this.ColorGuardEnabled := this.ReadInt("ColorGuard", "Enabled", this.ColorGuardEnabled)
            this.CheckInterval := this.ReadInt("ColorGuard", "CheckInterval", this.CheckInterval)
            this.PauseStability := this.ReadInt("ColorGuard", "PauseStability", this.PauseStability)
            this.ResumeStability := this.ReadInt("ColorGuard", "ResumeStability", this.ResumeStability)
            this.MinPauseMs := this.ReadInt("ColorGuard", "MinPauseMs", this.MinPauseMs)
            this.TargetX := this.ReadInt("ColorGuard", "TargetX", this.TargetX)
            this.TargetY := this.ReadInt("ColorGuard", "TargetY", this.TargetY)
            this.TargetColor := this.ReadStr("ColorGuard", "TargetColor", this.TargetColor)
            this.ColorVariance := this.ReadInt("ColorGuard", "ColorVariance", this.ColorVariance)

            ; [GUI]
            this.GuiX := this.ReadInt("GUI", "X", this.GuiX)
            this.GuiY := this.ReadInt("GUI", "Y", this.GuiY)

            this.Validate()
        }
    }

    ; If the INI location moved (e.g. to AppData for UNC/WSL mounts), copy the
    ; previous script-directory settings.ini over so existing config is kept.
    MigrateLegacyIni() {
        if FileExist(Config.IniFile)
            return
        legacy := A_ScriptDir "\settings.ini"
        if (legacy = Config.IniFile)
            return
        if FileExist(legacy) {
            try FileCopy legacy, Config.IniFile
        }
    }

    ; --------------------------------------------------------------------------
    ; Saving
    ; --------------------------------------------------------------------------
    Save() {
        try {
            ; [Settings]
            IniWrite(this.SpamIntervalMin, Config.IniFile, "Settings", "SpamIntervalMin")
            IniWrite(this.SpamIntervalMax, Config.IniFile, "Settings", "SpamIntervalMax")
            IniWrite(this.FlaskLoopInterval, Config.IniFile, "Settings", "FlaskLoopInterval")
            IniWrite(this.FlaskKeyDelayMin, Config.IniFile, "Settings", "FlaskKeyDelayMin")
            IniWrite(this.FlaskKeyDelayMax, Config.IniFile, "Settings", "FlaskKeyDelayMax")
            IniWrite(this.LootLoopInterval, Config.IniFile, "Settings", "LootLoopInterval")
            IniWrite(this.ShopPauseDelay, Config.IniFile, "Settings", "ShopPauseDelay")
            IniWrite(this.KeyHoldMin, Config.IniFile, "Settings", "KeyHoldMin")
            IniWrite(this.KeyHoldMax, Config.IniFile, "Settings", "KeyHoldMax")
            IniWrite(this.DefaultMouseSpeed, Config.IniFile, "Settings", "DefaultMouseSpeed")
            IniWrite(this.EnableLog, Config.IniFile, "Settings", "EnableLog")

            ; [ToggleState]
            IniWrite(this.ToggleSpamOn, Config.IniFile, "ToggleState", "Spam")
            IniWrite(this.ToggleFlasksOn, Config.IniFile, "ToggleState", "Flasks")
            IniWrite(this.ToggleLootOn, Config.IniFile, "ToggleState", "Loot")
            IniWrite(this.ToggleChannelOn, Config.IniFile, "ToggleState", "Channel")

            ; [KeyBindings]
            IniWrite(this.Key_Skill, Config.IniFile, "KeyBindings", "Key_Skill")
            IniWrite(this.Key_Loot, Config.IniFile, "KeyBindings", "Key_Loot")
            IniWrite(this.Key_Channel, Config.IniFile, "KeyBindings", "Key_Channel")
            IniWrite(this.Key_Shop, Config.IniFile, "KeyBindings", "Key_Shop")
            IniWrite(this.Key_Flask1, Config.IniFile, "KeyBindings", "Key_Flask1")
            IniWrite(this.Key_Flask2, Config.IniFile, "KeyBindings", "Key_Flask2")
            IniWrite(this.Key_Flask3, Config.IniFile, "KeyBindings", "Key_Flask3")
            IniWrite(this.Key_ToggleSpam, Config.IniFile, "KeyBindings", "Key_ToggleSpam")
            IniWrite(this.Key_ToggleFlasks, Config.IniFile, "KeyBindings", "Key_ToggleFlasks")
            IniWrite(this.Key_ToggleLoot, Config.IniFile, "KeyBindings", "Key_ToggleLoot")
            IniWrite(this.Key_ToggleChannel, Config.IniFile, "KeyBindings", "Key_ToggleChannel")
            IniWrite(this.Key_MasterPause, Config.IniFile, "KeyBindings", "Key_MasterPause")

            ; [ColorGuard]
            IniWrite(this.ColorGuardEnabled, Config.IniFile, "ColorGuard", "Enabled")
            IniWrite(this.CheckInterval, Config.IniFile, "ColorGuard", "CheckInterval")
            IniWrite(this.PauseStability, Config.IniFile, "ColorGuard", "PauseStability")
            IniWrite(this.ResumeStability, Config.IniFile, "ColorGuard", "ResumeStability")
            IniWrite(this.MinPauseMs, Config.IniFile, "ColorGuard", "MinPauseMs")
            IniWrite(this.TargetX, Config.IniFile, "ColorGuard", "TargetX")
            IniWrite(this.TargetY, Config.IniFile, "ColorGuard", "TargetY")
            IniWrite(this.TargetColor, Config.IniFile, "ColorGuard", "TargetColor")
            IniWrite(this.ColorVariance, Config.IniFile, "ColorGuard", "ColorVariance")

            ; [GUI]
            IniWrite(this.GuiX, Config.IniFile, "GUI", "X")
            IniWrite(this.GuiY, Config.IniFile, "GUI", "Y")
        }
    }

    ; --------------------------------------------------------------------------
    ; Validation
    ; --------------------------------------------------------------------------
    ; Normalizes numeric values so inverted/out-of-range input can never produce
    ; broken behavior or a thrown error at runtime.
    Validate() {
        ; min/max pairs: enforce ordering then floor
        this.NormalizePair(this, "SpamIntervalMin", "SpamIntervalMax", 10)
        this.NormalizePair(this, "FlaskKeyDelayMin", "FlaskKeyDelayMax", 1)
        this.NormalizePair(this, "KeyHoldMin", "KeyHoldMax", 1)

        this.FlaskLoopInterval := Max(100, this.FlaskLoopInterval)
        this.LootLoopInterval := Max(30, this.LootLoopInterval)
        this.ShopPauseDelay := Max(0, this.ShopPauseDelay)
        this.DefaultMouseSpeed := Min(Max(0, this.DefaultMouseSpeed), 100)

        this.CheckInterval := Max(50, this.CheckInterval)
        this.PauseStability := Max(1, this.PauseStability)
        this.ResumeStability := Max(1, this.ResumeStability)
        this.MinPauseMs := Max(0, this.MinPauseMs)
        this.ColorVariance := Max(0, this.ColorVariance)
        this.TargetX := Max(0, this.TargetX)
        this.TargetY := Max(0, this.TargetY)

        this.GuiX := Max(0, this.GuiX)
        this.GuiY := Max(0, this.GuiY)

        this.EnableLog := Min(Max(0, this.EnableLog), 1)

        ; toggles are booleans (0/1)
        this.ToggleSpamOn := Min(Max(0, this.ToggleSpamOn), 1)
        this.ToggleFlasksOn := Min(Max(0, this.ToggleFlasksOn), 1)
        this.ToggleLootOn := Min(Max(0, this.ToggleLootOn), 1)
        this.ToggleChannelOn := Min(Max(0, this.ToggleChannelOn), 1)
    }

    ; Orders a min/max property pair (swapping inverted input), then floors
    ; both values so a broken pair can never reach runtime. Property names are
    ; passed as strings because v2 only allows byref on plain variables.
    NormalizePair(obj, loName, hiName, floor) {
        lo := obj.%loName%
        hi := obj.%hiName%
        if (lo > hi) {
            t := lo
            lo := hi
            hi := t
        }
        obj.%loName% := Max(floor, lo)
        obj.%hiName% := Max(floor, hi)
    }

    ; --------------------------------------------------------------------------
    ; Typed read helpers
    ; --------------------------------------------------------------------------
    ReadInt(section, key, def) {
        return Integer(IniRead(Config.IniFile, section, key, def))
    }

    ReadStr(section, key, def) {
        return IniRead(Config.IniFile, section, key, def)
    }
}
