@echo off
title Git双仓库同步脚本
color 0A

echo ========================================
echo        Git双仓库同步脚本
echo ========================================

echo 强制添加所有文件...
git add --all .

echo 创建提交...
for /f "tokens=1-3 delims=/" %%a in ('date /t') do (
    set year=%%c
    set month=%%b
    set day=%%a
)
for /f "tokens=1-2 delims=:" %%a in ('time /t') do (
    set hour=%%a
    set minute=%%b
)
set commit_msg=自动同步 [%year%-%month%-%day% %hour%:%minute%]

git commit -m "%commit_msg%" --allow-empty

echo 推送到Gitee...
git push gitee-emutrain HEAD:master --force
if errorlevel 1 (
    echo Gitee推送失败
) else (
    echo Gitee推送成功
)

echo 推送到GitHub...
git push github-emutrain HEAD:main --force
if errorlevel 1 (
    echo GitHub推送失败
) else (
    echo GitHub推送成功
)

echo.
echo 完成!
echo ========================================
pause