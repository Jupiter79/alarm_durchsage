@echo off
setlocal enabledelayedexpansion

:: --- Administratorrechte anfordern ---
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Fordere Administratorrechte an... Bitte Bestaetigen.
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
:: -------------------------------------

set "LOGFILE=%~dp0install.log"
echo ========================================= > "%LOGFILE%"
echo  Alarm Durchsage Server - Installationslog >> "%LOGFILE%"
echo  Datum: %date% %time% >> "%LOGFILE%"
echo ========================================= >> "%LOGFILE%"

echo =========================================
echo  Alarm Durchsage Server - Windows Installation
echo =========================================
echo.
echo Installationsprotokoll wird gespeichert unter:
echo %LOGFILE%
echo.

:: 1. System-Pakete installieren
echo [1/5] Installiere System-Pakete (Git und VC Redistributable)...
echo [1/5] Installiere System-Pakete... >> "%LOGFILE%"
winget --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Winget nicht gefunden. Versuche Winget AppInstaller nachzuinstallieren...
    echo Versuche Winget zu installieren... >> "%LOGFILE%"
    
    :: VCLibs und UI.Xaml Abhaengigkeiten herunterladen, die oft (z.B. in der Sandbox) fehlen
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile 'vclibs.appx'" >> "%LOGFILE%" 2>&1
    powershell -Command "Add-AppxPackage -Path 'vclibs.appx'" >> "%LOGFILE%" 2>&1
    
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle' -OutFile 'winget.msixbundle'" >> "%LOGFILE%" 2>&1
    powershell -Command "Add-AppxPackage -Path 'winget.msixbundle'" >> "%LOGFILE%" 2>&1
    
    if exist vclibs.appx del vclibs.appx
    if exist uixaml.appx del uixaml.appx
    if exist winget.msixbundle del winget.msixbundle
    
    :: Path für winget aktualisieren
    set "PATH=%LOCALAPPDATA%\Microsoft\WindowsApps;%PATH%"
)

winget --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo Winget gefunden. Installiere Git und VC Redist... >> "%LOGFILE%"
    winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements --silent >> "%LOGFILE%" 2>&1
    winget install -e --id Microsoft.VCRedist.2015+.x64 --accept-package-agreements --accept-source-agreements --silent >> "%LOGFILE%" 2>&1
) else (
    echo Winget konnte nicht installiert werden. Lade VC Redistributable manuell herunter...
    echo Winget ist nicht verfuegbar. Installiere VC Redist manuell... >> "%LOGFILE%"
    
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vs/17/release/vc_redist.x64.exe' -OutFile 'vc_redist.exe'" >> "%LOGFILE%" 2>&1
    if exist vc_redist.exe (
        start /wait vc_redist.exe /install /quiet /norestart
        del vc_redist.exe
    )
)

:: PATH in dieser Session aktualisieren (damit Git sofort verfuegbar ist)
echo Aktualisiere Umgebungsvariablen...
echo Aktualisiere Umgebungsvariablen... >> "%LOGFILE%"
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%B"
set "PATH=%SYS_PATH%;%USR_PATH%;%PATH%;C:\Program Files\Git\cmd"
echo PATH wurde aktualisiert. >> "%LOGFILE%"

:: 2. Projekt herunterladen
echo.
echo [2/5] Lade Projekt herunter...
echo [2/5] Lade Projekt herunter... >> "%LOGFILE%"
set "INSTALL_DIR=%USERPROFILE%\alarm_durchsage"
if not exist "%INSTALL_DIR%" (
    git --version >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo Winget konnte Git nicht installieren. Installiere Git als Notloesung direkt...
        echo Lade Git Installer herunter... >> "%LOGFILE%"
        powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/Git-2.46.0-64-bit.exe' -OutFile 'git_installer.exe'" >> "%LOGFILE%" 2>&1
        if exist git_installer.exe (
            echo Installiere Git im Hintergrund...
            start /wait git_installer.exe /VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS
            del git_installer.exe
            set "PATH=%PATH%;C:\Program Files\Git\cmd"
        )
    )

    git --version >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        echo Git gefunden, klone Repository... >> "%LOGFILE%"
        git clone https://github.com/Jupiter79/alarm_durchsage.git "%INSTALL_DIR%" >> "%LOGFILE%" 2>&1
    ) else (
        echo FEHLER: Git wurde auf diesem System nicht gefunden! >> "%LOGFILE%"
        echo =========================================================
        echo FEHLER: Git ist nicht installiert oder nicht verfuegbar!
        echo.
        echo Da Winget auf diesem System fehlt oder fehlschlug,
        echo konnte Git nicht automatisch installiert werden.
        echo Git ist jedoch zwingend erforderlich, damit das Projekt
        echo heruntergeladen und spaeter aktualisiert werden kann.
        echo.
        echo Bitte lade Git manuell herunter und installiere es:
        echo https://git-scm.com/download/win
        echo =========================================================
        pause
        exit /b 1
    )
    
    if not exist "%INSTALL_DIR%" (
        echo FEHLER: Das Projekt konnte nicht heruntergeladen werden.
        echo Bitte ueberpruefe deine Internetverbindung.
        pause
        exit /b 1
    )
) else (
    echo Verzeichnis existiert bereits. Hole neueste Updates...
    echo Verzeichnis existiert bereits. Hole neueste Updates... >> "%LOGFILE%"
    cd /d "%INSTALL_DIR%"
    git --version >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        git pull >> "%LOGFILE%" 2>&1
    ) else (
        echo Git nicht verfuegbar, Update uebersprungen. >> "%LOGFILE%"
    )
)

