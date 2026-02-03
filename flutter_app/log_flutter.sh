#!/bin/bash
# Flutter日志输出到文件脚本

LOG_FILE="flutter_$(date +%Y%m%d_%H%M%S).log"

echo "开始记录Flutter日志到: $LOG_FILE"

# 启动应用并记录日志
flutter run -d windows 2>&1 | tee "$LOG_FILE"
