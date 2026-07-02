#!/bin/zsh
set -e

clear 2>/dev/null || true
echo "正在切换到性能模式..."
echo "目标：强制使用 AMD 独立显卡，提升图形性能。"
echo

/usr/bin/osascript <<'APPLESCRIPT'
do shell script "/usr/bin/pmset -a gpuswitch 1" with administrator privileges
APPLESCRIPT

echo
echo "已设置为性能模式。"
echo "当前显卡切换设置："
/usr/bin/pmset -g | /usr/bin/grep gpuswitch
echo
echo "提示：性能模式会明显增加功耗和发热。"
echo
if [[ -t 0 ]]; then
  echo "按任意键关闭窗口。"
  read -k 1
fi
