#Include, Gdip.ahk
#Include debugConsole.ahk

#q::
barLocX = 1107
barLoxY = 325
searchBoxSize = 20
DllCall("QueryPerformanceCounter", "Int64 *", startCount)
ImageSearch, healthX, healthY, barLocX-searchBoxSize, barLocY-searchBoxSize, barLocX+searchBoxSize, barLocY+searchBoxSize, healthBarCorner.png
;ImageSearch, healthX, healthY, barLocX-searchBoxSize, barLocY-searchBoxSize, barLocX+searchBoxSize, barLocY, healthBarCorner.png
;ImageSearch, healthX, healthY, barLocX-searchBoxSize, barLocY, barLocX+searchBoxSize, barLocY+searchBoxSize, healthBarCorner.png
DllCall("QueryPerformanceCounter", "Int64 *", stopCount)
DebugMessage(stopCount - startCount)
return

#s::Reload

#w::
;SetBatchLines, 50ms 
;Sleep, 4000
;;;;;;;;;;;;;;;;;;;;;;
;parameters and flags
performance := false
searchBoxSize := 20
screenX := 1920
screenY := 1080

;intialization
GoSub, overlayInit
;MouseGetPos, trackingX, trackingY ;point mouse near upper left of health bar of creep to be tracked
lastY := trackingY-searchBoxSize
if performance {
	DllCall("QueryPerformanceCounter", "Int64 *", lastCount)
}

Loop {
	searching := true
	barCount := 0
	lastX := 0
	lastY := 0
	while searching {
		;ImageSearch, healthX, healthY, trackingX-searchBoxSize, lastY, trackingX+searchBoxSize, trackingY+searchBoxSize, healthBarCorner.png ;this won't find multiple health bars on the same line
		;PixelSearch, healthX, healthY, trackingX-searchBoxSize, lastY, trackingX+searchBoxSize, trackingY+searchBoxSize, 0x6B6DFF, , Fast
		PixelSearch, healthX, healthY, lastX, lastY, screenX, screenY, 0x6B6DFF, , Fast
		if (ErrorLevel == 1) {
			;MsgBox, Couldnt find
			searching := false
		}
		else {
			;MsgBox, %healthX%, %healthY%
			;MouseMove, healthX, healthY
			barCount += 1
			lastY := healthY+1 ; this stops us from seeing more than one health bar on the same line
			healthBarsX%barCount% := healthX
			healthBarsY%barCount% := healthY
			;searching := false
		}
		if performance {
			DllCall("QueryPerformanceCounter", "Int64 *", currentCount)
			DebugMessage(currentCount - lastCount) ;lazily ignore when counter overflows
			lastCount := currentCount
		}
	}
	if performance {
		DebugMessage("drawing now")
	}	
	;MsgBox, %barCount%
	Gdip_GraphicsClear(G)
	Loop, %barCount% {
		Gdip_DrawEllipse(G, pPen, healthBarsX%A_Index%, healthBarsY%A_Index%, 60, 100)
		if performance {
			DllCall("QueryPerformanceCounter", "Int64 *", currentCount)
			DebugMessage(currentCount - lastCount) ;lazily ignore when counter overflows
			lastCount := currentCount
		}
		trackingX := healthBarsX%A_Index% ;sketchily track the last health bar we've found
		trackingY := healthBarsY%A_Index% ;I *think* that if it fails to find, it just looks in the last location
	}
	UpdateLayeredWindow(hwnd1, hdc, 0, 0, Width, Height)
	;Sleep, 100
	;DebugMessage("barCount:")
	;DebugMessage(barCount)
}
return

overlayInit:
; Start gdi+
If !pToken := Gdip_Startup()
{
	MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
	ExitApp
}
OnExit, Exit

; Set the width and height we want as our drawing area, to draw everything in. This will be the dimensions of our bitmap
Width :=1920, Height := 1080

; Create a layered window (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption
Gui, 1: -Caption +E0x80020 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs

; Show the window
Gui, 1: Show, NA

; Get a handle to this window we have created in order to update it later
hwnd1 := WinExist()

; Create a gdi bitmap with width and height of what we are going to draw into it. This is the entire drawing area for everything
hbm := CreateDIBSection(Width, Height)

; Get a device context compatible with the screen
hdc := CreateCompatibleDC()

; Select the bitmap into the device context
obm := SelectObject(hdc, hbm)

; Get a pointer to the graphics of the bitmap, for use with drawing functions
G := Gdip_GraphicsFromHDC(hdc)

; Set the smoothing mode to antialias = 4 to make shapes appear smother (only used for vector drawing and filling)
Gdip_SetSmoothingMode(G, 4)

; Create a fully opaque red pen (ARGB = Transparency, red, green, blue) to draw our line
pPen := Gdip_CreatePen(0xffff0000, 2)

; Create a fully opaque red brush (ARGB = Transparency, red, green, blue) to draw our box
pBrush := Gdip_BrushCreateSolid(0xffff0000)

return

overlayUpdate:
; Fill the graphics of the bitmap with a line
;Gdip_GraphicsClear(G)
Gdip_DrawEllipse(G, pPen, trackingX, trackingY, 60, 100)
UpdateLayeredWindow(hwnd1, hdc, 0, 0, Width, Height)
Return

;#######################################################################

Exit:
; gdi+ may now be shutdown on exiting the program
Gdip_Shutdown(pToken)
ExitApp
Return