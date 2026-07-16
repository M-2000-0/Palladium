@echo off
title Server
mode con: cols=90 lines=30
color 0F

echo.
echo  ============================================================
echo     ███████  ███████  ██████  ██    ██  ███████  ██████  ██████
echo     ██       ██       ██   ██ ██    ██ ██       ██   ██ ██   ██
echo     ███████  █████    ██████  ██    ██ █████    ██████  ██████
echo          ██  ██       ██   ██  ██  ██  ██       ██   ██ ██
echo     ███████  ███████  ██   ██   ████   ███████  ██   ██ ██
echo.
echo     Self-host. Your way.
echo  ============================================================
echo.
echo  Starting Server...
echo  Close this window to stop the server.
echo.

call palladium.bat

echo.
echo  Palladium has stopped. You may close this window.
pause
