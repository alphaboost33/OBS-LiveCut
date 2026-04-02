@echo off
setlocal enabledelayedexpansion
title OBS LiveCut - Ultimate Setup Engine
echo ===================================================
echo           OBS LIVECUT: AUTO-INSTALLER
echo ===================================================
echo.

:: 1. Check for Admin Rights
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Administrator privileges confirmed.
) else (
    echo [ERROR] Please right-click this file and "Run as Administrator".
    pause
    exit /b
)

:: 2. Define Variables
set "URL=https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
set "ZIP_FILE=%TEMP%\ffmpeg_download.zip"
set "EXTRACT_DIR=%TEMP%\ffmpeg_temp"
set "FINAL_DIR=C:\ffmpeg"

:: 3. Download FFmpeg
echo [1/4] Downloading FFmpeg from gyan.dev...
echo      (This may take a minute depending on your internet)
curl -L -o "%ZIP_FILE%" "%URL%"
if %errorLevel% neq 0 (
    echo [ERROR] Download failed. Check your internet connection.
    pause
    exit /b
)

:: 4. Extracting the ZIP
echo [2/4] Extracting files...
if exist "%EXTRACT_DIR%" rmdir /s /q "%EXTRACT_DIR%"
powershell -command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%EXTRACT_DIR%' -Force"

:: 5. Moving to C:\ffmpeg
echo [3/4] Installing to %FINAL_DIR%...
if exist "%FINAL_DIR%" rmdir /s /q "%FINAL_DIR%"
mkdir "%FINAL_DIR%"

:: The gyan.dev zip contains a subfolder like 'ffmpeg-7.0-essentials_build'
:: We find whatever that folder is named and move its contents
for /d %%i in ("%EXTRACT_DIR%\ffmpeg-*") do (
    xcopy "%%i\*" "%FINAL_DIR%\" /E /H /Y >nul
)

:: 6. Adding to System PATH
echo [4/4] Updating System Environment Variables...
:: Check if it's already in the path to avoid duplicates
echo %PATH% | findstr /I "C:\ffmpeg\bin" >nul
if %errorlevel% neq 0 (
    setx /M PATH "%PATH%;C:\ffmpeg\bin"
    echo      PATH updated successfully.
) else (
    echo      C:\ffmpeg\bin is already in your PATH.
)

:: 7. Cleanup
del "%ZIP_FILE%"
rmdir /s /q "%EXTRACT_DIR%"

echo.
echo ===================================================
echo [SUCCESS] FFmpeg is ready. OBS LiveCut can now run!
echo ===================================================
echo.
echo 1. Restart any open Command Prompts or OBS Studio.
echo 2. Type 'ffmpeg -version' in a new CMD to verify.
echo.
pause