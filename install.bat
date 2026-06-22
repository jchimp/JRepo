@ECHO off
REM -----------------------------------------------------------
REM  JRepo Installer for Windows
REM  Copies JRepo scripts to C:\Tools\JRepo and adds to PATH.
REM  Run as Administrator for PATH changes to take effect.
REM -----------------------------------------------------------

SET "INSTALL_DIR=C:\Tools\JRepo"

ECHO.
ECHO ==================================================
ECHO  JRepo Installer - Windows
ECHO ==================================================
ECHO.

REM -- Check for admin privileges
SET "IS_ADMIN=0"
NET SESSION >NUL 2>&1
IF %errorlevel% equ 0 (
    SET "IS_ADMIN=1"
    ECHO Running as Administrator.
) ELSE (
    ECHO WARNING: Not running as Administrator.
    ECHO   Scripts will be copied, but PATH will NOT be updated.
    ECHO   Re-run as Administrator to update PATH automatically,
    ECHO   or add %INSTALL_DIR% to your PATH manually.
    ECHO.
)

REM -- Create install directory
IF NOT EXIST "%INSTALL_DIR%" (
    MKDIR "%INSTALL_DIR%"
    ECHO Created directory: %INSTALL_DIR%
) ELSE (
    ECHO Directory exists:  %INSTALL_DIR%
)

REM -- COPY scripts
ECHO Copying files...

COPY /Y jrepo.ps1 "%INSTALL_DIR%\" >NUL 2>&1 && ECHO   Copied jrepo.ps1
COPY /Y jrepo.cmd "%INSTALL_DIR%\" >NUL 2>&1 && ECHO   Copied jrepo.cmd
COPY /Y jrepo.sh  "%INSTALL_DIR%\" >NUL 2>&1 && ECHO   Copied jrepo.sh

REM -- COPY optional files (ignore IF missing)
COPY /Y README.md          "%INSTALL_DIR%\" >NUL 2>&1 && ECHO   Copied README.md
COPY /Y sample.jrepoignore "%INSTALL_DIR%\" >NUL 2>&1 && ECHO   Copied sample.jrepoignore
COPY /Y LICENSE            "%INSTALL_DIR%\" >NUL 2>&1 && ECHO   Copied LICENSE

ECHO.

REM -- Update PATH (persistent + current session)
ECHO "%PATH%" | findstr /I /C:"%INSTALL_DIR%" >nul 2>&1
IF %errorlevel% equ 0 (
    ECHO PATH: %INSTALL_DIR% is already in PATH.
    GOTO :PATH_DONE
)
IF NOT "%IS_ADMIN%"=="1" (
    ECHO PATH: Skipped - no admin. Add this to your PATH manually:
    ECHO   %INSTALL_DIR%
    GOTO :PATH_DONE
)

REM -- Update SYSTEM PATH (persistent). Check SETX result BEFORE the SET below,
REM    since SET always resets errorlevel to 0 and would mask a SETX failure.
SETX /M PATH "%PATH%;%INSTALL_DIR%" >nul 2>&1
IF %errorlevel% equ 0 (
    REM -- Update CURRENT SESSION PATH (immediate use)
    SET "PATH=%PATH%;%INSTALL_DIR%"
    ECHO PATH: Added %INSTALL_DIR% to system PATH.
    ECHO PATH: Updated current session.
) ELSE (
    ECHO WARNING: Failed to update PATH. Add manually:
    ECHO   %INSTALL_DIR%
)

:PATH_DONE


REM -- Summary
ECHO.
ECHO ==================================================
ECHO  Installation complete!
ECHO ==================================================
ECHO  Location: %INSTALL_DIR%
ECHO.
ECHO  Commands available:
ECHO    jrepo init              Create a default .jrepoignore
ECHO    jrepo push ^<UNC-PATH^>   Push current dir to remote path
ECHO    jrepo pull ^<UNC-PATH^>   Pull from remote path to current dir
ECHO    jrepo help              Show usage and flags
ECHO.
ECHO  Open a NEW terminal for PATH changes to take effect.
ECHO ==================================================
ECHO.

PAUSE
