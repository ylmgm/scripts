@echo off
setlocal EnableExtensions DisableDelayedExpansion
if not "%~2"=="" goto usage
if /i "%~1"=="dp" goto dp
if /i "%~1"=="hs" goto hs
if /i "%~1"=="or" goto or
goto usage

:dp
set "profile=dp"
goto switch
:hs
set "profile=hs"
goto switch
:or
set "profile=or"

:switch
set "config_dir=%USERPROFILE%\.claude"
set "source=%config_dir%\settings.%profile%.json"
if not exist "%source%" (
    >&2 echo ERROR: Source file not found: "%source%"
    exit /b 1
)
copy /y "%source%" "%config_dir%\settings.json" >nul
if errorlevel 1 (
    >&2 echo ERROR: Failed to update settings.json.
    exit /b 1
)
echo Switched Claude settings to %profile%.
exit /b 0

:usage
>&2 echo Usage: cc dp ^| hs ^| or
exit /b 2