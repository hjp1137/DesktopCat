@echo off
chcp 65001 >nul
echo [DesktopCat] 正在启动桌宠猫与桌面窗口感知服务...
cd /d "%~dp0"

REM 1. 尝试静默拉起桌面感知服务
where pythonw >nul 2>nul
if %ERRORLEVEL% equ 0 (
    start "" pythonw tools\perception\perception_service.py
) else (
    where python >nul 2>nul
    if %ERRORLEVEL% equ 0 (
        start "" /B python tools\perception\perception_service.py
    )
)

REM 2. 启动桌面猫主程序
if exist "build\DesktopCat_Standalone.exe" (
    start "" build\DesktopCat_Standalone.exe
) else (
    echo [Error] 未找到 build\DesktopCat_Standalone.exe
    pause
)
