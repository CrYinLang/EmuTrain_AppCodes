@echo off
cd /d "%~dp0"
set PATH=%CD%;%PATH%

:loop
.\SecludedLauncher.exe --console

if %ERRORLEVEL% equ 0 (
    if exist "upgrade\" (
        xcopy upgrade\*.* . /E /I /Y > NUL
        rd /s /q upgrade
        goto loop
    )

    if exist "engine.exe" (
        .\engine.exe --console
    )
    
)

exit /b %ERRORLEVEL%
