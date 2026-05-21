@ECHO off
REM -----------------------------------------------------------
REM  jRepo Installer for Windows
REM  Copies jRepo scripts to C:\Tools\jRepo and adds to PATH.
REM  Run as Administrator for PATH changes to take effect.
REM -----------------------------------------------------------

SET "INSTALL_DIR=C:\Tools\jRepo"

ECHO.
ECHO [jrepo] ==================================================
ECHO [jrepo]  jRepo Installer - Windows
ECHO [jrepo] ==================================================
ECHO.

REM -- Check for admin privileges
SET "IS_ADMIN=0"
NET SESSION >NUL 2>&1
IF %errorlevel% equ 0 (
    SET "IS_ADMIN=1"
    ECHO [jrepo] Running as Administrator.
) ELSE (
    ECHO [jrepo] WARNING: Not running as Administrator.
    ECHO [jrepo]   Scripts will be copied, but PATH will NOT be updated.
    ECHO [jrepo]   Re-run as Administrator to update PATH automatically,
    ECHO [jrepo]   or add %INSTALL_DIR% to your PATH manually.
    ECHO.
)

REM -- Create install directory
IF NOT EXIST "%INSTALL_DIR%" (
    MKDIR "%INSTALL_DIR%"
    ECHO [jrepo] Created directory: %INSTALL_DIR%
) ELSE (
    ECHO [jrepo] Directory EXISTs:  %INSTALL_DIR%
)

REM -- COPY scripts
ECHO [jrepo] COPYing files...

COPY /Y jrepo.ps1 "%INSTALL_DIR%\" >NUL 2>&1 && ECHO [jrepo]   Copied jrepo.ps1
COPY /Y jrepo.cmd "%INSTALL_DIR%\" >NUL 2>&1 && ECHO [jrepo]   Copied jrepo.cmd
COPY /Y jrepo.sh  "%INSTALL_DIR%\" >NUL 2>&1 && ECHO [jrepo]   Copied jrepo.sh

REM -- COPY optional files (ignore IF missing)
COPY /Y README.md          "%INSTALL_DIR%\" >NUL 2>&1 && ECHO [jrepo]   Copied README.md
COPY /Y sample.jrepoignore "%INSTALL_DIR%\" >NUL 2>&1 && ECHO [jrepo]   Copied sample.jrepoignore
COPY /Y LICENSE            "%INSTALL_DIR%\" >NUL 2>&1 && ECHO [jrepo]   Copied LICENSE

ECHO.

REM -- Update PATH (persistent + current session)
ECHO "%PATH%" | findstr /I /C:"%INSTALL_DIR%" >nul 2>&1
IF %errorlevel% equ 0 (
    ECHO [jrepo] PATH: %INSTALL_DIR% is already in PATH.
    GOTO :PATH_DONE
)
IF NOT "%IS_ADMIN%"=="1" (
    ECHO [jrepo] PATH: Skipped - no admin. Add this to your PATH manually:
    ECHO [jrepo]   %INSTALL_DIR%
    GOTO :PATH_DONE
)

REM -- Update SYSTEM PATH (persistent)
SETX /M PATH "%PATH%;%INSTALL_DIR%" >nul 2>&1

REM -- Update CURRENT SESSION PATH (immediate use)
SET "PATH=%PATH%;%INSTALL_DIR%"

IF %errorlevel% equ 0 (
    ECHO [jrepo] PATH: Added %INSTALL_DIR% to system PATH.
    ECHO [jrepo] PATH: Updated current session.
) ELSE (
    ECHO [jrepo] WARNING: Failed to update PATH. Add manually:
    ECHO [jrepo]   %INSTALL_DIR%
)

:PATH_DONE


REM -- Summary
ECHO.
ECHO [jrepo] ==================================================
ECHO [jrepo]  Installation complete!
ECHO [jrepo] ==================================================
ECHO [jrepo]  Location: %INSTALL_DIR%
ECHO [jrepo]
ECHO [jrepo]  Commands available:
ECHO [jrepo]    jrepo init              Create a default .jrepoignore
ECHO [jrepo]    jrepo push ^<UNC-PATH^>   Push current dir to remote path
ECHO [jrepo]    jrepo pull ^<UNC-PATH^>   Pull from remote path to current dir
ECHO [jrepo]    jrepo help              Show usage and flags
ECHO [jrepo]
ECHO [jrepo]  Open a NEW terminal for PATH changes to take effect.
ECHO [jrepo] ==================================================
ECHO.

PAUSE