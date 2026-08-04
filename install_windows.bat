@echo off
setlocal enabledelayedexpansion

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

:: 1. System-Pakete installieren mit Winget (Python und Git)
echo [1/5] Installiere System-Pakete (Python und Git)...
echo [1/5] Installiere System-Pakete (Python und Git)... >> "%LOGFILE%"
winget install -e --id Python.Python.3.11 --accept-package-agreements --accept-source-agreements --silent >> "%LOGFILE%" 2>&1
winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements --silent >> "%LOGFILE%" 2>&1

:: PATH in dieser Session aktualisieren (damit py sofort verfuegbar ist)
echo Aktualisiere Umgebungsvariablen...
echo Aktualisiere Umgebungsvariablen... >> "%LOGFILE%"
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%B"
set "PATH=%SYS_PATH%;%USR_PATH%;%PATH%"
echo PATH wurde aktualisiert. >> "%LOGFILE%"

:: 2. Projekt klonen
echo.
echo [2/5] Lade Projekt herunter...
echo [2/5] Lade Projekt herunter... >> "%LOGFILE%"
set "INSTALL_DIR=%USERPROFILE%\alarm_durchsage"
if not exist "%INSTALL_DIR%" (
    git clone https://github.com/Jupiter79/alarm_durchsage.git "%INSTALL_DIR%" >> "%LOGFILE%" 2>&1
) else (
    echo Verzeichnis existiert bereits. Hole neueste Updates...
    echo Verzeichnis existiert bereits. Hole neueste Updates... >> "%LOGFILE%"
    cd /d "%INSTALL_DIR%"
    git pull >> "%LOGFILE%" 2>&1
)

cd /d "%INSTALL_DIR%"
echo Wechsle in Verzeichnis: %INSTALL_DIR% >> "%LOGFILE%"

:: 3. Python-Pakete installieren
echo.
echo [3/5] Installiere Python-Abhaengigkeiten...
echo [3/5] Installiere Python-Abhaengigkeiten... >> "%LOGFILE%"
:: Versuche 'py -3.11' (Python Launcher), da Python 3.11 zuvor installiert wurde
py -3.11 -m pip --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "PYTHON_CMD=py -3.11"
) else (
    py -m pip --version >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        set "PYTHON_CMD=py"
    ) else (
        set "PYTHON_CMD=python"
    )
)
echo Verwende Python-Befehl: %PYTHON_CMD% >> "%LOGFILE%"

%PYTHON_CMD% -m pip install --upgrade pip >> "%LOGFILE%" 2>&1
%PYTHON_CMD% -m pip install -r requirements.txt static-ffmpeg >> "%LOGFILE%" 2>&1

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
set "VBS_SCRIPT=%INSTALL_DIR%\start_alarm_durchsage.vbs"

:: VBScript erstellen um Konsolenfenster zu verstecken
(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run "cmd /c cd /d """ ^& "%INSTALL_DIR%" ^& """ & %PYTHON_CMD% durchsage.py", 0, False
) > "%VBS_SCRIPT%"
echo VBScript erstellt unter: %VBS_SCRIPT% >> "%LOGFILE%"

:: Shortcut im Autostart-Ordner erstellen via PowerShell
set "SHORTCUT_SCRIPT=%INSTALL_DIR%\create_shortcut.ps1"
(
echo $WshShell = New-Object -comObject WScript.Shell
echo $Shortcut = $WshShell.CreateShortcut("%AUTOSTART_DIR%\AlarmDurchsageServer.lnk"^)
echo $Shortcut.TargetPath = "wscript.exe"
echo $Shortcut.Arguments = """%VBS_SCRIPT%"""
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
wscript "%VBS_SCRIPT%"
echo.
echo Der Server läuft nun unsichtbar im Hintergrund. 
echo Du kannst das Webinterface im Browser aufrufen unter:
echo http://localhost:8122
echo.
echo TIPP: Es wird empfohlen, den PC bei Gelegenheit einmal neu zu starten,
echo um zu testen, ob der automatische Start (Autostart) korrekt funktioniert.
echo.
pause
