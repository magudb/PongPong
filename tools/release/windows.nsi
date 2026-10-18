;!@!UTF8!@!
Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"
!include "x64.nsh"

!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Traetoppen"
Name "Trætoppen"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\Traetoppen"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID lzma
CRCCheck force
VIProductVersion "${VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "Trætoppen Setup"
VIAddVersionKey /LANG=1033 "FileDescription" "Trætoppen installer"
VIAddVersionKey /LANG=1033 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "magudb"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\Traetoppen.exe"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Danish"

Function .onInit
  SetShellVarContext current
  SetRegView 64
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Trætoppen requires 64-bit Windows."
    SetErrorLevel 2
    Abort
  ${EndIf}
FunctionEnd

Function .onVerifyInstDir
  ${GetFileName} "$INSTDIR" $0
  StrCmpS $0 "Traetoppen" +2
  Abort
FunctionEnd

Section "Trætoppen (required)" Game
  SectionIn RO
  ${GetFileName} "$INSTDIR" $0
  StrCmpS $0 "Traetoppen" valid_directory
  SetErrorLevel 2
  Abort
valid_directory:
  SetOutPath "$INSTDIR"
  ClearErrors
  File "${SOURCE_DIR}\Traetoppen.exe"
  File "${SOURCE_DIR}\Traetoppen.pck"
  ${If} ${Errors}
    MessageBox MB_ICONSTOP "Close Trætoppen and run Setup again." /SD IDOK
    SetErrorLevel 2
    Abort
  ${EndIf}
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\Trætoppen.lnk" "$INSTDIR\Traetoppen.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Trætoppen"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "magudb"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Traetoppen.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://github.com/${REPOSITORY}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLUpdateInfo" "https://github.com/${REPOSITORY}/releases"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" ${SIZE_KB}
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section /o "Desktop shortcut" Desktop
  CreateShortcut "$DESKTOP\Trætoppen.lnk" "$INSTDIR\Traetoppen.exe"
SectionEnd

Function un.onInit
  SetShellVarContext current
  SetRegView 64
FunctionEnd

Section "Uninstall"
  ClearErrors
  Delete "$INSTDIR\Traetoppen.exe"
  Delete "$INSTDIR\Traetoppen.pck"
  ${If} ${Errors}
    MessageBox MB_ICONSTOP "Close Trætoppen before uninstalling." /SD IDOK
    SetErrorLevel 2
    Abort
  ${EndIf}
  Delete "$SMPROGRAMS\Trætoppen.lnk"
  Delete "$DESKTOP\Trætoppen.lnk"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  Delete "$INSTDIR\Uninstall.exe"
  ; Remove only our files. Player saves and any other files are retained.
  RMDir "$INSTDIR"
SectionEnd
