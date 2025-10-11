#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================
; FOLDER SETUP
; ============================================
SetupFolders() {
    scriptName := "ReHelicity.ahk"
    scriptPath := A_ScriptFullPath
    
    downloadsFolder := EnvGet("USERPROFILE") . "\Downloads\ReHelicity"
    settingsFolder := downloadsFolder . "\settings"
    debugFolder := downloadsFolder . "\debugging"
    newScriptPath := downloadsFolder . "\" . scriptName
    
    if (scriptPath = newScriptPath) {
        if (!DirExist(settingsFolder))
            DirCreate(settingsFolder)
        if (!DirExist(debugFolder))
            DirCreate(debugFolder)
        return {settings: settingsFolder, debug: debugFolder}
    }
    
    try {
        if (!DirExist(downloadsFolder))
            DirCreate(downloadsFolder)
        if (!DirExist(settingsFolder))
            DirCreate(settingsFolder)
        if (!DirExist(debugFolder))
            DirCreate(debugFolder)
        
        FileCopy(scriptPath, newScriptPath, 1)
        Run('"' . newScriptPath . '"')
        ExitApp()
    } catch as err {
        scriptDir := A_ScriptDir
        if (!DirExist(scriptDir . "\settings"))
            DirCreate(scriptDir . "\settings")
        if (!DirExist(scriptDir . "\debugging"))
            DirCreate(scriptDir . "\debugging")
        return {settings: scriptDir . "\settings", debug: scriptDir . "\debugging"}
    }
}

global Folders := SetupFolders()
global SettingsFile := Folders.settings . "\helicity_settings.ini"
global DataFolder := Folders.debug
global LogFile := DataFolder . "\helicity_log.txt"

; ============================================
; TESSERACT PATH DETECTION
; ============================================
DetectTesseractPath() {
    ; Check common installation locations
    possiblePaths := [
        EnvGet("USERPROFILE") . "\AppData\Local\Programs\Tesseract-OCR\tesseract.exe",
        EnvGet("LOCALAPPDATA") . "\Programs\Tesseract-OCR\tesseract.exe",
        "C:\Program Files\Tesseract-OCR\tesseract.exe",
        "C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
        A_ProgramFiles . "\Tesseract-OCR\tesseract.exe"
    ]
    
    ; Check each possible path
    for path in possiblePaths {
        if (FileExist(path)) {
            return path
        }
    }
    
    ; Try to find in PATH environment variable
    try {
        shell := ComObject("WScript.Shell")
        exec := shell.Exec("where tesseract.exe")
        result := exec.StdOut.ReadAll()
        if (result != "") {
            firstLine := StrSplit(result, "`n")[1]
            if (FileExist(Trim(firstLine))) {
                return Trim(firstLine)
            }
        }
    }
    
    return ""
}

global TesseractPath := DetectTesseractPath()

global Settings := {
    ServerLink: "https://www.roblox.com/games/17759606919/Helicity-1-8-4?privateServerLinkCode=YOUR_CODE_HERE",
    UseBloxstrap: false,
    TargetRisk: "HIGH",
    LapseRate: {enabled: false, comparison: ">=", value: 0},
    WindShear: {enabled: false, comparison: ">=", value: 0},
    CAPE: {enabled: false, comparison: ">=", value: 0},
    DewPoint: {enabled: false, comparison: ">=", value: 0},
    RelativeHumidity: {enabled: false, comparison: ">=", value: 0},
    InitialWaitAfterJoin: 18,
    SpawnDelay: 4,
    KeyPressDelay: 150,
    OCRRegion: {x: 0, y: 0, w: 0, h: 0},
    WebhookURL: "",
    WebhookEnabled: false,
    WebhookUserID: "",
    WebhookRoleID: ""
}

global Running := false
global Attempts := 0
global MainGui := ""
global LogBox := ""
global StatusText := ""
global AttemptText := ""
global CountdownGui := ""

global ValidationLimits := {
    LapseRate: 10,
    WindShear: 55,
    CAPE: 7000,
    DewPoint: 90,
    RelativeHumidity: 100
}

; ============================================
; GUI CLOSE HANDLER
; ============================================
OnGuiClose(*) {
    global Running
    
    if (Running) {
        result := MsgBox("Reroller is still running! Do you want to stop it and exit?", "Confirm Exit", "YesNo Icon!")
        if (result = "Yes") {
            StopAll()
            ExitApp()
        }
        return -1
    }
    
    ExitApp()
}

; ============================================
; INPUT VALIDATION FUNCTIONS
; ============================================

ValidateFloatInput(editControl, settingName) {
    global Settings, ValidationLimits
    
    value := Trim(editControl.Value)
    
    if (value = "") {
        editControl.Opt("Background0x1a1a1a")
        Settings.%settingName%.value := 0
        SaveSettings()
        return
    }
    
    if (IsNumber(value)) {
        numValue := Float(value)
        
        if (ValidationLimits.HasOwnProp(settingName) && numValue > ValidationLimits.%settingName%) {
            editControl.Opt("BackgroundRed")
            numValue := ValidationLimits.%settingName%
            editControl.Value := numValue
        }
        
        editControl.Opt("Background0x1a1a1a")
        
        if (Mod(numValue, 1) = 0) {
            Settings.%settingName%.value := Integer(numValue)
            editControl.Value := Integer(numValue)
        } else {
            formattedValue := Round(numValue, 1)
            Settings.%settingName%.value := formattedValue
            editControl.Value := formattedValue
        }
        
        SaveSettings()
    } else {
        editControl.Opt("BackgroundRed")
    }
}

ValidateIntegerInput(editControl, settingName) {
    global Settings
    
    value := Trim(editControl.Value)
    
    if (value = "") {
        editControl.Opt("Background0x1a1a1a")
        Settings.%settingName% := 0
        SaveSettings()
        return
    }
    
    if (IsInteger(value)) {
        editControl.Opt("Background0x1a1a1a")
        Settings.%settingName% := Integer(value)
        SaveSettings()
    } else {
        editControl.Opt("BackgroundRed")
    }
}

; ============================================
; GOOD SERVER POPUP
; ============================================

ShowGoodServerPopup(ocrResult) {
    global Running, Attempts
    
    lapseStr := (Mod(ocrResult.lapseRate, 1) = 0) ? Integer(ocrResult.lapseRate) : Round(ocrResult.lapseRate, 1)
    shearStr := (Mod(ocrResult.windShear, 1) = 0) ? Integer(ocrResult.windShear) : Round(ocrResult.windShear, 1)
    capeStr := (Mod(ocrResult.cape, 1) = 0) ? Integer(ocrResult.cape) : Round(ocrResult.cape, 1)
    dewStr := (Mod(ocrResult.dewPoint, 1) = 0) ? Integer(ocrResult.dewPoint) : Round(ocrResult.dewPoint, 1)
    humidStr := (Mod(ocrResult.relativeHumidity, 1) = 0) ? Integer(ocrResult.relativeHumidity) : Round(ocrResult.relativeHumidity, 1)
    
    details := "Risk Level: " . ocrResult.risk . "`n"
    details .= "Lapse Rate: " . lapseStr . " C`n"
    details .= "Wind Shear: " . shearStr . " kts`n"
    details .= "CAPE: " . capeStr . " J/Kg`n"
    details .= "Dew Point: " . dewStr . " F`n"
    details .= "Relative Humidity: " . humidStr . "%`n"
    details .= "`nFound after " . Attempts . " attempts"
    
    popupGui := Gui("+AlwaysOnTop -MinimizeBox", "ReHelicity - Good Server Found")
    popupGui.BackColor := "0x1a1a1a"
    popupGui.SetFont("s12 bold", "Segoe UI")
    
    popupGui.Add("Text", "x20 y20 w460 h40 c0x00FF00 Center", "Good server has been found")
    
    popupGui.SetFont("s10", "Segoe UI")
    popupGui.Add("GroupBox", "x20 y70 w460 h190 c0x555555", "Server Details")
    popupGui.Add("Text", "x40 y95 w420 h160 c0xcccccc", details)
    
    popupGui.SetFont("s11", "Segoe UI")
    popupGui.Add("Text", "x20 y260 w460 h30 c0xFFFFFF Center", "Would you like to continue rerolling?")
    
    popupGui.SetFont("s9", "Segoe UI")
    timerText := popupGui.Add("Text", "x20 y295 w460 h25 c0x888888 Center", "If not closed will continue to reroll in 15 minutes")
    
    popupGui.SetFont("s11 bold", "Segoe UI")
    btnContinue := popupGui.Add("Button", "x40 y330 w200 h45 Background0x2a7a2a c0xffffff", "Continue rerolling")
    btnClose := popupGui.Add("Button", "x260 y330 w200 h45 Background0x7a2a2a c0xffffff", "Close and wait")
    
    btnContinue.OnEvent("Click", (*) => ContinueRerolling(popupGui))
    btnClose.OnEvent("Click", (*) => ClosePopup(popupGui))
    
    autoCloseTime := A_TickCount + (15 * 60 * 1000)
    popupGui.Show("w500 h400")
    
    popupHwnd := popupGui.Hwnd
    
    SetTimer(UpdatePopupTimer, 1000)
    
    UpdatePopupTimer() {
        if (!WinExist("ahk_id " . popupHwnd)) {
            SetTimer(UpdatePopupTimer, 0)
            return
        }
        
        remaining := Round((autoCloseTime - A_TickCount) / 1000)
        
        if (remaining <= 0) {
            SetTimer(UpdatePopupTimer, 0)
            ContinueRerolling(popupGui)
            return
        }
        
        minutes := Floor(remaining / 60)
        seconds := Mod(remaining, 60)
        timeStr := Format("{:02d}:{:02d}", minutes, seconds)
        
        futureTime := FormatTime(DateAdd(A_Now, remaining, "Seconds"), "HH:mm")
        
        try {
            timerText.Text := "If not closed will continue to reroll in " . timeStr . " (" . futureTime . ")"
        }
    }
}

ContinueRerolling(popupGui) {
    global Running
    
    try {
        popupGui.Destroy()
    }
    
    LogToGUI("User chose to continue rerolling")
    Running := true
    UpdateStatus("Resuming rerolls...")
    
    if (QuickLeaveGame()) {
        LogToGUI("Successfully left game")
        Sleep(400)
    } else {
        LogToGUI("Failed to leave game, forcing close")
        CloseRoblox()
        Sleep(2000)
    }
    
    SetTimer(RunRerollerLoop, 100)
}

