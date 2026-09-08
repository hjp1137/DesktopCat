@echo off
setlocal
cd /d "%~dp0"
rem Godot owns the perception subprocess and stops it on exit.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_source.ps1" %*
exit /b %errorlevel%
