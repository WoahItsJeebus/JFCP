#Requires AutoHotkey v2.0.19
#SingleInstance Force

global version := "1.1.1"
global UI_Width := 560
global UI_Height := 190
global DLL_PATH := ""
global MainUI
global lblPath := ""
global txtPath
global txtStatus
global prgRead := ""
global A_LocalAppData := EnvGet("LOCALAPPDATA")
global JFCP_FC6_Dir := A_LocalAppData "\JFCP\FC6"
global SETTINGS_FILE := JFCP_FC6_Dir "\settings.ini"

; Buttons/Controls
global btnBrowse := ""
global btnPatch := ""
global txtPath := ""
global txtStatus := ""

; ------------------------- ;
CreateUI()
; ------------------------- ;

CreateDirectories() {
	global JFCP_FC6_Dir
	if !DirExist(JFCP_FC6_Dir)
		DirCreate(JFCP_FC6_Dir)
}

CreateUI(*) {
	global MainUI, lblPath, txtPath, txtStatus, prgRead, DLL_PATH, SETTINGS_FILE, btnBrowse, btnPatch, UI_Width, UI_Height
	CreateDirectories()

    DLL_PATH := IniRead(SETTINGS_FILE, "Settings", "DllPath", "")

    MainUI := Gui("+Resize", "Far Cry 6 FOV Patch Tool — v" version)
	MainUI.Opt("+MinSize420x170")
	MainUI.OnEvent("Size", HandleResize)

	lblPath := MainUI.AddText(, "FC_m64d3d12.dll Path:")
	txtPath := MainUI.AddEdit(, DLL_PATH)

	btnBrowse := MainUI.AddButton(, "Browse")
    btnBrowse.OnEvent("Click", BrowseDLL)

	prgRead := MainUI.AddProgress("Range0-100", 0)

	txtStatus := MainUI.AddText(, "Status: Waiting")

	btnPatch := MainUI.AddButton(, "Apply Patch")
	btnPatch.Enabled := false
    btnPatch.OnEvent("Click", ApplyPatch)

	LayoutControls(UI_Width, UI_Height)

	MainUI.Show("w" UI_Width " h" UI_Height)
	SetTimer(CheckPatchStatus, -100)
}

HandleResize(thisGui, MinMax, Width, Height) {
	if MinMax = -1
		return

	LayoutControls(Width, Height)
}

