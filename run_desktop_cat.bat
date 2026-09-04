@echo off
setlocal
cd /d "%~dp0"

echo [DesktopCat] Starting perception service...
where pythonw >nul 2>nul
if %errorlevel% equ 0 (
    start "" pythonw tools\perception\perception_service.py
) else (
    where python >nul 2>nul
    if %errorlevel% equ 0 (
        start "" /B python tools\perception\perception_service.py
    )
)

echo [DesktopCat] Starting DesktopCat...
echo [DesktopCat] Shortcuts:
echo   V / F9: Toggle virtual cat gym display
echo   C:      Toggle mouse following
echo   ESC:    Quit DesktopCat
echo.

build\DesktopCat_console.exe --path .
