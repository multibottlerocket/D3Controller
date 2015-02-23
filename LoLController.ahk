#Include Xinput.ahk
#Include json.ahk
#Include debugConsole.ahk
#Include, Gdip.ahk

; Champs this works decently with: Ahri, Ashe, Blitzcrank (sorta), Corki (maybe), Ezreal, 
; 	Gnar (maybe), Graves (sorta), Kennen, Renekton (sorta), Riven (maybe?), Rumble (the ult is weird), 
;	Sejuani, Shyvana (sorta), Sion, Sivir, Sona (sorta), Vel'Koz (maybe), Zac

XInput_Init()

;status variables and flags
stop = 0
moveCount = 0
moveUpdatecount = 0

;system parameters and derivatives
resolutionX = 1920
resolutionY = 1080
centerX := resolutionX/2 - 60 
centerY := resolutionY/2 - 20
analogMax = 32767 ;max value analog sticks can return
analogMin = -32768 ;min value analog sticks can return
triggerMax = 255 ;max value trigger can return
triggerMin = 0 ;min value trigger can return
moveCircleRadius = 200
aimCircleRadius = 420
aimingDirection := "inward"
side := "blue"

;shop variables
shopUpperLeftX := 292 ;upper left corner of shop
shopUpperLeftY := 72
shopAllItemsOffsetX := 400 ;center of "All Items" button, relative to upper left corner of shop
shopAllItemsOffsetY := 100
shopItemGridOffsetX := 310 ;upper left corner of upper left item in item grid, relative to upper left corner of shop
shopItemGridOffsetY := 210
shopItemGridSpacingX := 79 ;spacing of the item blocks when diplayed in "grid" mode
shopItemGridSpacingY := 95
shopItemBoxX := 56 ; dimensions of item box
shopItemBoxY := 74
;dragging the scroll bar by one Y pixel moves the items by 4 Y pixels
scrollBarOffsetX := 800 ;dead center of the scroll bar when it's at the topmost position
scrollBarOffsetY := 300
itemSelGridCoordX := 2
itemSelGridCoordY := 3

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

#s::Reload
;mask = 128
;var2 = 24+2048
;start := (mask & var2 == mask)
;DebugMessage(start)
return

#v::
if (side == "blue") {
	; switch to red
	centerX := resolutionX/2 + 90 
	centerY := resolutionX/2 - 540 
	side := "red"
} else { ; switch to blue
	centerX := resolutionX/2 - 60 
	centerY := resolutionY/2 - 20 
	side := "blue"
}
return

