; Generic crosshair overlay v1.0
; By evilc@evilc.com

; Instructions:
; =============
; Will ONLY work in WINDOWED mode
; 1) Run app to overlay crosshair to and make it active
; 2) Hit WIN+Insert to designate that as app to overlay to
; 3) crosshair will appear but probably in wrong place
; 4) Use WIN+Arrow keys to move crosshair to right place

; crosshair will ONLY appear while designated app is active
; Settings saved to INI file so you only have to set up once

; This is NOT a hack, it merely creates a transparent window
; that has "Always on top" property set
; Custom crosshairs can be used, edit ch.gif and edit size vars below

ch_x = 30    ; X size of ch.gif
ch_y = 30   ; Y size of ch.gif

; DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING!
; ==========================================================

; Find position of window on screen
WinGetPos, winx, winy, winw, winh, ahk_class %progclass%

; crosshairPosX and crosshairPosY hold offset of cursor within window (From centre)
crosshairPosX := 0
crosshairPosY := 0

; Calculate offsets
GoSub, offsetch

; Init overlay
Gui, Add, Picture, w%ch_x% h%ch_y% AltSubmit, ch.gif
Gui, Color, FFFFFF
GoSub, showch
Gui +AlwaysOnTop
WinSet, TransColor, White, %A_ScriptName%
Gui -Caption +ToolWindow

; Hide overlay
GoSub, hidech

; MAIN LOOP
SetTimer, tick, 500

; ================================================================================

; HOTKEYS
#Up::
    crosshairPosY -= 1
    GoSub, showch
return

#Down::
    crosshairPosY += 1
    GoSub, showch
return

#Left::
    crosshairPosX -= 1
    GoSub, showch
return

#Right::
    crosshairPosX += 1
    GoSub, showch
return

#Insert::
    WinGetActiveTitle, wint
    WinGetClass, progclass, %wint%
return


; Shows the crosshair
showch:
    GoSub, offsetch
    Gui, Show, NA x%chx% y%chy%
return

; Hides the crosshair
hidech:
    Gui, Cancel
return

; Calculate offset
offsetch:
    chx := winx + (winw /2) + crosshairPosX
    chy := winy + (winh /2) + crosshairPosY
return

tick:
    IfWinActive, ahk_class %progclass%
    {
        ; Check to see if window moved
        WinGetPos, winx, winy, winw, winh, ahk_class %progclass%
        ; Draw crosshair
        GoSub, showch
    }
        else
    {
        GoSub, hidech
    }
return