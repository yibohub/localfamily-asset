@echo off
REM Flutter日志输出到文件脚本（Windows）

set LOG_FILE=flutter_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
set LOG_FILE=%LOG_FILE: =0%

echo 开始记录Flutter日志到: %LOG_FILE%
echo.

flutter run -d windows 2>&1 | tee -a %LOG_FILE%

echo.
echo 日志已保存到: %LOG_FILE%
pause
