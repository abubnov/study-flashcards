@echo off
echo Building flashcards from *.csv ...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
echo.
pause
