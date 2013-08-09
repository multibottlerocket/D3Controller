#Include Xinput.ahk
#Include json.ahk
#Include debugConsole.ahk
#Include, Gdip.ahk
;DebugMessage("foo")
XInput_Init()

;status variables and flags
stop = 0
moveCount = 0
moveUpdatecount = 0

;system parameters and derivatives
resolutionX = 1920
resolutionY = 1080
centerX := resolutionX/2
centerY := resolutionY/2 - 40
analogMax = 32767 ;max value analog sticks can return
analogMin = -32768 ;min value analog sticks can return
triggerMax = 255 ;max value trigger can return
triggerMin = 0 ;min value trigger can return
moveCircleRadius = 200
aimCircleRadius = 300

;for bit-mapping to buttons, see:
;http://msdn.microsoft.com/en-us/library/microsoft.directx_sdk.reference.xinput_gamepad(v=vs.85).aspx
dPadUpMask 			:= 2**0
dPadDownMask 		:= 2**1
dPadLeftMask 		:= 2**2
dPadRightMask 		:= 2**3
startMask			:= 2**4
backMask			:= 2**5
leftThumbMask		:= 2**6
rightThumbMask		:= 2**7
leftShoulderMask	:= 2**8
rightShoulderMask	:= 2**9
buttonAMask 		:= 2**12
buttonBMask			:= 2**13
buttonXMask			:= 2**14
buttonYMask			:= 2**15

#q::stop++ ;flag to kill loop

#s::
mask = 128
var2 = 24+2048
start := (mask & var2 == mask)
DebugMessage(start)
return

#w::
GoSub, crosshair
;SetTimer, movement, 10 ;poll for movement every 20 ms
;Sleep, 5
;SetTimer, aiming, 10
lastCount := 0
Loop{
	if stop ;triggered by windows key + q
		Break
	;Loop, 4 { ;loop through each controller - TODO: change this to loop once, find controller, then only loop on that one
		if XInput_GetState(0, State)=0 {
			;get controller state
			wButtons := json(State,"wButtons") 	;for bit-mapping to buttons, see:
											 	;http://msdn.microsoft.com/en-us/library/microsoft.directx_sdk.reference.xinput_gamepad(v=vs.85).aspx
			leftTriggerAnalog := json(State,"bLeftTrigger") ;0-255
			rightTriggerAnalog := json(State,"bRightTrigger") ;0-255
			thumbLX := json(State,"sThumbLX") ; Left -32768 -> 32767 Right
			thumbLY := json(State,"sThumbLY") ; Down -32768 -> 32767 Up
			thumbRX := json(State,"sThumbRX") ; Left -32768 -> 32767 Right
			thumbRY := json(State,"sThumbRY") ; Down -32768 -> 32767 Up
			GoSub, aiming
			GoSub, movement
			GoSub, Ruler
			;DllCall("QueryPerformanceCounter", "Int64 *", currentCount)
			;DebugMessage(currentCount - lastCount) ;lazily ignore when counter overflows
			;lastCount := currentCount
			;DllCall("QueryPerformanceFrequency", "Int64 *", freq)
			;DebugMessage(freq)
		}
		;maybe add some exception handling if controller is unplugged later
			;need to figure out how to handle telling system when controller *should* be in
	;}
}
return

aiming:
	;get button states from wButtons status word
	getButtonStates(wButtons) 
	;turn analog trigger signals into binary buttons for now
	thresholdTriggers(leftTriggerAnalog, rightTriggerAnalog)
		;DebugMessage(rightTrigger)
		;Sleep, 100
	;handle ability aiming via left analog stick (since ability buttons are on the right)
;	analogStick2Offsets(thumbLX, thumbLY ;inputs
;						, offsetLX, offsetLY) ;outputs
	thresholdedAnalogStick2Offsets(thumbLX, thumbLY ;inputs
								 , offsetLX, offsetLY) ;outputs
	if((Abs(offsetLX)+Abs(offsetLY)) > 0) { ;only click for significant displacements
		;MouseMove, centerX+offsetLX, centerY+offsetLY, 0
		crosshairPosX := centerX+offsetLX
		crosshairPosY := centerY+offsetLY
	}
	else {
		crosshairPosX := autoMoveX
		crosshairPosY := autoMoveY
	}
		;DebugMessage(offsetLX)
	if((wButtons > 0) OR rightTrigger OR leftTrigger) { ;if any buttons are pressed
		MouseGetPos, currentX, currentY
		if ((currentX != crosshairPosX) OR (currentY != crosshairPosY)) {
			;DebugMessage("moving mouse")
			MouseMove, crosshairPosX, crosshairPosY, 0
		}
		movementAllowed := false
	}
	else {
		movementAllowed := true
	}
	;map controller state to key presses
	setButtonStates()
return

