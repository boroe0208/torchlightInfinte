#Requires AutoHotkey v2.0

; Press Ctrl + G while in your Stash or Map Device to run the search
^g::
{
    ; The search string for 80+ monsters and multiple uniques
    ; Uses 'r' for regex, captures 80-99 or 100+, and checks for multiple entries
    searchString := "r`"monsters: .+: .+ ([8-9]\d|[1-9]\d{2,})`""

    ; Set the clipboard to our search string
    A_Clipboard := searchString

    ; Brief sleep to ensure clipboard is ready
    Sleep(50)

    ; Send the commands to PoE
    ; Ctrl+F opens the search bar, Ctrl+A + Backspace clears it, Ctrl+V pastes
    Send("^f")
    Sleep(50)
    Send("^a{Backspace}")
    Sleep(50)
    Send("^v")
    Send("{Enter}")
}
