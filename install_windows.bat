@echo off
setlocal enabledelayedexpansion

echo =========================================
echo  Alarm Durchsage - Windows Installation
echo =========================================
echo.

:: 1. System-Pakete installieren mit Winget
echo [1/4] Installiere System-Pakete (Git, Python, FFmpeg)...
winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements --silent
winget install -e --id Python.Python.3.11 --accept-package-agreements --accept-source-agreements --silent
winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements --silent

:: PATH in dieser Session aktualisieren (damit git, py und ffmpeg sofort verfuegbar sind)
echo Aktualisiere Umgebungsvariablen...
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%B"
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%B"
set "PATH=%SYS_PATH%;%USR_PATH%;%PATH%"

:: 2. Repository klonen
echo.
echo [2/4] Klone Repository...
set "INSTALL_DIR=%USERPROFILE%\alarm_durchsage"
if not exist "%INSTALL_DIR%" (
    git clone https://github.com/Jupiter79/alarm_durchsage "%INSTALL_DIR%"
) else (
    echo Verzeichnis %INSTALL_DIR% existiert bereits.
)

cd /d "%INSTALL_DIR%"

:: 3. Python-Pakete installieren
echo.
echo [3/4] Installiere Python-Abhaengigkeiten...
:: Versuche 'py' (Python Launcher), falls 'python' nicht im PATH ist
py -m pip --version >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    set "PYTHON_CMD=py"
) else (
    set "PYTHON_CMD=python"
)

%PYTHON_CMD% -m pip install --upgrade pip
%PYTHON_CMD% -m pip install fastapi pydantic uvicorn pydub pygame edge-tts requests python-socketio python-multipart audioop-lts zeroconf

:: 4. Autostart einrichten
echo.
echo [4/4] Richte Autostart ein...
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
echo Installation erfolgreich abgeschlossen!
echo =========================================
echo Der Service wird beim naechsten Neustart automatisch im Hintergrund gestartet.
echo.
echo Um den Service JETZT zu starten, fuehre folgende Datei aus:
echo %VBS_SCRIPT%
echo.
pause
