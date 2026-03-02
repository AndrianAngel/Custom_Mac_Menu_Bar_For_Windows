; =============================================================================
; MacOS-Style Dark Menu Bar for Windows — Alpha 8
; =============================================================================
; Uses GuiFlatButton_menu.au3 and _WinAPI_DPI.au3 Libraries
; =============================================================================
; Author: AndrianAngel (Github)
; Open-Source: Non-commercial usage (AndrianAngel Copyright 01st March 2026
; =============================================================================

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPI.au3>
#include <WinAPIGdi.au3>
#include <WinAPISys.au3>
#include <WinAPISysWin.au3>
#include <GDIPlus.au3>
#include <GuiMenu.au3>
#include <TrayConstants.au3>
#include <MsgBoxConstants.au3>
#include <Array.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <ButtonConstants.au3>
#include <ColorConstants.au3>
#include <Misc.au3>

#include "_WinAPI_DPI.au3"
#include "GuiFlatButton_menu.au3"

Opt("TrayOnEventMode", 1)
Opt("TrayMenuMode", 1)
Opt("GUIOnEventMode", 1)

; ---------------------------------------------------------------------------
; SINGLE INSTANCE CHECK
; ---------------------------------------------------------------------------
Sleep(1200)

Global $hMutex = _Singleton("MacMenuBar_SingleInstance", 1)
If @error Then
    ; Try one more time after a short delay
    Sleep(500)
    $hMutex = _Singleton("MacMenuBar_SingleInstance", 1)
    If @error Then
        MsgBox($MB_ICONINFORMATION, "Mac Menu Bar", "Application is already running.")
        Exit
    EndIf
EndIf

; ---------------------------------------------------------------------------
; DPI SETUP
; ---------------------------------------------------------------------------
Global $iDPI = _WinAPI_SetDPIAwareness(), $iDPI_def = 96
If $iDPI = 0 Then Exit MsgBox($MB_ICONERROR, "ERROR", "Unable to set DPI awareness!!!", 10)
Global $iDPI1 = $iDPI / $iDPI_def
Global $iDPI2 = $iDPI_def / $iDPI

; ---------------------------------------------------------------------------
; DARK THEME COLORS
; ---------------------------------------------------------------------------
Global Const $CLR_BAR_BG    = 0x1E1E1E
Global Const $CLR_MENU_BG   = 0x2D2D2D
Global Const $CLR_TEXT      = 0xDCDCDC
Global Const $CLR_HIGHLIGHT = 0x3D5A80
Global Const $CLR_SEPARATOR = 0x444444

; GDI colors are BGR
Global Const $BGR_BAR_BG    = 0x001E1E1E
Global Const $BGR_TEXT      = 0x00DCDCDC

; GuiFlatButton menu bar colors
Global $iMenubarBk  = 0x1E1E1E
Global $iMenubarHov = 0x3D3D3D
Global $iMenubarSel = 0x3D5A80
Global $iPadding    = 16        

; ---------------------------------------------------------------------------
; GLOBAL STATE
; ---------------------------------------------------------------------------
Global $bIgnoreFS   = False
Global $bBoldFont   = False
Global $bMakeExpDef = False
Global $bReserveSpace = False  ; Reserve screen space like a taskbar
Global $sHotkey     = "^h"
Global $sIconPath   = @ScriptDir & "\icons\mac.ico"
Global $iBarHeight  = 30
Global $bBarVisible = True

Global $hLastActiveWnd = 0
Global $sLastAppName   = "App Name"
Global $hLastIcon      = 0
Global $hA1Icon        = 0  ; cached icon handle for a1.ico

; $hLastActiveWnd
Global $bMenuTracking = False

Global $iAutohideTimer = 0
Global $iLastIconCheck = 0
Global $sTimeStr       = ""
Global $sUsername      = @UserName

; Main bar window
Global $hBarWnd = 0

; GDI objects
Global $hBarDC = 0, $hMemDC = 0, $hBitmap = 0, $hOldBmp = 0
Global $hFont  = 0, $hFontBold = 0

; GuiFlatButton control IDs for the 7 menu buttons
Global $idBtn[8]   ; 0=AppName, 1=Quick, 2=Setting, 3=JumpTo, 4=Tools, 5=WinPos, 6=Resize, 7=Menu
Global $aBtnX[8]   ; screen-X of left edge of each button (for popup positioning)

; Icon control
Global $idIcon = 0
Global $idIconBG = 0

; Native Win32 popup menu handles
Global $hMenuAppName = 0
Global $hMenuQuick   = 0
Global $hMenuSetting = 0
Global $hMenuJumpTo  = 0
Global $hMenuTools   = 0
Global $hMenuWinPos  = 0
Global $hMenuResize  = 0
Global $hMenuBar     = 0

; Menu item ID bases
Global Const $ID_APPNAME_BASE = 1000
Global Const $ID_QUICK_BASE   = 1100
Global Const $ID_SETTING_BASE = 1200
Global Const $ID_JUMP_BASE    = 1400
Global Const $ID_TOOLS_BASE   = 1600
Global Const $ID_WINPOS_BASE  = 1800
Global Const $ID_RESIZE_BASE  = 1900
Global Const $ID_MENU_BASE    = 2000

; Settings dialog
Global $hSettingsDlg  = 0
Global $bShowSettings = False
Global $bRebuildBar   = False  ; set after settings save to rebuild bar safely

; Repaint timer
Global $iLastPaint = 0
Global $bExitApp = False  ; Safe exit flag

; Cached button end X position (set in _BuildBar, used in _PaintBar to avoid ControlGetPos during WM_PAINT)
Global $iCachedButtonsEnd = 0

; Cached active PID to avoid calling ProcessList() every 50ms
Global $iLastActivePID = 0

; Taskbar height detection
Global $iTaskbarHeight = 0

; ---------------------------------------------------------------------------
; DATA ARRAYS
; ---------------------------------------------------------------------------
Global $aMenuLabels[8] = ["", "Quick Actions", "Setting", "Jump To", "Tools", "Window Position", "Resize", "About"]

Global $aJumpFolders[11] = ["Startup (shell:startup)", "Temp (%temp%)", "Downloads", _
    "Documents", "Videos", "Pictures", "Music", "AppData", _
    "Program Files", "Program Files (x86)", "ProgramData"]
Global $aJumpPaths[11]
$aJumpPaths[0]  = @StartupDir
$aJumpPaths[1]  = @TempDir
$aJumpPaths[2]  = @UserProfileDir & "\Downloads"
$aJumpPaths[3]  = @UserProfileDir & "\Documents"
$aJumpPaths[4]  = @UserProfileDir & "\Videos"
$aJumpPaths[5]  = @UserProfileDir & "\Pictures"
$aJumpPaths[6]  = @UserProfileDir & "\Music"
$aJumpPaths[7]  = @AppDataDir
$aJumpPaths[8]  = "C:\Program Files"
$aJumpPaths[9]  = EnvGet("ProgramFiles(x86)")
If $aJumpPaths[9] = "" Then $aJumpPaths[9] = @ProgramFilesDir & " (x86)"
$aJumpPaths[10] = @HomeDrive & "\ProgramData"

Global $aTools[12][4] = [ _
    ["Mouse Pointer (Color/Size)",  "ms-settings:easeofaccess-cursor",           False, True ], _
    ["Power Options",               "control powercfg.cpl",                False, False], _
    ["Action Recorder (psr)",       "psr.exe",                             False, False], _
	["Power and Sleep",             "ms-settings:powersleep",                             False, True], _
	["Date and Time",               "ms-settings:dateandtime",                             False, True], _
    ["Screenshot (Win+Shift+S)",    "__SCREENSHOT__",                      False, False], _
    ["UAC Settings",                "UserAccountControlSettings.exe",      False, False], _
    ["DirectX Diag (dxdiag)",       "dxdiag.exe",                          False, False], _
    ["CMD",                         "cmd.exe",                             False, False], _
    ["CMD (Admin)",                 "cmd.exe",                             True,  False], _
    ["PowerShell",                  "powershell.exe",                      False, False], _
    ["PowerShell (Admin)",          "powershell.exe",                      True,  False]]

Global $aWinPositions[9] = ["UP", "DOWN", "LEFT", "RIGHT", "CENTER", _
    "UP LEFT", "UP RIGHT", "DOWN LEFT", "DOWN RIGHT"]

Global $aResizeNames[9]    = ["640x480","800x600","852x480","1280x720","1024x768", _
    "1280x1024","1920x1080","1152x864","1280x960"]
Global $aResizePresets[9][2] = [ _
    ["640","480"],["800","600"],["852","480"],["1280","720"],["1024","768"], _
    ["1280","1024"],["1920","1080"],["1152","864"],["1280","960"]]

Global $aSettingsItems[19][2] = [ _
    ["Main Settings (Win+I)",     "ms-settings:"],                  _
    ["Personalize",               "ms-settings:personalization"],    _
    ["Windows Security",          "windowsdefender:"],               _
    ["Apps & Features",           "ms-settings:appsfeatures"],       _
    ["Default Apps",              "ms-settings:defaultapps"],        _
    ["Startup Apps",              "ms-settings:startupapps"],        _
    ["Ergonomics Options",        "control access.cpl"],             _
    ["Display Options",           "ms-settings:display"],            _
    ["Device Manager",            "devmgmt.msc"],                    _
    ["Disk Manager",              "diskmgmt.msc"],                   _
    ["Printer (Control Panel)",   "control printers"],               _
    ["Account",                   "ms-settings:yourinfo"],           _
    ["Control Panel",             "control.exe"],                    _
    ["Task Manager",              "taskmgr.exe"],                    _
    ["Firewall",                  "wf.msc"],                         _
    ["Services",                  "services.msc"],                   _
	["Visual keyboard",           "C:\Windows\WinSxS\amd64_microsoft-windows-osk_31bf3856ad364e35_10.0.19041.1_none_60ade0eff94c37fc\osk.exe"],                   _
	["Restore Point",             "C:\Windows\WinSxS\amd64_microsoft-windows-s..ropertiesprotection_31bf3856ad364e35_10.0.19041.1_none_19a36451bbe13a1c\SystemPropertiesProtection.exe"],                   _
    ["Disk Cleanup",              "cleanmgr.exe"]]

; ===========================================================================
; STARTUP
; ===========================================================================
_LoadSettings()
_DetectTaskbarHeight()
_CreateTrayIcon()
HotKeySet($sHotkey, "_ShowSettings")
_GDIPlus_Startup()

; Enable Windows dark mode for this process
_SetCtrlColorMode(0, True)

; Set GuiFlatButton default colors
Local $aColorsEx = _
    [$iMenubarBk,  0xFFFFFF, $iMenubarBk,  _  
     $iMenubarBk,  0xFFFFFF, $iMenubarBk,  _   
     $iMenubarHov, 0xFFFFFF, $iMenubarHov, _   
     $iMenubarSel, 0xFFFFFF, $iMenubarSel]      
GuiFlatButton_SetDefaultColorsEx($aColorsEx)

_BuildBar()
_BuildMenus()
AdlibRegister("_MainLoop", 50)

While 1
    Sleep(100)
WEnd

_ExitApp()

; ===========================================================================
; DETECT TASKBAR HEIGHT
; ===========================================================================
Func _DetectTaskbarHeight()
    Local $hTaskbar = WinGetHandle("[CLASS:Shell_TrayWnd]")
    If Not @error Then
        Local $aPos = WinGetPos($hTaskbar)
        If IsArray($aPos) Then
            $iTaskbarHeight = $aPos[3]
        EndIf
    EndIf
    If $iTaskbarHeight = 0 Then $iTaskbarHeight = 40 ; Default fallback
EndFunc

; ===========================================================================
; BUILD THE BAR WINDOW
; ===========================================================================
Func _BuildBar()
    If IsHWnd($hBarWnd) Then
        If $hOldBmp  Then _WinAPI_SelectObject($hMemDC, $hOldBmp)
        If $hBitmap  Then _WinAPI_DeleteObject($hBitmap)
        If $hMemDC   Then _WinAPI_DeleteDC($hMemDC)
        If $hBarDC   Then _WinAPI_ReleaseDC($hBarWnd, $hBarDC)
        If $hFont    Then _WinAPI_DeleteObject($hFont)
        If $hFontBold Then _WinAPI_DeleteObject($hFontBold)
        GUIDelete($hBarWnd)
    EndIf

    $hBarWnd = GUICreate("MacMenuBar", @DesktopWidth, $iBarHeight, 0, 0, _
        BitOR($WS_POPUP, $WS_VISIBLE), _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))

    ; Dark title bar
    Local $tVal = DllStructCreate("int")
    DllStructSetData($tVal, 1, 1)
    DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hBarWnd, _
        "dword", 20, "struct*", $tVal, "dword", 4)

    _WinAPI_SetWindowLong($hBarWnd, $GWL_EXSTYLE, _
        BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))

    GUISetOnEvent($GUI_EVENT_CLOSE, "_ExitApp", $hBarWnd)
    GUISetFont(($iBarHeight > 25) ? 10 : 9, $FW_NORMAL, -1, "Segoe UI", $hBarWnd)

    WinMove($hBarWnd, "", 0, 0, @DesktopWidth, $iBarHeight)

    ; -----------------------------------------------------------------------
    ; BACKGROUND LABEL
    ; -----------------------------------------------------------------------
    Local $idBG = GUICtrlCreateLabel("", 0, 0, @DesktopWidth, $iBarHeight, $WS_CLIPSIBLINGS)
    GUICtrlSetBkColor($idBG, $CLR_BAR_BG)

    ; -----------------------------------------------------------------------
    ; NON-CLICKABLE ICON (icons\a1.ico) at left end with dark background
    ; Draw icon via GDI after window is shown to avoid white background
    ; -----------------------------------------------------------------------
    Local $iIconSize = $iBarHeight - 8

    $idIconBG = GUICtrlCreateLabel("", 2, 2, $iIconSize + 8, $iIconSize + 4)
    GUICtrlSetBkColor($idIconBG, $CLR_BAR_BG)
    GUICtrlSetState($idIconBG, $GUI_DISABLE)
    $idIcon = $idIconBG 

    ; -----------------------------------------------------------------------
    ; CREATE ALL 8 BUTTONS
    ; -----------------------------------------------------------------------
    Local $iLeftMargin = 5 + ($iIconSize) + 8   ; icon x + iconSize + gap

    ; Create App Name button (slot 0)
    $idBtn[0] = GuiFlatButton_Create($sLastAppName, $iLeftMargin, -2, -1, -1, $SS_CENTER)
    GUICtrlSetOnEvent($idBtn[0], "_OnMenuBtn0")
    Local $aPos = ControlGetPos($hBarWnd, "", $idBtn[0])
    GuiFlatButton_SetPos($idBtn[0], $aPos[0], $aPos[1], $aPos[2] + $iPadding + 20, $aPos[3])  ; Extra width for icon
    $aPos = ControlGetPos($hBarWnd, "", $idBtn[0])
    $aBtnX[0] = $aPos[0]
    Local $iNextX = $aPos[0] + $aPos[2]

    ; Create buttons 1-7
    For $m = 1 To 7
        $idBtn[$m] = GuiFlatButton_Create($aMenuLabels[$m], $iNextX, -2, -1, -1, $SS_CENTER)
        GUICtrlSetOnEvent($idBtn[$m], "_OnMenuBtn" & $m)
        $aPos = ControlGetPos($hBarWnd, "", $idBtn[$m])
        GuiFlatButton_SetPos($idBtn[$m], $aPos[0], $aPos[1], $aPos[2] + $iPadding, $aPos[3])
        $aPos = ControlGetPos($hBarWnd, "", $idBtn[$m])
        $aBtnX[$m] = $aPos[0]
        $iNextX = $aPos[0] + $aPos[2]
    Next

    GUISetState(@SW_SHOW, $hBarWnd)
    _UpdateWorkArea($bReserveSpace)

    ; Cache button end position so _PaintBar never needs to call ControlGetPos during WM_PAINT
    Local $aLastBtnPos = ControlGetPos($hBarWnd, "", $idBtn[7])
    If IsArray($aLastBtnPos) Then
        $iCachedButtonsEnd = $aLastBtnPos[0] + $aLastBtnPos[2]
    Else
        $iCachedButtonsEnd = 0
    EndIf

    ; Load a1.ico for GDI drawing (avoids white background from GUICtrlCreateIcon)
    If $hA1Icon Then DllCall("user32.dll", "bool", "DestroyIcon", "handle", $hA1Icon)
    $hA1Icon = 0
    Local $sA1File = @ScriptDir & "\icons\a1.ico"
    If FileExists($sA1File) Then
        Local $aLI = DllCall("user32.dll", "handle", "LoadImageW", "handle", 0, _
            "wstr", $sA1File, "uint", 1, "int", $iIconSize, "int", $iIconSize, "uint", 0x0010)
        If Not @error And $aLI[0] <> 0 Then $hA1Icon = $aLI[0]
    EndIf

    ; -----------------------------------------------------------------------
    ; GDI double-buffer setup (now only used for clock on the right)
    ; -----------------------------------------------------------------------
    $hBarDC  = _WinAPI_GetDC($hBarWnd)
    $hMemDC  = _WinAPI_CreateCompatibleDC($hBarDC)
    $hBitmap = _WinAPI_CreateCompatibleBitmap($hBarDC, @DesktopWidth, $iBarHeight)
    $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

    Local $iFS = ($iBarHeight > 25) ? 13 : 11
    $hFont     = _WinAPI_CreateFont($iFS, 0, 0, 0, 400, False, False, False, 1, 0, 0, 4, 0, "Segoe UI")
    $hFontBold = _WinAPI_CreateFont($iFS, 0, 0, 0, 700, False, False, False, 1, 0, 0, 4, 0, "Segoe UI")

    GUIRegisterMsg($WM_PAINT,        "_WM_PAINT")
    GUIRegisterMsg($WM_MOUSEMOVE,    "_WM_MOUSEMOVE")

    _UpdateWorkArea($bReserveSpace)

    _PaintBar()
