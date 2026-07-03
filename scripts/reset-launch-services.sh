#!/bin/bash
# 复位 WordClip 的 LaunchServices 注册。
#
# 背景：开发期若同时存在多个同 bundle id 的 WordClip.app 副本
# （命令行 .build-xcode/ 构建的 + Xcode DerivedData/ 里的 + /Applications 的），
# 它们会各自注册 wordclip: scheme。`open "wordclip://..."` 时系统可能挑中
# 非前台的副本冷启动，表现为收词时窗口闪烁 / 多开进程。
#
# 本脚本：杀掉所有实例 → 注销磁盘上所有副本的注册 → 只注册 /Applications 版 → 重启。
#
# 用法：bash scripts/reset-launch-services.sh
set -euo pipefail

LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
CANON="/Applications/WordClip.app"

echo "1) 杀掉所有 WordClip 实例"
pkill -x WordClip 2>/dev/null || true
sleep 1.5
echo "   剩余进程: $(pgrep -x WordClip | wc -l | tr -d ' ')"

echo "2) 注销磁盘上所有 WordClip.app 的 LaunchServices 注册"
while IFS= read -r app; do
  "$LSREG" -u "$app" 2>/dev/null || true
done < <(find \
  "$HOME/Library/Developer/Xcode/DerivedData" \
  "$HOME/Works/github/wordclip" \
  /Applications \
  -maxdepth 8 -name "WordClip.app" 2>/dev/null)

if [ ! -d "$CANON" ]; then
  echo "!! 未找到 $CANON —— 先构建 Release 并拷到 /Applications，或改本脚本 CANON 变量"
  exit 1
fi

echo "3) 只注册 $CANON"
"$LSREG" -f "$CANON"
sleep 1

echo "4) 当前 wordclip: scheme 注册数量: $("$LSREG" -dump 2>/dev/null | grep -c 'claimed schemes:.*wordclip')"

echo "5) 启动 $CANON"
open "$CANON"
sleep 2
echo "   进程数: $(pgrep -x WordClip | wc -l | tr -d ' ')"
echo "完成。"
