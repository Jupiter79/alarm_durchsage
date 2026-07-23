@echo off
setlocal enabledelayedexpansion

echo =========================================
echo  Alarm Durchsage - Windows Installation
echo =========================================
echo.

:: 1. System-Pakete installieren mit Winget (Python und Git)
echo [1/5] Installiere System-Pakete (Python und Git)...
winget install -e --id Python.Python.3.11 --accept-package-agreements --accept-source-agreements --silent
winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements --silent

:: PATH in dieser Session aktualisieren (damit py sofort verfuegbar ist)
echo Aktualisiere Umgebungsvariablen...
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%B"
set "PATH=%SYS_PATH%;%USR_PATH%;%PATH%"

:: 2. Projekt klonen
echo.
echo [2/5] Lade Projekt herunter...
set "INSTALL_DIR=%USERPROFILE%\alarm_durchsage"
if not exist "%INSTALL_DIR%" (
    git clone https://github.com/Jupiter79/alarm_durchsage.git "%INSTALL_DIR%"
) else (
    echo Verzeichnis existiert bereits. Hole neueste Updates...
    cd /d "%INSTALL_DIR%"
    git pull
)

cd /d "%INSTALL_DIR%"

:: 3. Python-Pakete installieren
echo.
echo [3/5] Installiere Python-Abhaengigkeiten...
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

%PYTHON_CMD% -m pip install --upgrade pip
%PYTHON_CMD% -m pip install fastapi pydantic uvicorn pydub pygame edge-tts requests python-socketio python-multipart static-ffmpeg

:: 3b. FFmpeg lokal einrichten (100% verlaesslich, ohne PATH-Probleme)
echo.
echo [4/5] Richte FFmpeg lokal ein...
%PYTHON_CMD% -c "import static_ffmpeg; static_ffmpeg.add_paths(); import shutil, os; shutil.copy(shutil.which('ffmpeg'), '.'); shutil.copy(shutil.which('ffprobe'), '.')" >nul 2>&1

:: 4. Autostart einrichten
echo.
echo [5/5] Richte Autostart ein...
set "AUTOSTART_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "VBS_SCRIPT=%INSTALL_DIR%\start_alarm_durchsage.vbs"

:: VBScript erstellen um Konsolenfenster zu verstecken
(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run "cmd /c cd /d """ ^& "%INSTALL_DIR%" ^& """ & %PYTHON_CMD% durchsage.py", 0, False
) > "%VBS_SCRIPT%"

:: Shortcut im Autostart-Ordner erstellen via PowerShell
set "SHORTCUT_SCRIPT=%INSTALL_DIR%\create_shortcut.ps1"
(
echo $WshShell = New-Object -comObject WScript.Shell
echo $Shortcut = $WshShell.CreateShortcut("%AUTOSTART_DIR%\AlarmDurchsage.lnk"^)
echo $Shortcut.TargetPath = "wscript.exe"
echo $Shortcut.Arguments = """%VBS_SCRIPT%"""
echo $Shortcut.WorkingDirectory = "%INSTALL_DIR%"
echo $Shortcut.Description = "Alarm Durchsage Autostart"
echo $Shortcut.Save^(^)
) > "%SHORTCUT_SCRIPT%"

powershell -ExecutionPolicy Bypass -File "%SHORTCUT_SCRIPT%"
del "%SHORTCUT_SCRIPT%"

echo.
echo =========================================
echo Installation fast abgeschlossen!
echo =========================================
echo WICHTIG: Damit die installierten Programme (wie FFmpeg) richtig
echo vom System erkannt werden, MUSS der PC einmal neu gestartet werden.
echo.
echo Nach dem Neustart startet der Service automatisch im Hintergrund.
echo.
set /p RESTART="Moechtest du den PC jetzt neu starten? (J/N): "
if /i "%RESTART%"=="J" (
    echo Neustart wird eingeleitet...
    shutdown /r /t 5
) else (
    echo.
    echo Bitte vergiss nicht, den PC spaeter manuell neu zu starten!
    echo Um den Service danach manuell zu testen, fuehre folgende Datei aus:
    echo %VBS_SCRIPT%
    echo.
    pause
)
