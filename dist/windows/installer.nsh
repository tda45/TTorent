Var uninstallerPath

Section "-hidden"

    ;Search if TTorent is already installed.
    FindFirst $0 $1 "$uninstallerPath\uninst.exe"
    FindClose $0
    StrCmp $1 "" done

    ;Run the uninstaller of the previous install.
    DetailPrint $(inst_unist)
    ExecWait '"$uninstallerPath\uninst.exe" /S _?=$uninstallerPath'
    Delete "$uninstallerPath\uninst.exe"
    RMDir "$uninstallerPath"

    done:

SectionEnd


Section $(inst_qbt_req) ;"TTorent (required)"

  SectionIn RO

  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  ; Put files there
  File "${QBT_DIST_DIR}\TTorent.exe"
  File "qt.conf"
  File /nonfatal /r /x "${QBT_DIST_DIR}\TTorent.exe" "${QBT_DIST_DIR}\*.*"

  ; Write the installation path into the registry
  WriteRegStr HKLM "Software\TTorent" "InstallLocation" "$INSTDIR"

  ; Register TTorent as possible default program for .torrent files and magnet links
  WriteRegStr HKLM "Software\TTorent\Capabilities" "ApplicationDescription" "A BitTorrent client in Qt"
  WriteRegStr HKLM "Software\TTorent\Capabilities" "ApplicationName" "TTorent"
  WriteRegStr HKLM "Software\TTorent\Capabilities\FileAssociations" ".torrent" "TTorent.File.Torrent"
  WriteRegStr HKLM "Software\TTorent\Capabilities\UrlAssociations" "magnet" "TTorent.Url.Magnet"
  WriteRegStr HKLM "Software\RegisteredApplications" "TTorent" "Software\TTorent\Capabilities"
  ; Register TTorent ProgIDs
  WriteRegStr HKLM "Software\Classes\TTorent.File.Torrent" "" "Torrent File"
  WriteRegStr HKLM "Software\Classes\TTorent.File.Torrent\DefaultIcon" "" '"$INSTDIR\TTorent.exe",1'
  WriteRegStr HKLM "Software\Classes\TTorent.File.Torrent\shell\open\command" "" '"$INSTDIR\TTorent.exe" "%1"'
  WriteRegStr HKLM "Software\Classes\TTorent.Url.Magnet" "" "Magnet URI"
  WriteRegStr HKLM "Software\Classes\TTorent.Url.Magnet\DefaultIcon" "" '"$INSTDIR\TTorent.exe",1'
  WriteRegStr HKLM "Software\Classes\TTorent.Url.Magnet\shell\open\command" "" '"$INSTDIR\TTorent.exe" "%1"'

  WriteRegStr HKLM "Software\Classes\.torrent" "Content Type" "application/x-bittorrent"
  WriteRegStr HKLM "Software\Classes\magnet" "" "URL:Magnet URI"
  WriteRegStr HKLM "Software\Classes\magnet" "Content Type" "application/x-magnet"
  WriteRegStr HKLM "Software\Classes\magnet" "URL Protocol" ""

  System::Call 'shell32::SHChangeNotify(i ${SHCNE_ASSOCCHANGED}, i ${SHCNF_IDLIST}, p 0, p 0)'

  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "DisplayName" "TTorent"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "UninstallString" '"$INSTDIR\uninst.exe"'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "DisplayIcon" '"$INSTDIR\TTorent.exe",0'
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "Publisher" "The TTorent project"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "URLInfoAbout" "https://www.TTorent.org"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "DisplayVersion" "${QBT_VERSION}"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "NoRepair" 1
  WriteUninstaller "uninst.exe"
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\TTorent" "EstimatedSize" "$0"

SectionEnd

; Optional section (can be disabled by the user)
Section /o $(inst_desktop) ;"Create Desktop Shortcut"

  CreateShortCut "$DESKTOP\TTorent.lnk" "$INSTDIR\TTorent.exe"

SectionEnd

Section $(inst_startmenu) ;"Create Start Menu Shortcut"

  CreateDirectory "$SMPROGRAMS\TTorent"
  CreateShortCut "$SMPROGRAMS\TTorent\TTorent.lnk" "$INSTDIR\TTorent.exe"
  CreateShortCut "$SMPROGRAMS\TTorent\$(inst_uninstall_link_description).lnk" "$INSTDIR\uninst.exe"

SectionEnd

Section /o $(inst_startup) ;"Start TTorent on Windows start up"

  !insertmacro UAC_AsUser_Call Function inst_startup_user ${UAC_SYNCREGISTERS}|${UAC_SYNCOUTDIR}|${UAC_SYNCINSTDIR}

SectionEnd

Function inst_startup_user

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "TTorent" "$INSTDIR\TTorent.exe"

FunctionEnd

Section $(inst_firewall)

  DetailPrint $(inst_firewallinfo)
  nsisFirewallW::AddAuthorizedApplication "$INSTDIR\TTorent.exe" "TTorent"

SectionEnd

Section $(inst_pathlimit) ;"Disable Windows path length limit (260 character MAX_PATH limitation, requires Windows 10 1607 or later)"

  WriteRegDWORD HKLM "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1

SectionEnd

;--------------------------------

Function .onInit

  !insertmacro Init "installer"
  !insertmacro MUI_LANGDLL_DISPLAY

  ${IfNot} ${AtLeastWaaS} 1809 ; Windows 10 (1809) / Windows Server 2019. Min supported version by Qt6
    MessageBox MB_OK|MB_ICONEXCLAMATION $(inst_requires_win10) /SD IDOK
    SetErrorLevel 1654 # WinError.h: `ERROR_INSTALL_REJECTED`
    Abort
  ${EndIf}

  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONEXCLAMATION $(inst_requires_64bit) /SD IDOK
    SetErrorLevel 1654 # WinError.h: `ERROR_INSTALL_REJECTED`
    Abort
  ${EndIf}

  ; check installer and current system architecture
  ${If} "${QBT_CPU_ARCH}" == "arm64"
  ${AndIf} ${IsNativeAMD64}  ; installing arm64 binary on x64
    MessageBox MB_OK|MB_ICONEXCLAMATION $(inst_arch_mismatch_arm64_on_x64) /SD IDOK
    SetErrorLevel 1654 # WinError.h: `ERROR_INSTALL_REJECTED`
    Abort
  ${EndIf}

  ;Search if TTorent is already installed.
  FindFirst $0 $1 "$INSTDIR\uninst.exe"
  FindClose $0
  StrCmp $1 "" done

  ;Copy old value to var so we can call the correct uninstaller
  StrCpy $uninstallerPath $INSTDIR

  ;Inform the user
  MessageBox MB_OKCANCEL|MB_ICONINFORMATION $(inst_uninstall_question) /SD IDOK IDOK done
  Quit

  done:

FunctionEnd

Function check_instance

  check:
  FindProcDLL::FindProc "TTorent.exe"
  StrCmp $R0 "1" 0 notfound
  MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION $(inst_warning) /SD IDCANCEL IDRETRY check IDCANCEL canceled

  canceled:
  SetErrorLevel 15618 # WinError.h: `ERROR_PACKAGES_IN_USE`
  Abort

  notfound:

FunctionEnd

Function PageFinishRun

  !insertmacro UAC_AsUser_ExecShell "" "$INSTDIR\TTorent.exe" "" "" ""

FunctionEnd

Function .onInstSuccess
  SetErrorLevel 0
FunctionEnd
