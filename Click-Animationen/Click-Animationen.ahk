#Requires AutoHotkey v2.0
#SingleInstance Force

Enabled := true
FrameCount := 48
FrameBytes := 128 * 128 * 4
StyleNames := ["Impuls", "Orbit", "Partikel"]
StyleFiles := ["impuls", "orbit", "partikel"]
SelectedStyle := 1
Waves := []
for styleFile in StyleFiles {
    data := FileRead(A_ScriptDir "\" styleFile ".bgra", "RAW")
    if data.Size != FrameCount * FrameBytes
        throw Error("Die Effektdatei ist unvollständig: " styleFile)
    Waves.Push(data)
}
Wave := Waves[SelectedStyle]
if A_Args.Length && A_Args[1] = "--check" {
    FileAppend("PASS: Three click presets loaded; no overlay opened.`n", "*")
    ExitApp(0)
}
DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")
Overlay := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80020 +E0x08000000 -DPIScale")
DC := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
Header := Buffer(40, 0)
NumPut("UInt", 40, "Int", 128, "Int", -128, "UShort", 1, "UShort", 32, Header)
Bits := 0
Bitmap := DllCall("gdi32\CreateDIBSection", "Ptr", DC, "Ptr", Header, "UInt", 0, "Ptr*", &Bits, "Ptr", 0, "UInt", 0, "Ptr")
if !DC || !Bitmap || !Bits
    throw Error("Der Klick-Effekt konnte nicht initialisiert werden.")
OldBitmap := DllCall("gdi32\SelectObject", "Ptr", DC, "Ptr", Bitmap, "Ptr")
Position := Buffer(8, 0)
Dimensions := Buffer(8, 0)
NumPut("Int", 128, "Int", 128, Dimensions)
Origin := Buffer(8, 0)
Blend := Buffer(4, 0)
NumPut("UChar", 0, "UChar", 0, "UChar", 255, "UChar", 1, Blend)
Started := 0
A_TrayMenu.Delete()
A_TrayMenu.Add("Click-Animation aktiv", ToggleEffect)
A_TrayMenu.Check("Click-Animation aktiv")
A_TrayMenu.Add()
for index, name in StyleNames
    A_TrayMenu.Add(name, SelectStyle.Bind(index))
A_TrayMenu.Check(StyleNames[SelectedStyle])
A_TrayMenu.Add()
A_TrayMenu.AddStandard()
A_IconTip := "Galaxy Cursor – " StyleNames[SelectedStyle]
OnExit(Cleanup)

~*LButton::StartWave()


#HotIf EffectChordAllowed()
~SC04B & NumpadAdd::SelectStyle(1)
~SC04C & NumpadAdd::SelectStyle(2)
~SC04D & NumpadAdd::SelectStyle(3)
#HotIf

EffectChordAllowed() {
    return !GetKeyState("Ctrl", "P") && !GetKeyState("Alt", "P") && !GetKeyState("Shift", "P") && !GetKeyState("LWin", "P") && !GetKeyState("RWin", "P") && !GetKeyState("SC04F", "P") && !GetKeyState("SC050", "P") && !GetKeyState("SC051", "P")
}

SelectStyle(index, *) {
    global SelectedStyle, StyleNames, Waves, Wave, Overlay
    SetTimer(PaintWave, 0)
    Overlay.Hide()
    A_TrayMenu.Uncheck(StyleNames[SelectedStyle])
    SelectedStyle := index
    Wave := Waves[index]
    A_TrayMenu.Check(StyleNames[index])
    A_IconTip := "Galaxy Cursor – " StyleNames[index]
}

StartWave(*) {
    global Enabled, Started, Position, Overlay
    if !Enabled
        return
    point := Buffer(8, 0)
    if !DllCall("GetCursorPos", "Ptr", point)
        return
    NumPut("Int", NumGet(point, 0, "Int") - 64, "Int", NumGet(point, 4, "Int") - 64, Position)
    Started := A_TickCount
    PaintWave()
    DllCall("ShowWindow", "Ptr", Overlay.Hwnd, "Int", 4)
    SetTimer(PaintWave, 16)
}

PaintWave(*) {
    global Started, FrameCount, FrameBytes, Wave, Bits, Overlay, DC, Position, Dimensions, Origin, Blend
    frame := Floor((A_TickCount - Started) / 16)
    if frame >= FrameCount {
        SetTimer(PaintWave, 0)
        Overlay.Hide()
        return
    }
    DllCall("RtlMoveMemory", "Ptr", Bits, "Ptr", Wave.Ptr + frame * FrameBytes, "UPtr", FrameBytes)
    if !DllCall("UpdateLayeredWindow", "Ptr", Overlay.Hwnd, "Ptr", 0, "Ptr", Position, "Ptr", Dimensions, "Ptr", DC, "Ptr", Origin, "UInt", 0, "Ptr", Blend, "UInt", 2) {
        SetTimer(PaintWave, 0)
        Overlay.Hide()
    }
}

ToggleEffect(*) {
    global Enabled, Overlay
    Enabled := !Enabled
    if Enabled
        A_TrayMenu.Check("Click-Animation aktiv")
    else {
        A_TrayMenu.Uncheck("Click-Animation aktiv")
        SetTimer(PaintWave, 0)
        Overlay.Hide()
    }
}

Cleanup(*) {
    global DC, OldBitmap, Bitmap, Overlay
    SetTimer(PaintWave, 0)
    Overlay.Destroy()
    DllCall("gdi32\SelectObject", "Ptr", DC, "Ptr", OldBitmap)
    DllCall("gdi32\DeleteObject", "Ptr", Bitmap)
    DllCall("gdi32\DeleteDC", "Ptr", DC)
}
