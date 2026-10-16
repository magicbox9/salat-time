; Salat Time for Windows — per-user installer (no administrator rights needed).
; Built by windows/build.sh with:  makensis -DVERSION=1.0.0 -DARCH=x64 -DSOURCE=<publish dir> -DOUTFILE=<setup.exe>

Unicode true
!include "MUI2.nsh"
!include "x64.nsh"

!ifndef VERSION
  !define VERSION "1.0.0"
!endif
!ifndef ARCH
  !define ARCH "x64"
!endif

Name "Salat Time"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\Salat Time"
InstallDirRegKey HKCU "Software\SalatTime" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "Salat Time ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "Salat Time"
VIAddVersionKey "FileDescription" "Salat Time installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Salat Time"

!define MUI_ICON "..\src\SalatTime\Assets\AppIcon.ico"
!define MUI_UNICON "..\src\SalatTime\Assets\AppIcon.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\SalatTime.exe"
!define MUI_FINISHPAGE_RUN_TEXT "$(RunNow)"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "Arabic"
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "Portuguese"
!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "SimpChinese"

LangString RunNow ${LANG_ENGLISH} "Open Salat Time"
LangString RunNow ${LANG_FRENCH} "Ouvrir Salat Time"
LangString RunNow ${LANG_ARABIC} "فتح Salat Time"
LangString RunNow ${LANG_SPANISH} "Abrir Salat Time"
LangString RunNow ${LANG_PORTUGUESE} "Abrir o Salat Time"
LangString RunNow ${LANG_RUSSIAN} "Открыть Salat Time"
LangString RunNow ${LANG_SIMPCHINESE} "打开 Salat Time"

Function .onInit
  !if "${ARCH}" == "arm64"
    ${IfNot} ${IsNativeARM64}
      MessageBox MB_ICONEXCLAMATION|MB_OK "This build is for Windows on ARM. Please use the x64 installer on this PC."
      Abort
    ${EndIf}
  !endif
FunctionEnd

Section "Salat Time" Main
  SectionIn RO
  ; Close a running copy so its files can be replaced.
  nsExec::Exec 'taskkill /F /IM SalatTime.exe'
  Sleep 400

  SetOutPath "$INSTDIR"
  File /r "${SOURCE}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortCut "$SMPROGRAMS\Salat Time.lnk" "$INSTDIR\SalatTime.exe" "" "$INSTDIR\SalatTime.exe" 0

  WriteRegStr HKCU "Software\SalatTime" "InstallDir" "$INSTDIR"
  !define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\SalatTime"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Salat Time"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "Salat Time"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\SalatTime.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  nsExec::Exec 'taskkill /F /IM SalatTime.exe'
  Sleep 400
  Delete "$SMPROGRAMS\Salat Time.lnk"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "SalatTime"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SalatTime"
  DeleteRegKey HKCU "Software\SalatTime"
  RMDir /r "$INSTDIR"
  ; Settings, the cached schedule and downloaded recitations stay in
  ; %APPDATA%\SalatTime so a reinstall keeps them.
SectionEnd