EndFunc

; ===========================================================================
; RESTART SCRIPT
; ===========================================================================
Func _RestartScript()
    _SaveSettings() 
    
    _UpdateWorkArea(False)
    
    If @Compiled Then
        $sRunPath = @ScriptFullPath
    Else
        ; For non-compiled scripts, we need to run AutoIt with the script
        $sRunPath = '"' & @AutoItExe & '" /AutoIt3ExecuteScript "' & @ScriptFullPath & '"'
    EndIf
    
    ; First, release the mutex so the new instance can start
    If $hMutex Then
        DllCall("kernel32.dll", "bool", "ReleaseMutex", "handle", $hMutex)
        $hMutex = 0
    EndIf
    
    ; Now launch new instance
    Run($sRunPath)
    
    ; Small delay to ensure new instance starts
    Sleep(500)
    
    ; Now clean up and exit
    _SafeExit()
    
    ; Force exit immediately
    Exit
EndFunc

; ===========================================================================
; BUILD NATIVE POPUP MENUS
; ===========================================================================
Func _BuildMenus()
    If $hMenuAppName Then _GUICtrlMenu_DestroyMenu($hMenuAppName)
    If $hMenuQuick   Then _GUICtrlMenu_DestroyMenu($hMenuQuick)
    If $hMenuSetting Then _GUICtrlMenu_DestroyMenu($hMenuSetting)
    If $hMenuJumpTo  Then _GUICtrlMenu_DestroyMenu($hMenuJumpTo)
    If $hMenuTools   Then _GUICtrlMenu_DestroyMenu($hMenuTools)
    If $hMenuWinPos  Then _GUICtrlMenu_DestroyMenu($hMenuWinPos)
    If $hMenuResize  Then _GUICtrlMenu_DestroyMenu($hMenuResize)
    If $hMenuBar     Then _GUICtrlMenu_DestroyMenu($hMenuBar)

    ; --- App Name menu ---
    $hMenuAppName = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuAppName)
    _MyAddMenuItem($hMenuAppName, "Open App Location",      $ID_APPNAME_BASE + 1)
    _MyAddMenuItem($hMenuAppName, "Show / Hide App Window", $ID_APPNAME_BASE + 2)
    _MyAddSep($hMenuAppName)
    _MyAddMenuItem($hMenuAppName, "Show/hide File Extensions", $ID_APPNAME_BASE + 3)
    _MyAddMenuItem($hMenuAppName, "Show/hide Hidden Files",    $ID_APPNAME_BASE + 4)

    ; --- Quick Actions ---
    $hMenuQuick = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuQuick)
    _MyAddMenuItem($hMenuQuick, "COPY          Ctrl+C",       $ID_QUICK_BASE + 0)
    _MyAddMenuItem($hMenuQuick, "CUT           Ctrl+X",       $ID_QUICK_BASE + 1)
    _MyAddMenuItem($hMenuQuick, "PASTE         Ctrl+V",       $ID_QUICK_BASE + 2)
    _MyAddMenuItem($hMenuQuick, "RENAME        F2",           $ID_QUICK_BASE + 3)
    _MyAddMenuItem($hMenuQuick, "NEW FOLDER    Ctrl+Shift+N", $ID_QUICK_BASE + 4)
    _MyAddSep($hMenuQuick)
    _MyAddMenuItem($hMenuQuick, "My Computer",         $ID_QUICK_BASE + 5)

    ; --- Setting ---
    $hMenuSetting = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuSetting)
    For $i = 0 To UBound($aSettingsItems) - 1
        _MyAddMenuItem($hMenuSetting, $aSettingsItems[$i][0], $ID_SETTING_BASE + $i)
    Next

    ; --- Jump To ---
    $hMenuJumpTo = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuJumpTo)
    For $i = 0 To UBound($aJumpFolders) - 1
        _MyAddMenuItem($hMenuJumpTo, $aJumpFolders[$i], $ID_JUMP_BASE + $i)
    Next

    ; --- Tools ---
    $hMenuTools = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuTools)
    For $i = 0 To UBound($aTools) - 1
        _MyAddMenuItem($hMenuTools, $aTools[$i][0], $ID_TOOLS_BASE + $i)
    Next

    ; --- Window Position ---
    $hMenuWinPos = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuWinPos)
    For $i = 0 To UBound($aWinPositions) - 1
        _MyAddMenuItem($hMenuWinPos, $aWinPositions[$i], $ID_WINPOS_BASE + $i)
    Next

    ; --- Resize ---
    $hMenuResize = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuResize)
    For $i = 0 To UBound($aResizeNames) - 1
        _MyAddMenuItem($hMenuResize, $aResizeNames[$i], $ID_RESIZE_BASE + $i)
    Next

    ; --- About (formerly Menu) ---
    $hMenuBar = _GUICtrlMenu_CreatePopup()
    _AddDarkMenu($hMenuBar)
    _MyAddMenuItem($hMenuBar, "Windows Version (winver)", $ID_MENU_BASE + 0)
