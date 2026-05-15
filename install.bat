@echo off
REM -----------------------------------------------------------
REM  JRepo Installer for Windows
REM  Copies jrepo scripts to C:\Tools\JRepo and adds to PATH.
REM  Run as Administrator for PATH changes to take effect.
REM -----------------------------------------------------------

set "INSTALL_DIR=C:\Tools\JRepo"

echo.
echo [jrepo] ==================================================
echo [jrepo]  JRepo Installer - Windows
echo [jrepo] ==================================================
echo.

REM -- Check for admin privileges
set "IS_ADMIN=0"
net session >nul 2>&1
if %errorlevel% equ 0 (
    set "IS_ADMIN=1"
    echo [jrepo] Running as Administrator.
) else (
    echo [jrepo] WARNING: Not running as Administrator.
    echo [jrepo]   Scripts will be copied, but PATH will NOT be updated.
    echo [jrepo]   Re-run as Administrator to update PATH automatically,
    echo [jrepo]   or add %INSTALL_DIR% to your PATH manually.
    echo.
)

REM -- Create install directory
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
    echo [jrepo] Created directory: %INSTALL_DIR%
) else (
    echo [jrepo] Directory exists:  %INSTALL_DIR%
)

REM -- Copy scripts
echo [jrepo] Copying files...

copy /Y jrepo.ps1 "%INSTALL_DIR%\" >nul 2>&1 && echo [jrepo]   Copied jrepo.ps1
copy /Y jrepo.cmd "%INSTALL_DIR%\" >nul 2>&1 && echo [jrepo]   Copied jrepo.cmd
copy /Y jrepo.sh  "%INSTALL_DIR%\" >nul 2>&1 && echo [jrepo]   Copied jrepo.sh

REM -- Copy optional files (ignore if missing)
copy /Y README.md          "%INSTALL_DIR%\" >nul 2>&1 && echo [jrepo]   Copied README.md
copy /Y sample.jrepoignore "%INSTALL_DIR%\" >nul 2>&1 && echo [jrepo]   Copied sample.jrepoignore
copy /Y LICENSE            "%INSTALL_DIR%\" >nul 2>&1 && echo [jrepo]   Copied LICENSE

echo.

REM -- Update PATH
echo "%PATH%" | findstr /I /C:"%INSTALL_DIR%" >nul 2>&1
if %errorlevel% equ 0 (
    echo [jrepo] PATH: %INSTALL_DIR% is already in PATH.
) else (
    if "%IS_ADMIN%"=="1" (
        setx /M PATH "%PATH%;%INSTALL_DIR%" >nul 2>&1
        if %errorlevel% equ 0 (
            echo [jrepo] PATH: Added %INSTALL_DIR% to system PATH.
        ) else (
            echo [jrepo] WARNING: Failed to update PATH. Add manually:
            echo [jrepo]   %INSTALL_DIR%
        )
    ) else (
        echo [jrepo] PATH: Skipped (no admin). Add this to your PATH manually:
        echo [jrepo]   %INSTALL_DIR%
    )
)

REM -- Summary
echo.
echo [jrepo] ==================================================
echo [jrepo]  Installation complete!
echo [jrepo] ==================================================
echo [jrepo]  Location: %INSTALL_DIR%
echo [jrepo]
echo [jrepo]  Commands available:
echo [jrepo]    jrepo init              Create a default .jrepoignore
echo [jrepo]    jrepo push ^<UNC-PATH^>   Push current dir to remote path
echo [jrepo]    jrepo pull ^<UNC-PATH^>   Pull from remote path to current dir
echo [jrepo]    jrepo help              Show usage and flags
echo [jrepo]
echo [jrepo]  Open a NEW terminal for PATH changes to take effect.
echo [jrepo] ==================================================
echo.

pause