cd /d "%INSTALL_DIR%"
echo Wechsle in Verzeichnis: %INSTALL_DIR% >> "%LOGFILE%"

:: 3. Lokale (portable) Python-Umgebung einrichten
echo.
echo [3/5] Richte portable Python-Umgebung ein...
echo [3/5] Richte portable Python-Umgebung ein... >> "%LOGFILE%"

set "PYTHON_DIR=%INSTALL_DIR%\python-embed"
set "PYTHON_CMD=%PYTHON_DIR%\python.exe"

if not exist "%PYTHON_DIR%\python.exe" (
    echo Lade Python 3.11 Embeddable herunter... >> "%LOGFILE%"
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip' -OutFile 'python-embed.zip'" >> "%LOGFILE%" 2>&1
    
    echo Entpacke Python... >> "%LOGFILE%"
    powershell -Command "Expand-Archive -Path 'python-embed.zip' -DestinationPath '%PYTHON_DIR%' -Force" >> "%LOGFILE%" 2>&1
    del python-embed.zip
    
    echo Aktiviere site-packages... >> "%LOGFILE%"
    powershell -Command "(Get-Content '%PYTHON_DIR%\python311._pth') -replace '#import site', 'import site' | Set-Content '%PYTHON_DIR%\python311._pth'" >> "%LOGFILE%" 2>&1
    
    echo Lade get-pip.py herunter und installiere pip... >> "%LOGFILE%"
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile 'get-pip.py'" >> "%LOGFILE%" 2>&1
    "%PYTHON_CMD%" get-pip.py >> "%LOGFILE%" 2>&1
    del get-pip.py
) else (
    echo Portable Python-Umgebung existiert bereits. >> "%LOGFILE%"
)

echo Installiere Python-Abhaengigkeiten...
echo Installiere Python-Abhaengigkeiten... >> "%LOGFILE%"
"%PYTHON_CMD%" -m pip install --upgrade pip >> "%LOGFILE%" 2>&1
"%PYTHON_CMD%" -m pip install -r requirements.txt static-ffmpeg >> "%LOGFILE%" 2>&1

:: 3b. FFmpeg lokal einrichten (100% verlaesslich, ohne PATH-Probleme)
echo.
echo [4/5] Richte FFmpeg lokal ein...
echo [4/5] Richte FFmpeg lokal ein... >> "%LOGFILE%"
%PYTHON_CMD% -c "import static_ffmpeg; static_ffmpeg.add_paths(); import shutil, os; shutil.copy(shutil.which('ffmpeg'), '.'); shutil.copy(shutil.which('ffprobe'), '.')" >> "%LOGFILE%" 2>&1

:: 4. Autostart einrichten
echo.
echo [5/5] Richte Autostart ein...
echo [5/5] Richte Autostart ein... >> "%LOGFILE%"
set "AUTOSTART_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "START_BAT=%INSTALL_DIR%\start_alarm_durchsage.bat"

:: Batch-Skript erstellen zum Starten
(
echo @echo off
echo cd /d "%INSTALL_DIR%"
echo "%PYTHON_CMD%" durchsage.py
) > "%START_BAT%"
echo Start-Skript erstellt unter: %START_BAT% >> "%LOGFILE%"

:: Shortcut im Autostart-Ordner erstellen via PowerShell
set "SHORTCUT_SCRIPT=%INSTALL_DIR%\create_shortcut.ps1"
(
echo $WshShell = New-Object -comObject WScript.Shell
echo $Shortcut = $WshShell.CreateShortcut("%AUTOSTART_DIR%\AlarmDurchsageServer.lnk"^)
echo $Shortcut.TargetPath = "powershell.exe"
echo $Shortcut.Arguments = '-WindowStyle Hidden -Command "Start-Process cmd -ArgumentList ''/c \"%START_BAT%\"'' -WindowStyle Hidden"'
echo $Shortcut.WorkingDirectory = "%INSTALL_DIR%"
echo $Shortcut.Description = "Alarm Durchsage Server Autostart"
echo $Shortcut.Save^(^)
) > "%SHORTCUT_SCRIPT%"

powershell -ExecutionPolicy Bypass -File "%SHORTCUT_SCRIPT%" >> "%LOGFILE%" 2>&1
del "%SHORTCUT_SCRIPT%"
echo Shortcut im Autostart erstellt. >> "%LOGFILE%"

echo.
echo =========================================
echo Installation abgeschlossen!
echo =========================================
echo ========================================= >> "%LOGFILE%"
echo Installation abgeschlossen! >> "%LOGFILE%"
echo ========================================= >> "%LOGFILE%"

echo Das System wurde erfolgreich installiert und in den Autostart eingetragen.
echo.
echo Der Alarmdurchsage-Server wird nun gestartet...
echo Starte Server... >> "%LOGFILE%"
powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%START_BAT%\"\"' -WindowStyle Hidden"
echo.
echo Der Server läuft nun unsichtbar im Hintergrund. 
echo Du kannst das Webinterface im Browser aufrufen unter:
echo http://localhost:8122
echo.
pause