EndFunc

; ===========================================================================
; GUIFLATBUTTON EVENT HANDLERS
; ===========================================================================
Func _OnMenuBtn0()   ; App Name
    _TrackMenu($hMenuAppName, 0)
EndFunc
Func _OnMenuBtn1()   ; Quick Actions
    _TrackMenu($hMenuQuick, 1)
EndFunc
Func _OnMenuBtn2()   ; Setting
    _TrackMenu($hMenuSetting, 2)
EndFunc
Func _OnMenuBtn3()   ; Jump To
    _TrackMenu($hMenuJumpTo, 3)
EndFunc
Func _OnMenuBtn4()   ; Tools
    _TrackMenu($hMenuTools, 4)
EndFunc
Func _OnMenuBtn5()   ; Window Position
    _TrackMenu($hMenuWinPos, 5)
EndFunc
Func _OnMenuBtn6()   ; Resize
    _TrackMenu($hMenuResize, 6)
EndFunc
Func _OnMenuBtn7()   ; About
    _TrackMenu($hMenuBar, 7)
EndFunc

; ---------------------------------------------------------------------------
; _TrackMenu — shows a popup below the button, handles result
; ---------------------------------------------------------------------------
Func _TrackMenu($hMenu, $iSlot)
    Local $hCurrent = WinGetHandle("[ACTIVE]")
    If Not @error Then
        Local $sTitle = WinGetTitle($hCurrent)
        If $sTitle <> "MacMenuBar" And $sTitle <> "▼ Bar Settings" Then
            $hLastActiveWnd = $hCurrent
        EndIf
    EndIf

    ; Lock menu tracking
    $bMenuTracking = True

    Local $aPos = ControlGetPos($hBarWnd, "", $idBtn[$iSlot])
    If @error Or Not IsArray($aPos) Then
        $bMenuTracking = False
        Return
    EndIf

    Local $tPT = DllStructCreate("long x;long y")
    DllStructSetData($tPT, "x", $aPos[0])
    DllStructSetData($tPT, "y", $iBarHeight)
    DllCall("user32.dll", "bool", "ClientToScreen", "hwnd", $hBarWnd, "struct*", $tPT)
    Local $iSX = DllStructGetData($tPT, "x")
    Local $iSY = DllStructGetData($tPT, "y")

    ; Show the menu
    Local $nCmd = _GUICtrlMenu_TrackPopupMenu($hMenu, $hBarWnd, $iSX, $iSY, 1, 1, 2)

    ; Handle the menu command
    If $nCmd <> 0 Then _HandleMenuCmd($nCmd)

    ; After menu closes, restore focus to the last active window
    If IsHWnd($hLastActiveWnd) And WinExists($hLastActiveWnd) Then
        WinActivate($hLastActiveWnd)
    EndIf

    ; Unlock menu tracking
    $bMenuTracking = False
