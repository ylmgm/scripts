@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0pp.ps1" %*
exit /b %errorlevel%
