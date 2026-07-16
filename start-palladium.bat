@echo off
title Palladium Portable Server
mode con: cols=90 lines=30
color 0B

echo.
echo  ============================================================
echo        __        __   _ _    _    ____    __  __  _   _   _
echo        \ \      / /__^| ^| ^|  ^| ^|  / ___^|  ^|  \/  ^| ^| ^| ^| ^| ^|
echo         \ \ /\ / / _ \ ^| ^|  ^| ^| ^| ^|  _   ^| ^|\  /^| ^| ^| ^| ^| ^| ^|
echo          \ V  V /  __/ ^| ^|__^| ^|___^| ^|_^| ^|  ^| ^| \/^| ^| ^|_^| ^| ^|_^|
echo           \_/\_/ \___^|_^|\____/^|_____^|  ^|_^|  ^|_^|  ^|\__,_^| \__,_^|
echo.
echo     Portable Server Manager
echo     Plug in. Power up. Host anything.
echo  ============================================================
echo.
echo  Starting Palladium...
echo  Close this window to stop the server.
echo.

cd /d "%~dp0palladium"
call palladium.bat

echo.
echo  Palladium has stopped. You may close this window.
pause
