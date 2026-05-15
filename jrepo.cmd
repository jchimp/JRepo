@ECHO OFF

REM  jrepo.cmd - Unified JRepo tool
REM  Usage:  jrepo <command> [args]
REM  Commands: push, pull, init, help

POWERSHELL.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0jrepo.ps1' %*"
EXIT /b %errorlevel%