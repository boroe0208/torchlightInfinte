#Requires AutoHotkey v2.0

; ==============================================================================
; TORCHLIGHT: INFINITE AUTOMATION SUITE (v2 - MODULAR REBUILD)
; ==============================================================================
; Same functionality as the original stable script, restructured into focused
; modules under src/. See README.md and docs/capabilities.md.
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

if !A_IsAdmin && !hasNoAdminFlag {
    try {
        if A_IsCompiled
            Run "*RunAs `"" A_ScriptFullPath "`""
        else
            Run "*RunAs `"" A_AhkPath "`" `"" A_ScriptFullPath "`""
    }
    ExitApp
}

; ------------------------------------------------------------------------------
; 2. MODULES
; ------------------------------------------------------------------------------
#Include "src\Config.ahk"
#Include "src\AutomationEngine.ahk"
#Include "src\ColorGuard.ahk"
#Include "src\WindowMonitor.ahk"
#Include "src\UI.ahk"
#Include "src\Controller.ahk"

; Target Application Group Definition
GroupAdd "TLI_Target", "ahk_exe TorchlightInfinite.exe"
GroupAdd "TLI_Target", "Torchlight: Infinite"
GroupAdd "TLI_Target", "Torchlight Infinite Test Harness"

; ------------------------------------------------------------------------------
; 3. BOOT
; ------------------------------------------------------------------------------
global App := Controller()

; ------------------------------------------------------------------------------
; 4. GLOBAL HOTKEYS (game-scoped)
; ------------------------------------------------------------------------------
#HotIf WinActive(Controller.TargetProcess)
~Esc:: {
    if App.isShopPaused {
        App.ColorGuardHibernationEnd := A_TickCount + App.cfg.ShopPauseDelay
        App.isShopPaused := false
        Sleep 100
        App.RestoreState()
        App.UpdateStatus("Resumed (Shop Closed)")
    }
}

End:: {
    App.ui.SavePosition()
    Reload()
}