movement:
	;handle character movement via right analog stick
	thresholdedAnalogStick2Offsets(thumbRX, thumbRY ;inputs
						, offsetRX, offsetRY) ;outputs
		;DebugMessage(offsetRX)
	if (moveUpdateCount > 10) {
		if(((Abs(offsetRX)+Abs(offsetRY)) > 0) & movementAllowed) { ;only click for significant displacements and when we're not locked out by something else
				;DebugMessage(offsetRX)
				;DebugMessage(offsetRY)
			;MouseGetPos, posX, posY ;save mouse position
			MouseClick, right, centerX+offsetRX, centerY+offsetRY, , 0
			autoMoveX := centerX+offsetRX
			autoMoveY := centerY+offsetRY
			autoMoving := true
			moveUpdateCount := 0
			;MouseMove, posX, posY, 0 ;instantly return mouse to previous position - currently feels/looks too weird
		}
	}
	else {
		moveUpdateCount += 1
	}

	if (autoMoving & movementAllowed) { ;maintain momentum if we are going in a direction already and don't have new input from user
		if (moveCount > 500) {
			MouseClick, right, autoMoveX, autoMoveY, , 0
			moveCount := 0
		}
		else {
			moveCount += 1
		}
	}
	else { ;we're being blocked from moving, so stop auto moving
		autoMoving := false
		if (moveCount > 500) {
			moveCount := 475
		}
		else {
			moveCount += 1
		}
	}
	
return

;this function takes in the analog X and Y values from a joystick
;and returns by reference the appropriate pixel offsets from the center for
;the mouse to click
analogStick2Offsets(analogX, analogY ;inputs
					, byRef offsetX, byRef offsetY) { ;outputs
	global aimCircleRadius
	global analogMax
	
	offsetX := (analogX/analogMax)*aimCircleRadius
	offsetY := (analogY/analogMax)*aimCircleRadius
}

;this function takes in the analog X and Y values from a joystick
;and returns by reference the appropriate pixel offsets from the center for
;the mouse to click
thresholdedAnalogStick2Offsets(analogX, analogY ;inputs
					, byRef offsetX, byRef offsetY) { ;outputs
	global moveCircleRadius
	global analogMax
	if (analogX > 0) { ;first or fourth quadrant
		angle := ATan(analogY/analogX)
	}
	else { ;second or third quadrant
		angle := 3.14159 + ATan(analogY/analogX)
	}

	radius := Sqrt(analogX**2 + analogY**2) ;could potentially remove the Sqrt for speed
		;DebugMessage(radius)
	if (radius > analogMax/4) { ;only click for significant displacements
			;DebugMessage(angle)
			;DebugMessage(moveCircleRadius)
		offsetX := moveCircleRadius*Cos(angle)
		offsetY := -moveCircleRadius*Sin(angle) ;Y direction is reversed since pixels count downward from top
			;DebugMessage(offsetX)
			;DebugMessage(offsetY)
	}
	else {
		offsetX := 0
		offsetY := 0
	}
}

;take in button status word and return button states by reference
getButtonStates(wButtons) { ;, byRef dPadUp, byRef dPadDown, byRef dPadLeft, byRef dPadRight
				;, byRef start, byRef back, byRef leftThumb, byRef rightThumb
				;, byRef leftShoulder, byRef rightShoulder, byRef buttonA
				;, byRef buttonB, byRef buttonX, byRef buttonY) {
	global

	dPadUp 			:= (dPadUpMask & wButtons == dPadUpMask)
	dPadDown 		:= (dPadDownMask & wButtons == dPadDownMask)
	dPadLeft 		:= (dPadLeftMask & wButtons == dPadLeftMask)
	dPadRight 		:= (dPadRightMask & wButtons == dPadRightMask)
	start 			:= (startMask & wButtons == startMask)
	back 			:= (backMask & wButtons == backMask)
	leftThumb 		:= (leftThumbMask & wButtons == leftThumbMask)
	rightThumb 		:= (rightThumbMask & wButtons == rightThumbMask)
	leftShoulder 	:= (leftShoulderMask & wButtons == leftShoulderMask)
	rightShoulder 	:= (rightShoulderMask & wButtons == rightShoulderMask)
	buttonA 		:= (buttonAMask & wButtons == buttonAMask)
	buttonB 		:= (buttonBMask & wButtons == buttonBMask)
	buttonX 		:= (buttonXMask & wButtons == buttonXMask)
	buttonY 		:= (buttonYMask & wButtons == buttonYMask)
}

;take in analog values of triggers and just threshold to make them buttons
thresholdTriggers(leftTriggerAnalog, rightTriggerAnalog) {
	global
	if (leftTriggerAnalog > triggerMax/4) {
		leftTrigger := 1
	}
	else {
		leftTrigger := 0
	}
	if (rightTriggerAnalog > triggerMax/4) {
		rightTrigger := 1
	}
	else {
		rightTrigger := 0
	}
}