LayoutControls(width, height) {
	global lblPath, txtPath, btnBrowse, prgRead, txtStatus, btnPatch

	local margin := 12
	local gap := 8
	local browseW := 90
	local patchW := 130
	local patchH := 30
	local labelH := 20
	local editH := 24
	local progressH := 18
	local statusH := 20

	local contentW := Max(260, width - (margin * 2))
	local pathW := Max(140, contentW - browseW - gap)

	local y := margin
	lblPath.Move(margin, y, contentW, labelH)

	y += labelH + 4
	txtPath.Move(margin, y, pathW, editH)
	btnBrowse.Move(margin + pathW + gap, y - 1, browseW, editH + 2)

	y += editH + 10
	prgRead.Move(margin, y, contentW, progressH)

	y += progressH + 8
	txtStatus.Move(margin, y, contentW, statusH)

	local patchY := Max(y + statusH + 8, height - margin - patchH)
	btnPatch.Move((width - patchW) // 2, patchY, patchW, patchH)
}

BrowseDLL(*) {
    global txtPath, SETTINGS_FILE
    local file := FileSelect(1, , "Select FC_m64d3d12.dll", "DLL (*.dll)")

    if !file
        return

    txtPath.Value := file

    IniWrite(file, SETTINGS_FILE, "Settings", "DllPath")
    CheckPatchStatus()
}

ApplyPatch(*) {
	global txtPath, txtStatus, btnPatch, prgRead

	dll := txtPath.Value

	if !FileExist(dll) {
		txtStatus.Value := "Status: DLL not found."
		prgRead.Value := 0
		return
	}

	txtStatus.Value := "Status: Reading file... 0%"
	prgRead.Value := 0
	btnPatch.Enabled := false

	try {
		data := ReadFileInChunks(dll, UpdateReadProgress)

		pattern := HexToBuffer("84 D2 74 19 F3 0F 10 05")
		replacement := HexToBuffer("84 D2 74 00 F3 0F 10 05")

		matches := FindPattern(data, pattern)

		if matches.Length = 0 {
			patchedPattern := HexToBuffer("84 D2 74 00 F3 0F 10 05")
			patchedMatches := FindPattern(data, patchedPattern)
			if patchedMatches.Length > 0 {
				prgRead.Value := 0
				txtStatus.Value := "Status: Already patched!"
			} else {
				txtStatus.Value := "Status: Pattern not found. Version may have changed."
			}
			return
		}

		if matches.Length > 1 {
			txtStatus.Value := "Status: Multiple matches found. Unsafe to patch."
			return
		}

		offset := matches[1]

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

		prgRead.Value := 100
		txtStatus.Value := "Status: Patch applied successfully."
	}
	catch Error as err {
		txtStatus.Value := "Status: Error - " err.Message
	}
	finally {
		btnPatch.Enabled := true
	}
}

ReadFileInChunks(filePath, progressCallback := "", chunkSize := 1048576) {
	local f := FileOpen(filePath, "r")
	if !IsObject(f)
		throw Error("Unable to open file for reading.")

	local totalSize := f.Length
	local data := Buffer(totalSize)
	local bytesReadTotal := 0

	if IsObject(progressCallback)
		progressCallback.Call(0)

	if totalSize = 0 {
		f.Close()
		if IsObject(progressCallback)
			progressCallback.Call(100)
		return data
	}

	while bytesReadTotal < totalSize {
		local bytesToRead := Min(chunkSize, totalSize - bytesReadTotal)
		local chunk := Buffer(bytesToRead)
		local bytesRead := f.RawRead(chunk, bytesToRead)

		if bytesRead <= 0
			break

		DllCall("ntdll\RtlMoveMemory"
			, "ptr", data.Ptr + bytesReadTotal
			, "ptr", chunk.Ptr
			, "uptr", bytesRead)

		bytesReadTotal += bytesRead

		if IsObject(progressCallback)
			progressCallback.Call(Round((bytesReadTotal / totalSize) * 100))
	}

	f.Close()

	if bytesReadTotal != totalSize
		throw Error("File read incomplete.")

	return data
}

UpdateReadProgress(percent) {
	global prgRead, txtStatus
	prgRead.Value := percent
	txtStatus.Value := "Status: Reading file... " percent "%"
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

CheckPatchStatus(*) {
	global txtPath, txtStatus, prgRead, btnPatch
	
	btnPatch.Enabled := false
	dll := txtPath.Value

	if dll = "" {
		txtStatus.Value := "Status: Waiting"
		prgRead.Value := 0
		return
	}

	if !FileExist(dll) {
		txtStatus.Value := "Status: DLL not found."
		prgRead.Value := 0
		return
	}

	txtStatus.Value := "Status: Checking..."
	prgRead.Value := 0

	try {
		; data := ReadFileInChunks(dll, UpdateReadProgress)
		data := ReadFileInChunks(dll)

		pattern := HexToBuffer("84 D2 74 19 F3 0F 10 05")
		patched := HexToBuffer("84 D2 74 00 F3 0F 10 05")

		unpatchedMatches := FindPattern(data, pattern)
		patchedMatches := FindPattern(data, patched)

		if unpatchedMatches.Length > 0 {
			prgRead.Value := 0
			txtStatus.Value := "Status: Not Patched"
		} else if patchedMatches.Length > 0 {
			prgRead.Value := 0
			txtStatus.Value := "Status: Already patched!"
		} else {
			prgRead.Value := 0
			txtStatus.Value := "Status: Unknown (pattern not found)"
		}
	}
	catch Error as err {
		prgRead.Value := 0
		txtStatus.Value := "Status: Error - " err.Message
	}

	btnPatch.Enabled := true
}

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
            , "cdecl ptr")

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