EndFunc

; ===========================================================================
; WM_PAINT  — repaint the GDI bar (now only clock on right)
; ===========================================================================
Func _WM_PAINT($hWnd, $iMsg, $wParam, $lParam)
    #forceref $iMsg, $wParam, $lParam
    If $hWnd = $hBarWnd Then
        ; CRITICAL: BeginPaint/EndPaint validates the update region.
        Local $tPS = DllStructCreate("hwnd hdc;bool fErase;long left;long top;long right;long bottom;bool fRestore;bool fIncUpdate;byte rgbReserved[32]")
        Local $aRet = DllCall("user32.dll", "handle", "BeginPaint", "hwnd", $hWnd, "struct*", $tPS)
        If Not @error And $aRet[0] <> 0 Then
            _PaintBar()
            DllCall("user32.dll", "bool", "EndPaint", "hwnd", $hWnd, "struct*", $tPS)
        EndIf
        Return 0
    EndIf
    Return $GUI_RUNDEFMSG
EndFunc

Func _WM_MOUSEMOVE($hWnd, $iMsg, $wParam, $lParam)
    #forceref $hWnd, $iMsg, $wParam, $lParam
    Return $GUI_RUNDEFMSG
EndFunc

; ===========================================================================
; GDI PAINT — draws background and clock on the right
; ===========================================================================
Func _PaintBar()
    ; Re-entrancy guard: WM_PAINT and the 500ms adlib timer can both fire
    Static $bPainting = False
    If $bPainting Then Return
    $bPainting = True

    ; Safety: if GDI objects aren't ready yet, bail out
    If $hMemDC = 0 Or $hBarDC = 0 Then
        $bPainting = False
        Return
    EndIf

    Local $hDC = $hMemDC
    Local $iW  = @DesktopWidth
    Local $iH  = $iBarHeight

    ; Fill entire background
    Local $hBrush = _WinAPI_CreateSolidBrush($BGR_BAR_BG)
    Local $tRect  = DllStructCreate("long left;long top;long right;long bottom")
    DllStructSetData($tRect, "left",   0)
    DllStructSetData($tRect, "top",    0)
    DllStructSetData($tRect, "right",  $iW)
    DllStructSetData($tRect, "bottom", $iH)
    _WinAPI_FillRect($hDC, $tRect, $hBrush)
    _WinAPI_DeleteObject($hBrush)

    ; Draw a1.ico icon with GDI (no white background)
    If $hA1Icon <> 0 Then
        Local $iIconSz = $iH - 8
        Local $iIconY  = ($iH - $iIconSz) / 2  ; vertically centered
        DllCall("user32.dll", "bool", "DrawIconEx", "handle", $hDC, _
            "int", 5, "int", $iIconY, "handle", $hA1Icon, _
            "int", $iIconSz, "int", $iIconSz, "uint", 0, "handle", 0, "uint", 3)
    EndIf
    Local $hUseFont = $hFont
    _WinAPI_SelectObject($hDC, $hUseFont)
    _WinAPI_SetTextColor($hDC, $BGR_TEXT)
    _WinAPI_SetBkMode($hDC, $TRANSPARENT)

    ; ---- Right side: Username | Day  Mon DD   HH:MM AM/PM ----
    Local $sRight = $sUsername & "  |  " & $sTimeStr
    Local $tSzR   = _GetTextSize($hDC, $sRight)
    Local $iRW    = DllStructGetData($tSzR, 1)
    Local $tTRR   = DllStructCreate("long left;long top;long right;long bottom")
    DllStructSetData($tTRR, "left",   $iW - $iRW - 12)
    DllStructSetData($tTRR, "top",    1)
    DllStructSetData($tTRR, "right",  $iW - 4)
    DllStructSetData($tTRR, "bottom", $iH - 1)
    _WinAPI_DrawText($hDC, $sRight, $tTRR, 0x0024)

    ; Find right edge of last button — use cached value (safe inside WM_PAINT)
    Local $iButtonsEnd = $iCachedButtonsEnd

    ; Blit icon area on the left (0 .. buttons start)
    Local $iIconAreaW = 5 + ($iH - 8) + 8  ; x + iconSize + gap
    _WinAPI_BitBlt($hBarDC, 0, 0, $iIconAreaW, $iH, $hDC, 0, 0, $SRCCOPY)

    ; Blit only the right strip (buttons end .. screen width)
    If $iButtonsEnd < $iW Then
        _WinAPI_BitBlt($hBarDC, $iButtonsEnd, 0, $iW - $iButtonsEnd, $iH, $hDC, $iButtonsEnd, 0, $SRCCOPY)
    EndIf

    $bPainting = False
EndFunc

Func _GetTextSize($hDC, $sText)
    Local $tSz = DllStructCreate("long cx;long cy")
    DllCall("gdi32.dll", "bool", "GetTextExtentPoint32W", "handle", $hDC, _
        "wstr", $sText, "int", StringLen($sText), "struct*", $tSz)
    Return $tSz
EndFunc

; ===========================================================================
; POPUP MENU HELPERS
; ===========================================================================
Func _AddDarkMenu($hMenu)
    _WinAPI_SetWindowTheme_unr($hMenu, "DarkMode_CFD", "")
    Local $hBrush = _WinAPI_CreateSolidBrush(0x002D2D2D)
    Local $tMI = DllStructCreate("dword cbSize;dword fMask;dword dwStyle;uint cyMax;ptr hbrBack;dword dwContextHelpID;ulong_ptr dwMenuData")
    DllStructSetData($tMI, "cbSize", DllStructGetSize($tMI))
    DllStructSetData($tMI, "fMask", BitOR(1, 2, 0x80))
    DllStructSetData($tMI, "dwStyle", 0x04000000)
    DllStructSetData($tMI, "hbrBack", $hBrush)
    DllCall("user32.dll", "bool", "SetMenuInfo", "handle", $hMenu, "struct*", $tMI)
    _SetCtrlColorMode($hMenu, True, "DarkMode_CFD")
EndFunc

Func _MyAddMenuItem($hMenu, $sText, $iID)
    _GUICtrlMenu_InsertMenuItem($hMenu, _GUICtrlMenu_GetItemCount($hMenu), $sText, $iID)
EndFunc

Func _MyAddSep($hMenu)
    Local $tInfo = DllStructCreate($tagMENUITEMINFO)
    DllStructSetData($tInfo, "cbSize", DllStructGetSize($tInfo))
    DllStructSetData($tInfo, "fMask",  $MIIM_FTYPE)
    DllStructSetData($tInfo, "fType",  $MFT_SEPARATOR)
    DllCall("user32.dll", "bool", "InsertMenuItemW", "handle", $hMenu, _
        "uint", _GUICtrlMenu_GetItemCount($hMenu), "bool", True, "struct*", $tInfo)
EndFunc

