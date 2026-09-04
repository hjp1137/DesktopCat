@echo off
setlocal
cd /d "%~dp0"

where pythonw >nul 2>nul
if %errorlevel% equ 0 (
    start "" pythonw tools\perception\perception_service.py
) else (
    where python >nul 2>nul
    if %errorlevel% equ 0 (
        start "" /B python tools\perception\perception_service.py
    )
)

if exist "build\DesktopCat_Standalone.exe" (
    start "" build\DesktopCat_Standalone.exe
)