;map controller button states to key states (released/depressed)
setButtonStates() { ;dPadUp, dPadDown, dPadLeft, dPadRight
				;, start, back, leftThumb, rightThumb
				;, leftShoulder, rightShoulder, buttonA
				;, buttonB, buttonX, buttonY) {
	global

	if back { ;put Ctrl first so that modifiers happen correctly
		Send {CTRL down}
		CTRLDn := true
	}
	if (!back & CTRLDn) {
		Send {CTRL up}
		CTRLDn := false
	} 
	if buttonA {
		Send {r down}
		rDown := true
	} 
	if (!buttonA & rDown) {
		Send {r up}
		rDown:= false
	}
	if buttonX {
		Send {d down}
		dDown := true
	} 
	if (!buttonX & dDown) {
		Send {d up}
		dDown := false
	}
	;if buttonY {
	;	Send, e
	;} 
	if buttonB {
		Send {f down}
		fDown := true
	} 
	if (!buttonB & fDown) {
		Send {f up}
		fDown := false
	}
	if rightShoulder {
		Send {w down}
		wDown := true
	}
	if (!rightShoulder & wDown) {
		Send {w up}
		wDown := false
	} 
	if rightTrigger{
		Send {e down}
		eDown := true
	}
	if (!rightTrigger & eDown) {
		Send {e up}
		eDown := false
	}
	if leftShoulder {
		Send {q down}
		qDown := true
	} 
	if (!leftShoulder & qDown) {
		Send {q up}
		qDown := false
	}
	if leftTrigger { ;attack-move on top of self for last-hitting
		Send {a down}
		MouseClick, left, centerX, centerY, ,0
		aDown := true
	}
	if (!leftTrigger & aDown) {
		Send {a up}
		aDown := false
	} 
	;if dPadRight { ;town portal
	;	Send, t
	;	Sleep, 50
	;} 
	if dPadDown {
		Send {b down}
		bDown := true
	}
	if (!dPadDown & bDown) {
		Send {b up}
		bDown := false
	}
	;if dPadLeft {
	;	Send {a down}
	;	MouseClick, left, centerX, centerY, ,0
	;	aDown := true
	;} 
	;if (!dPadLeft & aDown) {
	;	Send {a up}
	;	aDown := false
	;}
	;if dPadUp {
	;	Send {b down}
	;	bDown := true
	;}
	;if (!dPadUp & bDown) {
	;	Send {b up}
	;	bDown := false
	;}
	;if rightThumb {
	;	Send {a down}
	;	MouseClick, left, centerX, centerY, ,0
	;	aDown := true
	;} 
	;if (!rightThumb & aDown) {
	;	Send {a up}
	;	aDown := false
	;}
	if start { ;game menu
		Send {s down}
		sDown := true
	}
	if (!start & sDown) {
		Send {s up}
		sDown := false
	}
}

crosshair:
SetWinDelay 0
Restart:
Selecting := False
OldX := -1, OldY := -1
Locked  := False
Visible := True      ;<= determine start-up behaviour

; use VirtualScreen here to support multiple monitors
SysGet, VirtualScreenWidth, 78
SysGet, VirtualScreenHeight, 79
ID1 := Box(2,1,30)
;ID2 := Box(3,30,1)

;SetTimer Ruler, 10
if (Visible == False) {
    WinHide ahk_id %ID1%,, 
    WinHide ahk_id %ID2%,, 
}
Return


; === Toggle lock of crosshairs
;KeyWait, RButton, D
^NumpadDot::
;RButton::             ;using hotkey instead of waiting for a key keeps the right click from calling other behavior during script
if (Visible == False) {
    WinShow ahk_id %ID1%,, 
    WinShow ahk_id %ID2%,, 
  Visible := True 
}
if (Locked == False) {
  SetTimer Ruler, Off
  Locked := True 
  }
else {
  SetTimer Ruler, 10
  Locked := False 
  }
Return


; === Toggle display of crosshairs
^Numpad0::
if (Visible == True) {
    WinHide ahk_id %ID1%,, 
    WinHide ahk_id %ID2%,, 
    Visible := False
  }
else {
    WinShow ahk_id %ID1%,,
    WinShow ahk_id %ID2%,,
    Visible := True
}
Return


; === Terminate program
Numpad0::Send {Blind}{Numpad0}  ; necessary to make Numpad0 work normally
Numpad0 & NumpadDot::
;Escape::
OutOfHere:
ExitApp




; === Subroutines
Ruler:
   WinMove ahk_id %ID1%,, %crosshairPosX%, % crosshairPosY-15    ;create crosshair by moving 1/2 length of segment
;   WinMove ahk_id %ID2%,, % crosshairPosX-15, %crosshairPosY%
   ;ToolTip (Ctrl-0 to anchor)
Return 

Box(n,wide,high)
{
   Gui %n%:Color, FF0000,0             ; Red
   Gui %n%:-Caption +ToolWindow +E0x20 ; No title bar, No taskbar button, Transparent for clicks
   Gui %n%: Show, Center W%wide% H%high%      ; Show it
   WinGet ID, ID, A                    ; ...with HWND/handle ID
   Winset AlwaysOnTop,ON,ahk_id %ID%   ; Keep it always on the top
   WinSet Transparent,255,ahk_id %ID%  ; Opaque
   Return ID
}