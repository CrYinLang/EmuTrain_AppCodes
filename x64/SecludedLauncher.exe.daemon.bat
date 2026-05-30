@echo off

:loop
.\SecludedLauncher.exe.bat

if %ERRORLEVEL% neq 0 (
    echo.
    echo 退出码: %ERRORLEVEL%. 正在等待5秒后重启...
    timeout /t 5 /nobreak >nul
    goto loop
)

exit /b %ERRORLEVEL%
