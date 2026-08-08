; Tianxuan Desktop NSIS installer script
; Build output: build/windows/x64/runner/Release/

!define PRODUCT_NAME "Tianxuan Desktop"
!define PRODUCT_DIR "Tianxuan"

!include "MUI2.nsh"

; Installer output (relative to script dir scripts/desktop/ → repo root)
OutFile "..\..\setup-windows-x64.exe"

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
InstallDir "$PROGRAMFILES64\${PRODUCT_DIR}"

; Silent mode for auto-update: /S
RequestExecutionLevel admin

Section "Install"
  SetOutPath "$INSTDIR"
  ; 相对脚本目录（scripts/desktop/）定位构建产物
  File /r "..\..\build\windows\x64\runner\Release\*.*"
  CreateShortCut "$DESKTOP\${PRODUCT_NAME}.lnk" "$INSTDIR\tianxuan.exe"
  CreateDirectory "$SMPROGRAMS\${PRODUCT_DIR}"
  CreateShortCut "$SMPROGRAMS\${PRODUCT_DIR}\${PRODUCT_NAME}.lnk" "$INSTDIR\tianxuan.exe"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_DIR}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_DIR}" "UninstallString" "$INSTDIR\Uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\*.*"
  RMDir /r "$INSTDIR"
  Delete "$DESKTOP\${PRODUCT_NAME}.lnk"
  Delete "$SMPROGRAMS\${PRODUCT_DIR}\${PRODUCT_NAME}.lnk"
  RMDir "$SMPROGRAMS\${PRODUCT_DIR}"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_DIR}"
SectionEnd
