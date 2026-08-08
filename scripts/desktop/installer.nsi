; Tianxuan Desktop NSIS installer script
; Build output: build/windows/x64/runner/Release/

!define PRODUCT_NAME "Tianxuan Desktop"
!define INSTALL_DIR "$PROGRAMFILES64\Tianxuan"

!include "MUI2.nsh"

; Installer output (relative to script dir scripts/desktop/ → repo root)
OutFile "..\..\build\installer\setup.exe"

!define MUI_ICON "..\..\assets\icon-1024.png"
!define MUI_UNICON "..\..\assets\icon-1024.png"

; Interface
!define MUI_ABORTWARNING

; Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Languages
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

; Default install dir
InstallDir "$INSTALL_DIR"

; Silent mode for auto-update: /S
RequestExecutionLevel admin

Section "Install"
  SetOutPath "$INSTDIR"
  ; 相对脚本目录（scripts/desktop/）定位构建产物
  File /r "..\..\build\windows\x64\runner\Release\*.*"
  CreateShortCut "$DESKTOP\Tianxuan.lnk" "$INSTDIR\tianxuan.exe"
  CreateDirectory "$SMPROGRAMS\Tianxuan"
  CreateShortCut "$SMPROGRAMS\Tianxuan\Tianxuan.lnk" "$INSTDIR\tianxuan.exe"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tianxuan" "DisplayName" "Tianxuan Desktop"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tianxuan" "UninstallString" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\*.*"
  RMDir /r "$INSTDIR"
  Delete "$DESKTOP\Tianxuan.lnk"
  Delete "$SMPROGRAMS\Tianxuan\Tianxuan.lnk"
  RMDir "$SMPROGRAMS\Tianxuan"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tianxuan"
SectionEnd
