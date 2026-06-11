@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

set "URL=http://127.0.0.1:5173/"

echo Starting campus drone delivery dashboard...
echo.
echo Keep this window open while using the webpage.
echo Close this window to stop the local backend.
echo.

start "" powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 2; Start-Process '%URL%'"

where py >nul 2>nul
if %errorlevel%==0 (
  py -3 backend_server.py
  goto :end
)

where python >nul 2>nul
if %errorlevel%==0 (
  python backend_server.py
  goto :end
)

echo Python was not found.
echo Please install Python 3 first, then double-click start_web.bat again.
echo Download: https://www.python.org/downloads/

:end
pause
