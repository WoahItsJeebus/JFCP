#Requires AutoHotkey v2.0.19
#SingleInstance Force

global version := "1.0.0"
global DLL_PATH := ""
global MainUI
global txtPath
global txtStatus
global A_LocalAppData := EnvGet("LOCALAPPDATA")
global JFCP_FC6_Dir := A_LocalAppData "\JFCP\FC6"
global SETTINGS_FILE := JFCP_FC6_Dir "\settings.ini"

; Buttons/Controls
global btnBrowse := ""
global btnPatch := ""
global txtPath := ""
global txtStatus := ""

; States
global reading := false

; ------------------------- ;
CreateUI()
; ------------------------- ;

CreateDirectories() {
	global JFCP_FC6_Dir
	if !DirExist(JFCP_FC6_Dir)
		DirCreate(JFCP_FC6_Dir)
}

CreateUI(*) {
    global MainUI, txtPath, txtStatus, DLL_PATH, SETTINGS_FILE, btnBrowse, btnPatch, txtPath, txtStatus
	CreateDirectories()

    DLL_PATH := IniRead(SETTINGS_FILE, "Settings", "DllPath", "")

    MainUI := Gui("+Resize", "Far Cry 6 FOV Patch Tool — v" version)
    MainUI.AddText(, "FC_m64d3d12.dll Path:")

    txtPath := MainUI.AddEdit("w400", DLL_PATH)

    btnBrowse := MainUI.AddButton("x+10 yp-2 w80", "Browse")
    btnBrowse.OnEvent("Click", BrowseDLL)

    btnPatch := MainUI.AddButton("xm w120 h30", "Apply Patch")
    btnPatch.OnEvent("Click", ApplyPatch)

    txtStatus := MainUI.AddText("xm w500", "Status: Waiting")

    MainUI.Show()
}

BrowseDLL(*) {
    global txtPath, SETTINGS_FILE
    local file := FileSelect(1, , "Select FC_m64d3d12.dll", "DLL (*.dll)")

    if !file
        return

    txtPath.Value := file

    IniWrite(file, SETTINGS_FILE, "Settings", "DllPath")
}

ApplyPatch(*) {
	global txtPath, txtStatus, btnPatch, reading

	dll := txtPath.Value

	if !FileExist(dll) {
		txtStatus.Value := "Status: DLL not found."
		return
	}

	txtStatus.Value := "Status: Reading file..."
	btnPatch.Enabled := false
	reading := true
	SetTimer(AnimateReading, 100)

	data := FileRead(dll, "RAW")

	pattern := HexToBuffer("84 D2 74 19 F3 0F 10 05")
	replacement := HexToBuffer("84 D2 74 00 F3 0F 10 05")

	matches := FindPattern(data, pattern)

	if matches.Length = 0 {
		reading := false
		txtStatus.Value := "Status: Pattern not found. DLL may already be patched or version changed."
		return
	}

	if matches.Length > 1 {
		reading := false
		txtStatus.Value := "Status: Multiple matches found. Unsafe to patch."
		return
	}

	offset := matches[1]

	reading := false
	txtStatus.Value := "Status: Creating backup..."

	backup := dll ".bak"

	if !FileExist(backup)
		FileCopy(dll, backup)

	txtStatus.Value := "Status: Applying patch..."

	Loop replacement.Size
		NumPut("UChar", NumGet(replacement, A_Index - 1, "UChar"), data, offset + A_Index - 1)

	f := FileOpen(dll, "w")
	f.RawWrite(data)
	f.Close()

	txtStatus.Value := "Status: Patch applied successfully."
	btnPatch.Enabled := true
}

HexToBuffer(hex) {
	hex := StrReplace(hex, " ")
	local size := StrLen(hex) // 2
	local buf := Buffer(size)

	Loop size {
		byte := "0x" SubStr(hex, (A_Index - 1) * 2 + 1, 2)
		NumPut("UChar", byte, buf, A_Index - 1)
	}

	return buf
}

; FindPattern(data, pattern) {
; 	local matches := []
; 	local max := data.Size - pattern.Size

; 	Loop max + 1 {
; 		local offset := A_Index - 1
; 		local found := true

; 		Loop pattern.Size {
; 			if NumGet(data, offset + A_Index - 1, "UChar") != NumGet(pattern, A_Index - 1, "UChar") {
; 				found := false
; 				break
; 			}
; 		}

; 		if found
; 			matches.Push(offset)
; 	}

; 	return matches
; }

FindPattern(data, pattern) {
    local matches := []

    local dataPtr := data.Ptr
    local dataSize := data.Size
    local patPtr := pattern.Ptr
    local patSize := pattern.Size

    local firstByte := NumGet(pattern, 0, "UChar")

    local offset := 0

    while offset <= dataSize - patSize
    {
        local remaining := dataSize - offset

        ; Find next occurrence of the first byte
        local ptr := DllCall("msvcrt\memchr"
            , "ptr", dataPtr + offset
            , "int", firstByte
            , "uptr", remaining
            , "ptr")

        if !ptr
            break

        local foundOffset := ptr - dataPtr

        ; Verify the rest of the pattern
        if DllCall("ntdll\RtlCompareMemory"
            , "ptr", ptr
            , "ptr", patPtr
            , "uptr", patSize
            , "uptr") = patSize
        {
            matches.Push(foundOffset)

            ; Early exit if multiple matches
            if matches.Length > 1
                return matches
        }

        offset := foundOffset + 1
    }

    return matches
}

AnimateReading(*) {
	global txtStatus, reading
	if !reading
		return SetTimer(AnimateReading, 0)

	txtStatus.Value := "Status: Reading file"
	Loop 3 {
		if !reading
			return SetTimer(AnimateReading, 0)
		txtStatus.Value .= "."
		Sleep(500)
	}
}