; ===========================================================================
; HANDLE MENU COMMANDS
; ===========================================================================
Func _HandleMenuCmd($iCmd)
    ; Handle App Name menu items
    If $iCmd >= $ID_APPNAME_BASE And $iCmd < $ID_APPNAME_BASE + 10 Then
        Switch $iCmd
            Case $ID_APPNAME_BASE + 1
                _OpenAppLocation()
            Case $ID_APPNAME_BASE + 2
                _ToggleAppWindow()
            Case $ID_APPNAME_BASE + 3
                _ToggleFileExtension()
            Case $ID_APPNAME_BASE + 4
                _ToggleHiddenFiles()
        EndSwitch
        Return
    EndIf

    If $iCmd >= $ID_QUICK_BASE And $iCmd < $ID_QUICK_BASE + 10 Then
        _HandleQuickAction($iCmd - $ID_QUICK_BASE)
        Return
    EndIf

    If $iCmd >= $ID_SETTING_BASE And $iCmd < $ID_SETTING_BASE + 30 Then
        _LaunchItem($aSettingsItems[$iCmd - $ID_SETTING_BASE][1])
        Return
    EndIf

    If $iCmd >= $ID_JUMP_BASE And $iCmd < $ID_JUMP_BASE + 20 Then
        _JumpToFolder($iCmd - $ID_JUMP_BASE)
        Return
    EndIf

    If $iCmd >= $ID_TOOLS_BASE And $iCmd < $ID_TOOLS_BASE + 20 Then
        _RunTool($iCmd - $ID_TOOLS_BASE)
        Return
    EndIf

    If $iCmd >= $ID_WINPOS_BASE And $iCmd < $ID_WINPOS_BASE + 10 Then
        _PositionWindow($iCmd - $ID_WINPOS_BASE)
        Return
    EndIf

    If $iCmd >= $ID_RESIZE_BASE And $iCmd < $ID_RESIZE_BASE + 15 Then
        _ResizeWindow($iCmd - $ID_RESIZE_BASE)
        Return
    EndIf

    If $iCmd >= $ID_MENU_BASE And $iCmd < $ID_MENU_BASE + 10 Then
        Switch $iCmd - $ID_MENU_BASE
            Case 0
                ShellExecute(@WindowsDir & "\system32\winver.exe")
        EndSwitch
        Return
    EndIf
EndFunc

; ===========================================================================
; HANDLE QUICK ACTIONS WITH PROPER FOCUS RESTORATION
; ===========================================================================
Func _HandleQuickAction($iIndex)
    ; Restore focus to the last active window first
    If IsHWnd($hLastActiveWnd) And WinExists($hLastActiveWnd) Then
        WinActivate($hLastActiveWnd)
        Sleep(100) ; Give time for focus to restore
    EndIf
    
    Switch $iIndex
        Case 0 ; COPY
            Send("^c")
        Case 1 ; CUT
            Send("^x")
        Case 2 ; PASTE
            Send("^v")
        Case 3 ; RENAME
            Send("{F2}")
        Case 4 ; NEW FOLDER
            Send("^+n")
        Case 5 ; My Computer
            Run("explorer.exe ::{20D04FE0-3AEA-1069-A2D8-08002B30309D}")
    EndSwitch
EndFunc

; ===========================================================================
; MAIN LOOP (50 ms adlib)
; ===========================================================================
Func _MainLoop()
    If $bExitApp Then Exit
    _UpdateActiveApp()
    $sTimeStr = _GetFormattedTime()

    ; Fullscreen auto-hide logic
    If $bIgnoreFS Then
        Static $bWasFullscreen = False
        Local $bFS = _IsFullscreenAppRunning()
        If $bFS And Not $bWasFullscreen Then
            GUISetState(@SW_HIDE, $hBarWnd)
            $bBarVisible = False
            $bWasFullscreen = True
        ElseIf Not $bFS And $bWasFullscreen Then
            GUISetState(@SW_SHOW, $hBarWnd)
            $bBarVisible = True
            $bWasFullscreen = False
        EndIf
    EndIf

    ; Update App Name button text if changed
    If $idBtn[0] <> 0 Then
        Static $sLastBtnText = ""
        If $sLastBtnText <> $sLastAppName Then
            $sLastBtnText = $sLastAppName
            GuiFlatButton_SetData($idBtn[0], $sLastAppName)
        EndIf
    EndIf

    If $bShowSettings Then
        $bShowSettings = False
        _ShowSettingsDialog()
        If $bRebuildBar Then
            $bRebuildBar = False
            _BuildBar()
            _BuildMenus()
        EndIf
    EndIf

    ; Repaint every 500 ms (for clock update)
    If TimerDiff($iLastPaint) > 500 Then
        _PaintBar()
        $iLastPaint = TimerInit()
    EndIf
EndFunc