#c::
if (aimingDirection == "inward") {
	aimingDirection := "outward"
}
else {
	aimingDirection := "inward"
}
aimCircleRadius := 480 - aimCircleRadius
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
	processTriggers(leftTriggerAnalog, rightTriggerAnalog)
	;handle ability aiming via left analog stick (since ability buttons are on the right)
	thresholdedAnalogStick2Offsets(aimCircleRadius, thumbLX, thumbLY ;inputs
								 , offsetLX, offsetLY) ;outputs
	if((Abs(offsetLX)+Abs(offsetLY)) > 0) { ;only click for significant displacements
		if (aimingDirection == "inward") {
			crosshairPosX := centerX+(offsetLX*leftTriggerAnalogTrim)
			crosshairPosY := centerY+(offsetLY*leftTriggerAnalogTrim)
		}
		else {
			crosshairPosX := centerX+(offsetLX/leftTriggerAnalogTrim)
			crosshairPosY := centerY+(offsetLY/leftTriggerAnalogTrim)
		}
	}
	else {
		if (aimingDirection == "inward") {
			crosshairPosX := centerX+(offsetRX*leftTriggerAnalogTrim)*aimCircleRadius/moveCircleRadius
			crosshairPosY := centerY+(offsetRY*leftTriggerAnalogTrim)*aimCircleRadius/moveCircleRadius
		}
		else {
			crosshairPosX := centerX+(offsetRX/leftTriggerAnalogTrim)*aimCircleRadius/moveCircleRadius
			crosshairPosY := centerY+(offsetRY/leftTriggerAnalogTrim)*aimCircleRadius/moveCircleRadius
		}
	}
	if((wButtons > 0) OR rightTrigger) { ;if any buttons are pressed
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
	thresholdedAnalogStick2Offsets(moveCircleRadius, thumbRX, thumbRY ;inputs
						, offsetRX, offsetRY) ;outputs
		;DebugMessage(offsetRX)
	if (moveUpdateCount > 1) {
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
thresholdedAnalogStick2Offsets(circleRadius, analogX, analogY ;inputs
					, byRef offsetX, byRef offsetY) { ;outputs
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
		offsetX := circleRadius*Cos(angle)
		offsetY := -circleRadius*Sin(angle) ;Y direction is reversed since pixels count downward from top
			;DebugMessage(offsetX)
			;DebugMessage(offsetY)
	}
	else {
		offsetX := 0
		offsetY := 0
	}
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

;take in analog values of triggers, turn right trigger into a button, and turn left trigger into a trimmed analog value
processTriggers(leftTriggerAnalog, rightTriggerAnalog) {
	global
	if (leftTriggerAnalog < triggerMax/20) { ;not pressing trigger: full range
		leftTriggerAnalogTrim := 1
	}
	else if ((leftTriggerAnalog >= triggerMax/20) &(leftTriggerAnalog < triggerMax*19/20)) {
		leftTriggerAnalogTrim := 1 - 0.8*(leftTriggerAnalog - triggerMax/20)/(triggerMax*18/20) 
	}
	else {
		leftTriggerAnalogTrim := 0.2
	}
	if (rightTriggerAnalog > triggerMax/4) {
		rightTrigger := 1
	}
	else {
		rightTrigger := 0
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

;map controller button states to key states (released/depressed)
setButtonStates() { ;dPadUp, dPadDown, dPadLeft, dPadRight
				;, start, back, leftThumb, rightThumb
				;, leftShoulder, rightShoulder, buttonA
				;, buttonB, buttonX, buttonY) {
	global

	if (back & !backDown) { ;put Ctrl first so that modifiers happen correctly
		Send {CTRL down}
		backDown := true
	}
	if (!back & backDown) {
		Send {CTRL up}
		backDown := false
	} 
	if (buttonA & !aDown) {
		Send {r down}
		aDown := true
	} 
	if (!buttonA & aDown) {
		Send {r up}
		aDown:= false
	}
	if (buttonX & !xDown) {
		Send {d down}
		xDown := true
	} 
	if (!buttonX & xDown) {
		Send {d up}
		xDown := false
	}
	if (buttonY & !yDown) {
		Send {Tab down}
		yDown := true
	} 
	if (!buttonY & yDown) {
		Send {Tab up}
		yDown := false
	}
	if (buttonB & !bDown) {
		Send {f down}
		bDown := true
	} 
	if (!buttonB & bDown) {
		Send {f up}
		bDown := false
	}
	if (rightShoulder & !rShoulderDown){
		Send {w down}
		rShoulderDown := true
	}
	if (!rightShoulder & rShoulderDown) {
		Send {w up}
		rShoulderDown := false
	} 
	if (rightTrigger & !rTrigDown){
		Send {e down}
		rTrigDown := true
	}
	if (!rightTrigger & rTrigDown) {
		Send {e up}
		rTrigDown := false
	}
	if (leftShoulder & !lShoulderDown){ ;attack-move on top of self for last-hitting
		Send {q down}
		lShoulderDown := true
	}
	if (!leftShoulder & lShoulderDown) {
		Send {q up}
		lShoulderDown := false
	} 
	; if (leftTrigger & !lTrigDown){ ; currently being used for stretchy cursor
	; 	Send {1 down}
	; 	lTrigDown := true
	; } 
	; if (!leftTrigger & lTrigDown) {
	; 	Send {1 up}
	; 	lTrigDownp := false
	; }
	if (dPadRight & !dPadRDown){ ; shop
		Send {t down}
		dPadRDown := true
	}
	if (!dPadRight & dPadRDown) {
		Send {t up}
		dPadRDown := false
	}
	if (dPadDown & !dPadDDown){
		Send {s down}
		dPadDDown := true
	}
	if (!dPadDown & dPadDDown) {
		Send {s up}
		dPadDDown := false
	}
	if (dPadLeft & !dPadLDown){
		Send {a down}
		MouseClick, left, centerX, centerY, ,0
		dPadLDown := true
	} 
	if (!dPadLeft & dPadLDown) {
		Send {a up}
		dPadLDown := false
	}
	if (dPadUp & !dPadUDown){
		Send {2 down}
		dPadUDown := true
	}
	if (!dPadUp & dPadUDown) {
		Send {2 up}
		dPadUDown := false
	}
	;if (rightThumb & !rThumbDown){
	;	Send {a down}
	;	MouseClick, left, centerX, centerY, ,0
	;	rThumbDown := true
	;} 
	;if (!rightThumb & rThumbDown) {
	;	Send {a up}
	;	rThumbDown := false
	;}
	if (start & !startDown){ 
		Send {b down}
		startDown := true
	}
	if (!start & startDown) {
		Send {b up}
		startDown := false
	}
}

crosshair:
	SetWinDelay 0

	; use VirtualScreen here to support multiple monitors
	SysGet, VirtualScreenWidth, 78
	SysGet, VirtualScreenHeight, 79
	horzXHair := Box(2,3,30)
	vertXHair := Box(3,30,3)
	;horzXHair2 := Box(4,2,20)
	;vertXHair2 := Box(5,20,2)
	; lineDot1 := Box(5, 4, 4)
	; lineDot2 := Box(6, 4, 4)
	; lineDot3 := Box(7, 4, 4)
	; lineDot4 := Box(8, 4, 4)
	; lineDot5 := Box(9, 4, 4)
	; lineDot6 := Box(10, 4, 4)
	; lineDot7 := Box(11, 4, 4)
	; lineDot8 := Box(12, 4, 4)

	; === Sbroutines
	Ruler:
	   WinMove ahk_id %horzXHair%,, %crosshairPosX%, % crosshairPosY-15    ;create crosshair by moving 1/2 length of segment
	   WinMove ahk_id %vertXHair%,, % crosshairPosX-15, %crosshairPosY%
	   ;WinMove ahk_id %horzXHair2%,, % centerX + 0.5*offsetLX, % centerY + 0.5*offsetLY - 10
	   ;WinMove ahk_id %vertXHair2%,, % centerX + 0.5*offsetLX - 10, % centerY + 0.5*offsetLY
	   ; WinMove ahk_id %lineDot0%,, % centerX + 0.5*offsetLX, % centerY + 0.5*offsetLY
	   ; WinMove ahk_id %lineDot1%,, % centerX + 0.2*offsetLX, % centerY + 0.2*offsetLY
	   ; WinMove ahk_id %lineDot2%,, % centerX + 0.3*offsetLX, % centerY + 0.3*offsetLY
	   ; WinMove ahk_id %lineDot3%,, % centerX + 0.4*offsetLX, % centerY + 0.4*offsetLY
	   ; WinMove ahk_id %lineDot4%,, % centerX + 0.5*offsetLX, % centerY + 0.5*offsetLY
	   ; WinMove ahk_id %lineDot5%,, % centerX + 0.6*offsetLX, % centerY + 0.6*offsetLY
	   ; WinMove ahk_id %lineDot6%,, % centerX + 0.7*offsetLX, % centerY + 0.7*offsetLY
	   ; WinMove ahk_id %lineDot7%,, % centerX + 0.8*offsetLX, % centerY + 0.8*offsetLY
	   ; WinMove ahk_id %lineDot8%,, % centerX + 0.9*offsetLX, % centerY + 0.9*offsetLY
	Return 

	Box(n,wide,high)
	{
	   Gui %n%:Color, FFFFE0,0             ; whitish yellow
	   Gui %n%:-Caption +ToolWindow +E0x20 ; No title bar, No taskbar button, Transparent for clicks
	   Gui %n%: Show, Center W%wide% H%high%      ; Show it
	   WinGet ID, ID, A                    ; ...with HWND/handle ID
	   Winset AlwaysOnTop,ON,ahk_id %ID%   ; Keep it always on the top
	   WinSet Transparent,255,ahk_id %ID%  ; Opaque
	   Return ID
	}