ClosePopup(popupGui) {
    global Running
    
    try {
        popupGui.Destroy()
    }
    
    LogToGUI("User chose to stay in server")
    Running := false
    UpdateStatus("Waiting in good server")
}

; ============================================
; COUNTDOWN GUI FOR CALIBRATION
; ============================================

ShowCountdown(seconds) {
    global CountdownGui
    
    CountdownGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    CountdownGui.BackColor := "0x000000"
    CountdownGui.SetFont("s24 bold", "Segoe UI")
    
    countdownText := CountdownGui.Add("Text", "x10 y10 w100 h40 c0x00FF00 Center", seconds)
    
    WinSetTransColor("0x000000", CountdownGui)
    CountdownGui.Show("w120 h60 NoActivate")
    
    Loop seconds {
        remaining := seconds - A_Index + 1
        
        MouseGetPos(&mx, &my)
        CountdownGui.Move(mx + 20, my + 20)
        
        countdownText.Text := remaining
        
        if (remaining <= 3)
            countdownText.SetFont("c0xFF0000")
        
        Sleep(1000)
    }
    
    CountdownGui.Destroy()
    CountdownGui := ""
}

; ============================================
; AUTOMATIC THERMOS DETECTION
; ============================================

DetectThermosRegion() {
    global TesseractPath, DataFolder, Settings
    
    LogToGUI("Auto-detecting thermos position...")
    
    if (TesseractPath = "") {
        LogToGUI("ERROR: Tesseract not found!")
        LogToGUI("Install from: https://github.com/UB-Mannheim/tesseract/wiki")
        return false
    }
    
    if (!WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        LogToGUI("ERROR: Roblox window not found")
        return false
    }
    
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_exe RobloxPlayerBeta.exe")
    
    searchAreas := [
        {name: "Center", x: wx + Round(ww * 0.40), y: wy + Round(wh * 0.15), w: Round(ww * 0.20), h: Round(wh * 0.70)},
        {name: "Left-Center", x: wx + Round(ww * 0.25), y: wy + Round(wh * 0.15), w: Round(ww * 0.30), h: Round(wh * 0.70)},
        {name: "Right-Center", x: wx + Round(ww * 0.45), y: wy + Round(wh * 0.15), w: Round(ww * 0.30), h: Round(wh * 0.70)}
    ]
    
    foundArea := ""
    foundText := ""
    
    for area in searchAreas {
        LogToGUI("Searching " . area.name . " area: " . area.w . "x" . area.h)
        
        imageFile := DataFolder . "\thermos_search_" . area.name . ".png"
        outputFileBase := DataFolder . "\thermos_search_ocr_" . area.name
        outputTxtFile := outputFileBase . ".txt"
        
        if (FileExist(outputTxtFile))
            FileDelete(outputTxtFile)
        if (FileExist(imageFile))
            FileDelete(imageFile)
        
        pBitmap := CaptureScreenRegion(area.x, area.y, area.w, area.h)
        SaveBitmapToPNG(pBitmap, imageFile)
        DllCall("Gdiplus\GdipDisposeImage", "Ptr", pBitmap)
        
        tesseractCmd := '"' . TesseractPath . '" "' . imageFile . '" "' . outputFileBase . '" --psm 6 -l eng'
        RunWait(tesseractCmd, , "Hide")
        Sleep(300)
        
        if (FileExist(outputTxtFile)) {
            text := FileRead(outputTxtFile)
            textUpper := StrUpper(text)
            
            hasRisk := InStr(textUpper, "RISK")
            hasLapse := InStr(textUpper, "LAPSE")
            hasCape := InStr(textUpper, "CAPE")
            hasThermo := InStr(textUpper, "THERMODYNAMICS")
            hasShear := InStr(textUpper, "SHEAR")
            hasDew := InStr(textUpper, "DEW")
            
            keywordCount := hasRisk + hasLapse + hasCape + hasThermo + hasShear + hasDew
            
            if (keywordCount >= 3) {
                LogToGUI("Found thermos in " . area.name . " area! (Keywords: " . keywordCount . ")")
                foundArea := area
                foundText := textUpper
                break
            } else {
                LogToGUI(area.name . " area: Only " . keywordCount . " keywords found")
            }
        }
    }
    
    if (foundArea = "") {
        LogToGUI("ERROR: Could not find thermos in any search area")
        LogToGUI("Please use Manual Calibration (F6)")
        return false
    }
    
    LogToGUI("Thermos detected in " . foundArea.name . " area!")
    
    ocrX := foundArea.x
    ocrY := foundArea.y
    ocrW := foundArea.w
    ocrH := foundArea.h
    
    Settings.OCRRegion.x := ocrX
    Settings.OCRRegion.y := ocrY
    Settings.OCRRegion.w := ocrW
    Settings.OCRRegion.h := ocrH
    
    SaveSettings()
    
    LogToGUI("Auto-calibration complete!")
    LogToGUI("Region: " . ocrW . "x" . ocrH . " at (" . ocrX . ", " . ocrY . ")")
    LogToGUI("Testing detection...")
    
    Sleep(1000)
    testResult := ReadThermosOCR()
    
    if (testResult.success) {
        LogToGUI("SUCCESS! Thermos verified!")
        LogToGUI("Risk: " . testResult.risk)
        SoundBeep(1200, 300)
        return true
    } else {
        LogToGUI("WARNING: Verification failed")
        LogToGUI("Try Manual Calibration (F6)")
        return false
    }
}

; ============================================
; TESSERACT OCR FUNCTIONS
; ============================================

ReadThermosOCR() {
    global TesseractPath, DataFolder, Settings
    
    try {
        if (TesseractPath = "") {
            return {
                success: false, 
                error: "Tesseract not found. Please install Tesseract OCR."
            }
        }
        
        if (!FileExist(TesseractPath)) {
            return {
                success: false, 
                error: "Tesseract not found at: " . TesseractPath
            }
        }
        
        if (!WinExist("ahk_exe RobloxPlayerBeta.exe"))
            return {success: false, error: "Roblox window not found"}
        
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_exe RobloxPlayerBeta.exe")
        
        if (Settings.OCRRegion.w > 0 && Settings.OCRRegion.h > 0) {
            ocrX := Settings.OCRRegion.x
            ocrY := Settings.OCRRegion.y
            ocrW := Settings.OCRRegion.w
            ocrH := Settings.OCRRegion.h
            LogToGUI("Using calibrated OCR region")
        } else {
            ocrX := wx + 20
            ocrY := wy + 50
            ocrW := 420
            ocrH := 700
            LogToGUI("Using default OCR region")
        }
        
        LogToGUI("Capturing: " . Round(ocrX) . "," . Round(ocrY) . " " . Round(ocrW) . "x" . Round(ocrH))
        
        imageFile := DataFolder . "\thermos_capture.png"
        outputFileBase := DataFolder . "\thermos_ocr"
        outputTxtFile := outputFileBase . ".txt"
        
        if (FileExist(outputTxtFile))
            FileDelete(outputTxtFile)
        
        pBitmap := CaptureScreenRegion(ocrX, ocrY, ocrW, ocrH)
        SaveBitmapToPNG(pBitmap, imageFile)
        DllCall("Gdiplus\GdipDisposeImage", "Ptr", pBitmap)
        
        LogToGUI("Screenshot saved: " . imageFile)
        
        if (!FileExist(imageFile)) {
            LogToGUI("ERROR: Screenshot file was not created!")
            return {success: false, error: "Screenshot not created"}
        }
        
        LogToGUI("Running Tesseract OCR...")
        
        tesseractCmd := '"' . TesseractPath . '" "' . imageFile . '" "' . outputFileBase . '" --psm 6 -l eng'
        LogToGUI("Tesseract command: " . tesseractCmd)
        
        result := RunWait(tesseractCmd, , "Hide")
        LogToGUI("Tesseract exit code: " . result)
        
        Sleep(500)
        
        if (!FileExist(outputTxtFile)) {
            LogToGUI("ERROR: Tesseract output file not found at: " . outputTxtFile)
            LogToGUI("Check if Tesseract is properly installed")
            return {success: false, error: "OCR output not generated"}
        }
        
        text := FileRead(outputTxtFile)
        
        if (text != "") {
            LogToGUI("OCR read " . StrLen(text) . " characters")
            
            rawFile := DataFolder . "\thermos_ocr_raw.txt"
            if (FileExist(rawFile))
                FileDelete(rawFile)
            FileAppend(text, rawFile)
            
            return ParseThermosText(text)
        } else {
            LogToGUI("OCR returned empty text!")
            LogToGUI("Check screenshot: " . imageFile)
            return {success: false, error: "No text detected"}
        }
        
    } catch as err {
        LogToGUI("OCR Error: " . err.Message)
        return {success: false, error: err.Message}
    }
}

CaptureScreenRegion(x, y, w, h) {
    static token := 0
    if (!token) {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si)
        DllCall("Gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
    }
    
    hDC := DllCall("GetDC", "Ptr", 0, "Ptr")
    hCDC := DllCall("CreateCompatibleDC", "Ptr", hDC, "Ptr")
    hBmp := DllCall("CreateCompatibleBitmap", "Ptr", hDC, "Int", w, "Int", h, "Ptr")
    DllCall("SelectObject", "Ptr", hCDC, "Ptr", hBmp)
    DllCall("BitBlt", "Ptr", hCDC, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hDC, "Int", x, "Int", y, "UInt", 0x00CC0020)
    DllCall("Gdiplus\GdipCreateBitmapFromHBITMAP", "Ptr", hBmp, "Ptr", 0, "Ptr*", &pBitmap := 0)
    DllCall("DeleteObject", "Ptr", hBmp)
    DllCall("DeleteDC", "Ptr", hCDC)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hDC)
    return pBitmap
}

