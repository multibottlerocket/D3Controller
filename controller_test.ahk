#Include Xinput.ahk
#Include json.ahk

; Example: Control the vibration motors using the analog triggers of each controller.
XInput_Init()
Loop {
    Loop, 4 {
        if XInput_GetState(A_Index-1, State)=0 {
            LT := json(State,"bLeftTrigger")
            RT := json(State,"bRightTrigger")
            XInput_SetState(A_Index-1, LT*257, RT*257)
        }
    }
    Sleep, 100
}