; ===========================================================================
; SETTINGS DIALOG
; ===========================================================================
Func _ShowSettingsDialog()
    If $hSettingsDlg <> 0 And WinExists($hSettingsDlg) Then
        WinActivate($hSettingsDlg)
        Return
    EndIf

    Local $iDW = 480, $iDH = 290
    Local $iDX = (@DesktopWidth  - $iDW) / 2
    Local $iDY = (@DesktopHeight - $iDH) / 2

    $hSettingsDlg = GUICreate("▼ Bar Settings", $iDW, $iDH, $iDX, $iDY, _
        BitOR($WS_POPUP, $WS_CAPTION, $WS_SYSMENU), $WS_EX_TOPMOST)

    Local $tVal2 = DllStructCreate("int")
    DllStructSetData($tVal2, 1, 1)
    DllCall("dwmapi.dll", "long", "DwmSetWindowAttribute", "hwnd", $hSettingsDlg, _
        "dword", 20, "struct*", $tVal2, "dword", 4)

    GUISetBkColor(0x2D2D2D, $hSettingsDlg)

    Local $oldEventMode = Opt("GUIOnEventMode", 0)

    Local $iY = 15

    GUICtrlCreateLabel("Ignore when a fullscreen app is running", 30, $iY, 300, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    Local $hChk2 = GUICtrlCreateCheckbox("", 15, $iY, 15, 15)
    GUICtrlSetState($hChk2, ($bIgnoreFS) ? $GUI_CHECKED : $GUI_UNCHECKED)
    $iY += 28

    GUICtrlCreateLabel("Use current default file manager", 30, $iY, 420, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    Local $hChk4 = GUICtrlCreateCheckbox("", 15, $iY, 15, 15)
    GUICtrlSetState($hChk4, ($bMakeExpDef) ? $GUI_CHECKED : $GUI_UNCHECKED)
    $iY += 28

    ; Reserve space checkbox
    GUICtrlCreateLabel("Reserve screen space (like taskbar)", 30, $iY, 300, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    GUICtrlSetBkColor(-1, 0x2D2D2D)
    Local $hChk5 = GUICtrlCreateCheckbox("", 15, $iY, 15, 15)
    GUICtrlSetState($hChk5, ($bReserveSpace) ? $GUI_CHECKED : $GUI_UNCHECKED)
    $iY += 36

    GUICtrlCreateLabel("─────────────────────────────────────────────────────", 10, $iY, 460, 2)
    GUICtrlSetColor(-1, 0x555555)
    $iY += 14

    GUICtrlCreateLabel("Toggle Hotkey:", 15, $iY + 3, 110, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    Local $hHotkey = GUICtrlCreateInput($sHotkey, 130, $iY, 150, 22, $ES_AUTOHSCROLL)
    GUICtrlSetBkColor($hHotkey, 0x1E1E1E)
    GUICtrlSetColor($hHotkey, 0xDCDCDC)
    GUICtrlSetTip($hHotkey, "^h = Ctrl+H  !m = Alt+M  +s = Shift+S")
    $iY += 34

    GUICtrlCreateLabel("Custom Icon:", 15, $iY + 3, 110, 20)
    GUICtrlSetColor(-1, 0xDCDCDC)
    Local $hIconPath = GUICtrlCreateInput($sIconPath, 130, $iY, 270, 22, $ES_AUTOHSCROLL)
    GUICtrlSetBkColor($hIconPath, 0x1E1E1E)
    GUICtrlSetColor($hIconPath, 0xDCDCDC)
    Local $hBrowse = GUICtrlCreateButton("Browse", 408, $iY, 58, 24)
    GUICtrlSetBkColor($hBrowse, 0x3A3A3A)
    GUICtrlSetColor($hBrowse, 0xDCDCDC)
    $iY += 34

    $iY += 10

    ; Center the buttons at the bottom - SAVE and CANCEL in all caps
    Local $iButtonWidth = 100
    Local $iButtonSpacing = 20
    Local $iTotalWidth = ($iButtonWidth * 2) + $iButtonSpacing
    Local $iStartX = ($iDW - $iTotalWidth) / 2
    
    Local $hSave   = GUICtrlCreateButton("SAVE", $iStartX, $iDH - 50, $iButtonWidth, 32)
    GUICtrlSetBkColor($hSave, 0x3D5A80)
    GUICtrlSetColor($hSave, 0xFFFFFF)
    
    Local $hCancel = GUICtrlCreateButton("CANCEL", $iStartX + $iButtonWidth + $iButtonSpacing, $iDH - 50, $iButtonWidth, 32)
    GUICtrlSetBkColor($hCancel, 0x3A3A3A)
    GUICtrlSetColor($hCancel, 0xDCDCDC)

    GUISetState(@SW_SHOW, $hSettingsDlg)

    While 1
        Local $nMsg = GUIGetMsg()
        Switch $nMsg
            Case $GUI_EVENT_CLOSE, $hCancel
                ExitLoop

            Case $hBrowse
                Local $sPicked = FileOpenDialog("Select Icon", @ScriptDir & "\icons\", "Icons (*.ico;*.exe)", 1)
                If Not @error Then GUICtrlSetData($hIconPath, $sPicked)

            Case $hSave
                Local $bOldReserveSpace = $bReserveSpace
                
                $bIgnoreFS   = (GUICtrlRead($hChk2) = $GUI_CHECKED)
                $bMakeExpDef = (GUICtrlRead($hChk4) = $GUI_CHECKED)
                $bReserveSpace = (GUICtrlRead($hChk5) = $GUI_CHECKED)

                Local $sNewHotkey = GUICtrlRead($hHotkey)
                If $sNewHotkey <> $sHotkey Then
                    HotKeySet($sHotkey)
                    $sHotkey = $sNewHotkey
                    HotKeySet($sHotkey, "_ShowSettings")
                EndIf

                $sIconPath  = GUICtrlRead($hIconPath)

                _SaveSettings()
                
                ; Restart the script
                GUIDelete($hSettingsDlg)  ; Close dialog first
                $hSettingsDlg = 0
                _RestartScript() 

                $sIconPath  = GUICtrlRead($hIconPath)

                _SaveSettings()
                ; Set a flag; _MainLoop will rebuild after this dialog closes.
                Global $bRebuildBar = True
                ExitLoop
        EndSwitch
        Sleep(10)
    WEnd

    GUIDelete($hSettingsDlg)
    $hSettingsDlg = 0

    Opt("GUIOnEventMode", $oldEventMode)
EndFunc


; ===========================================================================
; SHOW SETTINGS (hotkey handler)
; ===========================================================================
Func _ShowSettings()
    $bShowSettings = True
EndFunc

; ===========================================================================
; ACTIVE APP TRACKING
; ===========================================================================
Func _UpdateActiveApp()
    ; Don't overwrite the saved window while a menu action is in progress
    If $bMenuTracking Then Return

    Local $hActive = WinGetHandle("[ACTIVE]")
    If @error Then Return

    Local $sTitle = WinGetTitle($hActive)
    ; Don't update if our bar or settings dialog is active
    If $sTitle = "MacMenuBar" Or $sTitle = "▼ Bar Settings" Then Return

    $hLastActiveWnd = $hActive

    Local $iPID = WinGetProcess($hActive)
    ; Only rebuild the app name when the foreground PID actually changes
    If $iPID = $iLastActivePID Then Return
    $iLastActivePID = $iPID

    Local $sName = _ProcessGetName($iPID)
    If StringLen($sName) > 26 Then $sName = StringLeft($sName, 23) & "..."
    If $sName = ""  Then $sName = "Desktop"
    $sLastAppName = $sName
EndFunc

Func _ProcessGetName($iPID)
    ; Cache result by PID - ProcessList() is slow, don't call it unless PID changed
    Static $iCachedPID  = -1
    Static $sCachedName = "Desktop"
    If $iPID = $iCachedPID Then Return $sCachedName

    Local $a = ProcessList()
    For $i = 1 To $a[0][0]
        If $a[$i][1] = $iPID Then
            $iCachedPID  = $iPID
            $sCachedName = StringReplace($a[$i][0], ".exe", "")
            Return $sCachedName
        EndIf
    Next
    $iCachedPID  = $iPID
    $sCachedName = "Desktop"
    Return "Desktop"
EndFunc

Func _ProcessGetExePath($iPID)
    Local $hProc = DllCall("kernel32.dll", "handle", "OpenProcess", _
        "dword", 0x0410, "bool", False, "dword", $iPID)
    If @error Or $hProc[0] = 0 Then Return ""
    Local $tBuf  = DllStructCreate("wchar[1024]")
    Local $tSize = DllStructCreate("dword")
    DllStructSetData($tSize, 1, 1024)
    DllCall("kernel32.dll", "bool", "QueryFullProcessImageNameW", _
        "handle", $hProc[0], "dword", 0, "struct*", $tBuf, "struct*", $tSize)
    DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $hProc[0])
    Return DllStructGetData($tBuf, 1)
EndFunc

; ===========================================================================
; TIME FORMATTING
; ===========================================================================
Func _GetFormattedTime()
    Local $aDays[7]    = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    Local $aMonths[13] = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    Local $iHour = @HOUR
    Local $sAMPM = "AM"
    If $iHour >= 12 Then
        $sAMPM = "PM"
        If $iHour > 12 Then $iHour -= 12
    EndIf
    If $iHour = 0 Then $iHour = 12
    Return $aDays[@WDAY - 1] & "  " & $aMonths[@MON] & " " & @MDAY & _
           "   " & $iHour & ":" & StringFormat("%02i", @MIN) & " " & $sAMPM
EndFunc

; ===========================================================================
; MENU ACTION HANDLERS
; ===========================================================================
Func _LaunchItem($sCmd)
    If StringLeft($sCmd, 3) = "ms-" Or StringLeft($sCmd, 16) = "windowsdefender:" Then
        ShellExecute($sCmd)
    ElseIf StringLeft($sCmd, 8) = "control " Then
        Run("control " & StringMid($sCmd, 9))
    Else
        ShellExecute($sCmd)
    EndIf
EndFunc

Func _JumpToFolder($iIdx)
    If $bMakeExpDef Then
        ; Let Windows use the default file manager
        ShellExecute($aJumpPaths[$iIdx])
    Else
        If FileExists($aJumpPaths[$iIdx]) Then
            Run('explorer.exe "' & $aJumpPaths[$iIdx] & '"')
        Else
            ShellExecute("explorer.exe", "shell:" & $aJumpFolders[$iIdx])
        EndIf
    EndIf
EndFunc

Func _RunTool($iIdx)
    Local $sExe   = $aTools[$iIdx][1]
    Local $bAdmin = $aTools[$iIdx][2]
    Local $bShell = $aTools[$iIdx][3]

    ; Special: Screenshot shortcut (Win+Shift+S)
    If $sExe = "__SCREENSHOT__" Then
        Send("#+s")
        Return
    EndIf

    ; Shell URI (ms-settings:, windowsdefender:, etc.)
    If $bShell Then
        ShellExecute($sExe)
        Return
    EndIf

    ; Control Panel shorthand e.g. "control powercfg.cpl"
    If StringLeft($sExe, 8) = "control " Then
        Run($sExe)
        Return
    EndIf

    ; Regular exe
    If $bAdmin Then
        ShellExecute($sExe, "", "", "runas")
    Else
        ShellExecute($sExe)
    EndIf
EndFunc

; ===========================================================================
; WINDOW POSITIONING
; ===========================================================================
Func _PositionWindow($iIdx)
    Local $hWnd = $hLastActiveWnd
    If Not IsHWnd($hWnd) Or $hWnd = 0 Then Return
    WinActivate($hWnd)
    Sleep(50)
    Local $aPos = WinGetPos($hWnd)
    If @error Then Return

    Switch $aWinPositions[$iIdx]
        Case "UP"
            WinMove($hWnd, "", $aPos[0], $iBarHeight)
        Case "DOWN"
            WinMove($hWnd, "", $aPos[0], @DesktopHeight - $aPos[3] - $iTaskbarHeight)
        Case "LEFT"
            WinMove($hWnd, "", 0, $aPos[1])
        Case "RIGHT"
            WinMove($hWnd, "", @DesktopWidth - $aPos[2], $aPos[1])
        Case "CENTER"
            WinMove($hWnd, "", (@DesktopWidth - $aPos[2]) / 2, (@DesktopHeight - $aPos[3] - $iTaskbarHeight) / 2)
        Case "UP LEFT"
            WinMove($hWnd, "", 0, $iBarHeight)
        Case "UP RIGHT"
            WinMove($hWnd, "", @DesktopWidth - $aPos[2], $iBarHeight)
        Case "DOWN LEFT"
            WinMove($hWnd, "", 0, @DesktopHeight - $aPos[3] - $iTaskbarHeight)
        Case "DOWN RIGHT"
            WinMove($hWnd, "", @DesktopWidth - $aPos[2], @DesktopHeight - $aPos[3] - $iTaskbarHeight)
    EndSwitch
EndFunc

Func _ResizeWindow($iIdx)
    Local $hWnd = $hLastActiveWnd
    If Not IsHWnd($hWnd) Or $hWnd = 0 Then Return
    WinActivate($hWnd)
    Sleep(50)
    Local $aPos = WinGetPos($hWnd)
    If @error Then Return
    WinMove($hWnd, "", $aPos[0], $aPos[1], _
        Number($aResizePresets[$iIdx][0]), Number($aResizePresets[$iIdx][1]))
EndFunc

Func _OpenAppLocation()
    Local $hWnd = $hLastActiveWnd
    If Not IsHWnd($hWnd) Then Return
    Local $iPID  = WinGetProcess($hWnd)
    Local $sPath = _ProcessGetExePath($iPID)
    If FileExists($sPath) Then
        If $bMakeExpDef Then
            ; Open parent folder with default file manager
            ShellExecute(StringRegExpReplace($sPath, "\\[^\\]+$", ""))
        Else
            Run('explorer.exe /select,"' & $sPath & '"')
        EndIf
    EndIf
EndFunc

Func _ToggleAppWindow()
    Local $hWnd = $hLastActiveWnd
    If Not IsHWnd($hWnd) Then Return
    If BitAND(WinGetState($hWnd), 2) Then
        WinSetState($hWnd, "", @SW_HIDE)
    Else
        WinSetState($hWnd, "", @SW_SHOW)
        WinActivate($hWnd)
    EndIf
EndFunc

Func _ToggleFileExtension()
    Local $iVal = RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "HideFileExt")
    If @error Then $iVal = 1
    RegWrite("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", _
        "HideFileExt", "REG_DWORD", ($iVal = 0) ? 1 : 0)
    _RefreshExplorer()
    ; Reactivate last window before sending F5
    If IsHWnd($hLastActiveWnd) And WinExists($hLastActiveWnd) Then
        WinActivate($hLastActiveWnd)
        Sleep(150)
    EndIf
    Send("{F5}")
    MsgBox($MB_OK, "File Extensions", "File extensions are now " & (($iVal = 0) ? "HIDDEN" : "SHOWN") & ".")
EndFunc

Func _ToggleHiddenFiles()
    Local $iVal = RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "Hidden")
    If @error Then $iVal = 2
    RegWrite("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", _
        "Hidden", "REG_DWORD", ($iVal = 1) ? 2 : 1)
    _RefreshExplorer()
    ; Reactivate last window before sending F5
    If IsHWnd($hLastActiveWnd) And WinExists($hLastActiveWnd) Then
        WinActivate($hLastActiveWnd)
        Sleep(150)
    EndIf
    Send("{F5}")
    MsgBox($MB_OK, "Hidden Files", "Hidden files are now " & (($iVal = 1) ? "HIDDEN" : "SHOWN") & ".")
EndFunc

Func _RefreshExplorer()
    DllCall("user32.dll", "lresult", "SendMessageTimeout", "hwnd", 0xFFFF, _
        "uint", 0x001A, "wparam", 0, "lparam", "str", "Environment", _
        "uint", 2, "dword", 1000, "dword*", 0)
EndFunc

; ===========================================================================
; FULLSCREEN DETECTION — uses WinAPISysWin.au3
; ===========================================================================
Func _IsFullscreenAppRunning()
    Local $hFG = _WinAPI_GetForegroundWindow()
    If $hFG = 0 Then Return False
    If $hFG = $hBarWnd Then Return False

    ; Exclude desktop shell windows
    ; fullscreen apps. Without this, clicking the desktop hides the bar.
    Local $sClass = _WinAPI_GetClassName($hFG)
    Switch $sClass
        Case "Progman", "WorkerW", "Shell_DefView", "Shell_TrayWnd", "DV2ControlHost"
            Return False
    EndSwitch

    ; Get the window's bounding rect using WinAPISysWin
    Local $tRect = _WinAPI_GetWindowRect($hFG)
    If @error Then Return False

    ; Get the monitor this window is on
    Local $hMonitor = _WinAPI_MonitorFromWindow($hFG, 2) ; 2 = MONITOR_DEFAULTTONEAREST
    If $hMonitor = 0 Then Return False

    ; Get that monitor's full rectangle (not work area)
    Local $tMonInfo  = DllStructCreate("dword cbSize;long left;long top;long right;long bottom;long wleft;long wtop;long wright;long wbottom;dword dwFlags")
    DllStructSetData($tMonInfo, "cbSize", DllStructGetSize($tMonInfo))
    Local $aRet = DllCall("user32.dll", "bool", "GetMonitorInfoW", "handle", $hMonitor, "struct*", $tMonInfo)
    If @error Or Not $aRet[0] Then Return False

    ; Compare window rect to the monitor's FULL rect (including taskbar area)
    Local $iWL = DllStructGetData($tRect, "Left")
    Local $iWT = DllStructGetData($tRect, "Top")
    Local $iWR = DllStructGetData($tRect, "Right")
    Local $iWB = DllStructGetData($tRect, "Bottom")

    Local $iML = DllStructGetData($tMonInfo, "left")
    Local $iMT = DllStructGetData($tMonInfo, "top")
    Local $iMR = DllStructGetData($tMonInfo, "right")
    Local $iMB = DllStructGetData($tMonInfo, "bottom")

    ; Window must cover the entire monitor (including taskbar — true fullscreen)
    If $iWL <= $iML And $iWT <= $iMT And $iWR >= $iMR And $iWB >= $iMB Then
        Return True
    EndIf

    Return False
EndFunc

; ===========================================================================
; WORK AREA MANAGEMENT - Makes bar behave like real taskbar
; ===========================================================================
Func _UpdateWorkArea($bReserve)
    Local $tRect = DllStructCreate("long left; long top; long right; long bottom")
    
    If $bReserve Then
        ; Reserve space at top for the bar, accounting for taskbar at bottom
        DllStructSetData($tRect, "left", 0)
        DllStructSetData($tRect, "top", $iBarHeight)
        DllStructSetData($tRect, "right", @DesktopWidth)
        DllStructSetData($tRect, "bottom", @DesktopHeight - $iTaskbarHeight)
    Else
        ; Reset to full screen minus taskbar
        DllStructSetData($tRect, "left", 0)
        DllStructSetData($tRect, "top", 0)
        DllStructSetData($tRect, "right", @DesktopWidth)
        DllStructSetData($tRect, "bottom", @DesktopHeight - $iTaskbarHeight)
    EndIf
    
    ; Set the new work area
    _SystemParametersInfo(0x002F, 0, DllStructGetPtr($tRect), 1) ; SPI_SETWORKAREA
    
    ; Tell Windows to refresh (broadcast the change)
    DllCall("user32.dll", "lresult", "SendMessageTimeout", _
        "hwnd", 0xFFFF, "uint", 0x001A, "wparam", 0, "lparam", 0, _
        "uint", 2, "dword", 1000, "dword*", 0)
    
    ; Force all top-level windows to reposition
    WinSetState("[CLASS:Progman]", "", @SW_HIDE)
    WinSetState("[CLASS:Progman]", "", @SW_SHOW)
    
    ; Also refresh the shell - FIXED: Keep this on one line or use proper line continuation
    Local $hTray = WinGetHandle("[CLASS:Shell_TrayWnd]")
    If Not @error Then
        DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hTray, _
            "hwnd", 0, "int", 0, "int", 0, "int", 0, "int", 0, _
            "uint", BitOR(0x0002, 0x0001)) ; SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE
    EndIf
EndFunc

; Wrapper for SystemParametersInfo - KEEP ONLY ONE VERSION
Func _SystemParametersInfo($iAction, $iParam, $pParam, $iUpdate)
    Local $aResult = DllCall("user32.dll", "bool", "SystemParametersInfoW", _
        "uint", $iAction, "uint", $iParam, "ptr", $pParam, "uint", $iUpdate)
    If @error Then Return False
    Return $aResult[0]
EndFunc

; ===========================================================================
; SETTINGS LOAD / SAVE
; ===========================================================================
Func _LoadSettings()
    Local $ini = @ScriptDir & "\settings.ini"
    If Not FileExists($ini) Then Return
	$bIgnoreFS   = (IniRead($ini, "Settings", "IgnoreFullscreen",   "False") = "True")
	$bMakeExpDef = (IniRead($ini, "Settings", "UseDefaultFileManager","False") = "True")
	$bReserveSpace = (IniRead($ini, "Settings", "ReserveSpace",     "False") = "True")
	$sHotkey     = IniRead($ini, "Settings", "Hotkey",              "^h")
    $sIconPath   = IniRead($ini, "Settings", "IconPath",            @ScriptDir & "\icons\mac.ico")
    $iBarHeight  = Number(IniRead($ini, "Settings", "BarHeight",    "30"))
    If $iBarHeight < 20 Then $iBarHeight = 20
    If $iBarHeight > 60 Then $iBarHeight = 60
    HotKeySet($sHotkey, "_ShowSettings")
EndFunc

Func _SaveSettings()
    Local $ini = @ScriptDir & "\settings.ini"
    IniWrite($ini, "Settings", "IgnoreFullscreen",    $bIgnoreFS)
    IniWrite($ini, "Settings", "UseDefaultFileManager", $bMakeExpDef)
	IniWrite($ini, "Settings", "ReserveSpace",        $bReserveSpace) 
    IniWrite($ini, "Settings", "Hotkey",              $sHotkey)
    IniWrite($ini, "Settings", "IconPath",            $sIconPath)
    IniWrite($ini, "Settings", "BarHeight",           $iBarHeight)
EndFunc

; ===========================================================================
; TRAY ICON
; ===========================================================================
Func _CreateTrayIcon()
    Local $idShow = TrayCreateItem("Show Menu Bar")
    TrayItemSetOnEvent($idShow, "_TrayShowBar")
    Local $idHide = TrayCreateItem("Hide Menu Bar")
    TrayItemSetOnEvent($idHide, "_TrayHideBar")
    TrayCreateItem("")
    Local $idSettings = TrayCreateItem("Bar Settings")
    TrayItemSetOnEvent($idSettings, "_TraySettings")
    TrayCreateItem("")
    Local $idExit = TrayCreateItem("Exit")
    TrayItemSetOnEvent($idExit, "_ExitApp")
    TraySetState($TRAY_ICONSTATE_SHOW)
    TraySetToolTip("MacOS Style Dark Menu Bar")
    TraySetClick(16)
EndFunc

Func _TrayShowBar()
    $bBarVisible = True
    ; First invalidate the entire window to clear any stale white content
    ; left from when the window was hidden, then show and force a repaint.
    DllCall("user32.dll", "bool", "InvalidateRect", "hwnd", $hBarWnd, "ptr", 0, "bool", True)
    GUISetState(@SW_SHOW, $hBarWnd)
    ; SetWindowPos with SWP_SHOWWINDOW | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER
    ; forces Windows to redraw the window cleanly in one shot
    DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hBarWnd, _
        "hwnd", 0, "int", 0, "int", 0, "int", 0, "int", 0, _
        "uint", BitOR(0x0040, 0x0002, 0x0001, 0x0004)) ; SWP_SHOWWINDOW|SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER
    _PaintBar()