SaveBitmapToPNG(pBitmap, filename) {
    CLSID := Buffer(16)
    
    NumPut("UInt", 0x557CF406, CLSID, 0)
    NumPut("UShort", 0x1A04, CLSID, 4)
    NumPut("UShort", 0x11D3, CLSID, 6)
    NumPut("UChar", 0x9A, CLSID, 8)
    NumPut("UChar", 0x73, CLSID, 9)
    NumPut("UChar", 0x00, CLSID, 10)
    NumPut("UChar", 0x00, CLSID, 11)
    NumPut("UChar", 0xF8, CLSID, 12)
    NumPut("UChar", 0x1E, CLSID, 13)
    NumPut("UChar", 0xF3, CLSID, 14)
    NumPut("UChar", 0x2E, CLSID, 15)
    
    result := DllCall("Gdiplus\GdipSaveImageToFile", "Ptr", pBitmap, "WStr", filename, "Ptr", CLSID, "Ptr", 0)
    
    if (result != 0) {
        LogToGUI("Warning: Failed to save PNG (code: " . result . ")")
    }
}

ParseThermosText(text) {
    result := {
        success: false,
        risk: "",
        lapseRate: 0,
        windShear: 0,
        cape: 0,
        dewPoint: 0,
        relativeHumidity: 0,
        rawText: text,
        error: ""
    }
    
    text := StrReplace(text, "`r", "")
    text := StrReplace(text, "`n", " ")
    text := StrReplace(text, "`t", " ")
    
    while (InStr(text, "  "))
        text := StrReplace(text, "  ", " ")
    
    textUpper := StrUpper(text)
    
    LogToGUI("Raw OCR text: " . SubStr(textUpper, 1, 200))
    
    if (!InStr(textUpper, "RISK") && !InStr(textUpper, "LAPSE") && !InStr(textUpper, "CAPE")) {
        result.error := "Not thermos interface - captured chat or other UI"
        LogToGUI("ERROR: Captured wrong interface (possibly chat)")
        LogToGUI("Try repositioning or reopening thermos")
        return result
    }
    
    if (InStr(textUpper, "HIGH") && InStr(textUpper, "RISK")) {
        result.risk := "HIGH"
        LogToGUI("Found risk: HIGH")
    } else if (InStr(textUpper, "MODERATE")) {
        result.risk := "MODERATE"
        LogToGUI("Found risk: MODERATE")
    } else if (InStr(textUpper, "SLIGHT")) {
        result.risk := "SLIGHT"
        LogToGUI("Found risk: SLIGHT")
    } else if (InStr(textUpper, "ENHAN") || InStr(textUpper, "HANCED") || (InStr(textUpper, "IAN") && InStr(textUpper, "CED"))) {
        result.risk := "ENHANCED"
        LogToGUI("Found risk: ENHANCED (detected fragmented text)")
    } else if (InStr(textUpper, "MARGINAL") || InStr(textUpper, "MARG")) {
        result.risk := "MARGINAL"
        LogToGUI("Found risk: MARGINAL")
    } else if (InStr(textUpper, "TSTM") || InStr(textUpper, "T-STM")) {
        result.risk := "TSTM"
        LogToGUI("Found risk: TSTM")
    }
    
    if (RegExMatch(textUpper, "LAPSE[^0-9]*(\d+)[\.,](\d)", &match)) {
        result.lapseRate := Float(match[1] . "." . match[2])
        LogToGUI("Found lapse rate: " . result.lapseRate . "C")
    } else if (RegExMatch(textUpper, "LAPSE[^0-9]*(\d+)\s*[CÂ°]", &match)) {
        result.lapseRate := Float(match[1])
        LogToGUI("Found lapse rate: " . result.lapseRate . "C")
    } else if (RegExMatch(textUpper, "(\d+)[\.,](\d+)\s*[Â°]?\s*C", &match)) {
        result.lapseRate := Float(match[1] . "." . match[2])
        LogToGUI("Found lapse rate: " . result.lapseRate . "C (fallback pattern)")
    }
    
    if (RegExMatch(textUpper, "DEW\s*POINT[^0-9]*(\d+)[\.,]?(\d*)", &match)) {
        if (match.Count >= 2 && match[2] != "") {
            result.dewPoint := Float(match[1] . "." . match[2])
        } else {
            result.dewPoint := Float(match[1])
        }
        LogToGUI("Found dew point: " . result.dewPoint . "F")
    } else if (RegExMatch(textUpper, "DEW[^0-9]*(\d+)[\.,]?(\d*)", &match)) {
        if (match.Count >= 2 && match[2] != "") {
            result.dewPoint := Float(match[1] . "." . match[2])
        } else {
            result.dewPoint := Float(match[1])
        }
        LogToGUI("Found dew point: " . result.dewPoint . "F (pattern 2)")
    } else if (RegExMatch(textUpper, "(\d{2})\s*Â°?\s*F", &match)) {
        dewValue := Float(match[1])
        if (dewValue >= 30 && dewValue <= 90) {
            result.dewPoint := dewValue
            LogToGUI("Found dew point: " . result.dewPoint . "F (fallback pattern)")
        }
    }
    
    if (RegExMatch(textUpper, "CAPE[^0-9]*(\d{3,4})[\.,]?(\d*)", &match)) {
        if (match.Count >= 2 && match[2] != "") {
            result.cape := Float(match[1] . "." . match[2])
        } else {
            result.cape := Float(match[1])
        }
        LogToGUI("Found CAPE: " . result.cape . " J/Kg")
    } else if (RegExMatch(textUpper, "(\d{3,4})\s*J", &match)) {
        result.cape := Float(match[1])
        LogToGUI("Found CAPE: " . result.cape . " J/Kg (fallback pattern)")
    }
    
    if (RegExMatch(textUpper, "SHEAR[^0-9]*(\d+)[\.,]?(\d*)", &match)) {
        if (match.Count >= 2 && match[2] != "") {
            result.windShear := Float(match[1] . "." . match[2])
        } else {
            result.windShear := Float(match[1])
        }
        LogToGUI("Found wind shear: " . result.windShear . " kts")
    } else if (RegExMatch(textUpper, "(\d+)\s*KTS", &match)) {
        shearValue := Float(match[1])
        if (shearValue >= 0 && shearValue <= 60) {
            result.windShear := shearValue
            LogToGUI("Found wind shear: " . result.windShear . " kts (fallback pattern)")
        }
    }
    
    if (RegExMatch(textUpper, "HUMID[^0-9]*(\d{2})[\.,]?(\d*)\s*[%l1I]", &match)) {
        humidValue := Float(match[1])
        if (match.Count >= 2 && match[2] != "" && match[2] != "1") {
            humidValue := Float(match[1] . "." . match[2])
        }
        if (humidValue <= 100) {
            result.relativeHumidity := humidValue
            LogToGUI("Found relative humidity: " . result.relativeHumidity . "%")
        }
    } else if (RegExMatch(textUpper, "(\d{2})\s*[%l1I]", &match)) {
        humidValue := Float(match[1])
        if (humidValue >= 10 && humidValue <= 100) {
            result.relativeHumidity := humidValue
            LogToGUI("Found relative humidity: " . result.relativeHumidity . "% (fallback pattern)")
        }
    }
    
    if (result.lapseRate = 0)
        LogToGUI("WARNING: Lapse Rate not found in OCR text")
    if (result.cape = 0)
        LogToGUI("WARNING: CAPE not found in OCR text")
    if (result.dewPoint = 0)
        LogToGUI("WARNING: Dew Point not found in OCR text")
    if (result.windShear = 0)
        LogToGUI("WARNING: Wind Shear not found in OCR text")
    if (result.relativeHumidity = 0)
        LogToGUI("WARNING: Relative Humidity not found in OCR text")
    
    result.success := (result.risk != "")
    
    if (!result.success) {
        result.error := "Failed to parse risk level"
        LogToGUI("Failed to parse risk level!")
    }
    
    return result
}

; ============================================
; WEBHOOK FUNCTION
; ============================================

