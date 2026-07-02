#!/bin/zsh
set -e

clear 2>/dev/null || true
echo "正在恢复自动显卡切换..."
echo "目标：由 macOS 根据负载自动选择集成显卡或独立显卡。"
echo

/usr/bin/osascript <<'APPLESCRIPT'
do shell script "/usr/bin/pmset -a gpuswitch 2" with administrator privileges
APPLESCRIPT

echo
echo "已恢复自动切换。"
echo "当前显卡切换设置："
/usr/bin/pmset -g | /usr/bin/grep gpuswitch
echo
if [[ -t 0 ]]; then
  echo "按任意键关闭窗口。"
  read -k 1
fi
