#Include Xinput.ahk
#Include json.ahk
#Include debugConsole.ahk
;DebugMessage("foo")
XInput_Init()

stop = 0
resolutionX = 1920
resolutionY = 1080
centerX := resolutionX/2
centerY := resolutionY/2 - 40
analogMax = 32767 ;max value analog sticks can return
analogMin = -32768 ;min value analog sticks can return
triggerMax = 255 ;max value trigger can return
triggerMin = 0 ;min value trigger can return
moveCircleRadius = 140
mouseButtonUp := true

#q::stop++ ;flag to kill loop

#s::
mask = 128
var2 = 24+2048
start := (mask & var2 == mask)
DebugMessage(start)
return

#w::
Loop{
	if stop ;triggered by windows key + q
		Break
	Loop, 4 { ;loop through each controller - TODO: change this to loop once, find controller, then only loop on that one
		if XInput_GetState(A_Index-1, State)=0 {
			;get controller state
			wButtons := json(State,"wButtons") 	;for bit-mapping to buttons, see:
											 	;http://msdn.microsoft.com/en-us/library/microsoft.directx_sdk.reference.xinput_gamepad(v=vs.85).aspx
			leftTriggerAnalog := json(State,"bLeftTrigger") ;0-255
			rightTriggerAnalog := json(State,"bRightTrigger") ;0-255
			thumbLX := json(State,"sThumbLX") ; Left -32768 -> 32767 Right
			thumbLY := json(State,"sThumbLY") ; Down -32768 -> 32767 Up
			thumbRX := json(State,"sThumbRX") ; Left -32768 -> 32767 Right
			thumbRY := json(State,"sThumbRY") ; Down -32768 -> 32767 Up

			;get button states from wButtons status word
			getButtonStates(wButtons) 
			;turn analog trigger signals into binary buttons for now
			thresholdTriggers(leftTriggerAnalog, rightTriggerAnalog)
				;DebugMessage(rightTrigger)
				;Sleep, 100
			;handle movement via left analog stick (since ability buttons on the right)
			analogStick2Offsets(thumbLX, thumbLY ;inputs
								, offsetLX, offsetLY) ;outputs
				;DebugMessage(offsetLX)
			if((Abs(offsetLX)+Abs(offsetLY)) > 0) { ;only click for significant displacements
					;DebugMessage(offsetLX)
					;DebugMessage(offsetLY)
				MouseMove, centerX+offsetLX, centerY+offsetLY, 0
				if mouseButtonUp {
					Send {Alt down} ; for tempest rush monk
					Click down
					mouseButtonUp := false
				}
			} else {
				if !mouseButtonUp {
					MouseMove, centerX, centerY, 0
					Click up
					Send {Alt up} ; for tempest rush monk
					mouseButtonUp := true
				}
			}
			;map controller state to key presses
			setButtonStates() 
			;;; not using right stick for tempest rush monk

			; if((Abs(offsetLX)+Abs(offsetLY)) <= 0) { ;yeah this is a ghetto else - i needed to splice in something mandatory
			; 	;handle character movement via right analog stick
			; 	analogStick2Offsets(thumbRX, thumbRY ;inputs
			; 						, offsetRX, offsetRY) ;outputs
			; 		;DebugMessage(offsetRX)
			; 	if((Abs(offsetRX)+Abs(offsetRY)) > 0) { ;only click for significant displacements
			; 			;DebugMessage(offsetRX)
			; 			;DebugMessage(offsetRY)
			; 		;MouseGetPos, posX, posY ;save mouse position
			; 		MouseMove, centerX+offsetRX, centerY+offsetRY, 0
			; 		if mouseButtonUp {
			; 			Send {Alt down} ; for tempest rush monk
			; 			Click down
			; 			mouseButtonUp := false
			; 		}
			; 		;MouseMove, posX, posY, 0 ;instantly return mouse to previous position - currently feels/looks too weird
			; 	} else { ; when release the movement stick, snap back to center and halt movement
			; 		MouseMove, centerX, centerY, 0
			; 		Click up
			; 		Send {Alt up} ; for tempest rush monk
			; 		mouseButtonUp := true
			; 	}
			; }
		}
		;maybe add some exception handling if controller is unplugged later
			;need to figure out how to handle telling system when controller *should* be in
	}
}
return

;this function takes in the analog X and Y values from a joystick
;and returns by reference the appropriate pixel offsets from the center for
;the mouse to click
analogStick2Offsets(analogX, analogY ;inputs
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
	if (radius > analogMax/2) { ;only click for significant displacements
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
	if (leftTriggerAnalog > triggerMax/2) {
		leftTrigger := 1
	}
	else {
		leftTrigger := 0
	}
	if (rightTriggerAnalog > triggerMax/2) {
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
	if buttonA { ;skill 1
		Send {q down}
;		Send, a
	} 
	else { 
		Send {q up}
	}
	if buttonX { ;skill 2
		Send {w down}
;		Send, w
	} 
	else { 
		Send {w up}
	}
	if buttonY { ;skill 3
		Send {e down}
;		Send, e
	} 
	else { 
		Send {e up}
	}
	if buttonB { ;skill 4
		Send {r down}
	} 
	else { 
		Send {r up}
	}
	if rightShoulder { ;skill 5 is left mouse click, which is also used to move
					   ;use this for shift to force usage of skill rather than moving
		Send {Alt Down}
	} 
	else { 
		Send {Alt Up}
	}
	if rightTrigger { ;skill 6
		Click right down
	} 
	else { 
		Click right up
	}
	if leftShoulder { ;potion
		Send, i
	} 
	if dPadRight { ;town portal
		Send, f
		Sleep, 50
	} 
	if dPadDown { ;map
		Send {Tab}
		Sleep, 50
	}
	if back { ;spam right click in a circle to pick shit up
		Random, startAngle, 0, 6.28
		Loop, 12 {
			angleToOffsets(startAngle, randOffsetX, randOffsetY)
			MouseClick, left, centerX+randOffsetX, centerY+randOffsetY
			startAngle += 3.14
			Sleep, 50
			angleToOffsets(startAngle, randOffsetX, randOffsetY)
			MouseClick, left, centerX+randOffsetX, centerY+randOffsetY
			startAngle += 0.26
			Sleep, 50
		}
	}
	if start { ;game menu
		Send {Esc}
		Sleep, 50
	}
}

angleToOffsets(angle ;inputs
			   , ByRef offsetX, ByRef offsetY) { ;outputs
	global moveCircleRadius
	offsetX := moveCircleRadius*Cos(angle)
	offsetY := -moveCircleRadius*Sin(angle) ;Y direction is reversed since pixels count downward from top
}