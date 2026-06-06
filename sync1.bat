@echo off
echo ==== 开始同步 EmuTrain ====
cd /d %~dp0

echo 1. 检查当前状态...
git status
echo.

echo 2. 检查远程仓库...
git remote -v
echo.

echo 3. 尝试从Gitee获取最新代码...
git fetch gitee-emutrain master
echo.

echo 4. 检查可用分支...
git branch -a
echo.

echo 5. 重置到远程版本...
git reset --hard gitee-emutrain/master
echo.

echo 6. 同步完成！
echo 当前最新提交：
git log --oneline -1
echo.

pause