EndFunc

Func _TrayHideBar()
    $bBarVisible = False
    GUISetState(@SW_HIDE, $hBarWnd)
EndFunc

Func _TraySettings()
    $bShowSettings = True
EndFunc

; ===========================================================================
; FUNCTIONS FROM MENUTEST.AU3 FOR DARK MODE
; ===========================================================================
Func _SetCtrlColorMode($hWnd, $bDarkMode = True, $sName = Default)
    If $sName = Default Then $sName = $bDarkMode ? 'DarkMode_Explorer' : 'Explorer'
    $bDarkMode = Not Not $bDarkMode
    If Not IsHWnd($hWnd) And $hWnd <> 0 Then $hWnd = GUICtrlGetHandle($hWnd)
    Local Enum $eDefault, $eAllowDark, $eForceDark, $eForceLight, $eMax
    If $hWnd <> 0 Then DllCall('uxtheme.dll', 'bool', 133, 'hwnd', $hWnd, 'bool', $bDarkMode)
    DllCall('uxtheme.dll', 'int', 135, 'int', ($bDarkMode ? $eForceDark : $eForceLight))
    If $hWnd <> 0 Then _WinAPI_SetWindowTheme_unr($hWnd, $sName)
    DllCall('uxtheme.dll', 'none', 104)
    If $hWnd <> 0 Then _SendMessage($hWnd, $WM_THEMECHANGED, 0, 0)
