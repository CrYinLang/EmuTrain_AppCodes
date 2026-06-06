@echo off
chcp 65001 >nul
title EmuTrain 同步 - 从 Gitee 拉取
color 0B

echo ========================================
echo     EmuTrain 从 Gitee 拉取最新代码
echo ========================================
echo.

cd /d %~dp0

echo [1/4] 检查当前分支...
for /f %%i in ('git rev-parse --abbrev-ref HEAD') do set BRANCH=%%i
echo 当前分支: %BRANCH%
echo.

echo [2/4] 从 Gitee 拉取最新代码...
git fetch gitee-emutrain master
if errorlevel 1 (
    echo [错误] 拉取失败，请检查网络或远程仓库配置
    pause
    exit /b 1
)
echo.

echo [3/4] 重置到 Gitee 最新版本...
git reset --hard gitee-emutrain/master
if errorlevel 1 (
    echo [错误] 重置失败
    pause
    exit /b 1
)
echo.

echo [4/4] 同步完成！
echo.
echo 最新提交:
git log --oneline -5
echo.
echo ========================================
pause