SendWebhook(ocrResult) {
    global Settings, Attempts, DataFolder
    
    if (!Settings.WebhookEnabled || Settings.WebhookURL = "")
        return
    
    try {
        lapseStr := (Mod(ocrResult.lapseRate, 1) = 0) ? Integer(ocrResult.lapseRate) : Round(ocrResult.lapseRate, 1)
        shearStr := (Mod(ocrResult.windShear, 1) = 0) ? Integer(ocrResult.windShear) : Round(ocrResult.windShear, 1)
        capeStr := (Mod(ocrResult.cape, 1) = 0) ? Integer(ocrResult.cape) : Round(ocrResult.cape, 1)
        dewStr := (Mod(ocrResult.dewPoint, 1) = 0) ? Integer(ocrResult.dewPoint) : Round(ocrResult.dewPoint, 1)
        humidStr := (Mod(ocrResult.relativeHumidity, 1) = 0) ? Integer(ocrResult.relativeHumidity) : Round(ocrResult.relativeHumidity, 1)
        
        pingContent := ""
        if (Settings.WebhookUserID != "" || Settings.WebhookRoleID != "") {
            if (Settings.WebhookUserID != "")
                pingContent .= "<@" . Settings.WebhookUserID . "> "
            if (Settings.WebhookRoleID != "")
                pingContent .= "<@&" . Settings.WebhookRoleID . "> "
        }
        
        currentTime := FormatTime(, "yyyy-MM-dd'T'HH:mm:ss'Z'")
        
        embedJson := '{'
        
        if (pingContent != "")
            embedJson .= '"content": "' . pingContent . '",'
        
        embedJson .= '"embeds": [{'
        embedJson .= '"title": "Helicity - Perfect Server Found!",'
        embedJson .= '"description": "ReHelicity has found a server matching your criteria!",'
        embedJson .= '"color": 8663711,'
        embedJson .= '"fields": ['
        
        embedJson .= '{"name": "━━━━━━━━━━━━━━━━━━━━","value": " ","inline": false},'
        embedJson .= '{"name": "Server Information","value": " ","inline": false},'
        embedJson .= '{"name": "Risk Level","value": "**' . ocrResult.risk . '**","inline": true},'
        embedJson .= '{"name": "Attempts","value": "**' . Attempts . '**","inline": true},'
        embedJson .= '{"name": "Time Found","value": "**' . FormatTime(, "HH:mm:ss") . '**","inline": true},'
        
        embedJson .= '{"name": "━━━━━━━━━━━━━━━━━━━━","value": " ","inline": false},'
        embedJson .= '{"name": "Thermodynamics","value": " ","inline": false},'
        
        if (Settings.LapseRate.enabled || ocrResult.lapseRate > 0)
            embedJson .= '{"name": "Lapse Rate","value": "**' . lapseStr . ' C**","inline": true},'
        
        if (Settings.CAPE.enabled || ocrResult.cape > 0)
            embedJson .= '{"name": "CAPE","value": "**' . capeStr . ' J/Kg**","inline": true},'
        
        if (Settings.DewPoint.enabled || ocrResult.dewPoint > 0)
            embedJson .= '{"name": "Dew Point","value": "**' . dewStr . ' F**","inline": true},'
        
        if (Settings.WindShear.enabled || ocrResult.windShear > 0)
            embedJson .= '{"name": "Wind Shear","value": "**' . shearStr . ' kts**","inline": true},'
        
        if (Settings.RelativeHumidity.enabled || ocrResult.relativeHumidity > 0)
            embedJson .= '{"name": "Relative Humidity","value": "**' . humidStr . '%**","inline": true},'
        
        embedJson .= '{"name": "━━━━━━━━━━━━━━━━━━━━","value": " ","inline": false},'
        embedJson .= '{"name": "Private Server Link","value": "[Click to Join Server](' . Settings.ServerLink . ')","inline": false}'
        
        embedJson .= '],'
        embedJson .= '"footer": {"text": "ReHelicity Reroller"},'
        embedJson .= '"timestamp": "' . currentTime . '"'
        embedJson .= '}]}'
        
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("POST", Settings.WebhookURL, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.Send(embedJson)
        
        LogToGUI("Webhook sent successfully")
    } catch as err {
        LogToGUI("Webhook error: " . err.Message)
    }
}

TestWebhook() {
    global Settings
    
    if (Settings.WebhookURL = "") {
        MsgBox("Please enter a webhook URL first!", "Error", "Icon!")
        return
    }
    
    LogToGUI("Sending test webhook...")
    
    testResult := {
        risk: "HIGH",
        lapseRate: 8.5,
        windShear: 45,
        cape: 3500,
        dewPoint: 72,
        relativeHumidity: 85
    }
    
    SendWebhook(testResult)
    MsgBox("Test webhook sent! Check your Discord channel.", "Test Complete", "Iconi")
}

; ============================================
; SETTINGS FUNCTIONS
; ============================================

LoadSettings() {
    global Settings, SettingsFile
    
    if (!FileExist(SettingsFile)) {
        SaveSettings()
        return
    }
    
    try {
        Settings.ServerLink := IniRead(SettingsFile, "General", "ServerLink", Settings.ServerLink)
        Settings.UseBloxstrap := IniRead(SettingsFile, "General", "UseBloxstrap", "0") = "1"
        Settings.TargetRisk := IniRead(SettingsFile, "General", "TargetRisk", Settings.TargetRisk)
        Settings.KeyPressDelay := Integer(IniRead(SettingsFile, "Timing", "KeyPressDelay", Settings.KeyPressDelay))
        Settings.InitialWaitAfterJoin := Integer(IniRead(SettingsFile, "Timing", "InitialWaitAfterJoin", Settings.InitialWaitAfterJoin))
        Settings.SpawnDelay := Integer(IniRead(SettingsFile, "Timing", "SpawnDelay", Settings.SpawnDelay))
        Settings.LapseRate.enabled := IniRead(SettingsFile, "LapseRate", "Enabled", "0") = "1"
        Settings.LapseRate.comparison := IniRead(SettingsFile, "LapseRate", "Comparison", ">=")
        Settings.LapseRate.value := Float(IniRead(SettingsFile, "LapseRate", "Value", "0"))
        Settings.WindShear.enabled := IniRead(SettingsFile, "WindShear", "Enabled", "0") = "1"
        Settings.WindShear.comparison := IniRead(SettingsFile, "WindShear", "Comparison", ">=")
        Settings.WindShear.value := Float(IniRead(SettingsFile, "WindShear", "Value", "0"))
        Settings.CAPE.enabled := IniRead(SettingsFile, "CAPE", "Enabled", "0") = "1"
        Settings.CAPE.comparison := IniRead(SettingsFile, "CAPE", "Comparison", ">=")
        Settings.CAPE.value := Float(IniRead(SettingsFile, "CAPE", "Value", "0"))
        Settings.DewPoint.enabled := IniRead(SettingsFile, "DewPoint", "Enabled", "0") = "1"
        Settings.DewPoint.comparison := IniRead(SettingsFile, "DewPoint", "Comparison", ">=")
        Settings.DewPoint.value := Float(IniRead(SettingsFile, "DewPoint", "Value", "0"))
        Settings.RelativeHumidity.enabled := IniRead(SettingsFile, "RelativeHumidity", "Enabled", "0") = "1"
        Settings.RelativeHumidity.comparison := IniRead(SettingsFile, "RelativeHumidity", "Comparison", ">=")
        Settings.RelativeHumidity.value := Float(IniRead(SettingsFile, "RelativeHumidity", "Value", "0"))
        Settings.OCRRegion.x := Integer(IniRead(SettingsFile, "OCRRegion", "X", "0"))
        Settings.OCRRegion.y := Integer(IniRead(SettingsFile, "OCRRegion", "Y", "0"))
        Settings.OCRRegion.w := Integer(IniRead(SettingsFile, "OCRRegion", "W", "0"))
        Settings.OCRRegion.h := Integer(IniRead(SettingsFile, "OCRRegion", "H", "0"))
        Settings.WebhookURL := IniRead(SettingsFile, "Webhook", "URL", "")
        Settings.WebhookEnabled := IniRead(SettingsFile, "Webhook", "Enabled", "0") = "1"
        Settings.WebhookUserID := IniRead(SettingsFile, "Webhook", "UserID", "")
        Settings.WebhookRoleID := IniRead(SettingsFile, "Webhook", "RoleID", "")
    }
}

SaveSettings() {
    global Settings, SettingsFile
    
    try {
        IniWrite(Settings.ServerLink, SettingsFile, "General", "ServerLink")
        IniWrite(Settings.UseBloxstrap ? "1" : "0", SettingsFile, "General", "UseBloxstrap")
        IniWrite(Settings.TargetRisk, SettingsFile, "General", "TargetRisk")
        IniWrite(String(Settings.KeyPressDelay), SettingsFile, "Timing", "KeyPressDelay")
        IniWrite(String(Settings.InitialWaitAfterJoin), SettingsFile, "Timing", "InitialWaitAfterJoin")
        IniWrite(String(Settings.SpawnDelay), SettingsFile, "Timing", "SpawnDelay")
        IniWrite(Settings.LapseRate.enabled ? "1" : "0", SettingsFile, "LapseRate", "Enabled")
        IniWrite(Settings.LapseRate.comparison, SettingsFile, "LapseRate", "Comparison")
        IniWrite(String(Settings.LapseRate.value), SettingsFile, "LapseRate", "Value")
        IniWrite(Settings.WindShear.enabled ? "1" : "0", SettingsFile, "WindShear", "Enabled")
        IniWrite(Settings.WindShear.comparison, SettingsFile, "WindShear", "Comparison")
        IniWrite(String(Settings.WindShear.value), SettingsFile, "WindShear", "Value")
        IniWrite(Settings.CAPE.enabled ? "1" : "0", SettingsFile, "CAPE", "Enabled")
        IniWrite(Settings.CAPE.comparison, SettingsFile, "CAPE", "Comparison")
        IniWrite(String(Settings.CAPE.value), SettingsFile, "CAPE", "Value")
        IniWrite(Settings.DewPoint.enabled ? "1" : "0", SettingsFile, "DewPoint", "Enabled")
        IniWrite(Settings.DewPoint.comparison, SettingsFile, "DewPoint", "Comparison")
        IniWrite(String(Settings.DewPoint.value), SettingsFile, "DewPoint", "Value")
        IniWrite(Settings.RelativeHumidity.enabled ? "1" : "0", SettingsFile, "RelativeHumidity", "Enabled")
        IniWrite(Settings.RelativeHumidity.comparison, SettingsFile, "RelativeHumidity", "Comparison")
        IniWrite(String(Settings.RelativeHumidity.value), SettingsFile, "RelativeHumidity", "Value")
        IniWrite(String(Settings.OCRRegion.x), SettingsFile, "OCRRegion", "X")
        IniWrite(String(Settings.OCRRegion.y), SettingsFile, "OCRRegion", "Y")
        IniWrite(String(Settings.OCRRegion.w), SettingsFile, "OCRRegion", "W")
        IniWrite(String(Settings.OCRRegion.h), SettingsFile, "OCRRegion", "H")
        IniWrite(Settings.WebhookURL, SettingsFile, "Webhook", "URL")
        IniWrite(Settings.WebhookEnabled ? "1" : "0", SettingsFile, "Webhook", "Enabled")
        IniWrite(Settings.WebhookUserID, SettingsFile, "Webhook", "UserID")
        IniWrite(Settings.WebhookRoleID, SettingsFile, "Webhook", "RoleID")
    }
}

; ============================================
; GUI FUNCTIONS
; ============================================

CreateGUI() {
    global MainGui, LogBox, StatusText, AttemptText, TesseractPath, Settings
    
    MainGui := Gui("+Resize", "Helicity Reroller v1.01")
    MainGui.BackColor := "0x0a0a0a"
    MainGui.SetFont("s10", "Segoe UI")
    MainGui.OnEvent("Close", OnGuiClose)
    
    MainGui.SetFont("s14 bold", "Segoe UI")
    MainGui.Add("Text", "x20 y20 w760 cWhite Center", "ReHelicity")
    MainGui.SetFont("s10", "Segoe UI")
    
    MainGui.Add("GroupBox", "x20 y60 w760 h80 c0x555555", "Status")
    StatusText := MainGui.Add("Text", "x40 y85 w720 c0xcccccc", "Status: Ready")
    AttemptText := MainGui.Add("Text", "x40 y110 w720 c0xcccccc", "Attempts: 0")
    
    MainGui.SetFont("s10 cWhite", "Segoe UI")
    tabControl := MainGui.Add("Tab3", "x20 y150 w760 h600 Background0x1a1a1a cWhite", ["Main", "Config", "Logs"])
    MainGui.SetFont("s10", "Segoe UI")
    
    tabControl.UseTab(1)
    
    MainGui.Add("GroupBox", "x40 y190 w720 h120 c0x555555", "Controls")
    
    btnStart := MainGui.Add("Button", "x60 y220 w330 h40 Background0x2a7a2a c0xffffff", "Start (F2)")
    btnStart.OnEvent("Click", (*) => StartReroller())
    
    btnStop := MainGui.Add("Button", "x410 y220 w330 h40 Background0x7a2a2a c0xffffff", "Stop (F3)")
    btnStop.OnEvent("Click", (*) => StopAll())
    
    btnTest := MainGui.Add("Button", "x60 y270 w680 h30 Background0x2a4a7a c0xffffff", "Test OCR (F4)")
    btnTest.OnEvent("Click", (*) => TestThermosRead())
    
    MainGui.Add("GroupBox", "x40 y320 w720 h80 c0x555555", "Target Risk Level")
    MainGui.Add("Text", "x60 y350 w100 c0xcccccc", "Risk Level:")
    ddRisk := MainGui.Add("DropDownList", "x170 y347 w200 Background0x1a1a1a c0xffffff", ["TSTM", "MARGINAL", "ENHANCED", "SLIGHT", "MODERATE", "HIGH"])
    ddRisk.Text := Settings.TargetRisk
    ddRisk.OnEvent("Change", (*) => (Settings.TargetRisk := ddRisk.Text, SaveSettings()))
    
    MainGui.Add("GroupBox", "x40 y410 w720 h320 c0x555555", "Optional Filters")
    
    yPos := 445
    chkLapse := MainGui.Add("Checkbox", "x60 y" . yPos . " w150 c0xcccccc", "Lapse Rate")
    chkLapse.Value := Settings.LapseRate.enabled
    chkLapse.OnEvent("Click", (*) => (Settings.LapseRate.enabled := chkLapse.Value, SaveSettings()))
    ddLapseComp := MainGui.Add("DropDownList", "x220 y" . (yPos-3) . " w70 Background0x1a1a1a c0xffffff", [">=", "<=", "="])
    ddLapseComp.Text := Settings.LapseRate.comparison
    ddLapseComp.OnEvent("Change", (*) => (Settings.LapseRate.comparison := ddLapseComp.Text, SaveSettings()))
    editLapseVal := MainGui.Add("Edit", "x300 y" . (yPos-3) . " w100 h25 Background0x1a1a1a c0xffffff", Settings.LapseRate.value)
    editLapseVal.OnEvent("Change", (*) => ValidateFloatInput(editLapseVal, "LapseRate"))
    MainGui.Add("Text", "x410 y" . yPos . " w100 c0x888888", "C (max 10)")
    
    yPos += 50
    chkShear := MainGui.Add("Checkbox", "x60 y" . yPos . " w150 c0xcccccc", "Wind Shear")
    chkShear.Value := Settings.WindShear.enabled
    chkShear.OnEvent("Click", (*) => (Settings.WindShear.enabled := chkShear.Value, SaveSettings()))
    ddShearComp := MainGui.Add("DropDownList", "x220 y" . (yPos-3) . " w70 Background0x1a1a1a c0xffffff", [">=", "<=", "="])
    ddShearComp.Text := Settings.WindShear.comparison
    ddShearComp.OnEvent("Change", (*) => (Settings.WindShear.comparison := ddShearComp.Text, SaveSettings()))
    editShearVal := MainGui.Add("Edit", "x300 y" . (yPos-3) . " w100 h25 Background0x1a1a1a c0xffffff", Settings.WindShear.value)
    editShearVal.OnEvent("Change", (*) => ValidateFloatInput(editShearVal, "WindShear"))
    MainGui.Add("Text", "x410 y" . yPos . " w100 c0x888888", "kts (max 55)")
    
    yPos += 50
    chkCAPE := MainGui.Add("Checkbox", "x60 y" . yPos . " w150 c0xcccccc", "CAPE")
    chkCAPE.Value := Settings.CAPE.enabled
    chkCAPE.OnEvent("Click", (*) => (Settings.CAPE.enabled := chkCAPE.Value, SaveSettings()))
    ddCAPEComp := MainGui.Add("DropDownList", "x220 y" . (yPos-3) . " w70 Background0x1a1a1a c0xffffff", [">=", "<=", "="])
    ddCAPEComp.Text := Settings.CAPE.comparison
    ddCAPEComp.OnEvent("Change", (*) => (Settings.CAPE.comparison := ddCAPEComp.Text, SaveSettings()))
    editCAPEVal := MainGui.Add("Edit", "x300 y" . (yPos-3) . " w100 h25 Background0x1a1a1a c0xffffff", Settings.CAPE.value)
    editCAPEVal.OnEvent("Change", (*) => ValidateFloatInput(editCAPEVal, "CAPE"))
    MainGui.Add("Text", "x410 y" . yPos . " w120 c0x888888", "J/Kg (max 7000)")
    
    yPos += 50
    chkDew := MainGui.Add("Checkbox", "x60 y" . yPos . " w150 c0xcccccc", "Dew Point")
    chkDew.Value := Settings.DewPoint.enabled
    chkDew.OnEvent("Click", (*) => (Settings.DewPoint.enabled := chkDew.Value, SaveSettings()))
    ddDewComp := MainGui.Add("DropDownList", "x220 y" . (yPos-3) . " w70 Background0x1a1a1a c0xffffff", [">=", "<=", "="])
    ddDewComp.Text := Settings.DewPoint.comparison
    ddDewComp.OnEvent("Change", (*) => (Settings.DewPoint.comparison := ddDewComp.Text, SaveSettings()))
    editDewVal := MainGui.Add("Edit", "x300 y" . (yPos-3) . " w100 h25 Background0x1a1a1a c0xffffff", Settings.DewPoint.value)
    editDewVal.OnEvent("Change", (*) => ValidateFloatInput(editDewVal, "DewPoint"))
    MainGui.Add("Text", "x410 y" . yPos . " w100 c0x888888", "F (max 90)")
    
    yPos += 50
    chkHumid := MainGui.Add("Checkbox", "x60 y" . yPos . " w150 c0xcccccc", "Rel. Humidity")
    chkHumid.Value := Settings.RelativeHumidity.enabled
    chkHumid.OnEvent("Click", (*) => (Settings.RelativeHumidity.enabled := chkHumid.Value, SaveSettings()))
    ddHumidComp := MainGui.Add("DropDownList", "x220 y" . (yPos-3) . " w70 Background0x1a1a1a c0xffffff", [">=", "<=", "="])
    ddHumidComp.Text := Settings.RelativeHumidity.comparison
    ddHumidComp.OnEvent("Change", (*) => (Settings.RelativeHumidity.comparison := ddHumidComp.Text, SaveSettings()))
    editHumidVal := MainGui.Add("Edit", "x300 y" . (yPos-3) . " w100 h25 Background0x1a1a1a c0xffffff", Settings.RelativeHumidity.value)
    editHumidVal.OnEvent("Change", (*) => ValidateFloatInput(editHumidVal, "RelativeHumidity"))
    MainGui.Add("Text", "x410 y" . yPos . " w100 c0x888888", "% (max 100)")
    
    tabControl.UseTab(2)
    
    MainGui.Add("GroupBox", "x40 y190 w720 h120 c0x555555", "Server Settings")
    MainGui.Add("Text", "x60 y220 w120 c0xcccccc", "Server Link:")
    editServerLink := MainGui.Add("Edit", "x180 y217 w550 h25 Background0x1a1a1a c0xffffff", Settings.ServerLink)
    editServerLink.OnEvent("Change", (*) => (Settings.ServerLink := editServerLink.Value, SaveSettings()))
    
    chkBloxstrap := MainGui.Add("Checkbox", "x60 y255 w200 c0xcccccc", "Use Bloxstrap")
    chkBloxstrap.Value := Settings.UseBloxstrap
    chkBloxstrap.OnEvent("Click", (*) => (Settings.UseBloxstrap := chkBloxstrap.Value, SaveSettings()))
    
    MainGui.Add("GroupBox", "x40 y320 w720 h150 c0x555555", "Discord Webhook")
    MainGui.Add("Text", "x60 y350 w120 c0xcccccc", "Webhook URL:")
    editWebhook := MainGui.Add("Edit", "x180 y347 w550 h25 Background0x1a1a1a c0xffffff", Settings.WebhookURL)
    editWebhook.OnEvent("Change", (*) => (Settings.WebhookURL := editWebhook.Value, SaveSettings()))
    
    MainGui.Add("Text", "x60 y385 w120 c0xcccccc", "User ID (ping):")
    editUserID := MainGui.Add("Edit", "x180 y382 w550 h25 Background0x1a1a1a c0xffffff", Settings.WebhookUserID)
    editUserID.OnEvent("Change", (*) => (Settings.WebhookUserID := editUserID.Value, SaveSettings()))
    
    MainGui.Add("Text", "x60 y420 w120 c0xcccccc", "Role ID (ping):")
    editRoleID := MainGui.Add("Edit", "x180 y417 w550 h25 Background0x1a1a1a c0xffffff", Settings.WebhookRoleID)
    editRoleID.OnEvent("Change", (*) => (Settings.WebhookRoleID := editRoleID.Value, SaveSettings()))
    
    chkWebhook := MainGui.Add("Checkbox", "x60 y450 w250 c0xcccccc", "Enable Webhook Notifications")
    chkWebhook.Value := Settings.WebhookEnabled
    chkWebhook.OnEvent("Click", (*) => (Settings.WebhookEnabled := chkWebhook.Value, SaveSettings()))
    
    MainGui.Add("GroupBox", "x40 y480 w720 h100 c0x555555", "Timing Settings")
    
    MainGui.Add("Text", "x60 y510 w180 c0xcccccc", "Key Press Delay (ms):")
    editKeyDelay := MainGui.Add("Edit", "x250 y507 w80 h25 Background0x1a1a1a c0xffffff", Settings.KeyPressDelay)
    editKeyDelay.OnEvent("Change", (*) => ValidateIntegerInput(editKeyDelay, "KeyPressDelay"))
    
    MainGui.Add("Text", "x60 y545 w180 c0xcccccc", "Wait After Join (sec):")
    editWaitJoin := MainGui.Add("Edit", "x250 y542 w80 h25 Background0x1a1a1a c0xffffff", Settings.InitialWaitAfterJoin)
    editWaitJoin.OnEvent("Change", (*) => ValidateIntegerInput(editWaitJoin, "InitialWaitAfterJoin"))
    
    MainGui.Add("Text", "x400 y545 w160 c0xcccccc", "Spawn Delay (sec):")
    editSpawnDelay := MainGui.Add("Edit", "x570 y542 w80 h25 Background0x1a1a1a c0xffffff", Settings.SpawnDelay)
    editSpawnDelay.OnEvent("Change", (*) => ValidateIntegerInput(editSpawnDelay, "SpawnDelay"))
    
    MainGui.Add("GroupBox", "x40 y590 w720 h70 c0x555555", "OCR Region")
    MainGui.Add("Text", "x60 y620 w480 c0xcccccc", "Status: " . (Settings.OCRRegion.w > 0 ? "Calibrated - " . Settings.OCRRegion.w . "x" . Settings.OCRRegion.h . " pixels" : "Will auto-detect on first run"))
    
    btnResetOCR := MainGui.Add("Button", "x550 y615 w85 h25 Background0x7a2a2a c0xffffff", "Reset (F5)")
    btnResetOCR.OnEvent("Click", (*) => ResetOCRRegion())
    
    btnManualOCR := MainGui.Add("Button", "x645 y615 w95 h25 Background0x2a7a7a c0xffffff", "Manual (F6)")
    btnManualOCR.OnEvent("Click", (*) => ManualCalibrateOCR())
    
    tabControl.UseTab(3)
    
    MainGui.Add("Text", "x40 y190 w720 h25 c0xcccccc", "Activity Log:")
    LogBox := MainGui.Add("Edit", "x40 y220 w720 h480 ReadOnly Multi Background0x000000 cWhite -Wrap +VScroll")
    
    btnClearLog := MainGui.Add("Button", "x630 y710 w130 h30 Background0x1a1a1a c0xffffff", "Clear Log")
    btnClearLog.OnEvent("Click", (*) => (LogBox.Value := ""))
    
    tabControl.UseTab()
    
    MainGui.SetFont("s8", "Segoe UI")
    MainGui.Add("Text", "x20 y760 w760 c0x666666", "F2=Start | F3=Stop | F4=Test OCR | F5=Reset Region | F6=Manual Calibrate")
    MainGui.SetFont("s10", "Segoe UI")
    
    MainGui.Show("w800 h800")
    
    LogToGUI("=== Helicity Reroller v1.01 ===")
    LogToGUI("Script initialized successfully")
    
    if (TesseractPath != "" && FileExist(TesseractPath)) {
        LogToGUI("Tesseract found: " . TesseractPath)
    } else {
        LogToGUI("WARNING: Tesseract NOT found!")
        LogToGUI("Install from: https://github.com/UB-Mannheim/tesseract/wiki")
        LogToGUI("Checked locations:")
        LogToGUI("  - %USERPROFILE%\AppData\Local\Programs\Tesseract-OCR\")
        LogToGUI("  - C:\Program Files\Tesseract-OCR\")
        LogToGUI("  - C:\Program Files (x86)\Tesseract-OCR\")
    }
    
    if (Settings.OCRRegion.w > 0) {
        LogToGUI("Previous OCR region loaded: " . Settings.OCRRegion.w . "x" . Settings.OCRRegion.h)
    } else {
        LogToGUI("Thermos will be auto-detected on first run")
    }
}

LogToGUI(msg) {
    global LogBox, LogFile
    timestamp := FormatTime(, "HH:mm:ss")
    output := "[" . timestamp . "] " . msg
    
    if (LogBox) {
        currentText := LogBox.Value
        LogBox.Value := currentText . output . "`n"
    }
    
    try {
        FileAppend(output . "`n", LogFile)
    }
}

UpdateStatus(status) {
    global StatusText
    if (StatusText)
        StatusText.Text := "Status: " . status
}

UpdateAttempts() {
    global AttemptText, Attempts
    if (AttemptText)
        AttemptText.Text := "Attempts: " . Attempts
}

; ============================================
; HOTKEYS
; ============================================

F2::StartReroller()
F3::StopAll()
F4::TestThermosRead()
F5::ResetOCRRegion()
F6::ManualCalibrateOCR()

; ============================================
; OCR RESET & MANUAL CALIBRATION
; ============================================

ResetOCRRegion() {
    global Settings
    
    Settings.OCRRegion.x := 0
    Settings.OCRRegion.y := 0
    Settings.OCRRegion.w := 0
    Settings.OCRRegion.h := 0
    
    SaveSettings()
    
    LogToGUI("=== OCR REGION RESET ===")
    LogToGUI("OCR region has been cleared")
    LogToGUI("It will auto-detect on next run")
    LogToGUI("Make sure thermos is open and visible!")
    
    SoundBeep(800, 200)
}

ManualCalibrateOCR() {
    global Settings
    
    LogToGUI("=== MANUAL OCR CALIBRATION ===")
    LogToGUI("Opening draggable calibration overlay...")
    LogToGUI("INSTRUCTIONS:")
    LogToGUI("1. Drag and resize the WHITE box over the thermos")
    LogToGUI("2. Press ENTER to confirm")
    LogToGUI("3. Press ESC to cancel")
    
    if (!WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        LogToGUI("ERROR: Roblox window not found!")
        LogToGUI("Please open Roblox first")
        return
    }
    
    WinActivate("ahk_exe RobloxPlayerBeta.exe")
    Sleep(200)
    
    WinGetPos(&wx, &wy, &ww, &wh, "ahk_exe RobloxPlayerBeta.exe")
    
    defaultW := 400
    defaultH := 700
    startX := wx + Round((ww - defaultW) / 2)
    startY := wy + Round((wh - defaultH) / 2)
    
    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    overlayGui.BackColor := "0x000000"
    
    borderThickness := 3
    topBorder := overlayGui.Add("Progress", "x0 y0 w" . defaultW . " h" . borderThickness . " Background0xFFFFFF")
    bottomBorder := overlayGui.Add("Progress", "x0 y" . (defaultH - borderThickness) . " w" . defaultW . " h" . borderThickness . " Background0xFFFFFF")
    leftBorder := overlayGui.Add("Progress", "x0 y0 w" . borderThickness . " h" . defaultH . " Background0xFFFFFF")
    rightBorder := overlayGui.Add("Progress", "x" . (defaultW - borderThickness) . " y0 w" . borderThickness . " h" . defaultH . " Background0xFFFFFF")
    
    WinSetTransColor("0x000000", overlayGui)
    overlayGui.Show("x" . startX . " y" . startY . " w" . defaultW . " h" . defaultH . " NA")
    overlayHwnd := overlayGui.Hwnd
    
    instructGui := Gui("+AlwaysOnTop +ToolWindow", "Calibration Instructions")
    instructGui.BackColor := "0x1a1a1a"
    instructGui.SetFont("s11 bold", "Segoe UI")
    instructGui.Add("Text", "x20 y20 w360 h30 c0xFFFFFF Center", "Drag & Resize the White Box")
    instructGui.SetFont("s10", "Segoe UI")
    instructGui.Add("Text", "x20 y60 w360 h120 c0xcccccc", "• Click and drag to move`n• Drag corners/edges to resize`n• Position over the thermos`n• Press ENTER to confirm`n• Press ESC to cancel")
    
    currentX := startX
    currentY := startY
    currentW := defaultW
    currentH := defaultH
    
    posText := instructGui.Add("Text", "x20 y190 w360 h80 c0x888888", "Position: " . currentX . ", " . currentY . "`nSize: " . currentW . " x " . currentH)
    
    instructGui.Show("w400 h290")
    instructHwnd := instructGui.Hwnd
    
    dragging := false
    resizing := false
    resizeMode := ""
    startMouseX := 0
    startMouseY := 0
    startBoxX := 0
    startBoxY := 0
    startBoxW := 0
    startBoxH := 0
    confirmed := false
    cancelled := false
    
    Hotkey("Enter", ConfirmCalibration, "On")
    Hotkey("Escape", CancelCalibration, "On")
    
    SetTimer(UpdateOverlay, 10)
    
    UpdateOverlay() {
        if (!WinExist("ahk_id " . overlayHwnd) || confirmed || cancelled) {
            SetTimer(UpdateOverlay, 0)
            return
        }
        
        MouseGetPos(&mx, &my)
        
        WinGetPos(&bx, &by, &bw, &bh, "ahk_id " . overlayHwnd)
        
        edgeSize := 20
        cornerSize := 40
        
        if (GetKeyState("LButton", "P")) {
            if (!dragging && !resizing) {
                leftEdge := (mx >= bx && mx <= bx + edgeSize && my >= by && my <= by + bh)
                rightEdge := (mx >= bx + bw - edgeSize && mx <= bx + bw && my >= by && my <= by + bh)
                topEdge := (mx >= bx && mx <= bx + bw && my >= by && my <= by + edgeSize)
                bottomEdge := (mx >= bx && mx <= bx + bw && my >= by + bh - edgeSize && my <= by + bh)
                
                topLeft := (mx >= bx && mx <= bx + cornerSize && my >= by && my <= by + cornerSize)
                topRight := (mx >= bx + bw - cornerSize && mx <= bx + bw && my >= by && my <= by + cornerSize)
                bottomLeft := (mx >= bx && mx <= bx + cornerSize && my >= by + bh - cornerSize && my <= by + bh)
                bottomRight := (mx >= bx + bw - cornerSize && mx <= bx + bw && my >= by + bh - cornerSize && my <= by + bh)
                
                inBox := (mx >= bx && mx <= bx + bw && my >= by && my <= by + bh)
                
                if (topLeft) {
                    resizing := true
                    resizeMode := "TL"
                } else if (topRight) {
                    resizing := true
                    resizeMode := "TR"
                } else if (bottomLeft) {
                    resizing := true
                    resizeMode := "BL"
                } else if (bottomRight) {
                    resizing := true
                    resizeMode := "BR"
                } else if (leftEdge) {
                    resizing := true
                    resizeMode := "L"
                } else if (rightEdge) {
                    resizing := true
                    resizeMode := "R"
                } else if (topEdge) {
                    resizing := true
                    resizeMode := "T"
                } else if (bottomEdge) {
                    resizing := true
                    resizeMode := "B"
                } else if (inBox) {
                    dragging := true
                }
                
                startMouseX := mx
                startMouseY := my
                startBoxX := bx
                startBoxY := by
                startBoxW := bw
                startBoxH := bh
            }
            
            if (dragging) {
                newX := startBoxX + (mx - startMouseX)
                newY := startBoxY + (my - startMouseY)
                overlayGui.Move(newX, newY)
                currentX := newX
                currentY := newY
            } else if (resizing) {
                newX := startBoxX
                newY := startBoxY
                newW := startBoxW
                newH := startBoxH
                
                switch resizeMode {
                    case "TL":
                        newX := startBoxX + (mx - startMouseX)
                        newY := startBoxY + (my - startMouseY)
                        newW := startBoxW - (mx - startMouseX)
                        newH := startBoxH - (my - startMouseY)
                    case "TR":
                        newY := startBoxY + (my - startMouseY)
                        newW := startBoxW + (mx - startMouseX)
                        newH := startBoxH - (my - startMouseY)
                    case "BL":
                        newX := startBoxX + (mx - startMouseX)
                        newW := startBoxW - (mx - startMouseX)
                        newH := startBoxH + (my - startMouseY)
                    case "BR":
                        newW := startBoxW + (mx - startMouseX)
                        newH := startBoxH + (my - startMouseY)
                    case "L":
                        newX := startBoxX + (mx - startMouseX)
                        newW := startBoxW - (mx - startMouseX)
                    case "R":
                        newW := startBoxW + (mx - startMouseX)
                    case "T":
                        newY := startBoxY + (my - startMouseY)
                        newH := startBoxH - (my - startMouseY)
                    case "B":
                        newH := startBoxH + (my - startMouseY)
                }
                
                if (newW < 100)
                    newW := 100
                if (newH < 100)
                    newH := 100
                
                topBorder.Move(0, 0, newW, borderThickness)
                bottomBorder.Move(0, newH - borderThickness, newW, borderThickness)
                leftBorder.Move(0, 0, borderThickness, newH)
                rightBorder.Move(newW - borderThickness, 0, borderThickness, newH)
                
                overlayGui.Move(newX, newY, newW, newH)
                currentX := newX
                currentY := newY
                currentW := newW
                currentH := newH
            }
            
            try {
                posText.Text := "Position: " . currentX . ", " . currentY . "`nSize: " . currentW . " x " . currentH
            }
        } else {
            dragging := false
            resizing := false
        }
    }
    
    ConfirmCalibration(*) {
        confirmed := true
        SetTimer(UpdateOverlay, 0)
        Hotkey("Enter", "Off")
        Hotkey("Escape", "Off")
        
        try {
            overlayGui.Destroy()
        }
        try {
            instructGui.Destroy()
        }
        
        Settings.OCRRegion.x := currentX
        Settings.OCRRegion.y := currentY
        Settings.OCRRegion.w := currentW
        Settings.OCRRegion.h := currentH
        
        SaveSettings()
        
        LogToGUI("CALIBRATION COMPLETE!")
        LogToGUI("Position: " . currentX . ", " . currentY)
        LogToGUI("Size: " . currentW . " x " . currentH)
        LogToGUI("Testing in 2 seconds...")
        
        SoundBeep(1200, 300)
        Sleep(2000)
        
        TestThermosRead()
    }
    
    CancelCalibration(*) {
        cancelled := true
        SetTimer(UpdateOverlay, 0)
        Hotkey("Enter", "Off")
        Hotkey("Escape", "Off")
        
        try {
            overlayGui.Destroy()
        }
        try {
            instructGui.Destroy()
        }
        
        LogToGUI("Calibration cancelled")
        SoundBeep(400, 200)
    }
}

; ============================================
; MAIN REROLLER FUNCTIONS
; ============================================

StartReroller() {
    global Running
    
    if (Running) {
        LogToGUI("Already running!")
        return
    }
    
    Running := true
    UpdateStatus("Running...")
    LogToGUI("=== REROLLER STARTED ===")
    LogToGUI("Target: " . Settings.TargetRisk)
    
    SetTimer(RunRerollerLoop, 100)
}

RunRerollerLoop() {
    global Running, Attempts
    
    if (!Running) {
        SetTimer(RunRerollerLoop, 0)
        return
    }
    
    SetTimer(RunRerollerLoop, 0)
    
    try {
        Attempts++
        UpdateAttempts()
        LogToGUI("=== ATTEMPT #" . Attempts . " ===")
        
        if (!LaunchRoblox()) {
            StopAll()
            return
        }
        
        if (!ExecuteFullSequence()) {
            LogToGUI("Sequence failed, rerolling...")
            
            if (!Running) {
                LogToGUI("Stopped by user - not closing Roblox")
                return
            }
            
            if (QuickLeaveGame()) {
                LogToGUI("Successfully left game after sequence failure")
                Sleep(400)
            } else {
                LogToGUI("Failed to leave game, forcing close")
                CloseRoblox()
                Sleep(2000)
            }
            
            if (Running)
                SetTimer(RunRerollerLoop, 100)
            return
        }
        
        LogToGUI("Reading thermos...")
        Sleep(2000)
        
        if (Settings.OCRRegion.w <= 0) {
            LogToGUI("Auto-detecting thermos position...")
            if (!DetectThermosRegion()) {
                LogToGUI("Auto-detection failed, retrying...")
                if (!Running) {
                    LogToGUI("Stopped by user - not closing Roblox")
                    return
                }
                CloseRoblox()
                Sleep(2000)
                if (Running)
                    SetTimer(RunRerollerLoop, 2000)
                return
            }
        }
        
        ocrResult := ReadThermosOCR()
        
        if (!ocrResult.success) {
            errorMsg := ocrResult.HasOwnProp("error") ? ocrResult.error : "Unknown OCR error"
            LogToGUI("OCR failed: " . errorMsg)
            
            if (!Running) {
                LogToGUI("Stopped by user - not closing Roblox")
                return
            }
            
            if (QuickLeaveGame()) {
                LogToGUI("Successfully left game after OCR failure")
                Sleep(400)
            } else {
                LogToGUI("Failed to leave game, forcing close")
                CloseRoblox()
                Sleep(2000)
            }
            
            if (Running)
                SetTimer(RunRerollerLoop, 100)
            return
        }
        
        LogToGUI("Results: Risk=" . ocrResult.risk . " | Lapse=" . ocrResult.lapseRate . " | Shear=" . ocrResult.windShear . " | CAPE=" . ocrResult.cape . " | Dew=" . ocrResult.dewPoint . " | Humid=" . ocrResult.relativeHumidity)
        
        LogToGUI("Checking conditions...")
        LogToGUI("Target Risk: " . Settings.TargetRisk . " | Found: " . ocrResult.risk . " | Match: " . (ocrResult.risk = Settings.TargetRisk ? "YES" : "NO"))
        
        if (Settings.LapseRate.enabled)
            LogToGUI("Lapse Rate filter: " . ocrResult.lapseRate . " " . Settings.LapseRate.comparison . " " . Settings.LapseRate.value . " = " . (CompareValue(ocrResult.lapseRate, Settings.LapseRate.comparison, Settings.LapseRate.value) ? "PASS" : "FAIL"))
        
        if (Settings.WindShear.enabled)
            LogToGUI("Wind Shear filter: " . ocrResult.windShear . " " . Settings.WindShear.comparison . " " . Settings.WindShear.value . " = " . (CompareValue(ocrResult.windShear, Settings.WindShear.comparison, Settings.WindShear.value) ? "PASS" : "FAIL"))
        
        if (Settings.CAPE.enabled)
            LogToGUI("CAPE filter: " . ocrResult.cape . " " . Settings.CAPE.comparison . " " . Settings.CAPE.value . " = " . (CompareValue(ocrResult.cape, Settings.CAPE.comparison, Settings.CAPE.value) ? "PASS" : "FAIL"))
        
        if (Settings.DewPoint.enabled)
            LogToGUI("Dew Point filter: " . ocrResult.dewPoint . " " . Settings.DewPoint.comparison . " " . Settings.DewPoint.value . " = " . (CompareValue(ocrResult.dewPoint, Settings.DewPoint.comparison, Settings.DewPoint.value) ? "PASS" : "FAIL"))
        
        if (Settings.RelativeHumidity.enabled)
            LogToGUI("Rel. Humidity filter: " . ocrResult.relativeHumidity . " " . Settings.RelativeHumidity.comparison . " " . Settings.RelativeHumidity.value . " = " . (CompareValue(ocrResult.relativeHumidity, Settings.RelativeHumidity.comparison, Settings.RelativeHumidity.value) ? "PASS" : "FAIL"))
        
        if (CheckConditions(ocrResult)) {
            LogToGUI("=== FOUND GOOD DAY! ===")
            LogToGUI("Risk: " . ocrResult.risk)
            if (Settings.LapseRate.enabled)
                LogToGUI("Lapse Rate: " . ocrResult.lapseRate . "C")
            if (Settings.WindShear.enabled)
                LogToGUI("Wind Shear: " . ocrResult.windShear . " kts")
            if (Settings.CAPE.enabled)
                LogToGUI("CAPE: " . ocrResult.cape . " J/Kg")
            if (Settings.DewPoint.enabled)
                LogToGUI("Dew Point: " . ocrResult.dewPoint . "F")
            if (Settings.RelativeHumidity.enabled)
                LogToGUI("Relative Humidity: " . ocrResult.relativeHumidity . "%")
            
            UpdateStatus("GOOD DAY FOUND!")
            
            Loop 3 {
                SoundBeep(1000, 300)
                Sleep(200)
            }
            
            Running := false
            SetTimer(RunRerollerLoop, 0)
            
            SendWebhook(ocrResult)
            
            ShowGoodServerPopup(ocrResult)
            return
        }
        
        LogToGUI("Not matched, rerolling...")
        
        if (!Running) {
            LogToGUI("Stopped by user - not closing Roblox")
            return
        }
        
        if (QuickLeaveGame()) {
            LogToGUI("Successfully left game")
            Sleep(400)
        } else {
            LogToGUI("Failed to leave game, forcing close")
            CloseRoblox()
            Sleep(2000)
        }
        
        if (Running)
            SetTimer(RunRerollerLoop, 100)
            
    } catch as err {
        LogToGUI("Error: " . err.Message)
        if (!Running) {
            LogToGUI("Stopped by user - not closing Roblox")
            return
        }
        CloseRoblox()
        if (Running)
            SetTimer(RunRerollerLoop, 3000)
    }
}

ExecuteFullSequence() {
    global Settings, Running
    
    LogToGUI("Waiting for Roblox...")
    if (!WaitForRobloxWindow(60)) {
        return false
    }
    
    if (!WaitForMainMenu(60)) {
        LogToGUI("Failed to detect main menu")
        return false
    }
    
    LogToGUI("Navigate to Play...")
    if (!SendKeySequence(["\", "Left", "Up", "Up", "Up", "Enter"], 150))
        return false
    
    LogToGUI("Select spawn...")
    if (!SendKeySequence(["Right", "Enter"], 150))
        return false
    
    SendKeySequence(["\"], 150)
    
    LogToGUI("Waiting 5 seconds after spawn...")
    Sleep(5000)
    
    LogToGUI("Opening thermos...")
    if (!SendKeySequence(["\", "Left", "Enter", "Left", "Left", "Down", "Enter"], 150))
        return false
    
    LogToGUI("Thermos opened")
    Sleep(1000)
    
    return true
}

SendKeySequence(keys, delayBetween := 150) {
    global Running
    
    if (!Running)
        return false
    
    if (!FocusRoblox())
        return false
    
    Sleep(150)
    
    for key in keys {
        if (!Running)
            return false
        
        try {
            Send("{" . key . "}")
            Sleep(delayBetween)
        } catch {
            return false
        }
    }
    
    return true
}

QuickLeaveGame() {
    global Running
    
    if (!Running)
        return false
    
    if (!FocusRoblox()) {
        LogToGUI("Failed to focus Roblox window")
        return false
    }
    
    try {
        LogToGUI("Executing leave sequence (ESC, L, Enter)...")
        Send("{Esc}")
        Sleep(100)
        Send("{l}")
        Sleep(100)
        Send("{Enter}")
        
        LogToGUI("Leave game sequence completed")
        return true
    } catch as err {
        LogToGUI("Leave game error: " . err.Message)
        return false
    }
}

CheckConditions(ocrResult) {
    global Settings
    
    if (ocrResult.risk != Settings.TargetRisk) {
        LogToGUI("Risk doesn't match - need " . Settings.TargetRisk . ", got " . ocrResult.risk)
        return false
    }
    
    if (Settings.LapseRate.enabled) {
        if (!CompareValue(ocrResult.lapseRate, Settings.LapseRate.comparison, Settings.LapseRate.value)) {
            LogToGUI("Lapse rate check FAILED: " . ocrResult.lapseRate . " " . Settings.LapseRate.comparison . " " . Settings.LapseRate.value)
            return false
        }
        LogToGUI("Lapse rate check PASSED")
    }
    
    if (Settings.WindShear.enabled) {
        if (!CompareValue(ocrResult.windShear, Settings.WindShear.comparison, Settings.WindShear.value)) {
            LogToGUI("Wind shear check FAILED: " . ocrResult.windShear . " " . Settings.WindShear.comparison . " " . Settings.WindShear.value)
            return false
        }
        LogToGUI("Wind shear check PASSED")
    }
    
    if (Settings.CAPE.enabled) {
        if (!CompareValue(ocrResult.cape, Settings.CAPE.comparison, Settings.CAPE.value)) {
            LogToGUI("CAPE check FAILED: " . ocrResult.cape . " " . Settings.CAPE.comparison . " " . Settings.CAPE.value)
            return false
        }
        LogToGUI("CAPE check PASSED")
    }
    
    if (Settings.DewPoint.enabled) {
        if (!CompareValue(ocrResult.dewPoint, Settings.DewPoint.comparison, Settings.DewPoint.value)) {
            LogToGUI("Dew point check FAILED: " . ocrResult.dewPoint . " " . Settings.DewPoint.comparison . " " . Settings.DewPoint.value)
            return false
        }
        LogToGUI("Dew point check PASSED")
    }
    
    if (Settings.RelativeHumidity.enabled) {
        if (!CompareValue(ocrResult.relativeHumidity, Settings.RelativeHumidity.comparison, Settings.RelativeHumidity.value)) {
            LogToGUI("Relative humidity check FAILED: " . ocrResult.relativeHumidity . " " . Settings.RelativeHumidity.comparison . " " . Settings.RelativeHumidity.value)
            return false
        }
        LogToGUI("Relative humidity check PASSED")
    }
    
    LogToGUI("ALL CONDITIONS PASSED!")
    return true
}

CompareValue(actual, operator, target) {
    switch operator {
        case ">=":
            return actual >= target
        case "<=":
            return actual <= target
        case "=":
            return Abs(actual - target) < 0.1
        default:
            return true
    }
}

TestThermosRead() {
    global Settings
    
    LogToGUI("=== TESTING OCR ===")
    
    if (!WinExist("ahk_exe RobloxPlayerBeta.exe")) {
        LogToGUI("ERROR: Roblox not running")
        return
    }
    
    if (Settings.OCRRegion.w <= 0) {
        LogToGUI("Auto-detecting thermos...")
        if (!DetectThermosRegion()) {
            LogToGUI("Auto-detection failed - make sure thermos is open!")
            return
        }
    }
    
    ocrResult := ReadThermosOCR()
    
    if (!ocrResult.success) {
        errorMsg := ocrResult.HasOwnProp("error") ? ocrResult.error : "Unknown error"
        LogToGUI("OCR Test FAILED: " . errorMsg)
        return
    }
    
    LogToGUI("=== OCR Test SUCCESS! ===")
    LogToGUI("Risk: " . ocrResult.risk)
    LogToGUI("Lapse: " . ocrResult.lapseRate . "C")
    LogToGUI("Shear: " . ocrResult.windShear . " kts")
    LogToGUI("CAPE: " . ocrResult.cape . " J/Kg")
    LogToGUI("Dew: " . ocrResult.dewPoint . "F")
    LogToGUI("Humidity: " . ocrResult.relativeHumidity . "%")
    
    SoundBeep(1000, 200)
}

LaunchRoblox() {
    global Settings
    
    LogToGUI("Launching Roblox...")
    
    url := Settings.ServerLink
    
    if (RegExMatch(url, "games/(\d+)", &match)) {
        placeId := match[1]
    } else {
        LogToGUI("Invalid server link")
        return false
    }
    
    if (RegExMatch(url, "privateServerLinkCode=([^&]+)", &match)) {
        code := match[1]
    } else {
        LogToGUI("Not a private server link")
        return false
    }
    
    robloxUrl := "roblox://placeId=" . placeId . "&linkCode=" . code
    
    LogToGUI("Place ID: " . placeId)
    LogToGUI("Link Code: " . code)
    
    try {
        if (Settings.UseBloxstrap) {
            bloxstrapPath := A_AppData . "\..\Local\Bloxstrap\Bloxstrap.exe"
            if (FileExist(bloxstrapPath)) {
                LogToGUI("Launching with Bloxstrap...")
                Run('"' . bloxstrapPath . '" "' . robloxUrl . '"')
            } else {
                LogToGUI("Bloxstrap not found, using default Roblox...")
                Run(robloxUrl)
            }
        } else {
            LogToGUI("Launching with default Roblox...")
            Run(robloxUrl)
        }
        
        return true
        
    } catch as err {
        LogToGUI("Launch failed: " . err.Message)
        return false
    }
}

WaitForRobloxWindow(timeout := 60) {
    startTime := A_TickCount
    
    Loop {
        if (WinExist("ahk_exe RobloxPlayerBeta.exe")) {
            Sleep(2000)
            return true
        }
        
        if ((A_TickCount - startTime) > (timeout * 1000))
            return false
        
        Sleep(500)
    }
}

WaitForMainMenu(timeout := 60) {
    global TesseractPath, DataFolder
    
    LogToGUI("Waiting for main menu to appear...")
    startTime := A_TickCount
    
    Loop {
        if ((A_TickCount - startTime) > (timeout * 1000)) {
            LogToGUI("Timeout waiting for menu")
            return false
        }
        
        try {
            if (!WinExist("ahk_exe RobloxPlayerBeta.exe")) {
                LogToGUI("Roblox window closed")
                return false
            }
            
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_exe RobloxPlayerBeta.exe")
            
            captureX := wx + (ww * 0.1)
            captureY := wy + (wh * 0.3)
            captureW := Round(ww * 0.3)
            captureH := Round(wh * 0.5)
            
            imageFile := DataFolder . "\menu_capture.png"
            outputFileBase := DataFolder . "\menu_ocr"
            outputTxtFile := outputFileBase . ".txt"
            
            if (FileExist(outputTxtFile))
                FileDelete(outputTxtFile)
            if (FileExist(imageFile))
                FileDelete(imageFile)
            
            pBitmap := CaptureScreenRegion(captureX, captureY, captureW, captureH)
            SaveBitmapToPNG(pBitmap, imageFile)
            DllCall("Gdiplus\GdipDisposeImage", "Ptr", pBitmap)
            
            tesseractCmd := '"' . TesseractPath . '" "' . imageFile . '" "' . outputFileBase . '" --psm 6 -l eng'
            RunWait(tesseractCmd, , "Hide")
            Sleep(200)
            
            if (FileExist(outputTxtFile)) {
                text := FileRead(outputTxtFile)
                textUpper := StrUpper(text)
                
                if (InStr(textUpper, "PLAY")) {
                    LogToGUI("Main menu detected!")
                    return true
                }
            }
            
        } catch as err {
            LogToGUI("Menu detection error: " . err.Message)
        }
        
        Sleep(500)
    }
    
    return false
}

FocusRoblox() {
    try {
        if (!WinExist("ahk_exe RobloxPlayerBeta.exe"))
            return false
        
        WinActivate("ahk_exe RobloxPlayerBeta.exe")
        Sleep(100)
        
        if (WinWaitActive("ahk_exe RobloxPlayerBeta.exe", , 3)) {
            Sleep(100)
            return true
        }
        
        return false
        
    } catch {
        return false
    }
}

CloseRoblox() {
    global Settings
    
    LogToGUI("Closing Roblox...")
    
    try {
        if (ProcessExist("RobloxPlayerBeta.exe"))
            ProcessClose("RobloxPlayerBeta.exe")
        
        if (Settings.UseBloxstrap && ProcessExist("Bloxstrap.exe")) {
            Sleep(1000)
            ProcessClose("Bloxstrap.exe")
        }
        
        Sleep(500)
        
    } catch {
        Sleep(1000)
    }
}

StopAll() {
    global Running
    
    Running := false
    SetTimer(RunRerollerLoop, 0)
    UpdateStatus("Stopped")
    LogToGUI("=== STOPPED ===")
    LogToGUI("Roblox left open - close manually if needed")
}

; ============================================
; STARTUP
; ============================================

LoadSettings()
CreateGUI()