EndFunc

Func _WinAPI_SetWindowTheme_unr($hWnd, $sName = Null, $sList = Null)
    Local $sResult = DllCall('UxTheme.dll', 'long', 'SetWindowTheme', 'hwnd', $hWnd, 'wstr', $sName, 'wstr', $sList)
    If @error Then Return SetError(@error, @extended, 0)
    If $sResult[0] Then Return SetError(10, $sResult[0], 0)
    Return 1
EndFunc

; ===========================================================================
; EXIT
; ===========================================================================
Func _ExitApp()
    AdlibUnRegister("_MainLoop")
    _UpdateWorkArea(False)  ; Restore full screen area on exit (minus taskbar)
    _SaveSettings()
    If $hOldBmp Then _WinAPI_SelectObject($hMemDC, $hOldBmp)
    If $hBitmap Then _WinAPI_DeleteObject($hBitmap)
    If $hMemDC Then _WinAPI_DeleteDC($hMemDC)
    If $hBarDC Then _WinAPI_ReleaseDC($hBarWnd, $hBarDC)
    If $hFont Then _WinAPI_DeleteObject($hFont)
    If $hFontBold Then _WinAPI_DeleteObject($hFontBold)
    If $hA1Icon Then DllCall("user32.dll", "bool", "DestroyIcon", "handle", $hA1Icon)
    _GDIPlus_Shutdown()
    Exit
EndFunc

; ===========================================================================
; SAFE EXIT - avoids freezing when called from menu handlers
; ===========================================================================
Func _SafeExit()
    AdlibUnRegister("_MainLoop")
    _UpdateWorkArea(False)
    _SaveSettings()
    
    ; Clean up resources
    If $hOldBmp Then _WinAPI_SelectObject($hMemDC, $hOldBmp)
    If $hBitmap Then _WinAPI_DeleteObject($hBitmap)
    If $hMemDC Then _WinAPI_DeleteDC($hMemDC)
    If $hBarDC Then _WinAPI_ReleaseDC($hBarWnd, $hBarDC)
    If $hFont Then _WinAPI_DeleteObject($hFont)
    If $hFontBold Then _WinAPI_DeleteObject($hFontBold)
    If $hA1Icon Then DllCall("user32.dll", "bool", "DestroyIcon", "handle", $hA1Icon)
    
    ; Close the main window
    If IsHWnd($hBarWnd) Then GUIDelete($hBarWnd)
    
    ; Release the mutex
    If $hMutex Then DllCall("kernel32.dll", "bool", "ReleaseMutex", "handle", $hMutex)
    
    _GDIPlus_Shutdown()
    
    ; Set a flag to exit the main loop
    Global $bExitApp = True
EndFunc